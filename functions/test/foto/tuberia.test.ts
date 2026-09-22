/**
 * El requisito de "procesar-foto/spec.md": el seed y la callable tienen que
 * dar el MISMO SHA-256 sobre la misma foto de entrada. Se mide corriendo el
 * seed de verdad -`node scripts/seed/seed.mjs --probar-foto`, la misma
 * verificacion que se hizo a mano al escribir este change-, no reimplementando
 * su logica en el test: si alguien cambia el seed, este test lo ve.
 *
 * ⚠️ `scripts/seed/fotos/` esta en `.gitignore` (son packshots de bodega, no
 * assets del repo) y por eso NO EXISTE en un checkout de CI -- medido el
 * 2026-09-22, corrida 35778011940: `ENOENT` sobre `alamos-malbec.jpg`. Las
 * dos pruebas que verifican el REQUISITO (mismo hash, y que la comparacion
 * discrimina) usan una fixture SINTETICA generada aca mismo, para no
 * depender de un archivo que sólo existe en esta maquina. Las pruebas que sí
 * dependen de las fotos reales (que numeros exactos da cada una) se saltan
 * con una razon visible cuando la carpeta no esta -- `skipped` cuenta, no es
 * un verde que no midio nada (CLAUDE.md).
 */
import { execFileSync } from 'node:child_process';
import { existsSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';
import assert from 'node:assert/strict';

import sharp from 'sharp';

import { procesarTuberia } from '../../src/foto/tuberia.ts';

const AQUI = dirname(fileURLToPath(import.meta.url));
const RAIZ = join(AQUI, '..', '..', '..');
const SEED = join(RAIZ, 'scripts', 'seed', 'seed.mjs');
const CARPETA_DE_FOTOS_REALES = join(RAIZ, 'scripts', 'seed', 'fotos');

const hayFotosReales = existsSync(CARPETA_DE_FOTOS_REALES);
const razonDeSkip = 'scripts/seed/fotos/ esta en .gitignore: no existe en este checkout';

/** Corre `seed.mjs --probar-foto` y devuelve el hash que imprime, sin tocar
 *  Firestore: esa rama del script sale antes de conectar. */
function hashDelSeed(ruta: string): string {
  const salida = execFileSync('node', [SEED, '--probar-foto', ruta], { encoding: 'utf8' });
  const m = /-> ([0-9a-f]{16})\.webp/.exec(salida);
  if (!m) throw new Error(`no se pudo leer el hash de la salida del seed:\n${salida}`);
  return m[1]!;
}

/**
 * Un packshot sintetico -un rectangulo de color sobre blanco-, para que
 * `trim()` tenga algo real que recortar (una imagen de un solo color no
 * sirve: no hay borde que distinguir). `seed.mjs --probar-foto` necesita una
 * RUTA, asi que se escribe a un archivo temporal; `procesarTuberia` toma el
 * mismo buffer directo.
 */
async function fixtureSintetica(): Promise<{ ruta: string; bytes: Buffer; limpiar: () => void }> {
  const bytes = await sharp({
    create: { width: 400, height: 400, channels: 3, background: '#ffffff' },
  })
    .composite([
      {
        input: await sharp({
          create: { width: 120, height: 260, channels: 3, background: '#6b1f2a' },
        })
          .jpeg()
          .toBuffer(),
        gravity: 'center',
      },
    ])
    .jpeg({ quality: 90 })
    .toBuffer();

  const dir = mkdtempSync(join(tmpdir(), 'bouquet-tuberia-'));
  const ruta = join(dir, 'fixture.jpg');
  writeFileSync(ruta, bytes);
  return { ruta, bytes, limpiar: () => rmSync(dir, { recursive: true, force: true }) };
}

test('el seed y procesarTuberia dan el mismo SHA-256 sobre la misma foto', async () => {
  const { ruta, bytes, limpiar } = await fixtureSintetica();
  try {
    const hashSeed = hashDelSeed(ruta);
    const resultado = await procesarTuberia(bytes);
    assert.equal(resultado.hash, hashSeed);
  } finally {
    limpiar();
  }
});

test('control negativo: el test SI discrimina cuando un numero cambia', async () => {
  // Si esto diera el mismo hash que el del seed, la comparacion de arriba
  // seria una tautologia -por ejemplo, si `procesarTuberia` ignorara sus
  // parametros o devolviera siempre el mismo buffer- y el test de arriba
  // pasaria sin medir nada.
  const { ruta, bytes, limpiar } = await fixtureSintetica();
  try {
    const hashSeed = hashDelSeed(ruta);
    const conOtraCalidad = await procesarTuberia(bytes, { calidadWebp: 40 });
    assert.notEqual(conOtraCalidad.hash, hashSeed);
  } finally {
    limpiar();
  }
});

// ------------------------------------------- pruebas contra fotos reales

test(
  'procesarTuberia informa cuanto recorto un packshot con margen',
  { skip: !hayFotosReales && razonDeSkip },
  async () => {
    const foto = join(CARPETA_DE_FOTOS_REALES, 'alamos-malbec.jpg');
    const resultado = await procesarTuberia(readFileSync(foto));
    // Medido el 2026-09-22 con el mismo archivo: recorta a 210x814. El alto
    // trimeado (814) YA es menor a 1200, asi que `withoutEnlargement` no lo
    // agranda -- el resize no hace nada en esta foto, y eso es correcto.
    assert.ok(resultado.porcentajeRecortado > 80 && resultado.porcentajeRecortado < 85);
    assert.equal(resultado.alto, 814);
  },
);

test(
  'una foto mas chica que el objetivo no se agranda',
  { skip: !hayFotosReales && razonDeSkip },
  async () => {
    const chica = join(CARPETA_DE_FOTOS_REALES, 'portillo-malbec.png');
    const resultado = await procesarTuberia(readFileSync(chica));
    assert.ok(resultado.alto < 1200);
  },
);
