// calcular.emulador.mjs -- el nucleo de `calcularPopularidad` contra el
// emulador de Firestore.  HU-11.3, ADR 025.
//
// Corre con:
//   firebase emulators:exec --only firestore --project demo-bouquet \
//     "node --test functions/test/metricas/calcular.emulador.mjs"
//
// Solo Firestore, SIN el emulador de Functions: su discovery no completa en
// esta maquina (ADR 015, 3.7).  Por eso el nucleo recibe la base y la hora por
// parametro, igual que `guardar.emulador.mjs`.
//
// NO termina en `.test.ts`: no la agarra el glob de `npm test`, que corre sin
// emuladores.
//
// Lo que prueba aca y no en contratos es lo que depende de FIRESTORE: que la
// consulta de la ventana traiga lo que tiene que traer (los dos bordes de
// `creadaEn`), que el documento quede con la forma que lee la vidriera, y que
// dos corridas den el mismo documento.

import assert from 'node:assert/strict';
import { beforeEach, describe, test } from 'node:test';

const PROYECTO = 'demo-bouquet';
assert.ok(process.env.FIRESTORE_EMULATOR_HOST, 'falta FIRESTORE_EMULATOR_HOST: correlo con emulators:exec');
process.env.GCLOUD_PROJECT = PROYECTO;

const { initializeApp } = await import('firebase-admin/app');
const { getFirestore, Timestamp } = await import('firebase-admin/firestore');
const { calcularPopularidad } = await import('../../src/metricas/calcular.ts');

const db = getFirestore(initializeApp({ projectId: PROYECTO }, 'test-metricas'));
const documento = db.doc('metricas/popularidad');

const DIA = 24 * 60 * 60 * 1000;
const AHORA = new Date('2026-09-29T08:00:00.000Z');
const haceDias = (n) => new Date(AHORA.getTime() - n * DIA);

/** Una Orden con lo que el job lee, mas lo que tendria una real. */
function orden(creadaEn, estadoPago, estadoEntrega, items) {
  return {
    numero: 1,
    origen: estadoPago === 'por_fuera' ? 'whatsapp' : 'vidriera',
    estadoPago,
    estadoEntrega,
    items: items.map(([productoId, cantidad]) => ({
      productoId,
      cantidad,
      nombre: productoId,
      precioUnitario: 1990000,
      botellas: 1,
    })),
    creadaEn: Timestamp.fromDate(creadaEn),
  };
}

let siguiente = 0;
const sembrar = (datos) => db.collection('ordenes').doc(`o${(siguiente += 1)}`).set(datos);

beforeEach(async () => {
  await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${PROYECTO}/databases/(default)/documents`, {
    method: 'DELETE',
  });
});

describe('calcular la popularidad', () => {
  test('cuenta las ventas de la ventana y escribe el documento medido', async () => {
    await sembrar(orden(haceDias(1), 'pagada', 'entregada', [['malbec', 2], ['torrontes', 1]]));
    await sembrar(orden(haceDias(30), 'por_fuera', 'sin_preparar', [['malbec', 3]]));
    // No son ventas: no suman.
    await sembrar(orden(haceDias(2), 'pendiente', 'sin_preparar', [['malbec', 50]]));
    await sembrar(orden(haceDias(2), 'por_fuera', 'cancelada', [['torrontes', 50]]));

    const r = await calcularPopularidad(db, AHORA);

    assert.deepEqual(r, { leidas: 4, ventas: 2, vinos: 2, ilegibles: 0 });
    const d = (await documento.get()).data();
    assert.deepEqual(d.unidades, { malbec: 5, torrontes: 1 });
    assert.equal(d.simulada, false);
    assert.equal(d.ventas, 2);
    assert.equal(d.ventanaDias, 90);
    assert.equal(d.calculadaEn.toDate().toISOString(), AHORA.toISOString());
    assert.equal(d.desde.toDate().toISOString(), haceDias(90).toISOString());
  });

  test('los bordes de la ventana: entra el primer instante, no entra lo de despues de la hora', async () => {
    await sembrar(orden(haceDias(90), 'pagada', 'entregada', [['en-el-borde', 1]]));
    await sembrar(orden(new Date(haceDias(90).getTime() - 1), 'pagada', 'entregada', [['un-ms-antes', 1]]));
    await sembrar(orden(new Date(AHORA.getTime() - 1), 'pagada', 'entregada', [['recien', 1]]));
    await sembrar(orden(AHORA, 'pagada', 'entregada', [['a-la-hora', 1]]));
    await sembrar(orden(new Date(AHORA.getTime() + DIA), 'pagada', 'entregada', [['despues', 1]]));

    const r = await calcularPopularidad(db, AHORA);

    assert.equal(r.leidas, 2);
    assert.deepEqual((await documento.get()).data().unidades, { 'en-el-borde': 1, recien: 1 });
  });

  test('una Orden sin creadaEn no entra en la ventana', async () => {
    const { creadaEn: _, ...sinHora } = orden(haceDias(1), 'pagada', 'entregada', [['sin-hora', 9]]);
    await sembrar(sinHora);
    await sembrar(orden(haceDias(1), 'pagada', 'entregada', [['con-hora', 1]]));

    await calcularPopularidad(db, AHORA);

    assert.deepEqual((await documento.get()).data().unidades, { 'con-hora': 1 });
  });

  test('un documento roto se cuenta como ilegible y no tira la corrida', async () => {
    await sembrar({ creadaEn: Timestamp.fromDate(haceDias(1)), estadoPago: 'pagada', estadoEntrega: 'entregada', items: 'roto' });
    await sembrar(orden(haceDias(1), 'pagada', 'entregada', [['sano', 2]]));

    const r = await calcularPopularidad(db, AHORA);

    assert.deepEqual(r, { leidas: 2, ventas: 1, vinos: 1, ilegibles: 1 });
    assert.deepEqual((await documento.get()).data().unidades, { sano: 2 });
  });

  test('pisa el documento simulado del seed entero, sin dejar sus campos', async () => {
    await documento.set({ simulada: true, muestra: true, unidades: { 'muestra-inventado': 500 } });
    await sembrar(orden(haceDias(3), 'pagada', 'entregada', [['real', 1]]));

    await calcularPopularidad(db, AHORA);

    const d = (await documento.get()).data();
    assert.deepEqual(d.unidades, { real: 1 });
    assert.equal(d.muestra, undefined);
    assert.equal(d.simulada, false);
  });

  test('sin ventas, un mapa vacio: la vidriera deja de ofrecer el orden por popularidad', async () => {
    await sembrar(orden(haceDias(3), 'pendiente', 'sin_preparar', [['a', 1]]));

    await calcularPopularidad(db, AHORA);

    const d = (await documento.get()).data();
    // Un mapa VACIO, no ausente: `armarCatalogo` descarta un `unidades` que no
    // es un mapa, y eso lo loguearia como documento roto en cada build.
    assert.deepEqual(d.unidades, {});
    assert.equal(d.ventas, 0);
    assert.equal(d.simulada, false);
  });

  test('dos corridas a la misma hora dan el mismo documento, byte a byte', async () => {
    await sembrar(orden(haceDias(5), 'pagada', 'entregada', [['b', 1], ['a', 2]]));
    await sembrar(orden(haceDias(6), 'por_fuera', 'despachada', [['c', 4]]));

    await calcularPopularidad(db, AHORA);
    const primera = (await documento.get()).data();
    await calcularPopularidad(db, AHORA);
    const segunda = (await documento.get()).data();

    assert.equal(JSON.stringify(segunda), JSON.stringify(primera));
    // Y no se infla: es lo que un contador que suma no cumple.
    assert.deepEqual(segunda.unidades, { a: 2, b: 1, c: 4 });
  });
});
