/**
 * `revisarPago` -- la sexta Cloud Function: el boton *"Volver a consultar"* del
 * detalle de un pedido de la vidriera.  HU-08.3, ADR 022 §5.
 *
 * Orden de las guardas, cada una antes de la siguiente:
 *   1. Esta autenticado y tiene el claim `rol: admin` (`exigirAdmin`).
 *   2. El pedido valida entero (`parsearPedidoDeRevision`, de contratos).
 * Recien despues se lee Firestore y se le pregunta a Mercado Pago.
 */
import { getFirestore } from 'firebase-admin/firestore';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { parsearPedidoDeRevision, type ResultadoDeRevision } from '@bouquet/contratos';

import { exigirAdmin } from '../auth.ts';
import { appDeFunctions } from '../firebase.ts';
import { revisarPago as revisarEnFirestore } from './revisar.ts';
import { SECRETOS_DE_MERCADO_PAGO, proveedorDeProduccion } from './secretos.ts';

export const revisarPago = onCall<unknown, Promise<ResultadoDeRevision>>(
  // 120 por la misma cuenta que las otras callables que escriben ordenes, mas la
  // busqueda en Mercado Pago.  Reintentar es seguro: cada hecho tiene su marcador.
  { region: 'us-central1', timeoutSeconds: 120, secrets: SECRETOS_DE_MERCADO_PAGO },
  async (request) => {
    const uid = exigirAdmin(request);

    const pedido = parsearPedidoDeRevision(request.data);
    if (!pedido.ok) throw new HttpsError('invalid-argument', pedido.motivo);

    return revisarEnFirestore(getFirestore(appDeFunctions()), proveedorDeProduccion(), pedido.valor, uid);
  },
);
