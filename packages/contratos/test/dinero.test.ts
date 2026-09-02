import { test } from 'node:test';
import assert from 'node:assert/strict';

import { centavos, desdePesos, formatearARS, porCantidad, sumar } from '../src/dinero.ts';

test('el camino flotante pierde un centavo en silencio; el nuestro grita', () => {
  // Esta es la razon entera por la que desdePesos parsea texto.
  //
  // 1.005 * 100 === 100.49999999999999, asi que Math.round da 100: un centavo
  // menos, sin error, para siempre. El precio queda mal y nadie se entera.
  assert.equal(1.005 * 100, 100.49999999999999);
  assert.equal(Math.round(1.005 * 100), 100, 'asi se equivoca el camino obvio');

  // El nuestro no redondea: rechaza. Un importe con tres decimales es un dato
  // mal cargado, y el modo de falla correcto es ruidoso.
  assert.throws(() => desdePesos('1.005'), RangeError);
});

test('desdePesos parsea pesos y centavos', () => {
  assert.equal(desdePesos('19.99'), 1999);
  assert.equal(desdePesos('19,99'), 1999, 'la coma es el separador local');
  assert.equal(desdePesos('19.9'), 1990, 'un decimal se completa a dos');
  assert.equal(desdePesos('1990'), 199000, 'sin decimales son pesos enteros');
  assert.equal(desdePesos(19.99), 1999, 'y desde number tambien es exacto');
  assert.equal(desdePesos('0'), 0);
  assert.equal(desdePesos('-5.50'), -550);
});

test('mas de dos decimales es un error, no algo a redondear', () => {
  // Un precio de 19.999 es un dato mal cargado y hay que verlo.
  assert.throws(() => desdePesos('19.999'), RangeError);
  assert.throws(() => desdePesos('gratis'), RangeError);
  assert.throws(() => desdePesos(''), RangeError);
  assert.throws(() => desdePesos('19.99.99'), RangeError);
});

test('centavos rechaza lo que no es entero', () => {
  assert.throws(() => centavos(19.99), RangeError);
  assert.throws(() => centavos(NaN), RangeError);
  assert.equal(centavos(1999), 1999);
});

test('aritmetica de una orden', () => {
  const malbec = desdePesos('8500');
  const espumante = desdePesos('12750.50');
  const total = sumar(porCantidad(malbec, 3), porCantidad(espumante, 1));
  assert.equal(total, 850000 * 3 + 1275050);
  assert.equal(total, 3825050);
});

test('la cantidad va entera: no se venden 2,5 botellas', () => {
  assert.throws(() => porCantidad(desdePesos('100'), 2.5), RangeError);
  assert.throws(() => porCantidad(desdePesos('100'), -1), RangeError);
  assert.equal(porCantidad(desdePesos('100'), 0), 0);
});

test('formatearARS sale en formato local', () => {
  const texto = formatearARS(desdePesos('12750.50'));
  // El separador de miles de es-AR es un espacio duro en algunas versiones de
  // ICU, asi que se afirma lo que no cambia, no la cadena entera.
  assert.match(texto, /\$/);
  assert.match(texto, /50$/, 'los centavos se muestran');
  assert.ok(texto.includes('750'), `salio "${texto}"`);
});
