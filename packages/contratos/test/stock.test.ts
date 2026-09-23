import { test } from 'node:test';
import assert from 'node:assert/strict';

import {
  CASOS_DE_MOVIMIENTO,
  CODIGOS_DE_RECHAZO,
  MOTIVOS_DE_AJUSTE,
  TOPE_DE_STOCK,
  aplicarOperacion,
  parsearPedidoDeMovimiento,
  type PedidoDeMovimiento,
} from '../src/stock.ts';

type OperacionDeStock = PedidoDeMovimiento["operacion"];

const ID = '3f2b9c1e-7a4d-4e8f-9b21-5c6d7e8f9a0b';

const pedido = (operacion: unknown, cambios: Record<string, unknown> = {}) => ({
  productoId: 'trumpeter-malbec',
  idMovimiento: ID,
  operacion,
  ...cambios,
});

const reponer = (cantidad: unknown) => pedido({ tipo: 'reponer', cantidad });
const corregir = (visto: unknown, valor: unknown, motivo: unknown = 'conteo') =>
  pedido({ tipo: 'corregir', visto, valor, motivo });

// ---------------------------------------------------------------- el parser

test('control positivo: una reposicion y una correccion validas pasan', () => {
  const r = parsearPedidoDeMovimiento(reponer(6));
  assert.ok(r.ok);
  assert.deepEqual(r.valor.operacion, { tipo: 'reponer', cantidad: 6 });

  const c = parsearPedidoDeMovimiento(corregir(10, 7, 'rotura'));
  assert.ok(c.ok);
  assert.deepEqual(c.valor.operacion, { tipo: 'corregir', visto: 10, valor: 7, motivo: 'rotura' });
});

test('reponer: cero, negativos, fracciones, textos y NaN se rechazan', () => {
  for (const cantidad of [0, -1, 1.5, '6', null, undefined, NaN, Infinity]) {
    assert.equal(parsearPedidoDeMovimiento(reponer(cantidad)).ok, false, `cantidad ${String(cantidad)}`);
  }
});

test('reponer: el tope de una sola reposicion es TOPE_DE_STOCK, ni una mas', () => {
  assert.ok(parsearPedidoDeMovimiento(reponer(TOPE_DE_STOCK)).ok);
  assert.equal(parsearPedidoDeMovimiento(reponer(TOPE_DE_STOCK + 1)).ok, false);
});

test('corregir: el valor puede ser 0 (se vacio el deposito) pero no negativo ni pasado el tope', () => {
  assert.ok(parsearPedidoDeMovimiento(corregir(5, 0)).ok);
  assert.equal(parsearPedidoDeMovimiento(corregir(5, -1)).ok, false);
  assert.ok(parsearPedidoDeMovimiento(corregir(5, TOPE_DE_STOCK)).ok);
  assert.equal(parsearPedidoDeMovimiento(corregir(5, TOPE_DE_STOCK + 1)).ok, false);
});

test('corregir: `visto` sin tope propio, para poder bajar un dato anterior a la baranda', () => {
  assert.ok(parsearPedidoDeMovimiento(corregir(TOPE_DE_STOCK + 900, 4000)).ok);
  assert.equal(parsearPedidoDeMovimiento(corregir(-1, 4)).ok, false);
  assert.equal(parsearPedidoDeMovimiento(corregir(2.5, 4)).ok, false);
});

test('el cero negativo se rechaza en cada campo: Firestore lo guardaria como double', () => {
  // `Number.isInteger(-0)` y `-0 >= 0` son true: sin `Object.is` pasaria, se
  // guardaria `doubleValue: 0` y `d.stock is int` de las reglas fallaria.
  // Control positivo: el 0 comun de cada campo si pasa.
  assert.ok(parsearPedidoDeMovimiento(corregir(5, 0)).ok);
  assert.ok(parsearPedidoDeMovimiento(corregir(0, 5)).ok);
  assert.equal(parsearPedidoDeMovimiento(corregir(5, -0)).ok, false, 'valor -0');
  assert.equal(parsearPedidoDeMovimiento(corregir(-0, 5)).ok, false, 'visto -0');
  assert.equal(parsearPedidoDeMovimiento(reponer(-0)).ok, false, 'cantidad -0');
});

test('corregir al mismo valor visto no es una correccion', () => {
  assert.equal(parsearPedidoDeMovimiento(corregir(10, 10)).ok, false);
});

test('corregir: el motivo es de la lista cerrada, y cada uno de la lista pasa', () => {
  for (const motivo of MOTIVOS_DE_AJUSTE) {
    assert.ok(parsearPedidoDeMovimiento(corregir(10, 7, motivo)).ok, motivo);
  }
  // Sin pasar por el helper: su valor por defecto convertiria `undefined` en
  // 'conteo' y este caso -el motivo AUSENTE- pasaria sin probar nada.
  for (const motivo of ['porque-si', '', null, 3, undefined]) {
    const operacion = { tipo: 'corregir', visto: 10, valor: 7, motivo };
    assert.equal(parsearPedidoDeMovimiento(pedido(operacion)).ok, false, String(motivo));
  }
  const sinMotivo = { tipo: 'corregir', visto: 10, valor: 7 };
  assert.equal(parsearPedidoDeMovimiento(pedido(sinMotivo)).ok, false, 'sin la clave motivo');
});

test('el pedido se cierra: una clave de mas, en cualquier nivel, lo rechaza', () => {
  assert.equal(parsearPedidoDeMovimiento(pedido({ tipo: 'reponer', cantidad: 6 }, { stock: 999 })).ok, false);
  assert.equal(parsearPedidoDeMovimiento(pedido({ tipo: 'reponer', cantidad: 6, despues: 999 })).ok, false);
  assert.equal(
    parsearPedidoDeMovimiento(pedido({ tipo: 'corregir', visto: 1, valor: 2, motivo: 'otro', por: 'yo' })).ok,
    false,
  );
});

test('productoId: sin barra, sin punto, sin ids reservados de Firestore', () => {
  for (const productoId of ['', 'a/b', '../x', 'a.b', '__reservado__', 12, null, 'x'.repeat(129)]) {
    assert.equal(
      parsearPedidoDeMovimiento(pedido({ tipo: 'reponer', cantidad: 1 }, { productoId })).ok,
      false,
      String(productoId),
    );
  }
  assert.ok(
    parsearPedidoDeMovimiento(pedido({ tipo: 'reponer', cantidad: 1 }, { productoId: 'muestra-catena-zapata' })).ok,
  );
});

test('idMovimiento: entre 16 y 64 caracteres seguros', () => {
  for (const idMovimiento of ['', 'corto', 'x'.repeat(65), 'con espacios y demas cosas!!', 7, null]) {
    assert.equal(
      parsearPedidoDeMovimiento(pedido({ tipo: 'reponer', cantidad: 1 }, { idMovimiento })).ok,
      false,
      String(idMovimiento),
    );
  }
});

test('lo que no es un objeto no es un pedido', () => {
  for (const x of [null, undefined, 3, 'reponer', [], [reponer(1)]]) {
    assert.equal(parsearPedidoDeMovimiento(x).ok, false);
  }
  assert.equal(parsearPedidoDeMovimiento(pedido('reponer')).ok, false);
  assert.equal(parsearPedidoDeMovimiento(pedido({ tipo: 'vaciar' })).ok, false);
});

test('el orden de las claves de la operacion parseada es fijo, sea cual sea el de entrada', () => {
  // La callable compara un reintento contra lo guardado por JSON.stringify:
  // solo sirve si el parser arma siempre el mismo orden.
  const a = parsearPedidoDeMovimiento(pedido({ tipo: 'corregir', visto: 3, valor: 9, motivo: 'conteo' }));
  const b = parsearPedidoDeMovimiento(pedido({ motivo: 'conteo', valor: 9, tipo: 'corregir', visto: 3 }));
  assert.ok(a.ok && b.ok);
  assert.equal(JSON.stringify(a.valor.operacion), JSON.stringify(b.valor.operacion));
});

// ------------------------------------------------------------ la cuenta

const rep = (cantidad: number): OperacionDeStock => ({ tipo: 'reponer', cantidad });
const cor = (visto: number, valor: number): OperacionDeStock => ({
  tipo: 'corregir',
  visto,
  valor,
  motivo: 'conteo',
});

test('reponer suma sobre el stock actual, y hasta el tope justo', () => {
  assert.deepEqual(aplicarOperacion(4, rep(6)), { ok: true, despues: 10 });
  assert.deepEqual(aplicarOperacion(0, rep(1)), { ok: true, despues: 1 });
  assert.deepEqual(aplicarOperacion(TOPE_DE_STOCK - 10, rep(10)), { ok: true, despues: TOPE_DE_STOCK });
});

test('reponer pasado el tope se rechaza, aunque cada numero por separado sea valido', () => {
  assert.deepEqual(aplicarOperacion(TOPE_DE_STOCK - 10, rep(11)), { ok: false, codigo: 'pasa-el-tope' });
  assert.deepEqual(aplicarOperacion(TOPE_DE_STOCK, rep(1)), { ok: false, codigo: 'pasa-el-tope' });
});

test('corregir fija el valor cuando lo visto coincide', () => {
  assert.deepEqual(aplicarOperacion(10, cor(10, 7)), { ok: true, despues: 7 });
  assert.deepEqual(aplicarOperacion(5, cor(5, 0)), { ok: true, despues: 0 });
});

test('corregir sobre un stock que cambio se rechaza: no pisa las ventas del medio', () => {
  // El operador vio 10, conto 7, y mientras tanto se vendieron dos: el stock
  // es 8.  Fijar 7 borraria una de las dos ventas.
  assert.deepEqual(aplicarOperacion(8, cor(10, 7)), { ok: false, codigo: 'cambio-el-stock' });
  // Y tambien si subio: entro una reposicion mientras contaba.
  assert.deepEqual(aplicarOperacion(16, cor(10, 7)), { ok: false, codigo: 'cambio-el-stock' });
});

test('reponer no mira lo visto: es conmutativa, dos reposiciones seguidas suman las dos', () => {
  const primera = aplicarOperacion(4, rep(6));
  assert.ok(primera.ok);
  assert.deepEqual(aplicarOperacion(primera.despues, rep(6)), { ok: true, despues: 16 });
});

// ------------------------------------------------------------- las fixtures

test('las fixtures cubren las cuatro salidas posibles', () => {
  const salidas = new Set<string>();
  for (const c of CASOS_DE_MOVIMIENTO) {
    const p = parsearPedidoDeMovimiento(pedido(c.operacion));
    if (!p.ok) {
      salidas.add('invalido');
      continue;
    }
    const a = aplicarOperacion(c.stock, p.valor.operacion);
    salidas.add(a.ok ? 'aplica' : a.codigo);
  }
  // Si una de las cuatro clases faltara, el espejo en Dart no la probaria.
  assert.deepEqual([...salidas].sort(), ['aplica', 'cambio-el-stock', 'invalido', 'pasa-el-tope']);
  for (const codigo of CODIGOS_DE_RECHAZO) assert.ok(salidas.has(codigo), codigo);
});

test('los `porque` de las fixtures no se repiten', () => {
  const porques = CASOS_DE_MOVIMIENTO.map((c) => c.porque);
  assert.equal(new Set(porques).size, porques.length);
});
