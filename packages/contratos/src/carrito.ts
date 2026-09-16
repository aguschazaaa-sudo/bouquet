/**
 * El carrito: lo que guarda el navegador, y el pedido que va a recibir
 * `crearOrden`.  ADR 008.
 *
 * El carrito NO lleva precios ni nombres. El precio sale siempre de la
 * proyeccion del momento, asi que un carrito viejo no puede "recordar" un
 * precio que ya no existe. El precio que el comprador VIO viaja aparte, en
 * `PedidoDeCompra`, para que `crearOrden` rechace -en vez de cobrar otro monto-
 * si cambio en el medio.
 *
 * `parsearCarrito` es el UNICO lugar que valida un carrito: lo usa el navegador
 * al leer `localStorage` y lo va a usar `crearOrden` al recibir el pedido. Dos
 * validadores del mismo dato se desincronizan (LECCIONES 6.4).
 */

import { CERO, porCantidad, sumar, type Centavos } from './dinero.ts';
import { TOPE_POR_PEDIDO, viajaSolo, type ProductoPublicado, type Validacion } from './producto.ts';

/**
 * 2 desde las cajas de seis: la linea guarda tambien `botellas`. Un carrito
 * `version: 1` NO se migra, se DESCARTA -- se cambio antes de que la tienda se
 * desplegara, asi que no habia un solo carrito real al que le pasara.
 */
export const VERSION_DEL_CARRITO = 2;

export interface LineaDeCarrito {
  readonly productoId: string;
  readonly cantidad: number;
  /**
   * Botellas por unidad de venta de ESE producto.
   *
   * Es lo UNICO del producto que el carrito guarda, y la excepcion esta
   * razonada. ADR 008 prohibe guardar precio y nombre porque "un carrito viejo
   * no puede recordar un precio que ya no existe"; `presentacion` es INMUTABLE
   * por regla de Firestore, asi que esto no es un snapshot que envejece, es un
   * hecho que no se mueve.
   *
   * Existe porque el contador de la barra vive en TODAS las rutas y solo lee
   * `localStorage`: sin este campo no puede decir cuantas botellas hay, y con
   * un pack de 2 en el carrito mostraria un numero distinto al de la pagina.
   *
   * NO es la fuente de verdad: `resolverCarrito` lo recalcula contra la
   * proyeccion y lo corrige si no coincide.
   */
  readonly botellas: number;
}

/** Lo que hace falta saber de un producto para ponerlo en el carrito. */
export interface ProductoDelCarrito {
  readonly productoId: string;
  readonly botellas: number;
  /** Unidades de venta, no botellas: `min(stock, 12)`. */
  readonly tope: number;
}

export interface Carrito {
  readonly version: typeof VERSION_DEL_CARRITO;
  /** Clave de idempotencia de `crearOrden`. Nace en el navegador y se renueva despues de cada orden. */
  readonly idCompra: string;
  readonly lineas: readonly LineaDeCarrito[];
}

/**
 * Sin `/` ni `.`: el id termina en una ruta de Firestore, y `productos/${id}`
 * con una barra adentro apunta a OTRO documento.
 */
const PRODUCTO_ID = /^[A-Za-z0-9_-]{1,128}$/;

/** Firestore reserva los ids `__…__`: ninguno es un producto. */
const RESERVADO = /^__.*__$/;

/**
 * Exportado para que `cajas.ts` valide los ids con ESTA regla y no con una
 * copia. LECCIONES 6.4: dos validadores del mismo dato se desincronizan.
 */
export const esProductoId = (x: unknown): x is string =>
  typeof x === 'string' && PRODUCTO_ID.test(x) && !RESERVADO.test(x);

/** `crypto.randomUUID()` da 36; el rango deja lugar sin aceptar basura. */
const ID_COMPRA = /^[A-Za-z0-9_-]{16,64}$/;

function esObjeto(x: unknown): x is Record<string, unknown> {
  return typeof x === 'object' && x !== null && !Array.isArray(x);
}

function soloClaves(x: Record<string, unknown>, permitidas: readonly string[]): boolean {
  return Object.keys(x).every((k) => permitidas.includes(k));
}

/**
 * RECHAZA lo que no cumple; no lo corrige. Un carrito con una cantidad negativa
 * no es un carrito con una cantidad a arreglar: es un dato que alguien toco, y
 * adivinar que quiso decir es exactamente lo que no se hace con plata.
 */
export function parsearCarrito(entrada: unknown): Validacion<Carrito> {
  let valor = entrada;
  if (typeof entrada === 'string') {
    try {
      valor = JSON.parse(entrada);
    } catch {
      return { ok: false, motivo: 'el carrito no es JSON' };
    }
  }
  if (!esObjeto(valor) || !soloClaves(valor, ['version', 'idCompra', 'lineas'])) {
    return { ok: false, motivo: 'el carrito no tiene la forma {version, idCompra, lineas}' };
  }
  if (valor.version !== VERSION_DEL_CARRITO) {
    return { ok: false, motivo: `version desconocida: ${String(valor.version)}` };
  }
  if (!(typeof valor.idCompra === 'string' && ID_COMPRA.test(valor.idCompra))) {
    return { ok: false, motivo: 'idCompra invalido' };
  }
  if (!Array.isArray(valor.lineas)) return { ok: false, motivo: 'lineas no es una lista' };

  const vistos = new Set<string>();
  const lineas: LineaDeCarrito[] = [];
  for (const l of valor.lineas) {
    if (!esObjeto(l) || !soloClaves(l, ['productoId', 'cantidad', 'botellas'])) {
      return { ok: false, motivo: 'una linea no tiene la forma {productoId, cantidad, botellas}' };
    }
    if (!esProductoId(l.productoId)) {
      return { ok: false, motivo: `productoId invalido: ${String(l.productoId)}` };
    }
    if (vistos.has(l.productoId)) return { ok: false, motivo: `productoId repetido: ${l.productoId}` };
    vistos.add(l.productoId);
    const c = l.cantidad;
    if (!(typeof c === 'number' && Number.isInteger(c) && c >= 1 && c <= TOPE_POR_PEDIDO)) {
      return { ok: false, motivo: `cantidad invalida en ${l.productoId}: ${String(c)}` };
    }
    const b = l.botellas;
    // ⚠️ SIN techo por arriba, y es deliberado. Se probo ponerle uno (24) y
    // fue PEOR: `validarProducto` y `firestore.rules` no lo tienen, asi que un
    // producto legitimo de 25 botellas lo escribe `fijarCantidad` sin chistar y
    // despues este parser rechaza el carrito ENTERO al releerlo -- se pierden
    // tambien los otros cinco vinos, y rota el idCompra. Lo encontro
    // revisor-pagos el 2026-09-14.
    //
    // La regla general: un validador no puede rechazar lo que su propio
    // escritor produce legitimamente. Si alguna vez se quiere el techo, va en
    // `validarProducto` Y en las reglas, para que un producto asi no llegue
    // nunca a la proyeccion.
    if (!(typeof b === 'number' && Number.isInteger(b) && b >= 1)) {
      return { ok: false, motivo: `botellas invalidas en ${l.productoId}: ${String(b)}` };
    }
    lineas.push({ productoId: l.productoId, cantidad: c, botellas: b });
  }
  return { ok: true, valor: { version: VERSION_DEL_CARRITO, idCompra: valor.idCompra, lineas } };
}

export function carritoVacio(idCompra: string): Carrito {
  if (!ID_COMPRA.test(idCompra)) throw new RangeError(`idCompra invalido: ${idCompra}`);
  return { version: VERSION_DEL_CARRITO, idCompra, lineas: [] };
}

// ------------------------------------------------------------- operaciones

export interface Cambio {
  readonly carrito: Carrito;
  /** true si lo pedido pasaba el tope: la cantidad quedo en el tope y la pantalla lo dice. */
  readonly alTope: boolean;
}

/** Deja la linea en `cantidad`, sin pasar el tope. Con tope 0 (agotado) no agrega nada. */
export function fijarCantidad(carrito: Carrito, producto: ProductoDelCarrito, cantidad: number): Cambio {
  const { productoId, botellas, tope } = producto;
  if (!esProductoId(productoId)) throw new RangeError(`productoId invalido: ${productoId}`);
  if (!Number.isInteger(botellas) || botellas < 1) {
    throw new RangeError(`botellas va entero y >= 1; llego ${botellas}`);
  }
  if (!Number.isInteger(cantidad) || cantidad < 1) {
    throw new RangeError(`la cantidad va entera y >= 1; llego ${cantidad}`);
  }
  if (tope <= 0) return { carrito, alTope: true };

  const nueva = Math.min(cantidad, tope);
  const existe = carrito.lineas.some((l) => l.productoId === productoId);
  const lineas = existe
    ? carrito.lineas.map((l) => (l.productoId === productoId ? { productoId, cantidad: nueva, botellas } : l))
    : [...carrito.lineas, { productoId, cantidad: nueva, botellas }];
  return { carrito: { ...carrito, lineas }, alTope: cantidad > tope };
}

/** Suma `cantidad` a lo que ya habia de ese vino, sin pasar su tope. */
export function agregar(carrito: Carrito, producto: ProductoDelCarrito, cantidad: number): Cambio {
  if (!Number.isInteger(cantidad) || cantidad < 1) {
    throw new RangeError(`se agrega de a enteros >= 1; llego ${cantidad}`);
  }
  const actual = carrito.lineas.find((l) => l.productoId === producto.productoId)?.cantidad ?? 0;
  return fijarCantidad(carrito, producto, actual + cantidad);
}

export function quitar(carrito: Carrito, productoId: string): Carrito {
  return { ...carrito, lineas: carrito.lineas.filter((l) => l.productoId !== productoId) };
}

/** Lo que muestra el contador de la barra. Sale de `localStorage`: cero lecturas. */
export function unidadesEnCarrito(carrito: Carrito): number {
  return carrito.lineas.reduce((n, l) => n + l.cantidad, 0);
}

// ------------------------------------------------ carrito contra proyeccion

export const ESTADOS_DE_LINEA = ['vigente', 'agotada', 'no-disponible'] as const;
export type EstadoDeLinea = (typeof ESTADOS_DE_LINEA)[number];

export interface LineaResuelta {
  readonly productoId: string;
  readonly cantidad: number;
  /** null si el producto ya no esta en la proyeccion: despublicado o borrado. */
  readonly producto: ProductoPublicado | null;
  readonly estado: EstadoDeLinea;
  /** true si la cantidad se bajo al tope de hoy. */
  readonly ajustada: boolean;
  /** CERO si la linea no esta vigente: lo que no se puede vender no suma. */
  readonly subtotal: Centavos;
}

export interface CarritoResuelto {
  readonly lineas: readonly LineaResuelta[];
  readonly total: Centavos;
  /** El carrito con las cantidades ajustadas. Se GUARDA antes de mostrar el total. */
  readonly carrito: Carrito;
  /** true si `carrito` cambio y hay que guardarlo. */
  readonly ajustado: boolean;
}

/**
 * Une el carrito con la proyeccion de hoy. El total es la suma de `precio x
 * cantidad` de las lineas vigentes, con la plata de `dinero.ts`, y es el mismo
 * calculo que va a repetir `crearOrden`: el total que ve el comprador no puede
 * salir de otra cuenta.
 *
 * Una linea agotada CONSERVA su cantidad en vez de bajar a 0: el parser rechaza
 * cantidades < 1, asi que bajarla dejaria guardado un carrito invalido, que en
 * la proxima visita se descartaria entero.
 */
export function resolverCarrito(carrito: Carrito, productos: readonly ProductoPublicado[]): CarritoResuelto {
  const porId = new Map(productos.map((p) => [p.id, p]));

  const lineas = carrito.lineas.map((l): LineaResuelta => {
    const producto = porId.get(l.productoId) ?? null;
    if (producto === null) {
      return { productoId: l.productoId, cantidad: l.cantidad, producto, estado: 'no-disponible', ajustada: false, subtotal: CERO };
    }
    if (producto.balde === 'agotado' || producto.tope <= 0) {
      return { productoId: l.productoId, cantidad: l.cantidad, producto, estado: 'agotada', ajustada: false, subtotal: CERO };
    }
    const cantidad = Math.min(l.cantidad, producto.tope);
    return {
      productoId: l.productoId,
      cantidad,
      producto,
      estado: 'vigente',
      ajustada: cantidad !== l.cantidad,
      subtotal: porCantidad(producto.precio, cantidad),
    };
  });

  // Las `botellas` guardadas se RECALCULAN contra la proyeccion. El campo
  // existe para que el contador de la barra no tenga que leer Firestore, no
  // para ser la verdad: si un producto se borro y se recreo con otra
  // presentacion -el hallazgo 1 de revisor-pagos-, aca se corrige y se guarda.
  // De un vino que ya no esta se conserva lo guardado: no hay con que mejorarlo.
  const reconstruidas = lineas.map(({ productoId, cantidad, producto }, i) => ({
    productoId,
    cantidad,
    botellas: producto?.botellas ?? carrito.lineas[i]!.botellas,
  }));

  const cambio = reconstruidas.some(
    (l, i) => l.cantidad !== carrito.lineas[i]!.cantidad || l.botellas !== carrito.lineas[i]!.botellas,
  );

  return {
    lineas,
    total: sumar(...lineas.map((l) => l.subtotal)),
    carrito: cambio ? { ...carrito, lineas: reconstruidas } : carrito,
    ajustado: cambio,
  };
}

// ------------------------------------------------------------------ la caja

/**
 * La botella SUELTA viaja en cajas FISICAS de esta cantidad: sola no tiene con
 * que viajar, asi que se vende de a seis.
 *
 * ⚠️ NO alcanza a lo que viene en su propia caja. Un producto de 2 botellas
 * trae su embalaje y viaja solo: no cuenta para este numero, no lo completa y
 * no lo rompe (`viajaSolo`, ADR 009 §10).
 *
 * El numero vive SOLO aca. El dia que se consigan cajas de 3, se cambia esta
 * linea y sus tests, y nada mas: ningun otro archivo escribe el 6 para esta
 * regla.
 */
export const BOTELLAS_POR_CAJA = 6;

/**
 * TODAS las botellas vigentes del carrito: `cantidad x presentacion.botellas`,
 * las sueltas y las que vienen en su propia caja.
 *
 * Es lo que el comprador se lleva, y por eso lo dice el rotulo del total. NO es
 * lo que mide la regla de la caja -- para eso esta `botellasSueltas`. Son dos
 * numeros distintos a proposito, porque contestan dos preguntas distintas:
 * "cuanto vino me llevo" y "me falta algo para poder despacharlo".
 *
 * Cuenta BOTELLAS, no unidades de venta. Un producto de 2 botellas aporta 2, y
 * el catalogo de muestra ya tiene dos de esos sobre veinte: contar unidades
 * daria el numero equivocado desde el primer dia. Es la misma unidad en la que
 * `balde` mide el stock.
 *
 * Las lineas agotadas y las de un vino que ya no esta NO cuentan, igual que no
 * suman al total: una botella que no se puede vender no llena una caja.
 */
export function botellasEnCarrito(resuelto: CarritoResuelto): number {
  let botellas = 0;
  for (const l of resuelto.lineas) {
    if (l.estado !== 'vigente' || l.producto === null) continue;
    botellas += l.cantidad * l.producto.botellas;
  }
  return botellas;
}

/**
 * Las botellas que NECESITAN la caja de seis: las que se venden sueltas.
 *
 * Lo que viene en su propia caja queda afuera de esta cuenta -- no suma ni
 * resta. Es la regla que decidio el dueno el 2026-09-15: *"los vinos que vienen
 * en cajas se venden sueltos, tienen su propio packaging, asi que pueden viajar
 * solos: no cuentan para la caja de 6"*.
 *
 * ⚠️ Un carrito de 4 sueltas + un pack de 2 tiene SEIS botellas y NO se puede
 * cobrar: las cuatro sueltas siguen sin caja. La pantalla tiene que decir ese
 * numero -4- y no el total, o el comprador ve seis y un boton que no aparece.
 */
export function botellasSueltas(resuelto: CarritoResuelto): number {
  let botellas = 0;
  for (const l of resuelto.lineas) {
    if (l.estado !== 'vigente' || l.producto === null) continue;
    if (viajaSolo(l.producto)) continue;
    botellas += l.cantidad * l.producto.botellas;
  }
  return botellas;
}

/**
 * Las botellas segun lo GUARDADO, sin catalogo. Es lo que puede saber el
 * contador de la barra, que vive en todas las rutas y no lee Firestore.
 *
 * No distingue lo agotado de lo vigente -para eso hace falta la proyeccion-,
 * asi que puede decir un numero mas alto que el de `/carrito`, que es la
 * fuente de verdad. Es el precio de que la barra cueste cero lecturas.
 */
export function botellasGuardadas(carrito: Carrito): number {
  return carrito.lineas.reduce((n, l) => n + l.cantidad * l.botellas, 0);
}

/**
 * Las sueltas segun lo guardado. Misma cuenta que `botellasSueltas`, con la
 * unica pista que hay en `localStorage`: `botellas` por linea.
 *
 * Por eso ese campo se guarda desde ADR 009 §4 -- sin el, la barra no puede
 * distinguir un pack de dos botellas de dos botellas sueltas, que es
 * exactamente la distincion que decide si el pedido se puede cobrar.
 */
export function botellasSueltasGuardadas(carrito: Carrito): number {
  return carrito.lineas.reduce((n, l) => (viajaSolo(l) ? n : n + l.cantidad * l.botellas), 0);
}

/**
 * Lo que de verdad va a viajar, separado por como viaja. Lo consume `envio.ts`
 * para armar los bultos, y no al reves: este archivo sabe del carrito y aquel
 * sabe de cajas y kilos.
 *
 * `propias` lleva UNA ENTRADA POR UNIDAD -dos packs de 2 son `[2, 2]`, no un 4-
 * porque cada uno es un bulto con su peso y su medida. Aplanarlo a un total de
 * botellas es justo el error que este cambio corrige: seis botellas en tres
 * packs no son una caja de seis, son tres bultos.
 */
export interface CargaDelPedido {
  /** Botellas sueltas: viajan juntas, de a `BOTELLAS_POR_CAJA` por caja. */
  readonly sueltas: number;
  /** Botellas adentro de cada unidad que trae su propia caja. */
  readonly propias: readonly number[];
}

export function cargaDelPedido(resuelto: CarritoResuelto): CargaDelPedido {
  let sueltas = 0;
  const propias: number[] = [];
  for (const l of resuelto.lineas) {
    if (l.estado !== 'vigente' || l.producto === null) continue;
    if (viajaSolo(l.producto)) {
      for (let i = 0; i < l.cantidad; i += 1) propias.push(l.producto.botellas);
    } else {
      sueltas += l.cantidad * l.producto.botellas;
    }
  }
  return { sueltas, propias };
}

export interface EstadoDeLaCaja {
  readonly botellas: number;
  readonly cajasCompletas: number;
  /** Cuantas faltan para el proximo multiplo. 0 si ya es multiplo. */
  readonly faltan: number;
  /** Cuantas sobran sobre el ultimo multiplo. 0 si ya es multiplo. */
  readonly sobran: number;
}

/**
 * La aritmetica sola, con el tamano por parametro.
 *
 * Existe separada para poder probar cajas de 3 sin mutar una constante: la
 * garantia que interesa no es "hoy da 6", es "la regla es parametrica", y eso
 * solo se prueba corriendola con dos tamanos distintos.
 */
export function contarCaja(botellas: number, porCaja: number = BOTELLAS_POR_CAJA): EstadoDeLaCaja {
  if (!Number.isInteger(porCaja) || porCaja < 1) {
    throw new RangeError(`la caja va entera y >= 1; llego ${porCaja}`);
  }
  const resto = botellas % porCaja;
  return {
    botellas,
    cajasCompletas: Math.floor(botellas / porCaja),
    faltan: resto === 0 ? 0 : porCaja - resto,
    sobran: resto,
  };
}

/**
 * Lo que la pantalla necesita para decir UNA sola frase. Derivado, nunca
 * guardado.
 *
 * Devuelve `faltan` Y `sobran` a proposito: con 7 botellas las dos son ciertas
 * -faltan 5, sobra 1- y cual de las dos decir es una decision de la vidriera,
 * no de este archivo.
 */
export function estadoDeLaCaja(resuelto: CarritoResuelto): EstadoDeLaCaja {
  return contarCaja(botellasSueltas(resuelto));
}

/**
 * La precondicion de COBRO. NO es una precondicion de validez: un carrito de 4
 * botellas es alguien comprando, y `parsearCarrito` lo acepta -- si lo
 * rechazara, el carrito a medio llenar se descartaria entero en la visita
 * siguiente, porque el parser rechaza en vez de corregir.
 *
 * `crearOrden` la va a repetir sobre SU PROPIA proyeccion: un numero de
 * botellas que mande el navegador no se cree.
 *
 * Un carrito vacio no es cobrable. Cero es multiplo de seis, pero no hay nada
 * que despachar. Por eso son DOS condiciones y no una: la segunda mira las
 * sueltas -- un pedido de un solo pack de 2 tiene CERO sueltas, y se cobra.
 */
export function sePuedeCobrar(resuelto: CarritoResuelto): boolean {
  return botellasEnCarrito(resuelto) > 0 && botellasSueltas(resuelto) % BOTELLAS_POR_CAJA === 0;
}

// ------------------------------------------------------- pedido de compra

export interface LineaDePedido {
  readonly productoId: string;
  readonly cantidad: number;
  /**
   * El precio unitario que el comprador tenia en pantalla. `crearOrden` relee
   * el precio y RECHAZA si no coincide: la pantalla puede tener hasta unos dos
   * minutos de atraso, y un precio viejo no se cobra.
   */
  readonly precioUnitarioVisto: Centavos;
}

/**
 * Lo que va a recibir `crearOrden` (la proxima sesion). Se define aca, antes
 * que su consumidor, para que el carrito nazca con la forma que despues se
 * valida.
 */
export interface PedidoDeCompra {
  /** Clave de idempotencia: el mismo idCompra dos veces es UNA orden. */
  readonly idCompra: string;
  readonly lineas: readonly LineaDePedido[];
}
