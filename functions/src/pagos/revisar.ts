/**
 * Volver a consultar el pago de una Orden, sin depender de que el aviso haya
 * llegado.  HU-08.3, ADR 022 §5.
 *
 * Busca en el proveedor TODOS los intentos de pago de la Orden -por la
 * referencia, no por un numero de operacion: si el aviso nunca llego, no hay
 * numero que consultar- y aplica cada uno con `aplicarConsulta`, el MISMO
 * nucleo que el aviso.  Asi un hecho que llega por los dos caminos a la vez
 * tiene efecto una vez: los dos escriben el mismo marcador.
 *
 * Del mas viejo al mas nuevo: la tabla de ADR 002 resuelve el resto.  Una
 * tarjeta rechazada y despues aprobada queda pagada en cualquier orden; en este
 * orden, ademas, cada paso es una transicion valida y el marcador de la vieja
 * dice `aplicado: true`.
 */
import type { Firestore } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';

import {
  ESTADOS_PAGO,
  type ConsultaDePago,
  type EstadoPago,
  type PedidoDeRevision,
  type ProveedorDePago,
  type ResultadoDeRevision,
} from '@bouquet/contratos';

import { aplicarConsulta } from './aplicar.ts';

const esEstadoPago = (x: unknown): x is EstadoPago =>
  typeof x === 'string' && (ESTADOS_PAGO as readonly string[]).includes(x);

/** Una fecha ilegible va primero: no se inventa donde cae. */
const cuando = (c: ConsultaDePago): number => Date.parse(c.creadoEn) || 0;

export async function revisarPago(
  db: Firestore,
  proveedor: ProveedorDePago,
  pedido: PedidoDeRevision,
  uid: string,
): Promise<ResultadoDeRevision> {
  // Afuera de una transaccion: es para decidir si vale la pena preguntarle al
  // proveedor.  Lo que se escribe se decide adentro de `aplicarConsulta`, sobre
  // la Orden que esa transaccion lee.
  const snap = await db.collection('ordenes').doc(pedido.ordenId).get();
  if (!snap.exists) throw new HttpsError('not-found', 'no existe la orden', { codigo: 'no-existe' });

  const antes: unknown = snap.get('estadoPago');
  if (!esEstadoPago(antes)) {
    throw new HttpsError('failed-precondition', 'la orden tiene un dato roto', { codigo: 'orden-rota' });
  }
  // Un pedido de WhatsApp se cobra por fuera: no hay nada que preguntarle a
  // nadie, y el panel no ofrece el boton.  Si llega igual, se dice por que.
  if (snap.get('origen') !== 'vidriera') {
    throw new HttpsError('failed-precondition', 'el cobro de este pedido va por fuera', { codigo: 'por-fuera' });
  }

  let encontradas: readonly ConsultaDePago[];
  try {
    encontradas = await proveedor.buscarPagosDeLaOrden(pedido.ordenId);
  } catch (e) {
    // El panel lo dice como *"Mercado Pago no contesto, proba de nuevo"*, no como
    // un error nuestro.  No se escribio nada: reintentar es seguro.
    throw new HttpsError('unavailable', 'el proveedor de pagos no contesto', {
      codigo: 'proveedor-caido',
      detalle: e instanceof Error ? e.message : String(e),
    });
  }
  const consultas = [...encontradas].sort((a, b) => cuando(a) - cuando(b));

  let estadoPago: EstadoPago = antes;
  for (const consulta of consultas) {
    const r = await aplicarConsulta(db, consulta, uid);
    if (r.es === 'aplicado' || r.es === 'repetido' || r.es === 'sin-aplicar') estadoPago = r.estadoPago;
  }
  return { estadoPago, cambio: estadoPago !== antes, encontrados: consultas.length };
}
