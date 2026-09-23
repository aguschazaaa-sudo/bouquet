/**
 * `procesarFoto` -- la primera Cloud Function del proyecto.
 *
 * El panel sube el crudo a Storage y llama a esta callable con su ruta; ella
 * la baja, la recorta con la MISMA tuberia que el seed, la sube como WebP
 * junto al producto y borra el crudo. Es sincronica a proposito -no un
 * trigger de Storage- para que HU-04.4 (un fallo se ve, con el nombre de la
 * foto) salga gratis del transporte (design.md decision 1).
 *
 * Orden de las guardas, cada una antes de la siguiente:
 *   1. Esta autenticado.
 *   2. Tiene el claim `rol: admin`.
 *   3. La ruta es `productos/{productoId}/{archivo}` con el id que vino en
 *      el argumento -sin esto, la callable es un endpoint HTTPS publico que
 *      procesa/borra cualquier objeto del bucket.
 *   4. El crudo pesa menos de 5 MB (metadata, sin bajar el archivo).
 *   5. Son bytes de jpeg/png/webp -leidos del contenido, nunca del path ni
 *      del contentType declarado.
 * Recien despues de las cinco se procesa y se sube.
 */
import { getStorage } from 'firebase-admin/storage';
import { HttpsError, onCall } from 'firebase-functions/v2/https';

import { exigirAdmin } from '../auth.ts';
import { appDeFunctions } from '../firebase.ts';
import { procesarTuberia } from './tuberia.ts';
import { TOPE_DE_BYTES, detectarFormato } from './validar.ts';
import { validarRutaDelCrudo } from './ruta.ts';

interface DatosDeEntrada {
  readonly productoId: string;
  readonly ruta: string;
}

interface RespuestaDeProcesarFoto {
  readonly url: string;
  readonly ancho: number;
  readonly alto: number;
  readonly porcentajeRecortado: number;
}

function esperaString(valor: unknown, campo: string): string {
  if (typeof valor !== 'string' || valor.length === 0) {
    throw new HttpsError('invalid-argument', `falta o esta vacio el campo "${campo}"`);
  }
  return valor;
}

export const procesarFoto = onCall<DatosDeEntrada, Promise<RespuestaDeProcesarFoto>>(
  { region: 'us-central1' },
  async (request) => {
    // 1 y 2. Autenticado y con el claim rol:admin. Las reglas de
    //    Firestore/Storage NO protegen esta callable -corre con el Admin SDK
    //    y las saltea por diseno- asi que esta es la unica puerta. Es la
    //    MISMA guarda que `moverStock` (auth.ts): una sola copia.
    exigirAdmin(request);

    const productoId = esperaString(request.data?.productoId, 'productoId');
    const rutaCruda = esperaString(request.data?.ruta, 'ruta');

    // 3. La ruta.
    const nombreDeArchivo = validarRutaDelCrudo(rutaCruda, productoId);
    if (!nombreDeArchivo) {
      throw new HttpsError(
        'invalid-argument',
        `la ruta "${rutaCruda}" no es productos/${productoId}/<archivo>`,
      );
    }

    const bucket = getStorage(appDeFunctions()).bucket();
    const archivoCrudo = bucket.file(rutaCruda);

    const [existe] = await archivoCrudo.exists();
    if (!existe) {
      throw new HttpsError('not-found', `no existe ${rutaCruda} en Storage`);
    }

    // 4. El peso, con metadata: no hace falta bajar el archivo para medirlo.
    const [metadata] = await archivoCrudo.getMetadata();
    const bytes = Number(metadata.size ?? 0);
    if (bytes >= TOPE_DE_BYTES) {
      throw new HttpsError(
        'invalid-argument',
        `${rutaCruda} pesa ${bytes} bytes, el tope es ${TOPE_DE_BYTES}`,
      );
    }

    const [buffer] = await archivoCrudo.download();

    // 5. El formato, leido del contenido.
    const formato = detectarFormato(buffer);
    if (!formato) {
      throw new HttpsError(
        'invalid-argument',
        `${rutaCruda} no es un jpeg, png ni webp reconocible por sus bytes`,
      );
    }

    let procesada;
    try {
      procesada = await procesarTuberia(buffer);
    } catch (error) {
      throw new HttpsError(
        'invalid-argument',
        `no se pudo procesar ${rutaCruda}: ${(error as Error).message}`,
      );
    }

    const destino = `productos/${productoId}/${procesada.hash}.webp`;
    const archivoFinal = bucket.file(destino);
    await archivoFinal.save(procesada.webp, {
      resumable: false,
      contentType: 'image/webp',
      metadata: { cacheControl: 'public, max-age=31536000, immutable' },
    });

    // El crudo se borra SOLO si todo lo anterior salio bien (requisito "El
    // archivo crudo no sobrevive a una subida exitosa").
    await archivoCrudo.delete();

    // URL publica directa, NO firmada: `productos/{id}/{archivo}` ya es de
    // lectura publica por storage.rules (`allow read: if true`), asi que una
    // signed URL solo agregaria una dependencia de IAM (signBlob) sin
    // necesidad. Misma forma que ya usa `scripts/seed/seed.mjs`.
    const url = `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(destino)}?alt=media`;

    return {
      url,
      ancho: procesada.ancho,
      alto: procesada.alto,
      porcentajeRecortado: procesada.porcentajeRecortado,
    };
  },
);
