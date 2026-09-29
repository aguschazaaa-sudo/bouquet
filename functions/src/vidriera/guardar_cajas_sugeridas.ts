/**
 * `guardarCajasSugeridas` -- la callable que reescribe `cajasSugeridas/publicas`.
 * HU-09.2, HU-09.3.
 *
 * La escritura del documento esta cerrada incluso para el admin
 * (`firestore.rules`): el dueno arma y reordena las cajas en el panel, y esta
 * es la unica puerta.
 *
 * Orden de las guardas, cada una antes de la siguiente:
 *   1. Esta autenticado y tiene el claim `rol: admin` (`exigirAdmin`).
 *   2. El nucleo (`guardar.ts`) valida el pedido entero y verifica la
 *      composicion contra el catalogo.
 */
import { getFirestore } from 'firebase-admin/firestore';
import { onCall } from 'firebase-functions/v2/https';

import { exigirAdmin } from '../auth.ts';
import { appDeFunctions } from '../firebase.ts';
import { guardarCajasSugeridas as guardarEnFirestore, type ResultadoDeGuardar } from './guardar.ts';

export const guardarCajasSugeridas = onCall<unknown, Promise<ResultadoDeGuardar>>(
  { region: 'us-central1' },
  async (request) => {
    exigirAdmin(request);

    return guardarEnFirestore(getFirestore(appDeFunctions()), request.data);
  },
);
