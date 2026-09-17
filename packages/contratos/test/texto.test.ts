/**
 * La normalizacion compartida. ARQUITECTURA §7: un solo lugar.
 *
 * Estos tests miden el comportamiento del TypeScript. Que el espejo en Dart
 * diga lo mismo NO se mide aca: lo mide `apps/admin/test/core/contratos/
 * texto_test.dart` contra las fixtures generadas. Son dos verificaciones
 * distintas y las dos hacen falta.
 */

import { test } from 'node:test';
import assert from 'node:assert/strict';

import {
  ENTRADAS_DE_TEXTO,
  PARES_DE_TEXTO,
  aSlug,
  clave,
  normalizar,
  seParecen,
} from '../src/texto.ts';

// ------------------------------------------------------------- normalizar

test('normalizar pasa a minusculas y saca los acentos', () => {
  assert.equal(normalizar('Torrontés'), 'torrontes');
  assert.equal(normalizar('Bodega Ñandú'), 'bodega nandu');
  assert.equal(normalizar('Château Vieux'), 'chateau vieux');
  assert.equal(normalizar('Pingüino'), 'pinguino');
});

test('normalizar recorta los extremos y colapsa los espacios internos', () => {
  assert.equal(normalizar('  Bodega   Catena ZAPATA '), 'bodega catena zapata');
});

test('normalizar CONSERVA los espacios: alimenta un contains', () => {
  // Si los sacara, buscar "catena zapata" -- que es como lo escribe el
  // operador -- no encontraria nada.
  assert.ok(normalizar('Catena Zapata').includes(' '));
  assert.ok(normalizar('bodega catena zapata').includes(normalizar('Catena Zapata')));
});

test('normalizar no rompe lo que ya es un slug', () => {
  assert.equal(normalizar('catena-zapata'), 'catena-zapata');
});

// ------------------------------------------------------------------ clave

test('el mismo nombre escrito de tres formas da una sola clave', () => {
  assert.equal(clave('Catena Zapata'), 'catenazapata');
  assert.equal(clave('catena-zapata'), 'catenazapata');
  assert.equal(clave('CATENA  ZAPATA'), 'catenazapata');
});

test('un nombre hecho solo de puntuacion no tiene clave', () => {
  assert.equal(clave('···'), '');
  assert.equal(clave(''), '');
});

// ----------------------------------------------------------------- aSlug

/** La misma expresion que `esSlug` en firestore.rules. */
const ES_SLUG = /^[a-z0-9]+(-[a-z0-9]+)*$/;

test('aSlug produce algo que firestore.rules acepta', () => {
  for (const entrada of ENTRADAS_DE_TEXTO) {
    const slug = aSlug(entrada);
    if (slug === '') continue;
    assert.ok(ES_SLUG.test(slug), `"${entrada}" dio un slug que esSlug rechaza: "${slug}"`);
  }
});

test('aSlug con tildes, enie y simbolos', () => {
  assert.equal(aSlug('Bodega Ñandú & Cía.'), 'bodega-nandu-cia');
  assert.equal(aSlug('Château Vieux'), 'chateau-vieux');
});

test('aSlug devuelve vacio cuando del nombre no sale nada', () => {
  // Y vacio NO cumple esSlug, que es justo lo que tiene que pasar: el panel
  // se niega a guardar.
  assert.equal(aSlug('···'), '');
  assert.equal(ES_SLUG.test(''), false);
});

// ------------------------------------------------------------- seParecen

test('una clave contenida en la otra: se parecen', () => {
  assert.equal(seParecen('Catena', 'Catena Zapata'), true);
  assert.equal(seParecen('Catena Zapata', 'Catena'), true);
});

test('dos bodegas distintas no se parecen', () => {
  assert.equal(seParecen('Catena', 'Norton'), false);
});

test('el mismo nombre escrito de dos formas se parece a si mismo', () => {
  assert.equal(seParecen('Catena Zapata', 'catena-zapata'), true);
});

test('una clave vacia NO se parece a nada', () => {
  // Sin este corte, la cadena vacia esta contenida en todas y toda bodega
  // nueva pareceria un duplicado de todo.
  assert.equal(seParecen('···', 'Norton'), false);
  assert.equal(seParecen('···', ''), false);
});

// ------------------------------------------------------------- fixtures

test('las fixtures no tienen entradas repetidas', () => {
  // Una entrada repetida infla el JSON y no agrega una sola verificacion.
  assert.equal(new Set(ENTRADAS_DE_TEXTO).size, ENTRADAS_DE_TEXTO.length);
  const pares = PARES_DE_TEXTO.map((p) => JSON.stringify(p));
  assert.equal(new Set(pares).size, pares.length);
});

test('las fixtures cubren un caso verdadero y uno falso de seParecen', () => {
  // Un set de fixtures que solo tiene casos verdaderos no distingue una
  // implementacion correcta de una que devuelve true siempre.
  const resultados = PARES_DE_TEXTO.map(([a, b]) => seParecen(a, b));
  assert.ok(resultados.includes(true), 'ningun par se parece: falta el control positivo');
  assert.ok(resultados.includes(false), 'todos los pares se parecen: falta el control negativo');
});
