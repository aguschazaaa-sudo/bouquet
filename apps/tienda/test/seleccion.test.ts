import { test } from 'node:test';
import assert from 'node:assert/strict';

import { centavos, type ProductoPublicado } from '@bouquet/contratos';

import { elegirSeleccion } from '../src/features/landing/seleccion.ts';

// Los seis vinos de la home, ADR 008 §7. Cada escenario con su control al lado.

function vino(id: string, cambios: Partial<ProductoPublicado> = {}): ProductoPublicado {
  return {
    id,
    slug: id,
    nombre: id,
    bodega: 'Rutini Wines',
    precio: centavos(1990000),
    botellas: 1,
    volumenMl: 750,
    imagenes: [`https://storage.googleapis.com/b/${id}.webp`],
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

const uvas = (p: Pick<ProductoPublicado, 'varietales' | 'esCorte'>) => p.varietales.join('+');
const slugs = (productos: ProductoPublicado[]) => elegirSeleccion(productos, uvas).map((v) => v.slug);

test('deja afuera los agotados y las cajas, y los que quedan entran', () => {
  const elegidos = slugs([
    vino('agotado', { balde: 'agotado' }),
    vino('caja', { botellas: 2 }),
    vino('quedan-pocas', { balde: 'quedan-pocas' }),
    vino('disponible'),
  ]);
  assert.deepEqual(elegidos, ['disponible', 'quedan-pocas']);
});

test('trae los tres colores aunque los tintos vendan más, y completa seis por puesto', () => {
  // Control: sin la regla de colores saldrían tinto-1 a tinto-6.
  const tintos = [1, 2, 3, 4, 5, 6, 7].map((n) => vino(`tinto-${n}`, { puesto: n }));
  const elegidos = slugs([
    ...tintos,
    vino('blanco', { color: 'blanco', puesto: 8 }),
    vino('rosado', { color: 'rosado', puesto: 9 }),
  ]);
  assert.deepEqual(elegidos, ['tinto-1', 'tinto-2', 'tinto-3', 'tinto-4', 'blanco', 'rosado']);
});

test('los que no tienen puesto van al final, y el empate se desarma por id', () => {
  const elegidos = slugs([vino('c'), vino('b', { puesto: 2 }), vino('a'), vino('d', { puesto: 1 })]);
  assert.deepEqual(elegidos, ['d', 'b', 'a', 'c']);
});

test('no lleva el precio: la home es estática y quedaría viejo', () => {
  const [v] = elegirSeleccion([vino('con-precio')], uvas);
  assert.equal(v?.slug, 'con-precio'); // control: el vino sí salió
  assert.ok(v && !('precio' in v));
  assert.deepEqual(Object.keys(v ?? {}).sort(), [
    'anada',
    'bodega',
    'color',
    'forma',
    'foto',
    'nombre',
    'region',
    'slug',
    'uvas',
  ]);
});

test('las uvas las escribe quien llama, y sin foto queda la silueta con su forma', () => {
  const [corte, chardonnay] = elegirSeleccion(
    [
      vino('a-corte', { varietales: ['Malbec', 'Tannat'], esCorte: true }),
      vino('b-chardonnay', { color: 'blanco', varietales: ['Chardonnay'], imagenes: [] }),
    ],
    uvas,
  );
  assert.equal(corte?.uvas, 'Malbec+Tannat');
  assert.equal(corte?.forma, 'bordelesa');
  assert.equal(chardonnay?.foto, null);
  assert.equal(chardonnay?.forma, 'borgonona');
});
