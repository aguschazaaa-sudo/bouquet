/**
 * El cobro de la vidriera, del lado que RECIBE: que dice el proveedor de un
 * pago, y si eso mueve el eje `estadoPago` de una Orden.  HU-08.1 y HU-08.3,
 * ADR 022.  El contrato del webhook es el de ADR 003.
 *
 * Aca vive lo que NO depende de Mercado Pago: la forma de una consulta ya
 * traducida, el puerto `ProveedorDePago` y `resolverConsulta`, la regla que
 * decide.  El adaptador de Mercado Pago (el SDK, la traduccion de sus estados,
 * la firma) vive en `functions/`: contratos no puede depender de un SDK que
 * habla por la red.
 *
 * ⚠️ LA VERDAD SALE DE LA CONSULTA, NUNCA DEL CUERPO DEL AVISO (ADR 003, regla
 * 1).  Por eso aca no hay un "aviso de pago aprobado": hay una `ConsultaDePago`,
 * que solo puede venir de preguntarle al proveedor.
 */

import type { Centavos } from './dinero.ts';
import { esIdDeOrden } from './despacho.ts';
import { transicionPagoValida, type EstadoPago, type Origen } from './orden.ts';
import type { Validacion } from './producto.ts';

/** Uno solo hoy (ADR 010): el dia que haya otro, esto se vuelve una lista. */
export type Proveedor = 'mercadopago';

/** Lo que dice el proveedor de UN pago, ya traducido a nuestros terminos. */
export interface ConsultaDePago {
  readonly proveedor: Proveedor;
  /** El numero de operacion del proveedor.  Es lo que se concilia (HU-08.1). */
  readonly operacionId: string;
  /**
   * El id de la Orden que puso la preferencia (`external_reference`).  `null`
   * si el pago no trae uno nuestro: la cuenta de Mercado Pago puede cobrar
   * otras cosas -un link de pago, un posnet- y sus avisos llegan igual.
   */
  readonly ordenId: string | null;
  /**
   * `null`: un estado del proveedor que NO mueve el eje (una mediacion, o uno
   * que no conocemos).  No se adivina: se registra y no se escribe.
   */
  readonly estado: EstadoPago | null;
  /** El estado crudo del proveedor (`approved`, `in_process`...). */
  readonly estadoDelProveedor: string;
  /** El detalle crudo (`accredited`, `cc_rejected_high_risk`...), si trae. */
  readonly detalle: string | null;
  /** Lo que el proveedor dice que se cobro, en centavos. */
  readonly monto: Centavos;
  /**
   * Lo que ya se devolvio de ese pago, en centavos (0 si nada).  Un reembolso
   * PARCIAL no cambia el estado crudo -sigue `approved`-: solo mueve esto.
   */
  readonly reembolsado: Centavos;
  readonly moneda: string;
  /** ISO 8601 del proveedor: ordena los intentos de un mismo pedido. */
  readonly creadoEn: string;
}

// ------------------------------------------------------------------ el puerto

/** Un aviso tal como llega por HTTP, antes de creerle nada. */
export interface AvisoRecibido {
  /** Los encabezados, con el nombre en minusculas. */
  readonly encabezados: Readonly<Record<string, string | undefined>>;
  /** Los parametros de la URL. */
  readonly parametros: Readonly<Record<string, string | undefined>>;
  readonly cuerpo: unknown;
}

export type LecturaDeAviso =
  | { readonly es: 'pago'; readonly operacionId: string }
  /** Un tema que no es un pago (`merchant_order`, un reclamo): se contesta y no se hace nada. */
  | { readonly es: 'otro-tema'; readonly tema: string }
  | { readonly es: 'firma-invalida'; readonly razon: string };

/**
 * ADR 003 pedia tres metodos.  `crearPreferencia` NO esta todavia, a
 * proposito: la llama `crearOrden` de la vidriera, que no existe, y un metodo
 * que nadie llama no esta entregado.  Entra con ella.
 */
export interface ProveedorDePago {
  readonly nombre: Proveedor;
  /**
   * Verifica la firma ANTES de mirar el cuerpo (ADR 003, regla 2).  Nunca
   * lanza: una firma que no cierra es una lectura, no un error del servidor.
   */
  leerAviso(aviso: AvisoRecibido): LecturaDeAviso;
  /** `null`: el proveedor no conoce ese pago. */
  consultarPago(operacionId: string): Promise<ConsultaDePago | null>;
  /** Todos los intentos de pago de una Orden.  Es la re-consulta de HU-08.3. */
  buscarPagosDeLaOrden(ordenId: string): Promise<readonly ConsultaDePago[]>;
}

// --------------------------------------------------------------- la decision

/** Lo que `resolverConsulta` necesita de la Orden, leido en la transaccion. */
export interface OrdenParaCobrar {
  readonly ordenId: string;
  readonly origen: Origen;
  readonly estadoPago: EstadoPago;
  readonly total: Centavos;
  /** La operacion que ya esta aplicada en `pago`, o `null` si ninguna. */
  readonly operacionId: string | null;
}

export const MOTIVOS_SIN_APLICAR = [
  'otra-orden',
  'no-es-de-la-vidriera',
  'estado-sin-traduccion',
  'otra-moneda',
  'pago-duplicado',
  'monto-distinto',
  'transicion-invalida',
] as const;
export type MotivoSinAplicar = (typeof MOTIVOS_SIN_APLICAR)[number];

export type Resolucion =
  | { readonly aplica: true; readonly estadoPago: EstadoPago; readonly cambia: boolean }
  | { readonly aplica: false; readonly motivo: MotivoSinAplicar };

/** La unica moneda en la que cobra la tienda. */
const MONEDA = 'ARS';

/**
 * Si lo que dijo el proveedor mueve el eje de pago de esta Orden.  Pura: la
 * llama la transaccion con la Orden que ACABA de leer.
 *
 * Cada `aplica: false` se REGISTRA, no se ignora en silencio (ADR 003, regla
 * 4): lo escribe el marcador.  Las guardas, en orden:
 *
 *  1. La consulta es de ESTA Orden.  Un aviso que dice una cosa y una consulta
 *     que dice otra se resuelve por la consulta.
 *  2. Es de la vidriera.  Un pedido de WhatsApp nace `por_fuera`, que es
 *     terminal: la tabla ya lo rechaza, pero con un motivo que no dice nada.
 *  3. El proveedor dijo algo que sabemos traducir.
 *  4. Es en pesos.
 *  5. No es un SEGUNDO cobro: un pago aprobado con otro numero de operacion,
 *     sobre una Orden que ya esta pagada por otro.  `pagada -> pagada` es valido
 *     en la tabla (reescribir el mismo estado), asi que sin esta guarda el
 *     segundo pisaba al primero en `pago` y nadie se enteraba de que al
 *     comprador le cobraron dos veces (hallazgo ALTO 2 de `revisor-pagos`).
 *  6. Si dice PAGADA, el monto es el total de la Orden, al centavo.  Un pago
 *     aprobado por menos no es "pagada": es un pedido que alguien tiene que
 *     mirar.  Solo se compara al pagar: un rechazo o un reembolso por otro
 *     monto no cobra nada.
 *  7. La transicion la acepta la tabla de ADR 002.  Un `pagada` sobre una Orden
 *     cancelada SI pasa -el eje de pago no mira el de entrega, y el operador
 *     tiene que ver *"cancelada con pago"* para devolver la plata-; un
 *     `rechazada` sobre una `pagada`, no.
 */
export function resolverConsulta(orden: OrdenParaCobrar, consulta: ConsultaDePago): Resolucion {
  if (consulta.ordenId !== orden.ordenId) return { aplica: false, motivo: 'otra-orden' };
  if (orden.origen !== 'vidriera') return { aplica: false, motivo: 'no-es-de-la-vidriera' };
  if (consulta.estado === null) return { aplica: false, motivo: 'estado-sin-traduccion' };
  if (consulta.moneda !== MONEDA) return { aplica: false, motivo: 'otra-moneda' };
  if (
    consulta.estado === 'pagada' &&
    orden.estadoPago === 'pagada' &&
    orden.operacionId !== null &&
    orden.operacionId !== consulta.operacionId
  ) {
    return { aplica: false, motivo: 'pago-duplicado' };
  }
  if (consulta.estado === 'pagada' && consulta.monto !== orden.total) {
    return { aplica: false, motivo: 'monto-distinto' };
  }
  if (!transicionPagoValida(orden.estadoPago, consulta.estado)) {
    return { aplica: false, motivo: 'transicion-invalida' };
  }
  return { aplica: true, estadoPago: consulta.estado, cambia: consulta.estado !== orden.estadoPago };
}

/**
 * El id del marcador de idempotencia de una consulta:
 * `ordenes/{ordenId}/marcadores/{este}`.
 *
 * ⚠️ ADR 003 lo escribia `pago-{paymentId}`, y con eso se PIERDE UNA VENTA: un
 * pago en efectivo llega primero `in_process` y dias despues `approved`, con el
 * MISMO id.  Con un marcador por id, el segundo aviso encuentra el marcador del
 * primero, se toma por repetido, y la Orden queda "en proceso" con la plata
 * cobrada.  La llave es el HECHO -este pago llego a este estado crudo, con esto
 * devuelto-, no el pago.  ADR 022 §3.
 *
 * Lo devuelto entra a la llave porque un reembolso PARCIAL no cambia el estado
 * crudo: sin eso, el aviso de la devolucion se tomaba por repetido y no se
 * reevaluaba nunca, ni con el codigo corregido (hallazgo ALTO 1 de
 * `revisor-pagos`).  Sin devolucion la llave no cambia: los marcadores que ya
 * existan siguen valiendo.
 */
export function idDelMarcadorDePago(consulta: ConsultaDePago): string {
  const base = `pago-${consulta.proveedor}-${consulta.operacionId}-${consulta.estadoDelProveedor}`;
  return consulta.reembolsado > 0 ? `${base}-r${consulta.reembolsado}` : base;
}

/** Lo que se escribe en `ordenes/{id}.pago` cuando una consulta se aplica (sin la hora, que la pone la base). */
export interface PagoDeOrden {
  readonly proveedor: Proveedor;
  readonly operacionId: string;
  readonly estadoDelProveedor: string;
  readonly detalle: string | null;
  readonly monto: Centavos;
  readonly reembolsado: Centavos;
}

export function pagoDeOrden(consulta: ConsultaDePago): PagoDeOrden {
  return {
    proveedor: consulta.proveedor,
    operacionId: consulta.operacionId,
    estadoDelProveedor: consulta.estadoDelProveedor,
    detalle: consulta.detalle,
    monto: consulta.monto,
    reembolsado: consulta.reembolsado,
  };
}

// ------------------------------------------ lo que no se aplica y se ve

/**
 * Si un hecho que NO se aplico tiene que verse en el panel: los que movieron
 * plata que la Orden no refleja.  Un cobro aprobado que no se aplico (un
 * segundo cobro, un monto distinto, un pago sobre una Orden ya devuelta) o un
 * estado sin traduccion (un contracargo, una disputa).  Un rechazo tardio o un
 * "en proceso" viejo que no se aplican no movieron nada: mostrarlos seria ruido.
 *
 * Se escribe en `ordenes/{id}.alertaDePago`, en la misma transaccion que el
 * marcador: el panel lo lee con el documento, sin una lectura mas.
 */
export function requiereAtencion(consulta: ConsultaDePago, resolucion: Resolucion): boolean {
  if (resolucion.aplica) return false;
  if (resolucion.motivo === 'otra-orden' || resolucion.motivo === 'no-es-de-la-vidriera') return false;
  return consulta.estado === 'pagada' || consulta.estado === null;
}

/** Lo que se escribe en `ordenes/{id}.alertaDePago` (sin la hora, que la pone la base).  Queda la ULTIMA. */
export interface AlertaDePago {
  readonly motivo: MotivoSinAplicar;
  readonly operacionId: string;
  readonly estadoDelProveedor: string;
  readonly monto: Centavos;
}

export function alertaDePago(consulta: ConsultaDePago, motivo: MotivoSinAplicar): AlertaDePago {
  return {
    motivo,
    operacionId: consulta.operacionId,
    estadoDelProveedor: consulta.estadoDelProveedor,
    monto: consulta.monto,
  };
}

// ------------------------------------------------- la re-consulta (HU-08.3)

/** Lo que recibe `revisarPago`. */
export interface PedidoDeRevision {
  readonly ordenId: string;
}

/** RECHAZA lo que no cumple; no lo corrige.  Mismo trato que los otros parsers. */
export function parsearPedidoDeRevision(entrada: unknown): Validacion<PedidoDeRevision> {
  if (
    typeof entrada !== 'object' ||
    entrada === null ||
    Array.isArray(entrada) ||
    !Object.keys(entrada).every((k) => k === 'ordenId')
  ) {
    return { ok: false, motivo: 'el pedido no tiene la forma {ordenId}' };
  }
  const { ordenId } = entrada as { ordenId?: unknown };
  if (!esIdDeOrden(ordenId)) return { ok: false, motivo: 'ordenId invalido' };
  return { ok: true, valor: { ordenId } };
}

/** Lo que devuelve `revisarPago`, y lo que el panel dice con eso. */
export interface ResultadoDeRevision {
  /** El estado de pago DESPUES de revisar. */
  readonly estadoPago: EstadoPago;
  /** true si la revision lo movio. */
  readonly cambio: boolean;
  /** Cuantos pagos tiene el proveedor para esta Orden.  0: el comprador no llego a pagar. */
  readonly encontrados: number;
}
