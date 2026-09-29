// guardar.emulador.mjs -- el nucleo de `guardarCajasSugeridas` contra el
// emulador de Firestore.  HU-09.2, HU-09.3.
//
// Corre con:
//   firebase emulators:exec --only firestore --project demo-bouquet \
//     "node --test functions/test/vidriera/guardar.emulador.mjs"
//
// Solo Firestore, SIN el emulador de Functions: su discovery no completa en
// esta maquina (ADR 015, 3.7).  Por eso el nucleo recibe la base por
// parametro y se prueba directo, igual que `crear.emulador.mjs` y
// `mover.emulador.mjs`.
//
// NO termina en `.test.ts`: no la agarra el glob de `npm test`, que corre sin
// emuladores.
//
// Cada requisito tiene un caso que APLICA y uno que RECHAZA: sin el que
// aplica, un rechazo pasaria tambien con una escritura que niega todo.

import assert from 'node:assert/strict';
import { beforeEach, describe, test } from 'node:test';

const PROYECTO = 'demo-bouquet';
assert.ok(process.env.FIRESTORE_EMULATOR_HOST, 'falta FIRESTORE_EMULATOR_HOST: correlo con emulators:exec');
process.env.GCLOUD_PROJECT = PROYECTO;

const { initializeApp } = await import('firebase-admin/app');
const { getFirestore } = await import('firebase-admin/firestore');
const { guardarCajasSugeridas } = await import('../../src/vidriera/guardar.ts');

const db = getFirestore(initializeApp({ projectId: PROYECTO }, 'test-vidriera'));

const documento = db.doc('cajasSugeridas/publicas');

// Lo que deja el panel en `productos`: solo hace falta lo que lee el nucleo
// (`presentacion.botellas`), mas los campos que tendria un vino real.
const vino = (botellas = 1, cambios = {}) => ({
  tipo: 'simple',
  precio: 1990000,
  stock: 10,
  presentacion: { botellas },
  publicado: true,
  ...cambios,
});
const sembrarVino = (id, botellas = 1, cambios = {}) => db.collection('productos').doc(id).set(vino(botellas, cambios));

const caja = (nombre, productoIds) => ({ nombre, productoIds });
const pedido = (...cajas) => ({ cajas });

/** Corre y devuelve el error como `{ code, details, motivo }`, o `null` si no fallo. */
async function fallo(promesa) {
  try {
    await promesa;
    return null;
  } catch (e) {
    return { code: e.code, details: e.details, motivo: e.message };
  }
}

const leerDocumento = async () => (await documento.get()).data();

beforeEach(async () => {
  // El emulador no se reinicia solo entre casos: se borra todo.
  await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${PROYECTO}/databases/(default)/documents`, {
    method: 'DELETE',
  });
});

// ============================================================ lo que aplica

describe('guardar cajas sugeridas', () => {
  test('guarda el documento con los slugs derivados, en el orden pedido; guardar dos veces da lo mismo', async () => {
    for (const id of ['v1', 'v2', 'v3', 'v4', 'v5', 'v6']) await sembrarVino(id, 1);

    const p = pedido(
      caja('Seis tintos', ['v1', 'v2', 'v3', 'v4', 'v5', 'v6']),
      caja('Para el asado', ['v1', 'v1', 'v1', 'v2', 'v2', 'v2']),
    );

    const r = await guardarCajasSugeridas(db, p);
    assert.deepEqual(r, { cajas: 2 });

    const esperado = {
      cajas: [
        { slug: 'seis-tintos', nombre: 'Seis tintos', productoIds: ['v1', 'v2', 'v3', 'v4', 'v5', 'v6'] },
        { slug: 'para-el-asado', nombre: 'Para el asado', productoIds: ['v1', 'v1', 'v1', 'v2', 'v2', 'v2'] },
      ],
    };
    assert.deepEqual(await leerDocumento(), esperado);

    // Guardar de nuevo, idempotente: el mismo documento.
    const r2 = await guardarCajasSugeridas(db, p);
    assert.deepEqual(r2, { cajas: 2 });
    assert.deepEqual(await leerDocumento(), esperado);
  });

  test('un documento previo con `muestra: true` y otras cajas queda reemplazado entero', async () => {
    await documento.set({ muestra: true, cajas: [{ slug: 'vieja', nombre: 'Vieja', productoIds: ['x', 'x', 'x', 'x', 'x', 'x'] }] });
    for (const id of ['v1', 'v2', 'v3', 'v4', 'v5', 'v6']) await sembrarVino(id, 1);

    await guardarCajasSugeridas(db, pedido(caja('Nueva', ['v1', 'v2', 'v3', 'v4', 'v5', 'v6'])));

    const guardado = await leerDocumento();
    assert.deepEqual(guardado, { cajas: [{ slug: 'nueva', nombre: 'Nueva', productoIds: ['v1', 'v2', 'v3', 'v4', 'v5', 'v6'] }] });
    assert.equal('muestra' in guardado, false, 'el guardado del dueno saca `muestra`');
  });

  test('un vino repetido -mismo id dos veces- suma dos botellas', async () => {
    await sembrarVino('v1', 1);
    await sembrarVino('v2', 1);
    await sembrarVino('v3', 1);

    const r = await guardarCajasSugeridas(db, pedido(caja('Tres por dos', ['v1', 'v1', 'v2', 'v2', 'v3', 'v3'])));

    assert.deepEqual(r, { cajas: 1 });
    assert.deepEqual((await leerDocumento()).cajas[0].productoIds, ['v1', 'v1', 'v2', 'v2', 'v3', 'v3']);
  });

  test('un vino despublicado o sin stock SI guarda: la caja se sigue ofreciendo con el lugar marcado', async () => {
    await sembrarVino('v1', 1, { publicado: false });
    await sembrarVino('v2', 1, { stock: 0 });
    for (const id of ['v3', 'v4', 'v5', 'v6']) await sembrarVino(id, 1);

    const r = await guardarCajasSugeridas(db, pedido(caja('Con caidos', ['v1', 'v2', 'v3', 'v4', 'v5', 'v6'])));

    assert.deepEqual(r, { cajas: 1 });
    assert.equal((await leerDocumento()).cajas[0].nombre, 'Con caidos');
  });

  test('la lista vacia guarda `{ cajas: [] }`', async () => {
    const r = await guardarCajasSugeridas(db, pedido());
    assert.deepEqual(r, { cajas: 0 });
    assert.deepEqual(await leerDocumento(), { cajas: [] });
  });

  test('control: la misma caja sin el que viaja solo, con uno suelto en su lugar, guarda', async () => {
    for (const id of ['v1', 'v2', 'v3', 'v4', 'v5', 'v6']) await sembrarVino(id, 1);
    const r = await guardarCajasSugeridas(db, pedido(caja('Toda suelta', ['v1', 'v2', 'v3', 'v4', 'v5', 'v6'])));
    assert.deepEqual(r, { cajas: 1 });
  });
});

// ============================================================== los rechazos

describe('lo que no guarda, y el documento previo queda igual', () => {
  test('un producto que no existe: failed-precondition, y el documento previo no se toca', async () => {
    for (const id of ['v1', 'v2', 'v3', 'v4', 'v5']) await sembrarVino(id, 1);
    await guardarCajasSugeridas(db, pedido(caja('La que queda', ['v1', 'v2', 'v3', 'v4', 'v5', 'v5'])));
    const antes = await leerDocumento();

    const e = await fallo(
      guardarCajasSugeridas(db, pedido(caja('Con fantasma', ['v1', 'v2', 'v3', 'v4', 'v5', 'fantasma']))),
    );

    assert.equal(e?.code, 'failed-precondition');
    assert.deepEqual(e?.details, { caja: 'Con fantasma' });
    assert.deepEqual(await leerDocumento(), antes, 'el documento previo no cambio');
  });

  test('un vino que viaja solo (2 botellas) rechaza, aunque la suma pudiera dar seis', async () => {
    await sembrarVino('pack', 2);
    for (const id of ['v1', 'v2', 'v3', 'v4', 'v5']) await sembrarVino(id, 1);

    const e = await fallo(guardarCajasSugeridas(db, pedido(caja('Con pack', ['pack', 'v1', 'v2', 'v3', 'v4', 'v5']))));

    assert.equal(e?.code, 'failed-precondition');
    assert.match(e?.motivo ?? '', /viene en su propia caja/);
    assert.deepEqual(e?.details, { caja: 'Con pack' });
    assert.equal((await documento.get()).exists, false, 'nunca se escribio nada');
  });

  test('nombre repetido: invalid-argument, sin escribir', async () => {
    for (const id of ['v1', 'v2', 'v3', 'v4', 'v5', 'v6']) await sembrarVino(id, 1);

    const e = await fallo(
      guardarCajasSugeridas(
        db,
        pedido(caja('Seis tintos', ['v1', 'v2', 'v3', 'v4', 'v5', 'v6']), caja('seis  tintos', ['v1', 'v2', 'v3', 'v4', 'v5', 'v6'])),
      ),
    );

    assert.equal(e?.code, 'invalid-argument');
    assert.equal((await documento.get()).exists, false, 'nada previo, y nada nuevo');
  });

  test('un pedido mal formado: invalid-argument, sin escribir', async () => {
    const e = await fallo(guardarCajasSugeridas(db, { cajas: 'no es una lista' }));
    assert.equal(e?.code, 'invalid-argument');
    assert.equal((await documento.get()).exists, false);
  });

  test('`details.caja` trae el nombre de la caja que fallo, no la primera que si cerraba', async () => {
    for (const id of ['v1', 'v2', 'v3', 'v4', 'v5', 'v6']) await sembrarVino(id, 1);

    const e = await fallo(
      guardarCajasSugeridas(
        db,
        pedido(
          caja('La buena', ['v1', 'v2', 'v3', 'v4', 'v5', 'v6']),
          caja('La rota', ['v1', 'v2', 'v3', 'v4', 'v5', 'fantasma']),
        ),
      ),
    );

    assert.equal(e?.code, 'failed-precondition');
    assert.deepEqual(e?.details, { caja: 'La rota' });
    // Ni siquiera la primera, que si cerraba, queda escrita: es todo o nada.
    assert.equal((await documento.get()).exists, false);
  });
});
