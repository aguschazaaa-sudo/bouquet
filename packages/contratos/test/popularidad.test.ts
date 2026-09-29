/**
 * La popularidad medida (HU-11.3, ADR 025).
 *
 * Cada regla con los dos lados: lo que cuenta y lo que no. Sin el lado que no
 * cuenta, una implementacion que suma todo pasa; sin el que cuenta, una que no
 * suma nada tambien.
 */

import { test } from 'node:test';
import assert from 'node:assert/strict';

import { ESTADOS_ENTREGA, ESTADOS_PAGO } from '../src/orden.ts';
import {
  contarPopularidad,
  cuentaComoVenta,
  inicioDeLaVentana,
  VENTANA_DE_POPULARIDAD_DIAS,
} from '../src/popularidad.ts';

function orden(estadoPago: string, estadoEntrega: string, items: unknown[]) {
  return { estadoPago, estadoEntrega, items };
}

const linea = (productoId: string, cantidad: number) => ({ productoId, cantidad, nombre: productoId, botellas: 1 });

test('cuentaComoVenta: exactamente pagada y por_fuera, sin cancelar', () => {
  const cuentan: string[] = [];
  for (const pago of ESTADOS_PAGO) {
    for (const entrega of ESTADOS_ENTREGA) {
      if (cuentaComoVenta(pago, entrega)) cuentan.push(`${pago}/${entrega}`);
    }
  }
  // 2 pagos x 5 entregas que no son `cancelada`. La lista entera, no un
  // conteo: si alguien agrega un estado, este test dice cual entro.
  assert.deepEqual(cuentan, [
    'pagada/sin_preparar',
    'pagada/preparando',
    'pagada/despachada',
    'pagada/entregada',
    'pagada/fallida',
    'por_fuera/sin_preparar',
    'por_fuera/preparando',
    'por_fuera/despachada',
    'por_fuera/entregada',
    'por_fuera/fallida',
  ]);
});

test('contarPopularidad suma unidades de venta por vino, entre Ordenes', () => {
  const r = contarPopularidad([
    orden('pagada', 'entregada', [linea('malbec-a', 2), linea('torrontes-b', 1)]),
    orden('por_fuera', 'sin_preparar', [linea('malbec-a', 3)]),
  ]);
  assert.deepEqual(r.unidades, { 'malbec-a': 5, 'torrontes-b': 1 });
  assert.equal(r.ventas, 2);
  assert.equal(r.ilegibles, 0);
});

test('lo que no es una venta no suma, y no es ilegible', () => {
  const r = contarPopularidad([
    orden('pendiente', 'sin_preparar', [linea('a', 1)]),
    orden('en_proceso', 'sin_preparar', [linea('a', 1)]),
    orden('rechazada', 'sin_preparar', [linea('a', 1)]),
    orden('reembolsada', 'cancelada', [linea('a', 1)]),
    orden('pagada', 'cancelada', [linea('a', 1)]),
    orden('por_fuera', 'cancelada', [linea('a', 1)]),
    // El control positivo, en la misma lista: sin el, un contador roto que
    // no suma nada tambien da `{}`.
    orden('pagada', 'despachada', [linea('b', 4)]),
  ]);
  assert.deepEqual(r.unidades, { b: 4 });
  assert.equal(r.ventas, 1);
  assert.equal(r.ilegibles, 0);
});

test('una Orden con una linea rota se descarta ENTERA', () => {
  const r = contarPopularidad([
    orden('pagada', 'entregada', [linea('a', 2), { productoId: 'b', cantidad: 0 }]),
    orden('pagada', 'entregada', [linea('a', 1), { productoId: 'C/../x', cantidad: 1 }]),
    orden('pagada', 'entregada', [linea('a', 1.5)]),
    orden('pagada', 'entregada', 'no-es-una-lista' as unknown as unknown[]),
    orden('pagada', 'entregada', [linea('d', 7)]),
  ]);
  // Ni la mitad sana de las rotas: `a` no aparece.
  assert.deepEqual(r.unidades, { d: 7 });
  assert.equal(r.ilegibles, 4);
  assert.equal(r.ventas, 1);
});

test('un documento que no es una Orden es ilegible y no tira la corrida', () => {
  const r = contarPopularidad([null, 3, 'x', [], {}, orden('pagada', 'inventado', []), orden('robado', 'entregada', [])]);
  assert.deepEqual(r.unidades, {});
  assert.equal(r.ilegibles, 7);
  assert.equal(r.ventas, 0);
});

test('determinista: el mismo documento en cualquier orden, con las claves ordenadas', () => {
  const ordenes = [
    orden('pagada', 'entregada', [linea('zeta', 1)]),
    orden('por_fuera', 'entregada', [linea('alfa', 2)]),
    orden('pagada', 'fallida', [linea('medio', 3)]),
  ];
  const ida = contarPopularidad(ordenes);
  const vuelta = contarPopularidad([...ordenes].reverse());
  assert.equal(JSON.stringify(ida), JSON.stringify(vuelta));
  assert.deepEqual(Object.keys(ida.unidades), ['alfa', 'medio', 'zeta']);
});

test('sin Ordenes, un mapa vacio: la vidriera no ofrece el orden por popularidad', () => {
  assert.deepEqual(contarPopularidad([]), { unidades: {}, ventas: 0, ilegibles: 0 });
});

test('inicioDeLaVentana resta los dias exactos', () => {
  const ahora = new Date('2026-09-29T08:00:00.000Z');
  assert.equal(inicioDeLaVentana(ahora, 1).toISOString(), '2026-09-28T08:00:00.000Z');
  assert.equal(inicioDeLaVentana(ahora).toISOString(), '2026-07-01T08:00:00.000Z');
  assert.equal(VENTANA_DE_POPULARIDAD_DIAS, 90);
  assert.throws(() => inicioDeLaVentana(ahora, 0), RangeError);
  assert.throws(() => inicioDeLaVentana(ahora, 1.5), RangeError);
});
