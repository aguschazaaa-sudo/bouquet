import { test } from 'node:test';
import assert from 'node:assert/strict';

import { validarRutaDelCrudo } from '../../src/foto/ruta.ts';

test('una ruta valida devuelve el nombre del archivo', () => {
  assert.equal(validarRutaDelCrudo('productos/malbec-a/uuid-1.jpg', 'malbec-a'), 'uuid-1.jpg');
});

test('rechaza la ruta de OTRO producto', () => {
  // El caso de seguridad del spec: si quien llama pudiera pasar la ruta de
  // otro producto, la callable procesaria/borraria un archivo ajeno.
  assert.equal(validarRutaDelCrudo('productos/malbec-b/x.jpg', 'malbec-a'), null);
});

test('rechaza segmentos de mas', () => {
  assert.equal(validarRutaDelCrudo('productos/malbec-a/2026/01/x.jpg', 'malbec-a'), null);
});

test('rechaza rutas fuera de productos/', () => {
  assert.equal(validarRutaDelCrudo('otra-cosa/x.jpg', 'malbec-a'), null);
});

test('rechaza sin nombre de archivo', () => {
  assert.equal(validarRutaDelCrudo('productos/malbec-a/', 'malbec-a'), null);
});

test('rechaza sin productoId', () => {
  assert.equal(validarRutaDelCrudo('productos//x.jpg', 'malbec-a'), null);
});
