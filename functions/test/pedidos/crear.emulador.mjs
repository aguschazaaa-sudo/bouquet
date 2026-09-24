// crear.emulador.mjs -- la transaccion de `crearOrdenDelPanel` contra el
// emulador de Firestore.  HU-10.1, ADR 018.
//
// Corre con:
//   firebase emulators:exec --only firestore --project demo-bouquet \
//     "node --test functions/test/pedidos/crear.emulador.mjs"
//
// Solo Firestore, SIN el emulador de Functions: su discovery no completa en
// esta maquina (ADR 015, 3.7).  Por eso el nucleo recibe la base por
// parametro y se prueba directo.
//
// NO termina en `.test.ts`: no la agarra el glob de `npm test`, que corre sin
// emuladores.
//
// Lo que se prueba ACA es lo que `armar.test.ts` no puede: atomicidad,
// concurrencia real, el documento como marcador y la carrera contra
// `moverStock`.  Cada requisito tiene un caso que APLICA y uno que RECHAZA: sin
// el que aplica, un rechazo pasaria tambien con una transaccion que niega todo.

import assert from 'node:assert/strict';
import { beforeEach, describe, test } from 'node:test';

const PROYECTO = 'demo-bouquet';
assert.ok(process.env.FIRESTORE_EMULATOR_HOST, 'falta FIRESTORE_EMULATOR_HOST: correlo con emulators:exec');
process.env.GCLOUD_PROJECT = PROYECTO;

const { initializeApp } = await import('firebase-admin/app');
const { getFirestore, Timestamp } = await import('firebase-admin/firestore');
const { crearOrdenDelPanel } = await import('../../src/pedidos/crear.ts');
const { moverStock } = await import('../../src/stock/mover.ts');
const { parsearPedidoDelPanel } = await import('@bouquet/contratos');

const db = getFirestore(initializeApp({ projectId: PROYECTO }, 'test-pedidos'));

const ordenes = db.collection('ordenes');
const contador = db.collection('contadores').doc('ordenes');

// Lo que el panel deja: los mismos campos que `documento_del_vino.dart`.
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

const sembrarVino = (id, cambios) => db.collection('productos').doc(id).set(vino(id, cambios));
const stockDe = async (id) => (await db.collection('productos').doc(id).get()).get('stock');
const cuantasOrdenes = async () => (await ordenes.get()).size;
const ultimoNumero = async () => (await contador.get()).get('ultimo');

let secuencia = 0;
const nuevoId = () => `pedido-de-prueba-${String(++secuencia).padStart(6, '0')}`;

const entrega = {
  nombre: 'Marta Gomez',
  telefono: '0351 15-555-1234',
  calle: 'San Martin',
  numero: '120',
  destino: { codigoPostal: '5000', localidad: 'Cordoba', provincia: 'X' },
};

/** Un pedido VALIDO, tal como lo deja `parsearPedidoDelPanel`. */
function pedido(lineas, idPedido = nuevoId(), cambiosDeEntrega = {}) {
  const r = parsearPedidoDelPanel({
    idPedido,
    lineas: lineas.map(([productoId, cantidad, precioUnitarioVisto = 1990000]) => ({ productoId, cantidad, precioUnitarioVisto })),
    entrega: { ...entrega, ...cambiosDeEntrega },
  });
  assert.ok(r.ok, `el pedido de la fixture tiene que validar: ${r.ok ? '' : r.motivo}`);
  return r.valor;
}

/** Corre y devuelve el error como `{ code, details }`, o `null` si no fallo. */
async function fallo(promesa) {
  try {
    await promesa;
    return null;
  } catch (e) {
    return { code: e.code, details: e.details };
  }
}

beforeEach(async () => {
  // El emulador no se reinicia solo entre casos: se borra todo.
  await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${PROYECTO}/databases/(default)/documents`, {
    method: 'DELETE',
  });
});

// ============================================================ lo que aplica

describe('crear una orden', () => {
  test('descuenta el stock, reserva el numero y crea la orden', async () => {
    await sembrarVino('vino-a', { stock: 10 });
    await sembrarVino('vino-b', { stock: 5, precio: 2500000 });

    const p = pedido([['vino-a', 2], ['vino-b', 3, 2500000]]);
    const r = await crearOrdenDelPanel(db, p, 'operador');

    assert.deepEqual(r, { ordenId: p.idPedido, numero: 1, repetido: false });
    assert.equal(await stockDe('vino-a'), 8);
    assert.equal(await stockDe('vino-b'), 2);
    assert.equal(await ultimoNumero(), 1);

    const o = (await ordenes.doc(p.idPedido).get()).data();
    assert.equal(o.numero, 1);
    assert.equal(o.origen, 'whatsapp');
    assert.equal(o.estadoPago, 'por_fuera');
    assert.equal(o.estadoEntrega, 'sin_preparar');
    assert.equal(o.creadaPor, 'operador');
    assert.equal(o.envio, null);
    assert.equal(o.total, 2 * 1990000 + 3 * 2500000);
    assert.equal(o.contacto.telefonoE164, '+5493515551234');
    assert.ok(o.creadaEn instanceof Timestamp, 'creadaEn lo pone la base, no el cliente');
    assert.ok(o.actualizadaEn instanceof Timestamp);
    assert.equal(o.items.length, 2);
    assert.deepEqual(o.items[0], { productoId: 'vino-a', nombre: 'Vino vino-a', precioUnitario: 1990000, cantidad: 2, botellas: 1 });
  });

  test('no escribe nada en el producto que no sea `stock`', async () => {
    // Un campo de mas rompe el `hasOnly` de las reglas y el panel deja de poder
    // editar ese vino, en silencio.
    await sembrarVino('vino-a', { stock: 10 });
    const antes = (await db.collection('productos').doc('vino-a').get()).data();
    await crearOrdenDelPanel(db, pedido([['vino-a', 2]]), 'operador');
    const despues = (await db.collection('productos').doc('vino-a').get()).data();
    assert.deepEqual({ ...despues, stock: 0 }, { ...antes, stock: 0 });
    assert.equal(despues.stock, 8);
  });

  test('los numeros salen consecutivos', async () => {
    await sembrarVino('vino-a', { stock: 10 });
    const numeros = [];
    for (let i = 0; i < 3; i += 1) {
      numeros.push((await crearOrdenDelPanel(db, pedido([['vino-a', 1]]), 'operador')).numero);
    }
    assert.deepEqual(numeros, [1, 2, 3]);
    assert.equal(await stockDe('vino-a'), 7);
  });

  test('el stock puede quedar en cero, y una venta mas ya no se puede', async () => {
    await sembrarVino('vino-a', { stock: 3 });
    await crearOrdenDelPanel(db, pedido([['vino-a', 3]]), 'operador');
    assert.equal(await stockDe('vino-a'), 0);
    const e = await fallo(crearOrdenDelPanel(db, pedido([['vino-a', 1]]), 'operador'));
    assert.equal(e?.code, 'failed-precondition');
    assert.equal(await stockDe('vino-a'), 0, 'nunca negativo');
  });

  test('cuatro botellas sueltas: la caja de seis no aplica', async () => {
    await sembrarVino('vino-a', { stock: 10 });
    const r = await crearOrdenDelPanel(db, pedido([['vino-a', 4]]), 'operador');
    assert.equal(r.numero, 1);
  });
});

// ================================================= la venta deja su movimiento

describe('cada venta queda en el historial del vino', () => {
  const movimientos = (id) => db.collection('productos').doc(id).collection('movimientos');

  test('un movimiento por linea, con lo que se vendio y quien', async () => {
    await sembrarVino('vino-a', { stock: 10 });
    await sembrarVino('vino-b', { stock: 5 });
    const p = pedido([['vino-a', 2], ['vino-b', 3]]);
    await crearOrdenDelPanel(db, p, 'operador');

    const a = await movimientos('vino-a').doc(`venta-${p.idPedido}`).get();
    assert.ok(a.exists, 'la venta de A dejo su movimiento');
    assert.deepEqual(a.get('operacion'), { tipo: 'venta', cantidad: 2, idPedido: p.idPedido, numero: 1 });
    assert.equal(a.get('antes'), 10);
    assert.equal(a.get('despues'), 8);
    assert.equal(a.get('por'), 'operador');
    assert.ok(a.get('en') instanceof Timestamp, 'la hora la pone el servidor');

    const b = await movimientos('vino-b').doc(`venta-${p.idPedido}`).get();
    assert.equal(b.get('antes'), 5);
    assert.equal(b.get('despues'), 2);
  });

  test('un reintento NO duplica el movimiento', async () => {
    await sembrarVino('vino-a', { stock: 10 });
    const p = pedido([['vino-a', 2]]);
    await crearOrdenDelPanel(db, p, 'operador');
    await crearOrdenDelPanel(db, p, 'operador');
    assert.equal((await movimientos('vino-a').get()).size, 1);
  });

  test('un rechazo no deja ningun movimiento', async () => {
    await sembrarVino('vino-a', { stock: 10 });
    await sembrarVino('vino-b', { stock: 1 });
    await fallo(crearOrdenDelPanel(db, pedido([['vino-a', 2], ['vino-b', 5]]), 'operador'));
    assert.equal((await movimientos('vino-a').get()).size, 0, 'ni el de la linea que estaba bien');
    assert.equal((await movimientos('vino-b').get()).size, 0);
  });

  test('conviven con los de `moverStock` en la misma coleccion', async () => {
    await sembrarVino('vino-a', { stock: 10 });
    await moverStock(
      db,
      { productoId: 'vino-a', idMovimiento: 'movimiento-de-prueba-0002', operacion: { tipo: 'reponer', cantidad: 5 } },
      'operador',
    );
    const p = pedido([['vino-a', 2]]);
    await crearOrdenDelPanel(db, p, 'operador');
    const ids = (await movimientos('vino-a').get()).docs.map((d) => d.id).sort();
    assert.deepEqual(ids, ['movimiento-de-prueba-0002', `venta-${p.idPedido}`].sort());
    assert.equal(await stockDe('vino-a'), 13);
  });
});

// ================================================================ atomicidad

describe('todo o nada', () => {
  test('una linea sin stock tira el pedido entero: la otra NO se descuenta', async () => {
    await sembrarVino('vino-a', { stock: 10 });
    await sembrarVino('vino-b', { stock: 5 });

    const e = await fallo(crearOrdenDelPanel(db, pedido([['vino-a', 2], ['vino-b', 6]]), 'operador'));

    assert.equal(e?.code, 'failed-precondition');
    assert.deepEqual(e?.details, { codigo: 'sin-stock', productoId: 'vino-b', actual: 5 });
    assert.equal(await stockDe('vino-a'), 10, 'la linea buena no se toco');
    assert.equal(await stockDe('vino-b'), 5);
    assert.equal(await cuantasOrdenes(), 0);
    assert.equal((await contador.get()).exists, false, 'el contador no se creo');
  });

  test('un rechazo no gasta un numero', async () => {
    await sembrarVino('vino-a', { stock: 1 });
    await fallo(crearOrdenDelPanel(db, pedido([['vino-a', 5]]), 'operador'));
    const r = await crearOrdenDelPanel(db, pedido([['vino-a', 1]]), 'operador');
    assert.equal(r.numero, 1, 'el numero 1 sigue libre: los numeros no tienen huecos');
  });
});

// ============================================================ los rechazos

describe('lo que no se puede vender', () => {
  const rechaza = async (esperado, mutar, lineas = [['vino-a', 1]]) => {
    await sembrarVino('vino-a', { stock: 10 });
    await mutar?.();
    const e = await fallo(crearOrdenDelPanel(db, pedido(lineas), 'operador'));
    assert.equal(e?.code, esperado.code);
    assert.equal(e?.details?.codigo, esperado.codigo);
    assert.equal(await stockDe('vino-a'), 'stockFinal' in esperado ? esperado.stockFinal : 10, 'el stock no se toco');
    assert.equal(await cuantasOrdenes(), 0);
  };

  test('un producto que no existe: not-found', async () => {
    const e = await fallo(crearOrdenDelPanel(db, pedido([['fantasma', 1]]), 'operador'));
    assert.equal(e?.code, 'not-found');
    assert.equal(e?.details?.codigo, 'no-existe');
  });

  test('un vino de muestra', async () => {
    await rechaza({ code: 'failed-precondition', codigo: 'de-muestra' }, () => sembrarVino('vino-a', { stock: 10, muestra: true }));
  });

  test('un compuesto', async () => {
    // Un compuesto no tiene `stock` propio: tampoco despues del rechazo.
    await rechaza({ code: 'failed-precondition', codigo: 'compuesto', stockFinal: undefined }, async () => {
      const c = vino('vino-a', { tipo: 'compuesto' });
      delete c.stock;
      await db.collection('productos').doc('vino-a').set(c);
    });
  });

  test('el precio cambio: el panel recibe el de ahora', async () => {
    await sembrarVino('vino-a', { stock: 10, precio: 2100000 });
    const e = await fallo(crearOrdenDelPanel(db, pedido([['vino-a', 1, 1990000]]), 'operador'));
    assert.equal(e?.code, 'failed-precondition');
    assert.deepEqual(e?.details, { codigo: 'cambio-el-precio', productoId: 'vino-a', actual: 2100000 });
    assert.equal(await stockDe('vino-a'), 10);
  });

  test('un vino sin precio: sin-precio, no cambio-el-precio', async () => {
    await sembrarVino('vino-a', { stock: 10, precio: 0, publicado: false });
    const e = await fallo(crearOrdenDelPanel(db, pedido([['vino-a', 1]]), 'operador'));
    assert.equal(e?.code, 'failed-precondition');
    assert.equal(e?.details?.codigo, 'sin-precio');
    assert.equal(await stockDe('vino-a'), 10);
  });

  test('un contador roto no se usa', async () => {
    await sembrarVino('vino-a', { stock: 10 });
    await contador.set({ ultimo: 'muchos' });
    const e = await fallo(crearOrdenDelPanel(db, pedido([['vino-a', 1]]), 'operador'));
    assert.equal(e?.code, 'failed-precondition');
    assert.equal(await stockDe('vino-a'), 10);
  });

  test('un vino NO publicado se vende igual', async () => {
    await sembrarVino('vino-a', { stock: 10, publicado: false });
    const r = await crearOrdenDelPanel(db, pedido([['vino-a', 1]]), 'operador');
    assert.equal(r.numero, 1);
  });
});

// ============================================================ idempotencia

describe('el mismo idPedido es UNA orden', () => {
  test('un reintento con las mismas lineas devuelve lo que paso, sin descontar dos veces', async () => {
    await sembrarVino('vino-a', { stock: 10 });
    const p = pedido([['vino-a', 2]]);

    const primero = await crearOrdenDelPanel(db, p, 'operador');
    const segundo = await crearOrdenDelPanel(db, p, 'operador');

    assert.equal(primero.repetido, false);
    assert.deepEqual(segundo, { ordenId: p.idPedido, numero: primero.numero, repetido: true });
    assert.equal(await stockDe('vino-a'), 8, 'se descuento UNA vez');
    assert.equal(await cuantasOrdenes(), 1);
    assert.equal(await ultimoNumero(), 1, 'y no se gasto un segundo numero');
  });

  test('el mismo id con OTRAS lineas: already-exists, y no se descuenta', async () => {
    await sembrarVino('vino-a', { stock: 10 });
    const id = nuevoId();
    await crearOrdenDelPanel(db, pedido([['vino-a', 2]], id), 'operador');

    const e = await fallo(crearOrdenDelPanel(db, pedido([['vino-a', 5]], id), 'operador'));
    assert.equal(e?.code, 'already-exists');
    assert.equal(await stockDe('vino-a'), 8);
    assert.equal(await cuantasOrdenes(), 1);
  });

  test('un reintento con OTRA direccion NO es el mismo pedido: already-exists con el numero', async () => {
    // El hallazgo 3 de `revisor-pagos`: antes devolvia `repetido: true` y la
    // correccion se perdia en silencio; la Orden seguia con la direccion vieja.
    await sembrarVino('vino-a', { stock: 10 });
    const id = nuevoId();
    const primero = await crearOrdenDelPanel(db, pedido([['vino-a', 2]], id), 'operador');

    const e = await fallo(crearOrdenDelPanel(db, pedido([['vino-a', 2]], id, { calle: 'Belgrano' }), 'operador'));

    assert.equal(e?.code, 'already-exists');
    assert.deepEqual(e?.details, { codigo: 'otro-pedido', numero: primero.numero });
    const o = (await ordenes.doc(id).get()).data();
    assert.equal(o.entrega.calle, 'San Martin', 'la Orden original no se toco');
    assert.equal(await stockDe('vino-a'), 8, 'y no se descuento de nuevo');
  });

  test('un reintento con OTRO cliente tampoco es el mismo pedido', async () => {
    await sembrarVino('vino-a', { stock: 10 });
    const id = nuevoId();
    await crearOrdenDelPanel(db, pedido([['vino-a', 2]], id), 'operador');
    const e = await fallo(crearOrdenDelPanel(db, pedido([['vino-a', 2]], id, { nombre: 'Otra Persona' }), 'operador'));
    assert.equal(e?.code, 'already-exists');
    assert.equal(await cuantasOrdenes(), 1);
  });

  test('el reintento tras vaciarse el stock devuelve lo que paso, no sin-stock', async () => {
    // El caso que justifica leer la Orden PRIMERO: el primer intento tuvo exito,
    // la respuesta se perdio, y otro pedido dejo el stock en 0.
    await sembrarVino('vino-a', { stock: 5 });
    const p = pedido([['vino-a', 2]]);
    const primero = await crearOrdenDelPanel(db, p, 'operador');
    await crearOrdenDelPanel(db, pedido([['vino-a', 3]]), 'operador');
    assert.equal(await stockDe('vino-a'), 0);

    const reintento = await crearOrdenDelPanel(db, p, 'operador');
    assert.deepEqual(reintento, { ordenId: p.idPedido, numero: primero.numero, repetido: true });
  });

  test('DOS llamadas simultaneas con el mismo id: una sola orden, el mismo numero', async () => {
    await sembrarVino('vino-a', { stock: 10 });
    const p = pedido([['vino-a', 2]]);

    const [a, b] = await Promise.all([crearOrdenDelPanel(db, p, 'operador'), crearOrdenDelPanel(db, p, 'operador')]);

    assert.equal(a.numero, b.numero);
    assert.equal([a, b].filter((r) => r.repetido).length, 1, 'exactamente una fue la que creo');
    assert.equal(await stockDe('vino-a'), 8, 'se descuento UNA vez');
    assert.equal(await cuantasOrdenes(), 1);
    assert.equal(await ultimoNumero(), 1);
  });
});

// ============================================================= concurrencia

describe('concurrencia real', () => {
  test('cinco cargas en paralelo sobre vinos distintos: numeros distintos y sin huecos', async () => {
    const ids = ['vino-a', 'vino-b', 'vino-c', 'vino-d', 'vino-e'];
    for (const id of ids) await sembrarVino(id, { stock: 10 });

    const rs = await Promise.all(ids.map((id) => crearOrdenDelPanel(db, pedido([[id, 1]]), 'operador')));

    const numeros = rs.map((r) => r.numero).sort((x, y) => x - y);
    assert.deepEqual(numeros, [1, 2, 3, 4, 5]);
    assert.equal(await ultimoNumero(), 5);
    assert.equal(await cuantasOrdenes(), 5);
  });

  test('dos pedidos de 6 sobre un vino con 10: exactamente uno tiene exito', async () => {
    await sembrarVino('vino-a', { stock: 10 });

    const rs = await Promise.all([
      fallo(crearOrdenDelPanel(db, pedido([['vino-a', 6]]), 'operador')),
      fallo(crearOrdenDelPanel(db, pedido([['vino-a', 6]]), 'operador')),
    ]);

    const fallaron = rs.filter((r) => r !== null);
    assert.equal(fallaron.length, 1, 'uno paso y el otro no');
    assert.equal(fallaron[0].code, 'failed-precondition');
    assert.equal(fallaron[0].details.codigo, 'sin-stock');
    assert.equal(await stockDe('vino-a'), 4);
    assert.equal(await cuantasOrdenes(), 1);
  });

  test('una venta y una reposicion a la vez: no se pierde ninguna', async () => {
    // `moverStock` y `crearOrdenDelPanel` escriben el mismo campo.  Firestore
    // serializa las dos, asi que el resultado es el de aplicar las dos.
    await sembrarVino('vino-a', { stock: 5 });

    await Promise.all([
      crearOrdenDelPanel(db, pedido([['vino-a', 4]]), 'operador'),
      moverStock(db, { productoId: 'vino-a', idMovimiento: 'movimiento-de-prueba-0001', operacion: { tipo: 'reponer', cantidad: 10 } }, 'operador'),
    ]);

    assert.equal(await stockDe('vino-a'), 11, '5 - 4 + 10, en cualquier orden');
  });
});
