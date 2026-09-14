// proyecto.mjs - la conexion de seed.mjs y borrar.mjs, y la baranda que les
// impide escribir en otro proyecto.  specs/datos-de-muestra, ADR 008.
//
// ⚠️ Medido el 2026-09-10 en la maquina de desarrollo: el proyecto activo de
// gcloud es `red-social-ryb3mf` y la cuota de las credenciales (ADC) apunta a
// `quiz-hoot-7ymbj0`. Con ADC y SIN projectId explicito, el seed habria
// escrito veinte vinos en una red social ajena, sin un solo error.

import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

export const PROYECTO = 'bouquet-vinos';
export const BUCKET = 'bouquet-vinos.firebasestorage.app';

const AQUI = dirname(fileURLToPath(import.meta.url));

/** El catalogo de muestra. Sus ids son la UNICA lista que borrar.mjs toca. */
export function leerCatalogo() {
  return JSON.parse(readFileSync(join(AQUI, 'catalogo.json'), 'utf8'));
}

/** Todo lo que el seed escribe en Firestore, como rutas. Deterministico. */
export function rutasSembradas(catalogo) {
  return [
    ...catalogo.bodegas.map((b) => `bodegas/${b.id}`),
    ...catalogo.vinos.map((v) => `productos/${v.id}`),
    'metricas/popularidad',
  ];
}

/**
 * Conecta con ADC y el projectId FIJO. Esa es la baranda entera: con el
 * projectId explicito el cliente escribe en bouquet-vinos sea cual sea el
 * proyecto activo de gcloud. (Habia un `if (db.projectId !== PROYECTO)`:
 * `db.projectId` devuelve el que se le paso, asi que comparaba el dato consigo
 * mismo y no podia fallar nunca. Lo encontro revisor-pagos y se saco: una
 * baranda que no puede fallar da confianza falsa.) Los imports van despues de
 * fijar la cuota, porque el cliente la lee al crearse.
 */
export async function conectar() {
  // Sin esto, cada pedido se autoriza y se factura contra la cuota de las
  // credenciales, que es de otro proyecto.
  process.env.GOOGLE_CLOUD_QUOTA_PROJECT = PROYECTO;

  const { applicationDefault, initializeApp } = await import('firebase-admin/app');
  const { getFirestore, Timestamp } = await import('firebase-admin/firestore');
  const { getStorage } = await import('firebase-admin/storage');

  const app = initializeApp({ credential: applicationDefault(), projectId: PROYECTO, storageBucket: BUCKET }, 'seed');
  const db = getFirestore(app);

  // Una lectura antes de cualquier escritura: si las credenciales o la cuota no
  // sirven, falla aca y no a mitad de un lote.
  await db.doc('metricas/popularidad').get();
  return { db, bucket: getStorage(app).bucket(BUCKET), Timestamp };
}
