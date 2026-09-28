/**
 * La seleccion de la portada que elige el duenio. HU-09.1, ADR 023.
 */

import { test } from 'node:test';
import assert from 'node:assert/strict';

import { centavos } from '../src/dinero.ts';
import type { ProductoPublicado } from '../src/producto.ts';
import {
  LUGARES_DE_LA_SELECCION,
  puedeIrEnLaSeleccion,
  resolverSeleccion,
  validarSeleccion,
} from '../src/seleccion.ts';

function publicado(id: string, cambios: Partial<ProductoPublicado> = {}): ProductoPublicado {
  return {
    id,
    slug: id,
    nombre: id,
    bodega: 'Rutini Wines',
    precio: centavos(1990000),
    botellas: 1,
    volumenMl: 750,
    imagenes: [],
    color: 'tinto',
    organico: false,
    varietales: ['Malbec'],
    esCorte: false,
    anada: 2023,
    region: 'Mendoza',
    descripcion: null,
    balde: 'disponible',
    tope: 12,
    puesto: null,
    ...cambios,
  };
}

// ------------------------------------------------------------ la forma

test('sin documento no hay eleccion: null, que no es una lista vacia', () => {
  assert.deepEqual(validarSeleccion(undefined), { productoIds: null, descartes: [] });
  assert.deepEqual(validarSeleccion(null), { productoIds: null, descartes: [] });
  // Control: el duenio eligio y saco todo. Eso SI es una eleccion.
  assert.deepEqual(validarSeleccion({ productoIds: [] }), { productoIds: [], descartes: [] });
});

test('un documento sin la lista se lee como que nunca eligio, y queda en el log', () => {
  const r = validarSeleccion({ ids: ['a'] });
  assert.equal(r.productoIds, null);
  assert.equal(r.descartes.length, 1);
  assert.equal(validarSeleccion('basura').productoIds, null);
  assert.equal(validarSeleccion(['a', 'b']).productoIds, null);
});

test('conserva el orden del duenio', () => {
  assert.deepEqual(validarSeleccion({ productoIds: ['c', 'a', 'b'] }).productoIds, ['c', 'a', 'b']);
});

test('un id invalido queda afuera solo, y el resto sigue valiendo', () => {
  const r = validarSeleccion({ productoIds: ['a', 7, '', 'b'] });
  assert.deepEqual(r.productoIds, ['a', 'b']);
  assert.equal(r.descartes.length, 2);
});

test('un id repetido entra una vez', () => {
  const r = validarSeleccion({ productoIds: ['a', 'b', 'a'] });
  assert.deepEqual(r.productoIds, ['a', 'b']);
  assert.match(r.descartes[0]!.motivo, /repetido/);
});

test(`pasado el tope de ${LUGARES_DE_LA_SELECCION}, los que sobran quedan afuera`, () => {
  const ids = ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'];
  const r = validarSeleccion({ productoIds: ids });
  assert.deepEqual(r.productoIds, ids.slice(0, LUGARES_DE_LA_SELECCION));
  assert.equal(r.descartes.length, 2);
  // Control: justo el tope entra entero, sin descartes.
  const justo = validarSeleccion({ productoIds: ids.slice(0, LUGARES_DE_LA_SELECCION) });
  assert.equal(justo.productoIds!.length, LUGARES_DE_LA_SELECCION);
  assert.equal(justo.descartes.length, 0);
});

// -------------------------------------------------------- que va en la portada

test('la portada dibuja una botella: ni cajas ni agotados', () => {
  assert.equal(puedeIrEnLaSeleccion({ botellas: 1, balde: 'disponible' }), true);
  assert.equal(puedeIrEnLaSeleccion({ botellas: 1, balde: 'quedan-pocas' }), true);
  assert.equal(puedeIrEnLaSeleccion({ botellas: 2, balde: 'disponible' }), false);
  assert.equal(puedeIrEnLaSeleccion({ botellas: 1, balde: 'agotado' }), false);
});

test('resolver saltea lo despublicado, lo agotado y las cajas, en el orden del duenio', () => {
  const productos = [
    publicado('a'),
    publicado('b', { balde: 'agotado' }),
    publicado('c', { botellas: 2 }),
    publicado('d'),
  ];
  const ids = resolverSeleccion(['d', 'no-esta', 'b', 'c', 'a'], productos).map((p) => p.id);
  assert.deepEqual(ids, ['d', 'a']);
  // Control: con todos vigentes entran todos, y en ESE orden, no en el del catalogo.
  assert.deepEqual(
    resolverSeleccion(['d', 'a'], [publicado('a'), publicado('d')]).map((p) => p.id),
    ['d', 'a'],
  );
});
