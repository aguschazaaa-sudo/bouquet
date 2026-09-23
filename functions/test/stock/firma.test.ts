import { test } from 'node:test';
import assert from 'node:assert/strict';

import { firmaDeOperacion } from '../../src/stock/mover.ts';

test('el mismo contenido en otro orden de claves da la misma firma', () => {
  // Firestore devuelve los mapas con las claves ordenadas, no en el orden en
  // que se escribieron.  Sin esto, un reintento legitimo se leeria como "otra
  // operacion" y rebotaria.
  const a = firmaDeOperacion({ tipo: 'corregir', visto: 3, valor: 9, motivo: 'conteo' });
  const b = firmaDeOperacion({ motivo: 'conteo', valor: 9, tipo: 'corregir', visto: 3 });
  assert.equal(a, b);
});

test('un solo valor distinto cambia la firma, en cada campo', () => {
  const base = { tipo: 'corregir', visto: 3, valor: 9, motivo: 'conteo' };
  const firma = firmaDeOperacion(base);
  for (const [campo, otro] of [['visto', 4], ['valor', 10], ['motivo', 'rotura'], ['tipo', 'reponer']] as const) {
    assert.notEqual(firmaDeOperacion({ ...base, [campo]: otro }), firma, campo);
  }
});

test('reponer 6 y reponer 7 son operaciones distintas', () => {
  assert.notEqual(firmaDeOperacion({ tipo: 'reponer', cantidad: 6 }), firmaDeOperacion({ tipo: 'reponer', cantidad: 7 }));
});

test('un campo de mas cambia la firma: no se cuela por ser "parecido"', () => {
  assert.notEqual(
    firmaDeOperacion({ tipo: 'reponer', cantidad: 6 }),
    firmaDeOperacion({ tipo: 'reponer', cantidad: 6, extra: 1 }),
  );
});
