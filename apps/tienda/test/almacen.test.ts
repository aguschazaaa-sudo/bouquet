import { test } from 'node:test';
import assert from 'node:assert/strict';

import { carritoVacio, parsearCarrito } from '@bouquet/contratos';

import { CARRITO_DEL_SERVIDOR } from '../src/features/carrito/almacen.ts';

test('el carrito del servidor no pasa el parser: nadie puede comprar con su idCompra', () => {
  // Si pasara, un checkout que leyera antes de hidratar mandaría la MISMA clave
  // de idempotencia para todos los compradores (revisor-pagos, hallazgo 6).
  assert.equal(parsearCarrito(CARRITO_DEL_SERVIDOR).ok, false);
  // Control: un carrito vacío de verdad sí pasa.
  assert.equal(parsearCarrito(carritoVacio('3f2b9c1e-7a4d-4e8f-9b21-5c6d7e8f9a0b')).ok, true);
});
