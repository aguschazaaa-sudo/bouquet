// fijar.emulador.mjs -- el nucleo de `fijarEnvioSinCargo` contra el emulador
// de Firestore.  HU-11.1, ADR 026.  TOCA PLATA (Workflow D).
//
// Corre con:
//   firebase emulators:exec --only firestore --project demo-bouquet \
//     "node --test functions/test/config/fijar.emulador.mjs"
//
// Solo Firestore, SIN el emulador de Functions: su discovery no completa en
// esta maquina (ADR 015, 3.7).  Por eso el nucleo recibe la base por
// parametro, igual que `guardar.emulador.mjs`.
//
// NO termina en `.test.ts`: no la agarra el glob de `npm test`, que corre sin
// emuladores.
//
// Cada guarda tiene un caso que GUARDA y uno que NO: sin el que guarda, un
// rechazo pasaria tambien con un nucleo que no escribe nunca.  Y cada "no se
// guardo" se mide LEYENDO el documento, no creyendole a la respuesta.

import assert from 'node:assert/strict';
import { beforeEach, describe, test } from 'node:test';

const PROYECTO = 'demo-bouquet';
assert.ok(process.env.FIRESTORE_EMULATOR_HOST, 'falta FIRESTORE_EMULATOR_HOST: correlo con emulators:exec');
process.env.GCLOUD_PROJECT = PROYECTO;

const { initializeApp } = await import('firebase-admin/app');
const { getFirestore } = await import('firebase-admin/firestore');
const { fijarEnvioSinCargo } = await import('../../src/config/fijar.ts');
const { leerConfigDeEnvios } = await import('@bouquet/contratos');

const db = getFirestore(initializeApp({ projectId: PROYECTO }, 'test-config'));
const documento = db.doc('config/envios');
const UID = 'duenio';

const pesos = (n) => n * 100;

/** Un vino como lo deja el panel: la baranda lee `precio` y `presentacion.botellas`. */
const sembrarVino = (id, precioEnPesos, cambios = {}) =>
  db.collection('productos').doc(id).set({
    tipo: 'simple',
    precio: pesos(precioEnPesos),
    stock: 10,
    presentacion: { botellas: 1 },
    publicado: true,
    ...cambios,
  });

/** Cinco sueltas a 10, 20, 30, 40 y 50 mil: la caja tipica es 6 x 30.000 = 180.000. */
async function sembrarCatalogo() {
  for (const [i, precio] of [10_000, 20_000, 30_000, 40_000, 50_000].entries()) {
    await sembrarVino(`vino-${i}`, precio);
  }
}

async function fallo(promesa) {
  try {
    await promesa;
    return null;
  } catch (e) {
    return { code: e.code, motivo: e.message };
  }
}

const leer = async () => (await documento.get()).data();

beforeEach(async () => {
  await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${PROYECTO}/databases/(default)/documents`, {
    method: 'DELETE',
  });
});

describe('fijar el envio sin cargo', () => {
  test('un monto sano se guarda entero, con quien y cuando', async () => {
    await sembrarCatalogo();
    const r = await fijarEnvioSinCargo(db, UID, { sinCargoDesde: pesos(250_000) });

    assert.deepEqual(r, { guardado: true, sinCargoDesde: pesos(250_000) });
    const d = await leer();
    assert.equal(d.sinCargoDesde, pesos(250_000));
    assert.equal(d.actualizadoPor, UID);
    assert.ok(d.actualizadoEn, 'la hora del servidor');
    // Lo que escribe es lo que la vidriera sabe leer.
    assert.deepEqual(leerConfigDeEnvios(d), { sinCargoDesde: pesos(250_000), roto: false });
  });

  test('PRIMERA escritura por debajo de una caja tipica: pregunta y NO guarda', async () => {
    await sembrarCatalogo();
    const r = await fijarEnvioSinCargo(db, UID, { sinCargoDesde: pesos(15_000) });

    assert.deepEqual(r, { guardado: false, motivo: 'debajo-de-una-caja', cajaTipica: pesos(180_000) });
    assert.equal((await documento.get()).exists, false, 'no se escribio nada');
  });

  test('confirmado, el mismo monto se guarda, y dice que la baranda lo marcaba', async () => {
    await sembrarCatalogo();
    const r = await fijarEnvioSinCargo(db, UID, { sinCargoDesde: pesos(15_000), confirmado: true });

    // `barandaConfirmada` es lo que la callable loguea como advertencia: sin
    // el, un umbral de $1 confirmado de entrada no deja rastro distinto de un
    // cambio sano (revisor-pagos, 2026-09-29).
    assert.deepEqual(r, {
      guardado: true,
      sinCargoDesde: pesos(15_000),
      barandaConfirmada: { motivo: 'debajo-de-una-caja', cajaTipica: pesos(180_000) },
    });
    assert.equal((await leer()).sinCargoDesde, pesos(15_000));
  });

  test('confirmado sin nada que confirmar: se guarda sin marca', async () => {
    await sembrarCatalogo();
    const r = await fijarEnvioSinCargo(db, UID, { sinCargoDesde: pesos(250_000), confirmado: true });
    assert.deepEqual(r, { guardado: true, sinCargoDesde: pesos(250_000) });
  });

  test('una caja tipica exacta no pregunta (el borde)', async () => {
    await sembrarCatalogo();
    const r = await fijarEnvioSinCargo(db, UID, { sinCargoDesde: pesos(180_000) });
    assert.equal(r.guardado, true);
  });

  test('lo que NO esta publicado no entra en la caja tipica', async () => {
    await sembrarCatalogo();
    // Cinco baratisimos sin publicar: si contaran, la caja tipica bajaria y
    // el monto de abajo no preguntaria.
    for (let i = 0; i < 5; i += 1) await sembrarVino(`oculto-${i}`, 100, { publicado: false });

    const r = await fijarEnvioSinCargo(db, UID, { sinCargoDesde: pesos(100_000) });
    assert.equal(r.guardado, false);
    assert.equal(r.cajaTipica, pesos(180_000));
  });

  test('bajar a menos de la mitad del anterior pregunta, y el anterior queda', async () => {
    await documento.set({ sinCargoDesde: pesos(200_000) });
    // Sin catalogo (menos de 5 publicados): la unica senal es el anterior.
    const r = await fijarEnvioSinCargo(db, UID, { sinCargoDesde: pesos(90_000) });

    assert.deepEqual(r, { guardado: false, motivo: 'menos-de-la-mitad', anterior: pesos(200_000) });
    assert.equal((await leer()).sinCargoDesde, pesos(200_000));
  });

  test('bajar a la mitad justa, o subir, no pregunta', async () => {
    await documento.set({ sinCargoDesde: pesos(200_000) });
    assert.equal((await fijarEnvioSinCargo(db, UID, { sinCargoDesde: pesos(100_000) })).guardado, true);
    assert.equal((await fijarEnvioSinCargo(db, UID, { sinCargoDesde: pesos(900_000) })).guardado, true);
    assert.equal((await leer()).sinCargoDesde, pesos(900_000));
  });

  test('un anterior ROTO no tira la callable y se reemplaza', async () => {
    // Sin catalogo, para que la unica senal posible sea el anterior.
    await documento.set({ sinCargoDesde: 'basura' });
    const r = await fijarEnvioSinCargo(db, UID, { sinCargoDesde: pesos(15_000) });
    assert.deepEqual(r, { guardado: true, sinCargoDesde: pesos(15_000) });
    assert.equal((await leer()).sinCargoDesde, pesos(15_000));
  });

  test('apagar se guarda sin preguntar, aunque hubiera un umbral', async () => {
    await sembrarCatalogo();
    await documento.set({ sinCargoDesde: pesos(200_000) });
    const r = await fijarEnvioSinCargo(db, UID, { sinCargoDesde: null });

    assert.deepEqual(r, { guardado: true, sinCargoDesde: null });
    const d = await leer();
    assert.equal(d.sinCargoDesde, null);
    assert.deepEqual(leerConfigDeEnvios(d), { sinCargoDesde: null, roto: false });
  });

  test('lo que no cumple la forma NO se guarda nunca, ni confirmado', async () => {
    await documento.set({ sinCargoDesde: pesos(200_000) });
    for (const malo of [
      { sinCargoDesde: 0, confirmado: true },
      { sinCargoDesde: -100, confirmado: true },
      { sinCargoDesde: 150_050, confirmado: true },
      { sinCargoDesde: '150000' },
      { sinCargoDesde: pesos(200_000), actualizadoPor: 'otro' },
      { confirmado: true },
      null,
    ]) {
      const e = await fallo(fijarEnvioSinCargo(db, UID, malo));
      assert.equal(e?.code, 'invalid-argument', JSON.stringify(malo));
    }
    assert.equal((await leer()).sinCargoDesde, pesos(200_000), 'el anterior sigue intacto');
  });

  test('guardar dos veces da lo mismo', async () => {
    await sembrarCatalogo();
    await fijarEnvioSinCargo(db, UID, { sinCargoDesde: pesos(250_000) });
    const primera = await leer();
    await fijarEnvioSinCargo(db, UID, { sinCargoDesde: pesos(250_000) });
    const segunda = await leer();
    assert.equal(segunda.sinCargoDesde, primera.sinCargoDesde);
    assert.deepEqual(Object.keys(segunda).sort(), ['actualizadoEn', 'actualizadoPor', 'sinCargoDesde']);
  });
});
