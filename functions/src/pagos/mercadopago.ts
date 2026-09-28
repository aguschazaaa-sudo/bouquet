/**
 * El adaptador de Mercado Pago del puerto `ProveedorDePago`.  ADR 022.
 *
 * Lo que es de Mercado Pago y de nadie mas: el SDK oficial, la traduccion de
 * sus estados a `estadoPago`, y la firma de sus avisos.  La regla que decide si
 * una consulta mueve una Orden NO esta aca: es `resolverConsulta`, en
 * contratos, y no sabe que existe Mercado Pago.
 *
 * El SDK es el oficial (`mercadopago`, cero dependencias) y la firma la
 * verifica SU `WebhookSignatureValidator`, no una copia nuestra del HMAC: una
 * implementacion recien escrita solo la probo quien la escribio.
 *
 * El cliente HTTP entra por parametro (`ClienteDeMercadoPago`): el SDK es la
 * unica pieza que habla por la red, y las pruebas -el pedido falso de
 * `pago.emulador.mjs`- reemplazan SOLO esa.  La traduccion y la firma corren
 * de verdad.
 */
import {
  InvalidWebhookSignatureError,
  MercadoPagoConfig,
  MPNotFoundError,
  Payment,
  WebhookSignatureValidator,
} from 'mercadopago';

import {
  desdePesos,
  esIdDeOrden,
  type AvisoRecibido,
  type Centavos,
  type ConsultaDePago,
  type EstadoPago,
  type LecturaDeAviso,
  type ProveedorDePago,
  type Validacion,
} from '@bouquet/contratos';

/**
 * Los estados de un pago de Mercado Pago, en nuestro eje.  `null`: no se
 * traduce, se registra y la Orden no se toca.
 *
 * - `pending` es `en_proceso` y no `pendiente`: `pendiente` es la Orden que
 *   todavia no tiene NINGUN intento de pago (ADR 003); un cupon de efectivo
 *   generado ya es un intento, y tarda dias (ADR 010 §7).
 * - `authorized` es una tarjeta autorizada sin capturar: la plata no esta.
 * - `cancelled` es un cupon que vencio o un pago que se cancelo: el comprador
 *   puede volver a intentar, y `rechazada` es la que admite reintento.
 * - `charged_back` y `in_mediation` NO se traducen: un contracargo o una
 *   disputa pueden resolverse a favor de la tienda, y `reembolsada` es
 *   terminal.  Marcarlos seria una decision irreversible tomada por un estado
 *   que no lo es.  ADR 022 §2.
 */
export const ESTADOS_DE_MERCADO_PAGO: Readonly<Record<string, EstadoPago | null>> = {
  pending: 'en_proceso',
  in_process: 'en_proceso',
  authorized: 'en_proceso',
  approved: 'pagada',
  rejected: 'rechazada',
  cancelled: 'rechazada',
  refunded: 'reembolsada',
  charged_back: null,
  in_mediation: null,
};

/** Un estado que Mercado Pago agregue manana tampoco se adivina. */
export function estadoDeMercadoPago(status: string): EstadoPago | null {
  return Object.hasOwn(ESTADOS_DE_MERCADO_PAGO, status) ? (ESTADOS_DE_MERCADO_PAGO[status] ?? null) : null;
}

const ID_DE_OPERACION = /^[A-Za-z0-9_-]{1,64}$/;
const ESTADO_CRUDO = /^[a-z_]{1,40}$/;

function esObjeto(x: unknown): x is Record<string, unknown> {
  return typeof x === 'object' && x !== null && !Array.isArray(x);
}

/** `null` si no son pesos con hasta dos decimales (un `1e-7`, un `19.999`). */
function aCentavos(pesos: number): Centavos | null {
  try {
    return desdePesos(pesos);
  } catch {
    return null;
  }
}

/**
 * Un pago de la API de Mercado Pago (`GET /v1/payments/{id}`, o un resultado
 * de `search`) como `ConsultaDePago`.  RECHAZA lo que no cumple: un pago con un
 * monto que no es plata, o sin estado, no se "arregla".
 *
 * El id y el estado crudo terminan en el id del marcador, que es un id de
 * documento de Firestore: por eso se validan con un patron cerrado.
 */
export function traducirPagoDeMercadoPago(crudo: unknown): Validacion<ConsultaDePago> {
  if (!esObjeto(crudo)) return { ok: false, motivo: 'el pago no es un objeto' };

  const id = typeof crudo.id === 'number' ? String(crudo.id) : crudo.id;
  if (typeof id !== 'string' || !ID_DE_OPERACION.test(id)) return { ok: false, motivo: 'el pago no tiene un id valido' };

  if (typeof crudo.status !== 'string' || !ESTADO_CRUDO.test(crudo.status)) {
    return { ok: false, motivo: `el pago ${id} no tiene un estado valido` };
  }
  const detalle = typeof crudo.status_detail === 'string' && crudo.status_detail !== '' ? crudo.status_detail : null;

  // `transaction_amount` viene en PESOS, con decimales.  `desdePesos` lo pasa a
  // centavos por texto, sin el redondeo flotante que pierde un centavo.
  if (typeof crudo.transaction_amount !== 'number' || !Number.isFinite(crudo.transaction_amount)) {
    return { ok: false, motivo: `el pago ${id} no tiene un monto` };
  }
  const monto = aCentavos(crudo.transaction_amount);
  if (monto === null) {
    return { ok: false, motivo: `el pago ${id} tiene un monto que no es plata: ${crudo.transaction_amount}` };
  }

  // Lo devuelto: ausente es 0 (la busqueda no siempre lo trae); presente, tiene
  // que ser plata.  Un reembolso parcial deja el estado en `approved` y mueve
  // solo esto (ADR 022 §3).
  const crudoDevuelto = crudo.transaction_amount_refunded ?? 0;
  const reembolsado = typeof crudoDevuelto === 'number' ? aCentavos(crudoDevuelto) : null;
  if (reembolsado === null || reembolsado < 0) {
    return { ok: false, motivo: `el pago ${id} tiene un reembolso que no es plata: ${String(crudoDevuelto)}` };
  }

  if (typeof crudo.currency_id !== 'string') return { ok: false, motivo: `el pago ${id} no tiene moneda` };
  if (typeof crudo.date_created !== 'string') return { ok: false, motivo: `el pago ${id} no tiene fecha` };

  return {
    ok: true,
    valor: {
      proveedor: 'mercadopago',
      operacionId: id,
      // Una referencia que no es un id nuestro es de otra venta de la misma
      // cuenta: se trata igual que la que no trae ninguna.
      ordenId: esIdDeOrden(crudo.external_reference) ? crudo.external_reference : null,
      estado: estadoDeMercadoPago(crudo.status),
      estadoDelProveedor: crudo.status,
      detalle,
      monto,
      reembolsado,
      moneda: crudo.currency_id,
      creadoEn: crudo.date_created,
    },
  };
}

// ----------------------------------------------------------------- el aviso

/**
 * Lee un aviso de Mercado Pago: la firma primero, el tema despues.
 *
 * - El `data.id` que firma Mercado Pago es el de la URL (`?data.id=`); el del
 *   cuerpo se usa solo si la URL no lo trae.  Y va en minusculas: la
 *   documentacion lo pide para los ids alfanumericos, y el validador del SDK
 *   no lo hace.  En un pago, que es numerico, no cambia nada.
 * - SIN ventana de tiempo (`toleranceSeconds`): repetir un aviso no hace dano,
 *   porque la verdad sale de la consulta, y una ventana corta rechazaria un
 *   reintento legitimo si Mercado Pago reenvia la marca de hora original.
 *   ADR 022 §4.
 */
export function leerAvisoDeMercadoPago(aviso: AvisoRecibido, secreto: string): LecturaDeAviso {
  const cuerpo = esObjeto(aviso.cuerpo) ? aviso.cuerpo : {};
  const dato = esObjeto(cuerpo.data) ? cuerpo.data : {};
  const delCuerpo = typeof dato.id === 'string' || typeof dato.id === 'number' ? String(dato.id) : undefined;
  const dataId = (aviso.parametros['data.id'] ?? delCuerpo)?.toLowerCase();

  try {
    WebhookSignatureValidator.validate({
      xSignature: aviso.encabezados['x-signature'],
      xRequestId: aviso.encabezados['x-request-id'],
      dataId,
      secret: secreto,
    });
  } catch (e) {
    if (e instanceof InvalidWebhookSignatureError) return { es: 'firma-invalida', razon: e.reason };
    throw e;
  }

  const tema = aviso.parametros['type'] ?? (typeof cuerpo.type === 'string' ? cuerpo.type : '');
  if (tema !== 'payment') return { es: 'otro-tema', tema };
  if (dataId === undefined || !ID_DE_OPERACION.test(dataId)) return { es: 'otro-tema', tema: 'payment-sin-id' };
  return { es: 'pago', operacionId: dataId };
}

// -------------------------------------------------------------- el adaptador

/** La unica pieza que habla por la red.  Las pruebas la reemplazan; nada mas. */
export interface ClienteDeMercadoPago {
  /** `null`: Mercado Pago no conoce ese pago (404). */
  obtener(operacionId: string): Promise<unknown>;
  buscarPorReferencia(ordenId: string): Promise<readonly unknown[]>;
}

/** El cliente de verdad, con el SDK oficial. */
export function clienteDelSdk(accessToken: string): ClienteDeMercadoPago {
  // 8 s por pedido: el webhook tiene que contestar antes de que Mercado Pago
  // lo de por caido, y el SDK reintenta los 5xx por su cuenta.
  const pagos = new Payment(new MercadoPagoConfig({ accessToken, options: { timeout: 8000 } }));
  return {
    async obtener(operacionId) {
      try {
        return await pagos.get({ id: operacionId });
      } catch (e) {
        if (e instanceof MPNotFoundError) return null;
        throw e;
      }
    },
    async buscarPorReferencia(ordenId) {
      // Una pagina de 30 (la de la API): un pedido no junta treinta intentos.
      const r = await pagos.search({ options: { external_reference: ordenId, sort: 'date_created', criteria: 'asc' } });
      return r.results ?? [];
    },
  };
}

/** Un pago que Mercado Pago devolvio y no se puede leer: es un error, no un "no existe". */
function traducidoOError(crudo: unknown): ConsultaDePago {
  const t = traducirPagoDeMercadoPago(crudo);
  if (!t.ok) throw new Error(`Mercado Pago devolvio un pago ilegible: ${t.motivo}`);
  return t.valor;
}

export function proveedorMercadoPago(cliente: ClienteDeMercadoPago, secretoDeFirma: string): ProveedorDePago {
  return {
    nombre: 'mercadopago',
    leerAviso: (aviso) => leerAvisoDeMercadoPago(aviso, secretoDeFirma),
    async consultarPago(operacionId) {
      const crudo = await cliente.obtener(operacionId);
      return crudo === null ? null : traducidoOError(crudo);
    },
    async buscarPagosDeLaOrden(ordenId) {
      const crudos = await cliente.buscarPorReferencia(ordenId);
      // La busqueda filtra por la referencia, pero se vuelve a mirar: un pago de
      // otra Orden no entra a esta por un filtro que no hizo lo que dice.
      return crudos.map(traducidoOError).filter((c) => c.ordenId === ordenId);
    },
  };
}
