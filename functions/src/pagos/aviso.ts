/**
 * Lo que hace el webhook de Mercado Pago, sin el `onRequest`.  ADR 003 (el
 * contrato), ADR 022 (lo que se decidio al escribirlo).
 *
 *   firma -> tema -> CONSULTA al proveedor -> transaccion con marcador
 *
 * El status que se contesta es una decision, no un detalle: Mercado Pago
 * REINTENTA todo lo que no sea 2xx, con backoff, durante ~24 h.
 *
 *  - 401: la firma no cierra.  Que reintente: si el secreto rota, los avisos
 *    que se perdieron en el medio vuelven a entrar.
 *  - 200: todo lo que se proceso, y todo lo que NUNCA va a salir distinto (otro
 *    tema, un pago que el proveedor no conoce, uno de otra venta de la cuenta,
 *    uno que no se aplica).  Reintentarlo solo hace ruido.
 *  - 500 (en `aviso_de_mercado_pago.ts`): lo que puede salir distinto la
 *    proxima -la API de Mercado Pago o Firestore caidos-.  Ese reintento es el
 *    que queremos.
 *
 * Se procesa ANTES de contestar, y no despues como sugiere la skill de
 * webhooks: en Cloud Functions lo que corre despues de responder no tiene CPU
 * garantizada, y un aviso contestado 200 y no procesado es una venta cobrada y
 * no registrada.  Es corto -una consulta y una transaccion-.
 */
import type { Firestore } from 'firebase-admin/firestore';
import * as logger from 'firebase-functions/logger';

import type { AvisoRecibido, ProveedorDePago } from '@bouquet/contratos';

import { aplicarConsulta } from './aplicar.ts';

export interface RespuestaAlAviso {
  readonly status: number;
  readonly cuerpo: string;
}

type Crudo = Readonly<Record<string, unknown>>;

/** Un encabezado o un parametro, que Express puede dar como lista: el primero. */
function primero(x: unknown): string | undefined {
  const v = Array.isArray(x) ? x[0] : x;
  return typeof v === 'string' ? v : undefined;
}

/** La request de Express como `AvisoRecibido`: nombres de encabezado en minusculas, valores sueltos. */
export function avisoDesdeHttp(encabezados: Crudo, parametros: Crudo, cuerpo: unknown): AvisoRecibido {
  const norm = (o: Crudo, minusculas: boolean) =>
    Object.fromEntries(Object.entries(o).map(([k, v]) => [minusculas ? k.toLowerCase() : k, primero(v)]));
  return { encabezados: norm(encabezados, true), parametros: norm(parametros, false), cuerpo };
}

export async function procesarAviso(
  db: Firestore,
  proveedor: ProveedorDePago,
  aviso: AvisoRecibido,
): Promise<RespuestaAlAviso> {
  const requestId = aviso.encabezados['x-request-id'];

  // 1. La firma, antes de creerle nada al cuerpo (ADR 003, regla 2).
  const lectura = proveedor.leerAviso(aviso);
  if (lectura.es === 'firma-invalida') {
    logger.warn('aviso de pago con firma invalida', { razon: lectura.razon, requestId });
    return { status: 401, cuerpo: 'firma invalida' };
  }
  if (lectura.es === 'otro-tema') return { status: 200, cuerpo: `ignorado: ${lectura.tema}` };

  // 2. La verdad sale de la consulta, no del cuerpo (ADR 003, regla 1).  Si la
  //    API falla, lanza, y el envoltorio contesta 500 para que reintente.
  const consulta = await proveedor.consultarPago(lectura.operacionId);
  if (consulta === null) {
    logger.warn('aviso de un pago que el proveedor no conoce', { operacionId: lectura.operacionId, requestId });
    return { status: 200, cuerpo: 'pago desconocido' };
  }

  // 3. La transaccion con su marcador.
  const r = await aplicarConsulta(db, consulta, `aviso:${proveedor.nombre}`);
  const contexto = { operacionId: consulta.operacionId, estadoDelProveedor: consulta.estadoDelProveedor, requestId };
  switch (r.es) {
    case 'aplicado':
    case 'repetido':
      logger.info(`aviso de pago ${r.es}`, { ...contexto, ordenId: r.ordenId, estadoPago: r.estadoPago });
      break;
    case 'sin-orden':
      logger.info('aviso de un pago sin Orden nuestra (otra venta de la cuenta)', contexto);
      break;
    case 'sin-aplicar':
      // Se registro en el marcador.  Si movio plata que la Orden no refleja (un
      // segundo cobro, un monto distinto, un contracargo), ademas quedo la
      // alerta en la Orden, y es ERROR: alguien tiene que devolver o revisar.
      // Un rechazo tardio sobre una pagada no movio nada: WARNING.
      (r.atencion ? logger.error : logger.warn)('aviso de pago que NO se aplico', {
        ...contexto,
        ordenId: r.ordenId,
        motivo: r.motivo,
        atencion: r.atencion,
      });
      break;
    case 'orden-inexistente':
    case 'orden-rota':
      // ERROR: `crearOrden` escribe la Orden ANTES de la preferencia, asi que un
      // pago con referencia a una Orden que no esta no deberia existir.  200 igual:
      // si es de otro entorno que comparte la cuenta, reintentar 24 h no la crea.
      // `revisarPago` la recupera si era una carrera.
      logger.error(`aviso de pago con ${r.es}`, { ...contexto, ordenId: r.ordenId });
      break;
  }
  return { status: 200, cuerpo: r.es };
}
