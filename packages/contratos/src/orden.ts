/**
 * La maquina de estados de Orden.  ADR 002.
 *
 * ESTE ES EL PUNTO NO NEGOCIABLE DEL DIA 1.
 *
 * En PadelPunilla los estados de Reserva quedaron repartidos entre Dart y TS,
 * y la condicion correcta para "entro en confirmada" hubo que DESCUBRIRLA
 * auditando 5 rutas distintas, meses despues de que el primer trigger
 * estuviera mal.
 *
 * Una Orden tiene DOS ejes independientes porque los dos hechos avanzan por
 * separado y a veces en desorden: se cobro (puede pasar antes, despues o
 * nunca) y se entrego (avanza por logistica, no por plata). Un unico string
 * obliga a inventar estados cruzados y a decidir cual gana cuando llegan
 * desordenados; con dos ejes no hay campo compartido que pisar.
 */

// ===========================================================================
// Eje 1 - el pago
// ===========================================================================

export const ESTADOS_PAGO = [
  'pendiente',
  'en_proceso',
  'pagada',
  'rechazada',
  'reembolsada',
  'por_fuera',
] as const;

export type EstadoPago = (typeof ESTADOS_PAGO)[number];

/**
 * Estados en los que una Orden puede NACER en el eje de pago.
 *
 * `pagada` esta en la lista y eso es toda la leccion 5.1: carga manual desde
 * el panel, link de pago pre-aprobado, y lo que agregue el dueno el ano que
 * viene. Un trigger que espere la transicion pendiente -> pagada NUNCA se
 * dispara para estas, y no falla: simplemente no corre.
 */
export const NACE_PAGO: readonly EstadoPago[] = ['pendiente', 'pagada', 'por_fuera'];

export const TRANSICIONES_PAGO: Readonly<Record<EstadoPago, readonly EstadoPago[]>> = {
  pendiente: ['en_proceso', 'pagada', 'rechazada'],
  en_proceso: ['pagada', 'rechazada'],
  pagada: ['reembolsada'],
  rechazada: ['en_proceso', 'pagada'], // reintento: una tarjeta rechazada se vuelve a intentar
  reembolsada: [],
  // Terminal, y no por olvido: describe un cobro que el sistema NO sigue (el de
  // un pedido de WhatsApp). Nada sale de aca y a nadie se llega despues de
  // nacer: si el pago pudiera pasar a `pagada`, `entroEnPagada` avisaria un
  // cobro que nunca paso por el sistema. ADR 018 §3.
  por_fuera: [],
};

// ===========================================================================
// El origen - de donde vino la Orden
// ===========================================================================

export const ORIGENES = ['vidriera', 'whatsapp'] as const;

export type Origen = (typeof ORIGENES)[number];

/**
 * El estado de pago con el que NACE una Orden de cada origen.  Es la unica
 * fuente de esa correspondencia: la callable no la reescribe.
 *
 * `por_fuera` es de whatsapp y NADA MAS, y `pendiente` es de la vidriera y nada
 * mas.  Una vidriera que naciera `por_fuera` no seria cobrada nunca; un pedido
 * de WhatsApp que naciera `pendiente` quedaria para siempre entre los que
 * requieren accion.  ADR 018 §3.
 */
export function estadoDePagoInicial(origen: Origen): EstadoPago {
  return origen === 'whatsapp' ? 'por_fuera' : 'pendiente';
}

// ===========================================================================
// Eje 2 - la entrega
// ===========================================================================

export const ESTADOS_ENTREGA = [
  'sin_preparar',
  'preparando',
  'despachada',
  'entregada',
  'fallida',
  'cancelada',
] as const;

export type EstadoEntrega = (typeof ESTADOS_ENTREGA)[number];

/**
 * En el eje de entrega la Orden solo puede nacer sin preparar: el carrito vive
 * en localStorage y la Orden nace confirmada, nunca en borrador.
 */
export const NACE_ENTREGA: readonly EstadoEntrega[] = ['sin_preparar'];

export const TRANSICIONES_ENTREGA: Readonly<Record<EstadoEntrega, readonly EstadoEntrega[]>> = {
  sin_preparar: ['preparando', 'cancelada'],
  preparando: ['despachada', 'cancelada'],
  despachada: ['entregada', 'fallida'],
  entregada: [],
  fallida: ['despachada'], // reintento de entrega: nadie en casa el martes, se vuelve el jueves
  cancelada: [],
};

// ===========================================================================
// Validacion de transiciones
// ===========================================================================

function valida<T extends string>(
  tabla: Readonly<Record<T, readonly T[]>>,
  nacimientos: readonly T[],
  antes: T | undefined,
  despues: T,
): boolean {
  if (antes === undefined) return nacimientos.includes(despues);
  // Reescribir el mismo estado es valido: los webhooks son at-least-once y una
  // re-entrega escribe lo mismo. Lo que no se puede repetir es el EFECTO, y de
  // eso se ocupa el marcador de idempotencia, no esta tabla.
  if (antes === despues) return true;
  return tabla[antes].includes(despues);
}

export function transicionPagoValida(antes: EstadoPago | undefined, despues: EstadoPago): boolean {
  return valida(TRANSICIONES_PAGO, NACE_PAGO, antes, despues);
}

export function transicionEntregaValida(
  antes: EstadoEntrega | undefined,
  despues: EstadoEntrega,
): boolean {
  return valida(TRANSICIONES_ENTREGA, NACE_ENTREGA, antes, despues);
}

// ===========================================================================
// entroEn* - la condicion que usan TODOS los triggers
// ===========================================================================

/**
 * "Entro en X" es el HECHO OBSERVABLE, no "hubo una escritura".
 *
 * `antes === undefined` en un create, asi que una Orden que nace pagada
 * tambien dispara entroEnPagada. Ese es exactamente el caso que un
 * `onDocumentUpdated` se pierde en silencio.
 *
 *   NO   onDocumentUpdated + "paso a pagada"
 *   SI   onDocumentWritten + entroEnPagada(antes, despues)
 *
 * Vive aca y no en cada flujo porque es un hecho del CICLO DE VIDA de la
 * entidad, no de un flujo.
 */
export function entroEn<T extends string>(
  objetivo: T,
  antes: T | undefined,
  despues: T | undefined,
): boolean {
  return despues === objetivo && antes !== objetivo;
}

export const entroEnPagada = (a: EstadoPago | undefined, d: EstadoPago | undefined): boolean =>
  entroEn('pagada', a, d);

export const entroEnReembolsada = (a: EstadoPago | undefined, d: EstadoPago | undefined): boolean =>
  entroEn('reembolsada', a, d);

export const entroEnDespachada = (
  a: EstadoEntrega | undefined,
  d: EstadoEntrega | undefined,
): boolean => entroEn('despachada', a, d);

export const entroEnEntregada = (
  a: EstadoEntrega | undefined,
  d: EstadoEntrega | undefined,
): boolean => entroEn('entregada', a, d);

export const entroEnCancelada = (
  a: EstadoEntrega | undefined,
  d: EstadoEntrega | undefined,
): boolean => entroEn('cancelada', a, d);
