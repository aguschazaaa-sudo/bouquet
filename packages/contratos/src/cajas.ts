/**
 * Las cajas sugeridas: las que ofrece el vendedor ya armadas.
 *
 * Una caja sugerida NO es un producto. Es una lista de `productoId` con un
 * nombre: no tiene precio propio -el precio es la suma de lo que quede en el
 * carrito-, no tiene stock propio, y no tiene documento en `productos`.
 * Elegirla LLENA el carrito; desde ahi el comprador cambia lo que quiera.
 *
 * openspec/changes/cajas-de-seis/specs/cajas-sugeridas.
 *
 * ---
 *
 * LA VALIDACION VA EN DOS TIEMPOS, y es a proposito:
 *
 *   1. `validarCajasSugeridas` mira la FORMA, sin catalogo. Es lo que puede
 *      correr sin saber cuantas botellas trae cada vino.
 *   2. `verificarComposicion` mira que la caja SUME una caja. Necesita el
 *      catalogo, y la corre el seed -- que ve el catalogo entero, publicado o
 *      no.
 *
 * Si la suma se exigiera al renderizar, una sugerencia con un vino
 * despublicado se caeria entera: no habria forma de saber cuantas botellas
 * traia el que falta. Y la spec pide lo contrario -- mostrarla con el lugar
 * marcado, porque cinco vinos siguen siendo una idea valida.
 */

import { agregar, BOTELLAS_POR_CAJA, esProductoId, type Carrito } from './carrito.ts';
import type { Descarte, ProductoPublicado, Validacion } from './producto.ts';

const SLUG = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;

function esObjeto(x: unknown): x is Record<string, unknown> {
  return typeof x === 'object' && x !== null && !Array.isArray(x);
}

function esTextoNoVacio(x: unknown): x is string {
  return typeof x === 'string' && x.trim().length > 0;
}

// -------------------------------------------------------------------- tipos

export interface CajaSugerida {
  readonly slug: string;
  readonly nombre: string;
  /**
   * Un id por BOTELLA, no por linea: repetir un id son dos botellas de ese
   * vino. Asi la suma es directa y llenar el carrito es un `agregar` por
   * entrada, que ya acumula solo.
   *
   * Por eso la lista tiene entre 1 y BOTELLAS_POR_CAJA entradas: un pack de 2
   * botellas ocupa UNA entrada y aporta 2.
   */
  readonly productoIds: readonly string[];
}

export interface CajasArmadas {
  readonly cajas: readonly CajaSugerida[];
  /** Lo que quedo afuera y por que. Lo loguea el servidor; no llega a la pagina. */
  readonly descartes: readonly Descarte[];
}

// ---------------------------------------------------------------- 1. la forma

function validarUna(x: unknown, donde: string): Validacion<CajaSugerida> {
  if (!esObjeto(x)) return { ok: false, motivo: `${donde}: no es un mapa` };
  if (!(typeof x.slug === 'string' && SLUG.test(x.slug))) {
    return { ok: false, motivo: `${donde}: slug invalido: ${String(x.slug)}` };
  }
  if (!esTextoNoVacio(x.nombre)) return { ok: false, motivo: `${donde}: nombre falta` };
  const ids = x.productoIds;
  if (!Array.isArray(ids) || ids.length === 0) {
    return { ok: false, motivo: `${donde}: productoIds tiene que ser una lista no vacia` };
  }
  // Cada entrada aporta AL MENOS una botella, asi que mas entradas que el
  // tamano de la caja no puede sumar una caja ni de casualidad.
  if (ids.length > BOTELLAS_POR_CAJA) {
    return { ok: false, motivo: `${donde}: ${ids.length} entradas para una caja de ${BOTELLAS_POR_CAJA}` };
  }
  const fuera = ids.filter((id) => !esProductoId(id));
  if (fuera.length) {
    return { ok: false, motivo: `${donde}: productoId invalido: ${JSON.stringify(fuera)}` };
  }
  return { ok: true, valor: { slug: x.slug, nombre: x.nombre, productoIds: [...(ids as string[])] } };
}

/**
 * Valida el documento crudo de cajas sugeridas. El Admin SDK no pasa por las
 * reglas, asi que un documento roto PUEDE existir: esto es lo que impide que
 * tire el render de `/vinos`.
 *
 * `undefined` y `null` NO son un error: el documento todavia no existe porque
 * el vendedor no cargo ninguna caja. Mismo criterio que `leerUnidades` con
 * `metricas/popularidad`.
 */
export function validarCajasSugeridas(datos: unknown): CajasArmadas {
  const descartes: Descarte[] = [];
  if (datos === undefined || datos === null) return { cajas: [], descartes };

  if (!esObjeto(datos) || !Array.isArray(datos.cajas)) {
    descartes.push({ id: 'cajasSugeridas', motivo: 'el documento no tiene la forma { cajas: [...] }' });
    return { cajas: [], descartes };
  }

  const validas: CajaSugerida[] = [];
  datos.cajas.forEach((cruda, i) => {
    const v = validarUna(cruda, `cajas[${i}]`);
    if (v.ok) validas.push(v.valor);
    else descartes.push({ id: `cajasSugeridas.cajas[${i}]`, motivo: v.motivo });
  });

  // Dos cajas con el mismo slug quedan afuera LAS DOS: elegir una seria elegir
  // al azar cual de las dos composiciones se ofrece. Mismo criterio que
  // `armarCatalogo` con los slugs de producto.
  const veces = new Map<string, number>();
  for (const c of validas) veces.set(c.slug, (veces.get(c.slug) ?? 0) + 1);

  const cajas = validas.filter((c) => {
    if ((veces.get(c.slug) ?? 0) > 1) {
      descartes.push({ id: `cajasSugeridas/${c.slug}`, motivo: `slug duplicado: ${c.slug}` });
      return false;
    }
    return true;
  });

  return { cajas, descartes };
}

// --------------------------------------------------------- 2. la composicion

/**
 * Que la caja SUME una caja. Necesita el catalogo, asi que la corren el seed y
 * CI, no el render.
 *
 * `botellasPorProducto` mapea id -> `presentacion.botellas`. Un id que no este
 * en el mapa es un error de composicion: el vendedor nombro un vino que no
 * existe.
 *
 * ⚠️ Hoy la corre SOLO `seed.mjs`. No la corre CI: si manana un panel escribe
 * cajas por una callable, esa callable tiene que llamarla a mano -- el
 * invariante vive en una convencion, no en una frontera.
 */
export function verificarComposicion(
  caja: CajaSugerida,
  botellasPorProducto: ReadonlyMap<string, number>,
): Validacion<number> {
  let botellas = 0;
  for (const id of caja.productoIds) {
    const b = botellasPorProducto.get(id);
    if (b === undefined) {
      return { ok: false, motivo: `${caja.slug}: el producto ${id} no existe` };
    }
    botellas += b;
  }
  if (botellas !== BOTELLAS_POR_CAJA) {
    return { ok: false, motivo: `${caja.slug}: suma ${botellas} botellas y la caja es de ${BOTELLAS_POR_CAJA}` };
  }
  return { ok: true, valor: botellas };
}

// ------------------------------------------------------------ 3. el resuelto

/**
 * `sin-suficiente` NO es `agotado`: del vino hay, lo que no hay es para OTRA
 * unidad de esta misma caja. Meterlo a presion en `agotado` hacia que la
 * tarjeta mostrara el mismo vino dos veces, una normal y otra con "Se agoto",
 * sobre un vino que esta a la venta. Lo marco revisor-pagos.
 */
export const ESTADOS_DE_LUGAR = ['vigente', 'agotado', 'sin-suficiente', 'no-disponible'] as const;
export type EstadoDeLugar = (typeof ESTADOS_DE_LUGAR)[number];

export interface LugarDeCaja {
  readonly productoId: string;
  /** null si el producto no esta en la proyeccion: despublicado o borrado. */
  readonly producto: ProductoPublicado | null;
  readonly estado: EstadoDeLugar;
}

export interface CajaSugeridaResuelta {
  readonly slug: string;
  readonly nombre: string;
  readonly lugares: readonly LugarDeCaja[];
  /** Botellas de los lugares vigentes. Puede ser menos que la caja. */
  readonly botellasVigentes: number;
  /** true si todos los lugares estan vigentes y suman la caja entera. */
  readonly completa: boolean;
}

export interface CajasResueltas {
  readonly cajas: readonly CajaSugeridaResuelta[];
  readonly descartes: readonly Descarte[];
}

/**
 * El join contra la proyeccion, EN MEMORIA.
 *
 * Nunca con un `get()` por id: seis ids por caja y seis cajas son 36 lecturas
 * por reconstruccion -- 32 -> 68, mas que el doble, y 133 % de la cuota con el
 * catalogo del MVP a 250 visitas. Los filtros del catalogo ya se resuelven asi
 * (ADR 004 §3); aca la misma disciplina vale 30x.
 *
 * Una sugerencia con un vino caido se muestra IGUAL, con el lugar marcado. Solo
 * se descarta cuando se puede juzgar que esta mal: todos sus vinos existen y
 * aun asi no suman una caja.
 */
export function resolverCajasSugeridas(
  cajas: readonly CajaSugerida[],
  productos: readonly ProductoPublicado[],
): CajasResueltas {
  const porId = new Map(productos.map((p) => [p.id, p]));
  const descartes: Descarte[] = [];
  const resueltas: CajaSugeridaResuelta[] = [];

  for (const caja of cajas) {
    // Cuantas unidades de cada producto ya se comprometieron en ESTA caja: un
    // id repetido pide dos, y el `tope` puede dar para una sola.
    //
    // ⚠️ Sin esto la tarjeta decia "6 botellas, completa" y el boton entregaba
    // cinco, porque `llenarConLaCaja` si respeta el tope. Dos cuentas de lo
    // mismo que no coinciden es LECCIONES 6.4, el motivo por el que este
    // archivo comparte `esProductoId` en vez de copiarlo.
    const comprometidas = new Map<string, number>();

    const lugares = caja.productoIds.map((productoId): LugarDeCaja => {
      const producto = porId.get(productoId) ?? null;
      if (producto === null) return { productoId, producto, estado: 'no-disponible' };
      if (producto.balde === 'agotado' || producto.tope <= 0) {
        return { productoId, producto, estado: 'agotado' };
      }
      const yaPedidas = comprometidas.get(productoId) ?? 0;
      if (yaPedidas >= producto.tope) {
        // Hay vino, pero no alcanza para otra unidad de ESTA caja.
        return { productoId, producto, estado: 'sin-suficiente' };
      }
      comprometidas.set(productoId, yaPedidas + 1);
      return { productoId, producto, estado: 'vigente' };
    });

    const todosPresentes = lugares.every((l) => l.producto !== null);
    const botellasDeclaradas = lugares.reduce((n, l) => n + (l.producto?.botellas ?? 0), 0);

    // Solo se juzga la suma cuando se la puede juzgar: con todos los vinos a la
    // vista. Si falta uno, no hay forma de saber cuantas botellas traia.
    if (todosPresentes && botellasDeclaradas !== BOTELLAS_POR_CAJA) {
      descartes.push({
        id: `cajasSugeridas/${caja.slug}`,
        motivo: `suma ${botellasDeclaradas} botellas y la caja es de ${BOTELLAS_POR_CAJA}`,
      });
      continue;
    }

    const botellasVigentes = lugares
      .filter((l) => l.estado === 'vigente')
      .reduce((n, l) => n + (l.producto?.botellas ?? 0), 0);

    resueltas.push({
      slug: caja.slug,
      nombre: caja.nombre,
      lugares,
      botellasVigentes,
      // `todosPresentes` tambien: si falta un producto no se pudo juzgar la
      // suma declarada, asi que "completa" seria una afirmacion sobre una
      // composicion que nunca se valido.
      completa: todosPresentes && botellasVigentes === BOTELLAS_POR_CAJA,
    });
  }

  return { cajas: resueltas, descartes };
}

// ----------------------------------------------------------- 4. al carrito

/**
 * Llena el carrito con una caja sugerida.
 *
 * AGREGA, no reemplaza: si el comprador ya tenia algo, se suma. Borrar lo suyo
 * para meter una sugerencia seria decidir por el, y el carrito ya sabe decir
 * que le sobran dos.
 *
 * Los lugares caidos se saltean -no hay que agregar- y el `tope` de cada vino
 * se respeta, asi que la caja PUEDE quedar incompleta. Eso no se oculta: lo
 * dice `estadoDeLaCaja` sobre el carrito resultante.
 *
 * Vive aca y no en un `onClick` porque es logica de carrito, y en un manejador
 * de evento no la prueba nadie.
 */
export function llenarConLaCaja(carrito: Carrito, caja: CajaSugeridaResuelta): Carrito {
  let resultado = carrito;
  for (const lugar of caja.lugares) {
    if (lugar.estado !== 'vigente' || lugar.producto === null) continue;
    const { id, botellas, tope } = lugar.producto;
    resultado = agregar(resultado, { productoId: id, botellas, tope }, 1).carrito;
  }
  return resultado;
}
