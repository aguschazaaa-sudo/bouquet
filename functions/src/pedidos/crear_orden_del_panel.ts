/**
 * `crearOrdenDelPanel` -- la tercera Cloud Function del proyecto, y la primera
 * que CREA una Orden.  HU-10.1, ADR 018.
 *
 * Es la del PANEL, y por eso el origen es siempre `whatsapp` y lo fija el
 * codigo, no el pedido (`parsearPedidoDelPanel` lo rechaza si viene).  Una
 * `crearOrden` de la vidriera, cuando exista, sera OTRA callable con OTRAS
 * guardas: sin claim, y exigiendo la caja de seis.  Si fueran una sola con un
 * `origen` en el pedido, un comprador se saltearia la regla diciendo
 * `'whatsapp'` (hallazgo 12 del mapa del panel).
 *
 * Orden de las guardas, cada una antes de la siguiente:
 *   1. Esta autenticado y tiene el claim `rol: admin` (`exigirAdmin`).
 *   2. El pedido valida entero (`parsearPedidoDelPanel`, de contratos: la
 *      MISMA forma que el panel arma en Dart).
 * Recien despues se toca Firestore, y todo lo demas -que el producto exista, que
 * haya stock, que el precio no haya cambiado- pasa adentro de la transaccion.
 */
import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { parsearPedidoDelPanel } from '@bouquet/contratos';

import { exigirAdmin } from '../auth.ts';
import { appDeFunctions } from '../firebase.ts';
import { crearOrdenDelPanel as crearEnFirestore, type ResultadoDeCrear } from './crear.ts';

export const crearOrdenDelPanel = onCall<unknown, Promise<ResultadoDeCrear>>(
  // 120 y no los 60 de por defecto: `maxAttempts: 10` con el backoff de Firestore
  // suma ~75 s, y una funcion que muere a mitad de los reintentos deja un
  // resultado AMBIGUO (hallazgo 10 de `revisor-pagos`).  Es seguro reintentar
  // igual, porque el panel reusa el `idPedido`.
  { region: 'us-central1', timeoutSeconds: 120 },
  async (request) => {
    const uid = exigirAdmin(request);

    const pedido = parsearPedidoDelPanel(request.data);
    if (!pedido.ok) throw new HttpsError('invalid-argument', pedido.motivo);

    return crearEnFirestore(getFirestore(appDeFunctions()), pedido.valor, uid);
  },
);
