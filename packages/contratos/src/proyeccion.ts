/**
 * La proyeccion de los dos ejes a UN estado para mostrar.  ADR 002.
 *
 * Es la unica fuente del rotulo que ve el cliente y del que ve el operador.
 * La UI nunca arma un rotulo a partir de los dos campos: eso son dos
 * implementaciones del mismo rotulo, y se desincronizan (LECCIONES 6.4).
 */

import type { EstadoEntrega, EstadoPago } from './orden.ts';

export const ESTADOS_PUBLICOS = [
  'recibida',
  'confirmando',
  'pago_rechazado',
  'pagada',
  'en_preparacion',
  'en_camino',
  'entregada',
  'entregada_impaga',
  'no_entregada',
  'cancelada',
  'cancelada_con_pago',
  'reembolsada',
] as const;

export type EstadoPublico = (typeof ESTADOS_PUBLICOS)[number];

/**
 * Total sobre los 5 x 6 = 30 pares. El orden de las ramas ES la logica:
 * los terminales de entrega mandan, despues los terminales de pago, y recien
 * ahi el avance normal.
 *
 * No hay `default` que trague casos: un par sin rama seria un rotulo
 * inventado, y hay un test que recorre los 30.
 */
export function proyectarEstadoPublico(pago: EstadoPago, entrega: EstadoEntrega): EstadoPublico {
  // 1. Cancelada manda sobre todo lo demas.
  if (entrega === 'cancelada') {
    // El caso del webhook fuera de orden: un `pagado` que llega despues de un
    // `cancelado` escribe SU eje y no toca el otro. El resultado es "pagada
    // pero cancelada", que es exactamente lo que paso - y es un caso que el
    // operador tiene que ver para devolver la plata.
    if (pago === 'pagada') return 'cancelada_con_pago';
    if (pago === 'reembolsada') return 'reembolsada';
    return 'cancelada';
  }

  // 2. No se pudo entregar.
  if (entrega === 'fallida') return 'no_entregada';

  // 3. Llego. Si ademas no se cobro, es un caso operativo real (contra
  //    entrega que el repartidor no cobro) y no puede quedar disfrazado.
  if (entrega === 'entregada') {
    return pago === 'pagada' ? 'entregada' : 'entregada_impaga';
  }

  // 4-6. Terminales y transitorios del pago, sobre una entrega que avanza.
  if (pago === 'reembolsada') return 'reembolsada';
  if (pago === 'rechazada') return 'pago_rechazado';
  if (pago === 'en_proceso') return 'confirmando';

  // 7-9. Avance normal. Aca pago solo puede ser 'pendiente' o 'pagada'.
  if (entrega === 'despachada') return 'en_camino';
  if (entrega === 'preparando') return 'en_preparacion';
  return pago === 'pagada' ? 'pagada' : 'recibida';
}

/**
 * `confirmando` NO se llama "pendiente", y eso es deliberado.
 *
 * En PadelPunilla el estado transitorio decia "Pendiente" - la misma palabra
 * con la que se lee una espera de DIAS que depende de una persona. Quien caia
 * en aprobacion manual no podia distinguir su orden detenida de una que iba a
 * confirmarse en dos segundos.
 *
 * Y esto sobrevive a cualquier optimizacion de latencia: el estado existe
 * siempre, aunque dure 300 ms.
 */
export const ROTULOS: Readonly<Record<EstadoPublico, { cliente: string; operador: string }>> = {
  recibida: { cliente: 'Pedido recibido', operador: 'Recibida - falta cobrar' },
  confirmando: { cliente: 'Confirmando...', operador: 'Pago en proceso' },
  pago_rechazado: { cliente: 'No pudimos cobrar el pago', operador: 'Pago rechazado' },
  pagada: { cliente: 'Pago acreditado', operador: 'Pagada - falta preparar' },
  en_preparacion: { cliente: 'Preparando tu pedido', operador: 'En preparacion' },
  en_camino: { cliente: 'En camino', operador: 'Despachada' },
  entregada: { cliente: 'Entregado', operador: 'Entregada' },
  entregada_impaga: { cliente: 'Entregado', operador: 'ENTREGADA SIN COBRAR' },
  no_entregada: { cliente: 'No pudimos entregarlo', operador: 'Entrega fallida - reprogramar' },
  cancelada: { cliente: 'Pedido cancelado', operador: 'Cancelada' },
  cancelada_con_pago: { cliente: 'Pedido cancelado', operador: 'CANCELADA CON PAGO - devolver' },
  reembolsada: { cliente: 'Pedido cancelado y reintegrado', operador: 'Reembolsada' },
};

/** Los que exigen que alguien haga algo. Son la bandeja de entrada del panel. */
export const REQUIEREN_ACCION: readonly EstadoPublico[] = [
  'pagada',
  'entregada_impaga',
  'no_entregada',
  'cancelada_con_pago',
];
