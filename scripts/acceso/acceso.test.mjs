// acceso.test.mjs - el script de accesos contra el emulador de Auth.
// openspec/changes/panel-entrar/specs/panel-cuentas.
//
// Corre con:
//   firebase emulators:exec --only auth --project demo-bouquet \
//     "node --test scripts/acceso/acceso.test.mjs"
//
// Cada requisito tiene un caso ACEPTADO y uno RECHAZADO: sin el aceptado, un
// script que se niega a todo pasaria todos los rechazos.

import assert from 'node:assert/strict';
import { after, before, beforeEach, describe, test } from 'node:test';

import {
  AccesoNegado,
  PROYECTO_EMULADOR,
  ROL,
  conectar,
  darAcceso,
  listarConAcceso,
  normalizarMail,
  quitarAcceso,
} from './acceso.mjs';

const HOST = process.env.FIREBASE_AUTH_EMULATOR_HOST;
const BASE = `http://${HOST}`;
let auth;
let cerrar;

// Registrarse como lo haria un extrano con la API key publica.
async function registrarseConContrasena(mail) {
  const r = await fetch(
    `${BASE}/identitytoolkit.googleapis.com/v1/accounts:signUp?key=clave-de-control`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email: mail, password: 'clave-del-extrano', returnSecureToken: true }),
    },
  );
  assert.equal(r.status, 200, 'el emulador no dejo registrarse');
  return (await r.json()).localId;
}

before(async () => {
  // Sin emulador, estos tests no corren contra nada: frenar en vez de pasar.
  assert.ok(HOST, 'falta FIREBASE_AUTH_EMULATOR_HOST: correlo con emulators:exec');
  ({ auth, cerrar } = await conectar({ emulador: true }));
});

after(async () => cerrar?.());

beforeEach(async () => {
  const r = await fetch(`${BASE}/emulator/v1/projects/${PROYECTO_EMULADOR}/accounts`, {
    method: 'DELETE',
  });
  assert.equal(r.status, 200);
});

describe('dar', () => {
  test('un mail nuevo nace sin contrasena y con el rol', async () => {
    const r = await darAcceso(auth, '  Familia@Gmail.com ');
    assert.equal(r.creada, true);
    assert.equal(r.mail, 'familia@gmail.com');
    const u = await auth.getUser(r.uid);
    assert.deepEqual(u.providerData, []);
    assert.equal(u.passwordHash, undefined);
    assert.deepEqual(u.customClaims, { rol: ROL });
  });

  test('una cuenta verificada conserva sus otros claims', async () => {
    const u = await auth.createUser({ email: 'hijo@gmail.com', password: 'una-clave', emailVerified: true });
    await auth.setCustomUserClaims(u.uid, { avisaPorWhatsApp: true });
    const r = await darAcceso(auth, 'hijo@gmail.com');
    assert.equal(r.creada, false);
    assert.deepEqual((await auth.getUser(u.uid)).customClaims, { avisaPorWhatsApp: true, rol: ROL });
  });

  test('una cuenta registrada por un tercero NO se habilita', async () => {
    const uid = await registrarseConContrasena('prima@gmail.com');
    await assert.rejects(darAcceso(auth, 'prima@gmail.com'), AccesoNegado);
    const u = await auth.getUser(uid);
    assert.equal(u.customClaims, undefined, 'la cuenta quedo con claims');
  });

  test('control: la misma cuenta, verificada, si se habilita', async () => {
    const uid = await registrarseConContrasena('prima@gmail.com');
    await auth.updateUser(uid, { emailVerified: true });
    await darAcceso(auth, 'prima@gmail.com');
    assert.equal((await auth.getUser(uid)).customClaims.rol, ROL);
  });

  test('algo que no es un mail se rechaza antes de tocar nada', async () => {
    await assert.rejects(darAcceso(auth, 'sin-arroba'), AccesoNegado);
    assert.equal((await auth.listUsers()).users.length, 0);
  });
});

describe('quitar', () => {
  test('saca el rol, deja lo demas y revoca las sesiones', async () => {
    const { uid } = await darAcceso(auth, 'tio@gmail.com');
    await auth.setCustomUserClaims(uid, { rol: ROL, avisaPorWhatsApp: true });
    const antes = (await auth.getUser(uid)).tokensValidAfterTime;
    await new Promise((listo) => setTimeout(listo, 1100));

    const r = await quitarAcceso(auth, 'tio@gmail.com');
    const u = await auth.getUser(uid);
    assert.equal(r.teniaAcceso, true);
    assert.deepEqual(u.customClaims, { avisaPorWhatsApp: true });
    assert.notEqual(u.tokensValidAfterTime, antes, 'las sesiones no se revocaron');
  });

  test('un mail sin cuenta se informa, no se crea', async () => {
    await assert.rejects(quitarAcceso(auth, 'nadie@gmail.com'), AccesoNegado);
    assert.equal((await auth.listUsers()).users.length, 0);
  });
});

describe('listar', () => {
  // No ejercita la paginacion: con tres cuentas hay una sola pagina.
  test('solo los que tienen el rol', async () => {
    await darAcceso(auth, 'b@gmail.com');
    await darAcceso(auth, 'a@gmail.com');
    const otro = await auth.createUser({ email: 'sin@gmail.com' });
    await auth.setCustomUserClaims(otro.uid, { rol: 'repartidor' });
    assert.deepEqual(await listarConAcceso(auth), ['a@gmail.com', 'b@gmail.com']);
  });
});

describe('baranda', () => {
  test('el emulador usa un proyecto demo-, que no puede tocar uno real', async () => {
    assert.match(PROYECTO_EMULADOR, /^demo-/);
  });

  test('sin --emulador y con la variable del emulador puesta, se niega', async () => {
    await assert.rejects(conectar({ emulador: false }), AccesoNegado);
  });

  test('normalizarMail', () => {
    assert.equal(normalizarMail(' A@B.com '), 'a@b.com');
    assert.throws(() => normalizarMail('a@b'), AccesoNegado);
  });
});
