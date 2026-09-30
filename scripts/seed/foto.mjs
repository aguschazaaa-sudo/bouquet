// foto.mjs - la tuberia de foto que comparten seed.mjs y catalogo/cargar.mjs.
//
// Vive aparte para que haya UNA sola copia del lado de los scripts:
// `functions/test/foto/tuberia.test.ts` corre `seed.mjs --probar-foto` y exige
// el mismo SHA-256 que `procesarFoto`, asi que lo que carga cargar.mjs queda
// cubierto por el mismo test sin escribir otro.

import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';

import sharp from 'sharp';

import { TUBERIA_DE_FOTO } from '../../packages/contratos/src/foto.ts';

export const sha256 = (buf) => createHash('sha256').update(buf).digest('hex');

/**
 * Las imagenes genericas de "no disponible" que sirven las vinotecas en lugar
 * de la foto. Se reconocen por el hash exacto del archivo: la de Jumbo
 * aparecio como candidata para Don Nicanor (2026-09-10), y otra vez para
 * Navarro Correas y Argento (2026-09-30). La lista crece cuando aparezca otra;
 * un placeholder nuevo pasa hasta que alguien lo agregue.
 */
const PLACEHOLDERS = new Map([
  ['929c8b2ca776c84d023085e52155f059b74941295ad0b079030f8d18442f5e47', 'Jumbo, "Imagen no disponible"'],
]);

/**
 * WebP, recortada al borde de la botella. El recorte lo pidieron las dos
 * maquetas por separado: `object-fit` iguala la caja, no la botella, y sin
 * recortar el fondo una botella ocupa el 81 % del alto y otra el 100 %.
 *
 * Los tres numeros salen de `contratos/foto.ts`, no estan en linea aca: es
 * la MISMA tuberia que aplica `procesarFoto` sobre lo que sube el panel
 * (openspec/changes/panel-fotos-de-un-vino). `tuberia.test.ts` exige que las
 * dos den el mismo SHA-256 sobre la misma entrada.
 */
export async function prepararFoto(ruta) {
  const original = readFileSync(ruta);
  const placeholder = PLACEHOLDERS.get(sha256(original));
  if (placeholder) return { ok: false, motivo: `es un placeholder (${placeholder})` };

  let formato;
  try {
    formato = (await sharp(original).metadata()).format;
  } catch {
    return { ok: false, motivo: 'no es una imagen' };
  }
  if (!['jpeg', 'png', 'webp'].includes(formato)) return { ok: false, motivo: `formato ${formato}` };

  const webp = await sharp(original)
    .trim({ threshold: TUBERIA_DE_FOTO.umbralRecorte })
    .resize({ height: TUBERIA_DE_FOTO.alto, withoutEnlargement: true })
    .webp({ quality: TUBERIA_DE_FOTO.calidadWebp })
    .toBuffer();
  return { ok: true, webp, hash: sha256(webp).slice(0, 16) };
}
