import { readFileSync, readdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { test } from 'node:test';
import assert from 'node:assert/strict';

import { contentTypeDe, detectarFormato } from '../../src/foto/validar.ts';

const AQUI = dirname(fileURLToPath(import.meta.url));
const FOTOS = join(AQUI, '..', '..', '..', 'scripts', 'seed', 'fotos');

test('control positivo: las 19 fotos reales del seed se detectan', () => {
  const archivos = readdirSync(FOTOS).filter((f) => f.endsWith('.jpg') || f.endsWith('.png'));
  assert.equal(archivos.length, 19);
  for (const archivo of archivos) {
    const formato = detectarFormato(readFileSync(join(FOTOS, archivo)));
    const esperado = archivo.endsWith('.png') ? 'png' : 'jpeg';
    assert.equal(formato, esperado, `${archivo} deberia detectarse como ${esperado}`);
  }
});

test('un PDF renombrado foto.jpg NO se detecta como imagen', () => {
  // Cabecera real de PDF, sin ninguna relacion con los bytes magicos de
  // jpeg/png/webp: es el caso que ARQUITECTURA §5.4 pide que NO pase por
  // extension ni contentType declarado.
  const pdf = Buffer.from('%PDF-1.4\n1 0 obj<<>>endobj\ntrailer<<>>\n%%EOF');
  assert.equal(detectarFormato(pdf), null);
});

test('un HEIC no se detecta: no esta en la lista cerrada', () => {
  // Cabecera minima de un contenedor ISOBMFF con marca "heic" -- ni jpeg, ni
  // png, ni webp.
  const heic = Buffer.from([
    0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70, 0x68, 0x65, 0x69, 0x63, 0x00, 0x00, 0x00, 0x00,
  ]);
  assert.equal(detectarFormato(heic), null);
});

test('un archivo vacio no se detecta', () => {
  assert.equal(detectarFormato(Buffer.alloc(0)), null);
});

test('un archivo mas corto que la firma no revienta', () => {
  assert.equal(detectarFormato(Buffer.from([0xff, 0xd8])), null);
});

test('un WebP se detecta por RIFF....WEBP', () => {
  const riff = Buffer.concat([
    Buffer.from('RIFF', 'ascii'),
    Buffer.from([0, 0, 0, 0]),
    Buffer.from('WEBP', 'ascii'),
  ]);
  assert.equal(detectarFormato(riff), 'webp');
});

test('contentTypeDe da el mime real de cada formato', () => {
  assert.equal(contentTypeDe('jpeg'), 'image/jpeg');
  assert.equal(contentTypeDe('png'), 'image/png');
  assert.equal(contentTypeDe('webp'), 'image/webp');
});
