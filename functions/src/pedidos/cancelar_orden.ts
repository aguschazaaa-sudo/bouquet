/**
 * `cancelarOrden` -- la cuarta Cloud Function del proyecto, y la unica que
 * DEVUELVE stock.  HU-07.6, ADR 019.
 *
 * Existe porque cancelar no es solo cambiar un estado: las botellas que el
 * pedido descontaba vuelven a la venta, y `stock` lo escribe solo el servidor
 * (ADR 008).  El resto del eje de entrega -preparar, despachar, entregar, la
 * entrega fallida- lo escribe el panel directo y lo validan las reglas; este
 * paso no, y las reglas se lo niegan a cualquier cliente.
 *
 * Orden de las guardas, cada una antes de la siguiente:
 *   1. Esta autenticado y tiene el claim `rol: admin` (`exigirAdmin`).
 *   2. El pedido valida entero (`parsearPedidoDeCancelacion`, de contratos).
 * Recien despues se toca Firestore, y que la Orden exista y se pueda cancelar
 * pasa adentro de la transaccion, contra lo que se acaba de leer.
 */
import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { parsearPedidoDeCancelacion } from '@bouquet/contratos';

import { exigirAdmin } from '../auth.ts';
import { appDeFunctions } from '../firebase.ts';
import { cancelarOrden as cancelarEnFirestore, type ResultadoDeCancelar } from './cancelar.ts';

export const cancelarOrden = onCall<unknown, Promise<ResultadoDeCancelar>>(
  // 120 por la misma cuenta que `crearOrdenDelPanel`: `maxAttempts: 10` con el
  // backoff de Firestore suma ~75 s.  Reintentar es seguro: la Orden cancelada es
  // su propio marcador.
  { region: 'us-central1', timeoutSeconds: 120 },
  async (request) => {
    const uid = exigirAdmin(request);

    const pedido = parsearPedidoDeCancelacion(request.data);
    if (!pedido.ok) throw new HttpsError('invalid-argument', pedido.motivo);

    return cancelarEnFirestore(getFirestore(appDeFunctions()), pedido.valor, uid);
  },
);
