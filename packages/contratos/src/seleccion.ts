/**
 * La seleccion de la portada: los vinos que elige el duenio (HU-09.1, ADR 023).
 *
 * Vive en UN documento, `seleccion/publica`, con una lista ordenada de
 * `productoId`. Mismo patron que `cajasSugeridas/publicas`: se reescribe
 * entero, asi que guardar dos veces da lo mismo, y el orden es el que eligio
 * el duenio.
 *
 * ---
 *
 * LA VALIDACION VA EN DOS TIEMPOS, como la de las cajas:
 *
 *   1. `validarSeleccion` mira la FORMA, sin catalogo. Las reglas ya cierran
 *      la escritura del panel, pero el Admin SDK no pasa por ellas: un
 *      documento roto PUEDE existir, y esto es lo que impide que tire el build
 *      de la portada.
 *   2. `resolverSeleccion` cruza los ids con la proyeccion, EN MEMORIA, y deja
 *      solo los que la portada puede dibujar hoy.
 *
 * Un vino elegido que se despublica o se agota NO rompe la seleccion: se
 * saltea, y la portada muestra los que quedan. El panel lo avisa.
 */

import { esProductoId } from './carrito.ts';
import type { Descarte, ProductoPublicado } from './producto.ts';

/**
 * Cuantos vinos entran en la portada. La grilla de la escena 2 esta pensada
 * para seis, y las reglas lo exigen como tope (`firestore.rules`,
 * `seleccion`).
 */
export const LUGARES_DE_LA_SELECCION = 6;

function esObjeto(x: unknown): x is Record<string, unknown> {
  return typeof x === 'object' && x !== null && !Array.isArray(x);
}

export interface SeleccionLeida {
  /**
   * `null` si el duenio nunca eligio: el documento no existe, o esta tan roto
   * que no se puede leer como una lista. Entonces la portada usa la regla
   * provisoria de ADR 008 §7. Una lista VACIA no es lo mismo: el duenio
   * eligio y despues saco todo.
   */
  readonly productoIds: readonly string[] | null;
  /** Lo que quedo afuera y por que. Lo loguea el build; no llega a la pagina. */
  readonly descartes: readonly Descarte[];
}

/**
 * Valida el documento crudo `seleccion/publica`.
 *
 * Un id invalido, uno repetido o uno que pasa el tope quedan afuera SOLOS: el
 * resto de la eleccion sigue valiendo. Mismo criterio que las cajas con un
 * vino caido.
 */
export function validarSeleccion(datos: unknown): SeleccionLeida {
  const descartes: Descarte[] = [];
  if (datos === undefined || datos === null) return { productoIds: null, descartes };

  if (!esObjeto(datos) || !Array.isArray(datos.productoIds)) {
    descartes.push({ id: 'seleccion', motivo: 'el documento no tiene la forma { productoIds: [...] }' });
    return { productoIds: null, descartes };
  }

  const productoIds: string[] = [];
  datos.productoIds.forEach((id: unknown, i: number) => {
    const donde = `seleccion.productoIds[${i}]`;
    if (!esProductoId(id)) {
      descartes.push({ id: donde, motivo: `productoId invalido: ${JSON.stringify(id)}` });
    } else if (productoIds.includes(id)) {
      descartes.push({ id: donde, motivo: `repetido: ${id}` });
    } else if (productoIds.length >= LUGARES_DE_LA_SELECCION) {
      descartes.push({ id: donde, motivo: `pasa el tope de ${LUGARES_DE_LA_SELECCION}: ${id}` });
    } else {
      productoIds.push(id);
    }
  });

  return { productoIds, descartes };
}

/**
 * Si la portada puede dibujar este vino. La tarjeta dibuja UNA botella, asi
 * que un vino que viene en su propia caja no entra; y uno agotado no se ofrece
 * en la vidriera.
 *
 * Es la MISMA condicion que usa la regla provisoria, y el panel la espeja para
 * avisar antes de que la portada saltee un vino elegido
 * (`apps/admin/lib/features/vidriera/domain/seleccion_de_la_portada.dart`).
 */
export function puedeIrEnLaSeleccion(p: Pick<ProductoPublicado, 'balde' | 'botellas'>): boolean {
  return p.balde !== 'agotado' && p.botellas === 1;
}

/**
 * Los vinos elegidos que la portada puede dibujar hoy, EN EL ORDEN DEL DUENIO.
 *
 * `productos` es la proyeccion publica: un id que no esta ahi esta
 * despublicado, no existe, o `armarCatalogo` lo descarto. El cruce va en
 * memoria, nunca con un `get()` por id (ADR 004 §3).
 */
export function resolverSeleccion(
  productoIds: readonly string[],
  productos: readonly ProductoPublicado[],
): ProductoPublicado[] {
  const porId = new Map(productos.map((p) => [p.id, p]));
  const resueltos: ProductoPublicado[] = [];
  for (const id of productoIds) {
    const p = porId.get(id);
    if (p !== undefined && puedeIrEnLaSeleccion(p)) resueltos.push(p);
  }
  return resueltos;
}
