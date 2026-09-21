import { test } from 'node:test';
import assert from 'node:assert/strict';

import { centavos, type ProductoPublicado } from '@bouquet/contratos';

import {
  CORTE,
  ESTADO_INICIAL,
  cepasDelCatalogo,
  escribirEnLaUrl,
  filtrar,
  leerDeLaUrl,
  ordenar,
  ordenesDisponibles,
} from '../src/features/catalogo/filtros.ts';

// Un escenario por test de specs/vidriera-catalogo, con su control al lado.

function vino(id: string, cambios: Partial<ProductoPublicado> = {}): ProductoPublicado {
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

const CATALOGO = [
  vino('malbec'),
  vino('corte-con-malbec', { varietales: ['Malbec', 'Cabernet Sauvignon'], esCorte: true }),
  vino('chardonnay-organico', { color: 'blanco', varietales: ['Chardonnay'], organico: true }),
  vino('torrontes', { color: 'blanco', varietales: ['Torrontés'] }),
  vino('rosado', { color: 'rosado' }),
];
const ids = (ps: readonly ProductoPublicado[]) => ps.map((p) => p.id);

test('blanco y orgánico juntos dejan sólo los blancos orgánicos', () => {
  assert.deepEqual(ids(filtrar(CATALOGO, { ...ESTADO_INICIAL, color: 'blanco', organico: true })), ['chardonnay-organico']);
  // Control: sin el orgánico entran los dos blancos.
  assert.deepEqual(ids(filtrar(CATALOGO, { ...ESTADO_INICIAL, color: 'blanco' })), ['chardonnay-organico', 'torrontes']);
});

test('la cepa Malbec no incluye los cortes que llevan Malbec', () => {
  const soloMalbec = ids(filtrar(CATALOGO, { ...ESTADO_INICIAL, cepas: ['Malbec'] }));
  assert.ok(soloMalbec.includes('malbec'));
  assert.ok(!soloMalbec.includes('corte-con-malbec'), 'un corte no es un Malbec');
  // Control: el corte aparece bajo los cortes.
  assert.deepEqual(ids(filtrar(CATALOGO, { ...ESTADO_INICIAL, cepas: [CORTE] })), ['corte-con-malbec']);
});

test('una combinación imposible no deja ningún vino', () => {
  assert.equal(filtrar(CATALOGO, { ...ESTADO_INICIAL, color: 'rosado', organico: true }).length, 0);
});

test('el agotado más barato va después de todos los disponibles', () => {
  const lista = [
    vino('caro', { precio: centavos(3000000) }),
    vino('barato-agotado', { precio: centavos(500000), balde: 'agotado', tope: 0 }),
    vino('medio', { precio: centavos(1500000) }),
  ];
  assert.deepEqual(ids(ordenar(lista, 'precio-asc')), ['medio', 'caro', 'barato-agotado']);
  assert.deepEqual(ids(ordenar(lista, 'precio-desc')), ['caro', 'medio', 'barato-agotado']);
  assert.deepEqual(ids(ordenar(lista, 'nombre')), ['caro', 'medio', 'barato-agotado']);
});

test('el nombre se compara en español, con acentos', () => {
  const lista = [vino('Zuccardi'), vino('Álamos'), vino('Norton')];
  assert.deepEqual(ids(ordenar(lista, 'nombre')), ['Álamos', 'Norton', 'Zuccardi']);
});

test('sin métricas no se ofrece la popularidad', () => {
  assert.ok(!ordenesDisponibles(false).includes('popularidad'));
  assert.ok(ordenesDisponibles(true).includes('popularidad'));
});

test('la popularidad ordena por puesto, y los que no tienen van al final', () => {
  const lista = [vino('b', { puesto: 2 }), vino('sin', { puesto: null }), vino('a', { puesto: 1 })];
  assert.deepEqual(ids(ordenar(lista, 'popularidad')), ['a', 'b', 'sin']);
});

test('las cepas del catálogo no incluyen los cortes, y van de la más frecuente a la menos', () => {
  assert.deepEqual(cepasDelCatalogo(CATALOGO), ['Malbec', 'Chardonnay', 'Torrontés']);
});

test('la URL guarda el estado y lo devuelve igual', () => {
  const opciones = { cepas: ['Malbec', 'Torrontés'], hayCortes: true, hayPopularidad: false };
  const estado = { color: 'blanco', cepas: ['Torrontés', CORTE], organico: true, orden: 'nombre' } as const;
  const url = escribirEnLaUrl(estado);
  assert.deepEqual(leerDeLaUrl(url, opciones), estado);
  assert.equal(escribirEnLaUrl(ESTADO_INICIAL), '', 'el estado por defecto no ensucia la URL');
});

test('lo que no existe en la URL se ignora', () => {
  const opciones = { cepas: ['Malbec'], hayCortes: false, hayPopularidad: false };
  const e = leerDeLaUrl('?color=naranjo&cepa=Garnacha,corte,Malbec&orden=popularidad', opciones);
  assert.equal(e.color, 'todos');
  assert.deepEqual(e.cepas, ['Malbec'], 'sin cortes en el catálogo, "corte" no vale');
  assert.equal(e.orden, 'precio-asc', 'sin métricas, la popularidad vuelve al orden por defecto');
});
