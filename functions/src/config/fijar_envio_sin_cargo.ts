/**
 * `fijarEnvioSinCargo` -- la callable que escribe `config/envios`. HU-11.1,
 * ADR 026.
 *
 * `config` es solo del servidor, creacion incluida (ARQUITECTURA §9.4): el
 * dueno fija desde que monto no cobra el envio en el panel, y esta es la unica
 * puerta. La baranda contra el dedo gordo vive en el nucleo (`fijar.ts`).
 *
 * Orden de las guardas, cada una antes de la siguiente:
 *   1. Esta autenticado y tiene el claim `rol: admin` (`exigirAdmin`).
 *   2. El nucleo valida, pregunta si hace falta, y guarda con el `uid`.
 */
import { getFirestore } from 'firebase-admin/firestore';
import * as logger from 'firebase-functions/logger';
import { onCall } from 'firebase-functions/v2/https';

import { exigirAdmin } from '../auth.ts';
import { appDeFunctions } from '../firebase.ts';
import { fijarEnvioSinCargo as fijarEnFirestore, type ResultadoDeFijar } from './fijar.ts';

export const fijarEnvioSinCargo = onCall<unknown, Promise<ResultadoDeFijar>>(
  { region: 'us-central1' },
  async (request) => {
    const uid = exigirAdmin(request);

    const r = await fijarEnFirestore(getFirestore(appDeFunctions()), uid, request.data);
    // Toca plata: queda dicho quien lo cambio y a cuanto, o por que se pregunto.
    // Un monto que la baranda marcaba y se guardo confirmado es una ADVERTENCIA:
    // es el caso para el que existe la baranda, y tiene que poder buscarse.
    if (!r.guardado) logger.info('envio sin cargo: pide confirmar', { uid, ...r });
    else if (r.barandaConfirmada) logger.warn('envio sin cargo fijado CONTRA la baranda, confirmado', { uid, ...r });
    else logger.info('envio sin cargo fijado', { uid, ...r });
    return r;
  },
);
