/**
 * La popularidad medida: cuantas unidades de cada vino se vendieron en los
 * ultimos `VENTANA_DE_POPULARIDAD_DIAS` dias (HU-11.3, ADR 025).
 *
 * Vive en UN documento, `metricas/popularidad`, que se RECALCULA entero sobre
 * la ventana y nunca se acumula (ADR 008): un contador que suma de a una venta
 * se infla con cada reintento; uno recalculado da lo mismo si corre dos veces.
 * Lo escribe solo el servidor -el job `calcularPopularidad`-, el panel lo lee
 * entero, y la vidriera recibe el PUESTO, nunca las unidades (`armarCatalogo`).
 *
 * Hasta el 2026-09-29 lo escribia solo el seed, marcado `simulada: true`. El
 * job escribe `simulada: false`, y es lo que mira el panel para creerle
 * (`LoQueMasSeVende.desde`, en Dart): no muestra un ranking simulado, porque
 * mostrar un ranking sobre datos que no se miden es mentirle a quien lo lee
 * (EP-11, §8.3).
 */

import { esProductoId } from './carrito.ts';
import { ESTADOS_ENTREGA, ESTADOS_PAGO, type EstadoEntrega, type EstadoPago } from './orden.ts';

/**
 * Cuantos dias mira hacia atras. Decision mia (ADR 025 §2): una temporada. Con
 * menos, un negocio chico tiene tan pocas ventas que el ranking lo decide una
 * sola compra grande; con mas, un vino que dejo de venderse sigue arriba meses.
 *
 * El documento lleva el numero escrito (`ventanaDias`): el panel dice "en los
 * ultimos N dias" leyendolo de ahi, sin espejo en Dart que se desincronice.
 */
export const VENTANA_DE_POPULARIDAD_DIAS = 90;

/**
 * Los pagos que dicen que la venta OCURRIO: cobrada por Mercado Pago, o
 * cobrada por fuera (un pedido de WhatsApp, ADR 018 §3).
 *
 * Afuera, y a proposito: `pendiente` y `en_proceso` (todavia no es una venta),
 * `rechazada` (no lo fue) y `reembolsada` (se deshizo).
 */
const PAGOS_DE_UNA_VENTA: readonly EstadoPago[] = ['pagada', 'por_fuera'];

/**
 * Si una Orden cuenta para la popularidad. Una cancelada NO, aunque este
 * pagada: `cancelada_con_pago` es plata por devolver, no un vino que se fue.
 * Una entrega `fallida` SI: el vino esta vendido y se reprograma.
 */
export function cuentaComoVenta(pago: EstadoPago, entrega: EstadoEntrega): boolean {
  return PAGOS_DE_UNA_VENTA.includes(pago) && entrega !== 'cancelada';
}

export interface PopularidadContada {
  /** Unidades de venta por `productoId`. Solo los que vendieron algo. */
  readonly unidades: Readonly<Record<string, number>>;
  /** Cuantas Ordenes contaron como venta. */
  readonly ventas: number;
  /**
   * Cuantos documentos no se pudieron leer como Orden y quedaron afuera. El
   * job lo loguea: un numero distinto de cero es un documento roto, y el
   * ranking sin el es mas chico, no falso.
   */
  readonly ilegibles: number;
}

function esObjeto(x: unknown): x is Record<string, unknown> {
  return typeof x === 'object' && x !== null && !Array.isArray(x);
}

const esEstadoPago = (x: unknown): x is EstadoPago => (ESTADOS_PAGO as readonly unknown[]).includes(x);
const esEstadoEntrega = (x: unknown): x is EstadoEntrega => (ESTADOS_ENTREGA as readonly unknown[]).includes(x);

/**
 * Las lineas de una Orden, o `null` si alguna no se puede leer. Una Orden con
 * una linea rota se descarta ENTERA: contar la mitad de un pedido es inventar
 * uno que nadie hizo.
 */
function lineasDe(items: unknown): { productoId: string; cantidad: number }[] | null {
  if (!Array.isArray(items)) return null;
  const lineas: { productoId: string; cantidad: number }[] = [];
  for (const item of items) {
    if (!esObjeto(item) || !esProductoId(item.productoId)) return null;
    const cantidad = item.cantidad;
    if (typeof cantidad !== 'number' || !Number.isInteger(cantidad) || cantidad < 1) return null;
    lineas.push({ productoId: item.productoId, cantidad });
  }
  return lineas;
}

/**
 * Suma las unidades vendidas de cada vino sobre las Ordenes crudas de la
 * ventana. Recibe `unknown` a proposito: el Admin SDK no pasa por las reglas,
 * y un documento roto se cuenta como `ilegible`, nunca tira la corrida.
 *
 * Suma UNIDADES DE VENTA (`cantidad`), no botellas: es la unidad que ya usa
 * `armarCatalogo` para ordenar la vidriera, y un estuche de dos que se vende
 * mucho es un producto que se vende mucho.
 *
 * Pura y determinista: las mismas Ordenes dan el mismo documento, en
 * cualquier orden. Es la mitad de la idempotencia del job; la otra mitad es
 * que se escribe con `set` entero.
 */
export function contarPopularidad(ordenes: readonly unknown[]): PopularidadContada {
  const unidades = new Map<string, number>();
  let ventas = 0;
  let ilegibles = 0;

  for (const orden of ordenes) {
    if (!esObjeto(orden) || !esEstadoPago(orden.estadoPago) || !esEstadoEntrega(orden.estadoEntrega)) {
      ilegibles += 1;
      continue;
    }
    const lineas = lineasDe(orden.items);
    if (lineas === null) {
      ilegibles += 1;
      continue;
    }
    if (!cuentaComoVenta(orden.estadoPago, orden.estadoEntrega)) continue;
    ventas += 1;
    for (const { productoId, cantidad } of lineas) {
      unidades.set(productoId, (unidades.get(productoId) ?? 0) + cantidad);
    }
  }

  // Claves ordenadas: dos corridas sobre los mismos datos escriben el mismo
  // mapa, byte a byte.
  const ordenadas = [...unidades.entries()].sort(([a], [b]) => a.localeCompare(b));
  return { unidades: Object.fromEntries(ordenadas), ventas, ilegibles };
}

/** El primer instante que entra en la ventana que termina en `ahora`. */
export function inicioDeLaVentana(ahora: Date, dias: number = VENTANA_DE_POPULARIDAD_DIAS): Date {
  if (!Number.isInteger(dias) || dias < 1) throw new RangeError(`la ventana va entera y >= 1; llego ${dias}`);
  return new Date(ahora.getTime() - dias * 24 * 60 * 60 * 1000);
}
