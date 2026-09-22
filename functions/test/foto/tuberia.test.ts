/**
 * El requisito de "procesar-foto/spec.md": el seed y la callable tienen que
 * dar el MISMO SHA-256 sobre la misma foto de entrada. Se mide corriendo el
 * seed de verdad -`node scripts/seed/seed.mjs --probar-foto`, la misma
 * verificacion que se hizo a mano al escribir este change-, no reimplementando
 * su logica en el test: si alguien cambia el seed, este test lo ve.
 */
import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';
import assert from 'node:assert/strict';

import { procesarTuberia } from '../../src/foto/tuberia.ts';

const AQUI = dirname(fileURLToPath(import.meta.url));
const RAIZ = join(AQUI, '..', '..', '..');
const SEED = join(RAIZ, 'scripts', 'seed', 'seed.mjs');
const FOTO = join(RAIZ, 'scripts', 'seed', 'fotos', 'alamos-malbec.jpg');

/** Corre `seed.mjs --probar-foto` y devuelve el hash que imprime, sin tocar
 *  Firestore: esa rama del script sale antes de conectar. */
function hashDelSeed(ruta: string): string {
  const salida = execFileSync('node', [SEED, '--probar-foto', ruta], { encoding: 'utf8' });
  const m = /-> ([0-9a-f]{16})\.webp/.exec(salida);
  if (!m) throw new Error(`no se pudo leer el hash de la salida del seed:\n${salida}`);
  return m[1]!;
}

test('el seed y procesarTuberia dan el mismo SHA-256 sobre la misma foto', async () => {
  const hashSeed = hashDelSeed(FOTO);
  const resultado = await procesarTuberia(readFileSync(FOTO));
  assert.equal(resultado.hash, hashSeed);
});

test('control negativo: el test SI discrimina cuando un numero cambia', async () => {
  // Si esto diera el mismo hash que el del seed, la comparacion de arriba
  // seria un tautologia -por ejemplo, si `procesarTuberia` ignorara sus
  // parametros o devolviera siempre el mismo buffer- y el test de arriba
  // pasaria sin medir nada.
  const hashSeed = hashDelSeed(FOTO);
  const conOtraCalidad = await procesarTuberia(readFileSync(FOTO), { calidadWebp: 40 });
  assert.notEqual(conOtraCalidad.hash, hashSeed);
});

test('procesarTuberia informa cuanto recorto un packshot con margen', async () => {
  const resultado = await procesarTuberia(readFileSync(FOTO));
  // Medido el 2026-09-22 con el mismo archivo: recorta a 210x814. El alto
  // trimeado (814) YA es menor a 1200, asi que `withoutEnlargement` no lo
  // agranda -- el resize no hace nada en esta foto, y eso es correcto.
  assert.ok(resultado.porcentajeRecortado > 80 && resultado.porcentajeRecortado < 85);
  assert.equal(resultado.alto, 814);
});

test('una foto mas chica que el objetivo no se agranda', async () => {
  const chica = join(RAIZ, 'scripts', 'seed', 'fotos', 'portillo-malbec.png');
  const resultado = await procesarTuberia(readFileSync(chica));
  assert.ok(resultado.alto < 1200);
});
