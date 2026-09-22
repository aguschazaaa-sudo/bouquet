/**
 * Que es una imagen que la vidriera puede servir, mirando los BYTES, nunca
 * el nombre del archivo ni el `contentType` que declara quien sube (design.md
 * decision 3). Es mas estricto que ARQUITECTURA §5.4 regla 1 -que pide
 * derivar del `mimeType`-, no menos: en Android el `mimeType` puede venir
 * `null`, y leer los bytes resuelve las dos plataformas con un solo camino.
 */

export type FormatoDeFoto = 'jpeg' | 'png' | 'webp';

const CONTENT_TYPE: Record<FormatoDeFoto, string> = {
  jpeg: 'image/jpeg',
  png: 'image/png',
  webp: 'image/webp',
};

/**
 * `null` cuando los bytes no son de ninguno de los tres formatos que la
 * vidriera sabe servir -incluye un PDF, un HEIC, o cualquier otra cosa con
 * un nombre de archivo enganoso.
 */
export function detectarFormato(bytes: Buffer): FormatoDeFoto | null {
  if (bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) {
    return 'jpeg';
  }
  if (
    bytes.length >= 8 &&
    bytes[0] === 0x89 &&
    bytes[1] === 0x50 &&
    bytes[2] === 0x4e &&
    bytes[3] === 0x47 &&
    bytes[4] === 0x0d &&
    bytes[5] === 0x0a &&
    bytes[6] === 0x1a &&
    bytes[7] === 0x0a
  ) {
    return 'png';
  }
  if (
    bytes.length >= 12 &&
    bytes[0] === 0x52 &&
    bytes[1] === 0x49 &&
    bytes[2] === 0x46 &&
    bytes[3] === 0x46 && // "RIFF"
    bytes[8] === 0x57 &&
    bytes[9] === 0x45 &&
    bytes[10] === 0x42 &&
    bytes[11] === 0x50 // "WEBP"
  ) {
    return 'webp';
  }
  return null;
}

export function contentTypeDe(formato: FormatoDeFoto): string {
  return CONTENT_TYPE[formato];
}

/** 5 MB, el mismo tope que `pesaMenosDe5MB()` de `storage.rules`. Repetido
 *  a proposito: la regla ya lo aplica del lado del bucket, esta constante
 *  es para que el panel avise ANTES de subir (spec `panel-fotos-vino`,
 *  requisito "El panel mide el peso antes de subir"). */
export const TOPE_DE_BYTES = 5 * 1024 * 1024;
