// mover.emulador.mjs -- la transaccion de `moverStock` contra el emulador de
// Firestore.  EP-05, ADR 016.
//
// Corre con:
//   firebase emulators:exec --only firestore --project demo-bouquet \
//     "node --test functions/test/stock/mover.emulador.mjs"
//
// Solo Firestore, SIN el emulador de Functions: su discovery no completa en
// esta maquina (ADR 015, 3.7).  Por eso el nucleo recibe la base por
// parametro y se prueba directo.
//
// NO termina en `.test.ts`: no la agarra el glob de `npm test`, que corre sin
// emuladores (mismo motivo que `procesar_foto.emulador.mjs`).
//
// Cada requisito tiene un caso que APLICA y uno que RECHAZA.  Sin el que
// aplica, un rechazo pasaria tambien con una transaccion que niega todo.

import assert from 'node:assert/strict';
import { beforeEach, describe, test } from 'node:test';

const PROYECTO = 'demo-bouquet';
assert.ok(process.env.FIRESTORE_EMULATOR_HOST, 'falta FIRESTORE_EMULATOR_HOST: correlo con emulators:exec');
process.env.GCLOUD_PROJECT = PROYECTO;

const { initializeApp } = await import('firebase-admin/app');
const { getFirestore, Timestamp } = await import('firebase-admin/firestore');
const { moverStock } = await import('../../src/stock/mover.ts');

const db = getFirestore(initializeApp({ projectId: PROYECTO }, 'test-stock'));

const ID = 'vino-de-prueba';
const producto = db.collection('productos').doc(ID);
const marcadores = producto.collection('movimientos');

// Lo que el panel deja: los mismos campos que `documento_del_vino.dart`.
const vino = (cambios = {}) => ({
  tipo: 'simple',
  slug: ID,
  nombre: 'Vino de prueba',
  precio: 1990000,
  stock: 10,
  presentacion: { botellas: 1 },
  imagenes: [],
  publicado: true,
  fichaVino: { bodegaId: 'b', varietales: ['Malbec'], color: 'tinto', organico: false, region: 'Mendoza', volumenMl: 750 },
  ...cambios,
});

let contador = 0;
/** Un idMovimiento nuevo y valido (16 a 64 caracteres seguros). */
const nuevoId = () => `movimiento-de-prueba-${String(++contador).padStart(6, '0')}`;

const pedido = (operacion, idMovimiento = nuevoId()) => ({ productoId: ID, idMovimiento, operacion });
const reponer = (cantidad, id) => pedido({ tipo: 'reponer', cantidad }, id);
const corregir = (visto, valor, motivo = 'conteo', id) => pedido({ tipo: 'corregir', visto, valor, motivo }, id);

const stockDe = async () => (await producto.get()).get('stock');
const hayMarcador = async (id) => (await marcadores.doc(id).get()).exists;
const cuantosMarcadores = async () => (await marcadores.get()).size;

/** Corre y devuelve el error como `{ code, details }`, o `null` si no fallo. */
async function fallo(promesa) {
  try {
    await promesa;
    return null;
  } catch (e) {
    return { code: e.code, details: e.details };
  }
}

async function borrarTodo() {
  await fetch(
    `http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${PROYECTO}/databases/(default)/documents`,
    { method: 'DELETE' },
  );
}

beforeEach(async () => {
  await borrarTodo();
  await producto.set(vino());
});

describe('reponer', () => {
  test('suma sobre el stock y deja el marcador con quien, antes, despues y que', async () => {
    const p = reponer(6);
    const r = await moverStock(db, p, 'la-duena');
    assert.deepEqual(r, { antes: 10, despues: 16, repetido: false });
    assert.equal(await stockDe(), 16);

    const m = (await marcadores.doc(p.idMovimiento).get()).data();
    assert.equal(m.por, 'la-duena');
    assert.equal(m.antes, 10);
    assert.equal(m.despues, 16);
    assert.deepEqual(m.operacion, { tipo: 'reponer', cantidad: 6 });
    assert.ok(m.en instanceof Timestamp, 'el marcador lleva la hora del SERVIDOR');
  });

  test('sobre un producto sin stock: lo deja en la cantidad', async () => {
    await producto.set(vino({ stock: 0 }));
    assert.deepEqual(await moverStock(db, reponer(24), 'u'), { antes: 0, despues: 24, repetido: false });
  });

  test('el mismo idMovimiento otra vez NO suma dos veces', async () => {
    const p = reponer(6);
    const primera = await moverStock(db, p, 'u');
    const segunda = await moverStock(db, p, 'u');
    assert.equal(primera.repetido, false);
    assert.deepEqual(segunda, { antes: 10, despues: 16, repetido: true });
    assert.equal(await stockDe(), 16, 'un solo efecto');
    assert.equal(await cuantosMarcadores(), 1);
  });

  test('el reintento devuelve lo de la primera vez, aunque el stock ya sea otro', async () => {
    const p = reponer(6);
    await moverStock(db, p, 'u');
    await moverStock(db, reponer(4), 'u'); // otro movimiento en el medio: 20
    assert.deepEqual(await moverStock(db, p, 'u'), { antes: 10, despues: 16, repetido: true });
    assert.equal(await stockDe(), 20);
  });

  test('el mismo idMovimiento con OTRA operacion: already-exists, y no aplica ninguna', async () => {
    const id = nuevoId();
    await moverStock(db, reponer(6, id), 'u');
    const e = await fallo(moverStock(db, reponer(7, id), 'u'));
    assert.equal(e?.code, 'already-exists');
    assert.equal(await stockDe(), 16, 'la segunda no se aplico');
  });

  test('pasa el tope: rechazada, con el stock actual en el error, sin marcador', async () => {
    await producto.set(vino({ stock: 4995 }));
    const p = reponer(6);
    const e = await fallo(moverStock(db, p, 'u'));
    assert.equal(e?.code, 'failed-precondition');
    assert.deepEqual(e.details, { codigo: 'pasa-el-tope', actual: 4995 });
    assert.equal(await stockDe(), 4995);
    assert.equal(await hayMarcador(p.idMovimiento), false, 'un rechazo no deja marcador');
    // Control positivo del mismo borde: justo hasta el tope si entra.
    assert.deepEqual(await moverStock(db, reponer(5), 'u'), { antes: 4995, despues: 5000, repetido: false });
  });

  test('12 reposiciones AL MISMO TIEMPO suman exacto: ninguna se pierde', async () => {
    await producto.set(vino({ stock: 0 }));
    const resultados = await Promise.all(Array.from({ length: 12 }, () => moverStock(db, reponer(1), 'u')));
    assert.equal(await stockDe(), 12);
    assert.equal(await cuantosMarcadores(), 12);
    // Cada una vio un "antes" distinto: se serializaron de verdad.
    assert.deepEqual(resultados.map((r) => r.antes).sort((a, b) => a - b), Array.from({ length: 12 }, (_, i) => i));
  });

  test('5 toques simultaneos con el MISMO idMovimiento son UN movimiento', async () => {
    const p = reponer(6);
    const resultados = await Promise.all(Array.from({ length: 5 }, () => moverStock(db, p, 'u')));
    assert.equal(await stockDe(), 16, 'suma una sola vez');
    assert.equal(resultados.filter((r) => !r.repetido).length, 1, 'exactamente uno lo aplico');
    assert.equal(await cuantosMarcadores(), 1);
  });
});

describe('corregir', () => {
  test('fija el valor cuando lo visto coincide, hacia abajo y hacia arriba', async () => {
    assert.deepEqual(await moverStock(db, corregir(10, 7, 'rotura'), 'u'), { antes: 10, despues: 7, repetido: false });
    assert.equal(await stockDe(), 7);
    assert.deepEqual(await moverStock(db, corregir(7, 30, 'conteo'), 'u'), { antes: 7, despues: 30, repetido: false });
    assert.equal(await stockDe(), 30);
  });

  test('el marcador guarda el motivo', async () => {
    const p = corregir(10, 7, 'rotura');
    await moverStock(db, p, 'u');
    const m = (await marcadores.doc(p.idMovimiento).get()).data();
    assert.deepEqual(m.operacion, { tipo: 'corregir', visto: 10, valor: 7, motivo: 'rotura' });
  });

  test('se vendieron dos mientras contaba: rechazada, y el stock queda como estaba', async () => {
    // El operador vio 10 y conto 7; entre medio se vendieron dos y el stock es 8.
    await producto.update({ stock: 8 });
    const p = corregir(10, 7);
    const e = await fallo(moverStock(db, p, 'u'));
    assert.equal(e?.code, 'failed-precondition');
    assert.deepEqual(e.details, { codigo: 'cambio-el-stock', actual: 8 });
    assert.equal(await stockDe(), 8, 'no se piso ninguna venta');
    assert.equal(await hayMarcador(p.idMovimiento), false);
  });

  test('DOS correcciones con el mismo `visto` a la vez: gana una sola', async () => {
    const [a, b] = await Promise.all([
      fallo(moverStock(db, corregir(10, 7), 'u')),
      fallo(moverStock(db, corregir(10, 3), 'u')),
    ]);
    const perdedoras = [a, b].filter((e) => e !== null);
    assert.equal(perdedoras.length, 1, 'exactamente una perdio');
    assert.equal(perdedoras[0].code, 'failed-precondition');
    assert.equal(perdedoras[0].details.codigo, 'cambio-el-stock');
    assert.ok([7, 3].includes(await stockDe()), 'el stock es el de la que gano');
    assert.equal(await cuantosMarcadores(), 1);
  });

  test('una reposicion en el medio cuenta como cambio: corregir se rechaza', async () => {
    await moverStock(db, reponer(6), 'u'); // el stock pasa a 16 mientras el operador cuenta
    const e = await fallo(moverStock(db, corregir(10, 7), 'u'));
    assert.equal(e?.details?.codigo, 'cambio-el-stock');
    assert.equal(await stockDe(), 16);
  });
});

describe('lo que NO se puede mover', () => {
  test('un producto que no existe: not-found, sin marcador', async () => {
    const p = { productoId: 'no-existe', idMovimiento: nuevoId(), operacion: { tipo: 'reponer', cantidad: 1 } };
    assert.equal((await fallo(moverStock(db, p, 'u')))?.code, 'not-found');
    const marcador = await db.collection('productos').doc('no-existe').collection('movimientos').get();
    assert.equal(marcador.size, 0);
    // Y no creo el producto fantasma.
    assert.equal((await db.collection('productos').doc('no-existe').get()).exists, false);
  });

  test('un compuesto no tiene stock propio: failed-precondition, y no se le escribe uno', async () => {
    const { stock: _sinStock, ...compuesto } = vino({ tipo: 'compuesto' });
    await producto.set(compuesto);
    const e = await fallo(moverStock(db, reponer(6), 'u'));
    assert.equal(e?.code, 'failed-precondition');
    assert.equal((await producto.get()).get('stock'), undefined, 'sigue sin campo stock');
    assert.equal(await cuantosMarcadores(), 0);
  });

  test('un reintento devuelve lo que paso aunque el producto ya sea compuesto', async () => {
    // Hallazgo 6 de revisor-pagos: el marcador se mira ANTES que el tipo. Si
    // se mirara despues, un reintento legitimo de un movimiento que SI paso
    // daria error solo porque el producto cambio de estado en el medio.
    const p = reponer(6);
    await moverStock(db, p, 'u');
    const { stock: _stock, ...compuesto } = vino({ tipo: 'compuesto' });
    await producto.set(compuesto);
    assert.deepEqual(await moverStock(db, p, 'u'), { antes: 10, despues: 16, repetido: true });
    // Y un movimiento NUEVO sobre el mismo compuesto si se rechaza.
    assert.equal((await fallo(moverStock(db, reponer(1), 'u')))?.code, 'failed-precondition');
  });

  test('un simple con el stock roto no se toca: failed-precondition', async () => {
    for (const roto of ['10', 3.5, -2, null]) {
      await producto.set(vino({ stock: roto }));
      assert.equal((await fallo(moverStock(db, reponer(6), 'u')))?.code, 'failed-precondition', String(roto));
    }
    assert.equal(await cuantosMarcadores(), 0);
  });

  test('un vino de muestra SI se puede mover (se prueba en produccion sin tocar uno real)', async () => {
    await producto.set(vino({ muestra: true }));
    assert.deepEqual(await moverStock(db, reponer(1), 'u'), { antes: 10, despues: 11, repetido: false });
  });
});

describe('lo que la transaccion NO toca', () => {
  test('el producto queda con los MISMOS campos: solo cambia `stock`', async () => {
    // Un campo de mas rompe el `hasOnly` de las reglas y el panel deja de
    // poder editar este vino, en silencio.
    const antes = (await producto.get()).data();
    await moverStock(db, reponer(6), 'u');
    await moverStock(db, corregir(16, 5, 'rotura'), 'u');
    const despues = (await producto.get()).data();
    assert.deepEqual(Object.keys(despues).sort(), Object.keys(antes).sort());
    assert.deepEqual({ ...despues, stock: 0 }, { ...antes, stock: 0 }, 'ningun otro campo cambio');
    assert.equal(despues.stock, 5);
  });
});
