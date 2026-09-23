/**
 * `moverStock` -- la segunda Cloud Function del proyecto, y la primera que
 * escribe plata.  EP-05, ADR 016.
 *
 * El panel NO escribe `stock` (las reglas lo congelan, ADR 008): pide esto.
 * Dos operaciones -reponer y corregir-, las dos con la clave de idempotencia
 * `idMovimiento` que el panel genera al abrir la hoja.
 *
 * Orden de las guardas, cada una antes de la siguiente:
 *   1. Esta autenticado y tiene el claim `rol: admin` (`exigirAdmin`).
 *   2. El pedido valida entero (`parsearPedidoDeMovimiento`, de contratos:
 *      la MISMA forma que el panel espeja en Dart).
 * Recien despues se toca Firestore, y todo lo demas -que el producto exista,
 * sea simple, y que la cuenta cierre- pasa adentro de la transaccion.
 */
import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { parsearPedidoDeMovimiento } from '@bouquet/contratos';

import { exigirAdmin } from '../auth.ts';
import { appDeFunctions } from '../firebase.ts';
import { moverStock as moverEnFirestore, type ResultadoDelMovimiento } from './mover.ts';

export const moverStock = onCall<unknown, Promise<ResultadoDelMovimiento>>(
  { region: 'us-central1' },
  async (request) => {
    const uid = exigirAdmin(request);

    const pedido = parsearPedidoDeMovimiento(request.data);
    if (!pedido.ok) throw new HttpsError('invalid-argument', pedido.motivo);

    return moverEnFirestore(getFirestore(appDeFunctions()), pedido.valor, uid);
  },
);
