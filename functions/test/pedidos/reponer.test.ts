import { test } from 'node:test';
import assert from 'node:assert/strict';

import { armarReposicion, leerItems, type ItemAReponer } from '../../src/pedidos/reponer.ts';

// Lo que el panel deja en `productos/{id}`, lo minimo que mira la reposicion.
const vino = (cambios: Record<string, unknown> = {}) => ({
  tipo: 'simple',
  nombre: 'Vino',
  stock: 10,
  presentacion: { botellas: 1 },
  ...cambios,
});

const item = (productoId: string, cantidad: number, botellas = 1): ItemAReponer => ({
  productoId,
  nombre: `Vino ${productoId}`,
  cantidad,
  botellas,
});

const leidos = (entradas: [string, unknown][]) => new Map<string, unknown>(entradas);

// ------------------------------------------------------------ lo que vuelve

test('control positivo: cada linea vuelve a su vino con el snapshot', () => {
  const r = armarReposicion(
    [item('vino-a', 2), item('caja-b', 1, 6)],
    leidos([
      ['vino-a', vino({ stock: 8 })],
      ['caja-b', vino({ stock: 3, presentacion: { botellas: 6 } })],
    ]),
  );
  assert.deepEqual(r.stock, [
    { productoId: 'vino-a', antes: 8, despues: 10 },
    { productoId: 'caja-b', antes: 3, despues: 4 },
  ]);
  assert.deepEqual(r.sinReponer, []);
});

test('vuelve sobre el stock de AHORA, no sobre el de cuando se vendio', () => {
  // Se vendieron 2 de 10 (quedaron 8) y despues alguien repuso 20: vuelven a 30.
  const r = armarReposicion([item('vino-a', 2)], leidos([['vino-a', vino({ stock: 28 })]]));
  assert.deepEqual(r.stock, [{ productoId: 'vino-a', antes: 28, despues: 30 }]);
});

test('desde cero tambien vuelve: un vino agotado por esta venta', () => {
  const r = armarReposicion([item('vino-a', 3)], leidos([['vino-a', vino({ stock: 0 })]]));
  assert.deepEqual(r.stock, [{ productoId: 'vino-a', antes: 0, despues: 3 }]);
});

test('dos lineas del mismo vino suman: un solo cambio, la segunda no pisa a la primera', () => {
  const r = armarReposicion([item('vino-a', 2), item('vino-a', 3)], leidos([['vino-a', vino({ stock: 5 })]]));
  assert.deepEqual(r.stock, [{ productoId: 'vino-a', antes: 5, despues: 10 }]);
});

test('NO aplica el tope: vuelve lo que salio aunque lo pase', () => {
  const r = armarReposicion([item('vino-a', 20)], leidos([['vino-a', vino({ stock: 4990 })]]));
  assert.deepEqual(r.stock, [{ productoId: 'vino-a', antes: 4990, despues: 5010 }]);
});

test('no mira nada del vino que no sea tipo, stock y presentacion', () => {
  // Un vino despublicado, sin precio o sin ficha igual recibe sus botellas.
  const r = armarReposicion(
    [item('vino-a', 1)],
    leidos([['vino-a', { tipo: 'simple', stock: 1, presentacion: { botellas: 1 }, publicado: false }]]),
  );
  assert.deepEqual(r.stock, [{ productoId: 'vino-a', antes: 1, despues: 2 }]);
});

// ------------------------------------------------------- lo que NO vuelve, y se dice

test('el hallazgo 1 de ADR 008: un vino recreado en otra presentacion NO recibe la linea', () => {
  // Salio 1 caja de 6. Hoy el slug es una botella suelta: sumar "1" dejaria 5
  // botellas a la venta que no existen.
  const r = armarReposicion([item('vino-a', 1, 6)], leidos([['vino-a', vino({ stock: 10 })]]));
  assert.deepEqual(r.stock, []);
  assert.deepEqual(r.sinReponer, [{ productoId: 'vino-a', nombre: 'Vino vino-a', cantidad: 1, motivo: 'otra_presentacion' }]);
});

test('cada motivo, con una linea sana al lado que SI vuelve', () => {
  const casos: [string, unknown, string][] = [
    ['borrado', undefined, 'no_existe'],
    ['compuesto', vino({ tipo: 'compuesto' }), 'compuesto'],
    ['sin tipo', vino({ tipo: undefined }), 'producto_roto'],
    ['stock negativo', vino({ stock: -1 }), 'producto_roto'],
    ['stock fraccion', vino({ stock: 1.5 }), 'producto_roto'],
    ['stock texto', vino({ stock: '8' }), 'producto_roto'],
    ['sin presentacion', vino({ presentacion: undefined }), 'otra_presentacion'],
  ];
  for (const [porque, crudo, motivo] of casos) {
    const r = armarReposicion(
      [item('roto', 2), item('sano', 1)],
      leidos([
        ['roto', crudo],
        ['sano', vino({ stock: 4 })],
      ]),
    );
    assert.deepEqual(r.sinReponer.map((s) => s.motivo), [motivo], porque);
    assert.deepEqual(r.stock, [{ productoId: 'sano', antes: 4, despues: 5 }], `${porque}: la sana vuelve igual`);
  }
});

// ----------------------------------------------------------- leer la Orden

test('lee las lineas que escribe crearOrdenDelPanel', () => {
  const guardadas = [{ productoId: 'vino-a', nombre: 'Vino A', precioUnitario: 1990000, cantidad: 2, botellas: 1 }];
  assert.deepEqual(leerItems(guardadas), [{ productoId: 'vino-a', nombre: 'Vino A', cantidad: 2, botellas: 1 }]);
});

test('una Orden con lineas ilegibles no se adivina: null', () => {
  const malos: [string, unknown][] = [
    ['sin items', undefined],
    ['vacio', []],
    ['no es lista', { a: 1 }],
    ['linea null', [null]],
    ['sin productoId', [{ cantidad: 1, botellas: 1 }]],
    ['cantidad 0', [{ productoId: 'a', cantidad: 0, botellas: 1 }]],
    ['cantidad fraccion', [{ productoId: 'a', cantidad: 1.5, botellas: 1 }]],
    ['sin botellas: el snapshot que la reposicion necesita', [{ productoId: 'a', cantidad: 1 }]],
  ];
  for (const [porque, crudo] of malos) assert.equal(leerItems(crudo), null, porque);
});

test('sin nombre, la linea se lee igual y se nombra por su id', () => {
  assert.deepEqual(leerItems([{ productoId: 'a', cantidad: 1, botellas: 1 }]), [
    { productoId: 'a', nombre: 'a', cantidad: 1, botellas: 1 },
  ]);
});
