/**
 * `avisoDeMercadoPago` -- el webhook.  La quinta Cloud Function, y la primera
 * que NO es del panel: la llama Mercado Pago.  ADR 003 y ADR 022.
 *
 * Es publica (`invoker: 'public'`) porque Mercado Pago no tiene un token de
 * Google: lo que la protege es la firma, que se verifica antes de todo.  Sin el
 * `invoker`, IAM la frena con un 403 que el codigo nunca ve -el mismo modo de
 * falla que tuvo `procesarFoto` (ADR 015)-.
 *
 * Todo lo que hace esta en `procesarAviso`; aca solo se arma el proveedor con
 * los secretos y se traduce un error a 500, que es el que hace reintentar.
 */
import { getFirestore } from 'firebase-admin/firestore';
import * as logger from 'firebase-functions/logger';
import { onRequest } from 'firebase-functions/v2/https';

import { appDeFunctions } from '../firebase.ts';
import { avisoDesdeHttp, procesarAviso } from './aviso.ts';
import { SECRETOS_DE_MERCADO_PAGO, proveedorDeProduccion } from './secretos.ts';

export const avisoDeMercadoPago = onRequest(
  // 60 s: una consulta a Mercado Pago (8 s de timeout, con sus reintentos) y una
  // transaccion.  Mercado Pago da por caido un aviso que tarda, y lo reintenta.
  { region: 'us-central1', timeoutSeconds: 60, invoker: 'public', secrets: SECRETOS_DE_MERCADO_PAGO },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).send('solo POST');
      return;
    }
    try {
      const aviso = avisoDesdeHttp(req.headers, req.query, req.body);
      const r = await procesarAviso(getFirestore(appDeFunctions()), proveedorDeProduccion(), aviso);
      res.status(r.status).send(r.cuerpo);
    } catch (e) {
      logger.error('el aviso de pago no se pudo procesar: Mercado Pago lo va a reintentar', e);
      res.status(500).send('error');
    }
  },
);
