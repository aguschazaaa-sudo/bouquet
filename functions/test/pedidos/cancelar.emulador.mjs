// cancelar.emulador.mjs -- la transaccion de `cancelarOrden` contra el emulador
// de Firestore.  HU-07.6, ADR 019 §5.
//
// Corre con:
//   firebase emulators:exec --only firestore --project demo-bouquet \
//     "node --test functions/test/pedidos/cancelar.emulador.mjs"
//
// En CI la corre el job `suite_emulador`, EN SERIE con las otras suites que
// usan el mismo emulador.
//
// Lo que se prueba ACA es lo que `reponer.test.ts` no puede: que el stock vuelva
// UNA vez aunque se cancele dos veces a la vez, que un rechazo no deje nada a
// medias, y la carrera contra `moverStock`.  Las ordenes se crean con
// `crearOrdenDelPanel` de verdad: una cancelacion probada sobre una Orden
// armada a mano probaria la forma que yo creo que tiene, no la que tiene.

import assert from 'node:assert/strict';
import { beforeEach, describe, test } from 'node:test';

const PROYECTO = 'demo-bouquet';
assert.ok(process.env.FIRESTORE_EMULATOR_HOST, 'falta FIRESTORE_EMULATOR_HOST: correlo con emulators:exec');
process.env.GCLOUD_PROJECT = PROYECTO;

const { initializeApp } = await import('firebase-admin/app');
const { getFirestore, Timestamp } = await import('firebase-admin/firestore');
const { crearOrdenDelPanel } = await import('../../src/pedidos/crear.ts');
const { cancelarOrden } = await import('../../src/pedidos/cancelar.ts');
const { moverStock } = await import('../../src/stock/mover.ts');
const { parsearPedidoDelPanel } = await import('@bouquet/contratos');

const db = getFirestore(initializeApp({ projectId: PROYECTO }, 'test-cancelar'));
const ordenes = db.collection('ordenes');

const vino = (id, cambios = {}) => ({
  tipo: 'simple',
  slug: id,
  nombre: `Vino ${id}`,
  precio: 1990000,
  stock: 10,
  presentacion: { botellas: 1 },
  imagenes: [],
  publicado: true,
  fichaVino: { bodegaId: 'b', varietales: ['Malbec'], color: 'tinto', organico: false, region: 'Mendoza', volumenMl: 750 },
  ...cambios,
});

const producto = (id) => db.collection('productos').doc(id);
const sembrarVino = (id, cambios) => producto(id).set(vino(id, cambios));
const stockDe = async (id) => (await producto(id).get()).get('stock');
const movimientos = async (id) => (await producto(id).collection('movimientos').get()).docs.map((d) => d.id).sort();

let secuencia = 0;
const nuevoId = () => `pedido-de-cancelar-${String(++secuencia).padStart(6, '0')}`;

const entrega = {
  nombre: 'Marta Gomez',
  telefono: '0351 15-555-1234',
  calle: 'San Martin',
  numero: '120',
  destino: { codigoPostal: '5000', localidad: 'Cordoba', provincia: 'X' },
};

/** Crea una Orden de verdad y devuelve su id. */
async function unPedido(lineas) {
  const r = parsearPedidoDelPanel({
    idPedido: nuevoId(),
    lineas: lineas.map(([productoId, cantidad, precioUnitarioVisto = 1990000]) => ({ productoId, cantidad, precioUnitarioVisto })),
    entrega,
  });
  assert.ok(r.ok, `el pedido de la fixture tiene que validar: ${r.ok ? '' : r.motivo}`);
  const creada = await crearOrdenDelPanel(db, r.valor, 'operador');
  return creada.ordenId;
}

const cancelar = (ordenId, motivo = 'mal_cargado', uid = 'operador') => cancelarOrden(db, { ordenId, motivo }, uid);

async function fallo(promesa) {
  try {
    await promesa;
    return null;
  } catch (e) {
    return { code: e.code, details: e.details };
  }
}

beforeEach(async () => {
  await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${PROYECTO}/databases/(default)/documents`, {
    method: 'DELETE',
  });
});

// ============================================================ lo que aplica

describe('cancelar un pedido que no salio', () => {
  test('el stock vuelve, la orden queda cancelada y dice por que y quien', async () => {
    await sembrarVino('vino-a', { stock: 10 });
    await sembrarVino('caja-b', { stock: 4, presentacion: { botellas: 6 } });
    const id = await unPedido([['vino-a', 2], ['caja-b', 1]]);
    assert.equal(await stockDe('vino-a'), 8, 'control: la venta desconto');

    const r = await cancelar(id, 'cliente', 'otra-persona');

    assert.deepEqual(r, { numero: 1, repetido: false, sinReponer: [] });
    assert.equal(await stockDe('vino-a'), 10);
    assert.equal(await stockDe('caja-b'), 4, 'la caja vuelve como caja: 1 unidad de venta');

    const o = (await ordenes.doc(id).get()).data();
    assert.equal(o.estadoEntrega, 'cancelada');
    assert.equal(o.estadoPago, 'por_fuera', 'el eje de pago no se toca');
    assert.equal(o.cancelacion.motivo, 'cliente');
    assert.equal(o.cancelacion.por, 'otra-persona');
    assert.ok(o.cancelacion.en instanceof Timestamp, 'la hora la pone el servidor');
    assert.deepEqual(o.cancelacion.sinReponer, []);
    assert.equal(o.items.length, 2, 'el snapshot queda: el historico de la venta no se tira');
  });

  test('desde preparando tambien se cancela', async () => {
    await sembrarVino('vino-a', { stock: 10 });
    const id = await unPedido([['vino-a', 3]]);
    await ordenes.doc(id).update({ estadoEntrega: 'preparando' });
    const r = await cancelar(id);
    assert.equal(r.repetido, false);
    assert.equal(await stockDe('vino-a'), 10);
  });

  test('deja su movimiento en el historial del vino, al lado de la venta', async () => {
    await sembrarVino('vino-a', { stock: 10 });
    const id = await unPedido([['vino-a', 2]]);
    await cancelar(id);

    assert.deepEqual(await movimientos('vino-a'), [`cancelacion-${id}`, `venta-${id}`]);
    const m = await producto('vino-a').collection('movimientos').doc(`cancelacion-${id}`).get();
    assert.deepEqual(m.get('operacion'), { tipo: 'cancelacion', cantidad: 2, idPedido: id, numero: 1 });
    assert.equal(m.get('antes'), 8);
    assert.equal(m.get('despues'), 10);
    assert.equal(m.get('por'), 'operador');
    assert.ok(m.get('en') instanceof Timestamp);
  });

  test('no escribe nada en el producto que no sea `stock`', async () => {
    await sembrarVino('vino-a', { stock: 10 });
    const id = await unPedido([['vino-a', 2]]);
    const antes = (await producto('vino-a').get()).data();
    await cancelar(id);
    const despues = (await producto('vino-a').get()).data();
    assert.deepEqual({ ...despues, stock: 0 }, { ...antes, stock: 0 });
  });
});

// ============================================================ idempotencia

describe('la orden cancelada es su propio marcador', () => {
  test('un reintento devuelve lo que paso y no devuelve el stock dos veces', async () => {
    await sembrarVino('vino-a', { stock: 10 });
    const id = await unPedido([['vino-a', 2]]);
    await cancelar(id);
    const r = await cancelar(id, 'otro');
    assert.deepEqual(r, { numero: 1, repetido: true, sinReponer: [] });
    assert.equal(await stockDe('vino-a'), 10);
    assert.equal((await ordenes.doc(id).get()).get('cancelacion.motivo'), 'mal_cargado', 'el reintento no pisa el motivo');
    assert.equal((await movimientos('vino-a')).length, 2, 'la venta y UNA cancelacion');
  });

  test('dos cancelaciones A LA VEZ devuelven el stock una sola vez', async () => {
    await sembrarVino('vino-a', { stock: 10 });
    const id = await unPedido([['vino-a', 4]]);
    const rs = await Promise.all([cancelar(id), cancelar(id), cancelar(id)]);
    assert.equal(rs.filter((r) => !r.repetido).length, 1, 'exactamente una aplico');
    assert.equal(await stockDe('vino-a'), 10);
  });

  test('un reintento con lineas que no se repusieron devuelve las mismas', async () => {
    await sembrarVino('vino-a', { stock: 10 });
    const id = await unPedido([['vino-a', 2]]);
    await producto('vino-a').delete();
    const primero = await cancelar(id);
    const segundo = await cancelar(id);
    assert.equal(primero.sinReponer.length, 1);
    assert.deepEqual(segundo.sinReponer, primero.sinReponer);
  });
});

// ======================================================= lo que NO se repone

describe('una linea que no puede volver no traba la cancelacion', () => {
  test('un vino borrado: la orden se cancela, esa linea se dice y la otra vuelve', async () => {
    await sembrarVino('vino-a', { stock: 10 });
    await sembrarVino('vino-b', { stock: 5 });
    const id = await unPedido([['vino-a', 2], ['vino-b', 1]]);
    await producto('vino-a').delete();

    const r = await cancelar(id);

    assert.deepEqual(r.sinReponer, [{ productoId: 'vino-a', nombre: 'Vino vino-a', cantidad: 2, motivo: 'no_existe' }]);
    assert.equal(await stockDe('vino-b'), 5);
    assert.equal((await producto('vino-a').get()).exists, false, 'no resucita el vino borrado');
    const o = (await ordenes.doc(id).get()).data();
    assert.equal(o.estadoEntrega, 'cancelada');
    assert.deepEqual(o.cancelacion.sinReponer, r.sinReponer, 'queda escrito en la orden');
  });

  test('el hallazgo 1 de ADR 008: recreado como otra presentacion, NO recibe la linea', async () => {
    await sembrarVino('vino-a', { stock: 10, presentacion: { botellas: 6 } });
    const id = await unPedido([['vino-a', 1]]);
    // Se borro y se volvio a crear con el mismo slug, ahora suelto.
    await producto('vino-a').set(vino('vino-a', { stock: 10, presentacion: { botellas: 1 } }));

    const r = await cancelar(id);

    assert.deepEqual(r.sinReponer.map((s) => s.motivo), ['otra_presentacion']);
    assert.equal(await stockDe('vino-a'), 10, 'la caja de 6 no vuelve como 1 botella');
    // `set` no borra la subcoleccion: la venta vieja sigue ahi, y no hay una
    // cancelacion porque no se movio nada.
    assert.deepEqual(await movimientos('vino-a'), [`venta-${id}`]);
  });
});

// ============================================================ lo que rechaza

describe('lo que no se cancela', () => {
  for (const estado of ['despachada', 'entregada', 'fallida']) {
    test(`${estado}: ya salio, y no se toca nada`, async () => {
      await sembrarVino('vino-a', { stock: 10 });
      const id = await unPedido([['vino-a', 2]]);
      await ordenes.doc(id).update({ estadoEntrega: estado });
      const antes = (await ordenes.doc(id).get()).data();

      const e = await fallo(cancelar(id));

      assert.equal(e?.code, 'failed-precondition');
      assert.equal(e?.details?.codigo, 'ya-salio');
      assert.equal(e?.details?.estado, estado, 'el estado de ahora viaja en el error');
      assert.equal(await stockDe('vino-a'), 8, 'el stock no volvio');
      assert.deepEqual((await ordenes.doc(id).get()).data(), antes, 'la orden no cambio');
      assert.deepEqual(await movimientos('vino-a'), [`venta-${id}`]);
    });
  }

  test('una orden que no existe: not-found', async () => {
    const e = await fallo(cancelar('pedido-que-no-existe-0001'));
    assert.equal(e?.code, 'not-found');
  });

  test('una orden sin lineas legibles no se adivina: orden-rota, y no se toca', async () => {
    await ordenes.doc('pedido-roto-0000000001').set({ numero: 9, estadoEntrega: 'sin_preparar', items: [{ productoId: 'x' }] });
    const e = await fallo(cancelar('pedido-roto-0000000001'));
    assert.equal(e?.details?.codigo, 'orden-rota');
    assert.equal((await ordenes.doc('pedido-roto-0000000001').get()).get('estadoEntrega'), 'sin_preparar');
  });
});

// ================================================ la carrera contra moverStock

describe('cancelar y mover el stock a la vez', () => {
  test('una reposicion concurrente suma con la cancelacion, sin pisarse', async () => {
    await sembrarVino('vino-a', { stock: 10 });
    const id = await unPedido([['vino-a', 2]]);
    await Promise.all([
      cancelar(id),
      moverStock(db, { productoId: 'vino-a', idMovimiento: 'a1b2c3d4e5f60718293a', operacion: { tipo: 'reponer', cantidad: 5 } }, 'operador'),
    ]);
    assert.equal(await stockDe('vino-a'), 8 + 2 + 5);
  });

  test('una venta concurrente del mismo vino tambien', async () => {
    await sembrarVino('vino-a', { stock: 10 });
    const id = await unPedido([['vino-a', 2]]);
    await Promise.all([cancelar(id), unPedido([['vino-a', 3]])]);
    assert.equal(await stockDe('vino-a'), 8 + 2 - 3);
  });
});
