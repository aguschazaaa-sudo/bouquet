// procesar_foto.emulador.mjs -- procesarFoto contra el emulador, de punta a
// punta: sube el crudo, llama a la callable por HTTP, lee la respuesta.
// openspec/changes/panel-fotos-de-un-vino/specs/procesar-foto.
//
// Corre con:
//   firebase emulators:exec --only auth,firestore,functions,storage \
//     --project demo-bouquet "node --test functions/test/foto/procesar_foto.emulador.mjs"
//
// NO termina en `.test.ts`: no la agarra el glob de `npm test`, que corre sin
// emuladores (mismo motivo que scripts/acceso/acceso.test.mjs vive fuera del
// glob por defecto de su carpeta).
//
// Los tres controles del spec, mas uno de seguridad:
//   1. Un packshot -> sube, recorta ~83%.
//   2. Una foto con fondo -> sube IGUAL, recorta ~0% (el dato no bloquea).
//   3. Un PDF renombrado foto.jpg -> `invalid-argument`, no escribe nada.
//   4. Sin el claim rol:admin -> `permission-denied`.

import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { after, before, test } from 'node:test';

const AQUI = dirname(fileURLToPath(import.meta.url));
const RAIZ = join(AQUI, '..', '..', '..');
const PROYECTO = 'demo-bouquet';
const REGION = 'us-central1';

const HOST_AUTH = process.env.FIREBASE_AUTH_EMULATOR_HOST;
const HOST_FUNCTIONS = process.env.FIREBASE_FUNCTIONS_EMULATOR_HOST ?? '127.0.0.1:5001';
const HOST_STORAGE = process.env.FIREBASE_STORAGE_EMULATOR_HOST;

assert.ok(HOST_AUTH, 'falta FIREBASE_AUTH_EMULATOR_HOST: correlo con emulators:exec');
assert.ok(HOST_STORAGE, 'falta FIREBASE_STORAGE_EMULATOR_HOST: correlo con emulators:exec');

process.env.GCLOUD_PROJECT = PROYECTO;

const { initializeApp, deleteApp } = await import('firebase-admin/app');
const { getAuth } = await import('firebase-admin/auth');
const { getStorage } = await import('firebase-admin/storage');

const app = initializeApp({ projectId: PROYECTO, storageBucket: `${PROYECTO}.appspot.com` }, 'test-foto');
const auth = getAuth(app);
const bucket = getStorage(app).bucket();

const URL_CALLABLE = `http://${HOST_FUNCTIONS}/${PROYECTO}/${REGION}/procesarFoto`;

let idTokenAdmin;

before(async () => {
  const uid = 'operador-de-prueba';
  await auth.createUser({ uid, email: 'operador@bouquet.test' }).catch(() => {});
  await auth.setCustomUserClaims(uid, { rol: 'admin' });

  const customToken = await auth.createCustomToken(uid);
  const r = await fetch(
    `http://${HOST_AUTH}/identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=clave-de-control`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ token: customToken, returnSecureToken: true }),
    },
  );
  assert.equal(r.status, 200, 'el emulador de Auth no dejo intercambiar el custom token');
  idTokenAdmin = (await r.json()).idToken;
});

after(async () => {
  await deleteApp(app);
});

async function subirCrudo(productoId, nombre, bytes, contentType) {
  const ruta = `productos/${productoId}/${nombre}`;
  await bucket.file(ruta).save(bytes, { contentType, resumable: false });
  return ruta;
}

async function llamarCallable(data, { conToken = true } = {}) {
  const headers = { 'Content-Type': 'application/json' };
  if (conToken) headers.Authorization = `Bearer ${idTokenAdmin}`;
  const r = await fetch(URL_CALLABLE, { method: 'POST', headers, body: JSON.stringify({ data }) });
  return { status: r.status, cuerpo: await r.json() };
}

/** Sintetiza la MISMA composicion "botella sobre una mesa" que se uso para
 *  medir el clasificador refutado en el proposal: fondo de madera, sin
 *  borde uniforme. */
async function fotoConFondo() {
  const sharpMod = await import('sharp');
  const sharp = sharpMod.default;
  const W = 1400;
  const H = 1400;
  const px = Buffer.alloc(W * H * 3);
  for (let i = 0; i < W * H; i++) {
    const v = Math.floor(Math.random() * 38);
    px[i * 3] = 128 + v;
    px[i * 3 + 1] = 82 + v;
    px[i * 3 + 2] = 44 + v;
  }
  const mesa = await sharp(px, { raw: { width: W, height: H, channels: 3 } }).jpeg().toBuffer();
  const botellaBase = readFileSync(join(RAIZ, 'scripts', 'seed', 'fotos', 'alamos-malbec.jpg'));
  const botella = await sharp(botellaBase).trim({ threshold: 12 }).resize({ height: 1100 }).toBuffer();
  return sharp(mesa).composite([{ input: botella, gravity: 'center' }]).jpeg({ quality: 90 }).toBuffer();
}

// -------------------------------------------------------- control 1: packshot

test('control 1: un packshot sube y recorta ~83%', async () => {
  const bytes = readFileSync(join(RAIZ, 'scripts', 'seed', 'fotos', 'alamos-malbec.jpg'));
  const ruta = await subirCrudo('vino-packshot', 'crudo.jpg', bytes, 'image/jpeg');

  const { status, cuerpo } = await llamarCallable({ productoId: 'vino-packshot', ruta });

  assert.equal(status, 200, JSON.stringify(cuerpo));
  assert.ok(cuerpo.result.url.includes('vino-packshot'));
  assert.ok(cuerpo.result.porcentajeRecortado > 80 && cuerpo.result.porcentajeRecortado < 85);

  // El crudo se borro, el WebP quedo.
  const [archivos] = await bucket.getFiles({ prefix: 'productos/vino-packshot/' });
  assert.equal(archivos.length, 1);
  assert.ok(archivos[0].name.endsWith('.webp'));
});

// --------------------------------------------------- control 2: foto con fondo

test('control 2: una foto con fondo SUBE IGUAL, y avisa 0% de recorte', async () => {
  const bytes = await fotoConFondo();
  const ruta = await subirCrudo('vino-con-fondo', 'crudo.jpg', bytes, 'image/jpeg');

  const { status, cuerpo } = await llamarCallable({ productoId: 'vino-con-fondo', ruta });

  assert.equal(status, 200, JSON.stringify(cuerpo));
  assert.equal(cuerpo.result.porcentajeRecortado, 0);

  const [archivos] = await bucket.getFiles({ prefix: 'productos/vino-con-fondo/' });
  assert.equal(archivos.length, 1, 'el dato de 0% no tiene que bloquear la subida');
});

// -------------------------------------------------- control 3: PDF renombrado

test('control 3: un PDF renombrado foto.jpg se rechaza, sin escribir nada', async () => {
  const pdf = Buffer.from('%PDF-1.4\n1 0 obj<<>>endobj\ntrailer<<>>\n%%EOF');
  const ruta = await subirCrudo('vino-pdf-falso', 'foto.jpg', pdf, 'image/jpeg');

  const { status, cuerpo } = await llamarCallable({ productoId: 'vino-pdf-falso', ruta });

  assert.equal(status, 400);
  assert.equal(cuerpo.error.status, 'INVALID_ARGUMENT');

  const [archivos] = await bucket.getFiles({ prefix: 'productos/vino-pdf-falso/' });
  assert.equal(archivos.length, 1, 'el crudo original sigue ahi: no se escribio ningun webp');
  assert.ok(archivos[0].name.endsWith('foto.jpg'));
});

// --------------------------------------------------- control 4: sin el claim

test('control 4: sin el claim rol:admin, permission-denied', async () => {
  const uid = 'operador-sin-rol';
  await auth.createUser({ uid, email: 'sinrol@bouquet.test' }).catch(() => {});
  const customToken = await auth.createCustomToken(uid);
  const r = await fetch(
    `http://${HOST_AUTH}/identitytoolkit.googleapis.com/v1/accounts:signInWithCustomToken?key=clave-de-control`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ token: customToken, returnSecureToken: true }),
    },
  );
  const idTokenSinRol = (await r.json()).idToken;

  const headers = { 'Content-Type': 'application/json', Authorization: `Bearer ${idTokenSinRol}` };
  const resp = await fetch(URL_CALLABLE, {
    method: 'POST',
    headers,
    body: JSON.stringify({ data: { productoId: 'x', ruta: 'productos/x/y.jpg' } }),
  });
  const cuerpo = await resp.json();

  assert.equal(resp.status, 403);
  assert.equal(cuerpo.error.status, 'PERMISSION_DENIED');
});

test('sin autenticar, unauthenticated', async () => {
  const { status, cuerpo } = await llamarCallable(
    { productoId: 'x', ruta: 'productos/x/y.jpg' },
    { conToken: false },
  );
  assert.equal(status, 401);
  assert.equal(cuerpo.error.status, 'UNAUTHENTICATED');
});

test('la ruta de OTRO producto se rechaza', async () => {
  const { status, cuerpo } = await llamarCallable({
    productoId: 'malbec-a',
    ruta: 'productos/malbec-b/x.jpg',
  });
  assert.equal(status, 400);
  assert.equal(cuerpo.error.status, 'INVALID_ARGUMENT');
});
