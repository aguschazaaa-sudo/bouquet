/**
 * Aplica la MISMA tuberia que `scripts/seed/seed.mjs`, con los mismos numeros
 * -`TUBERIA_DE_FOTO` de `@bouquet/contratos`-, para que una foto subida desde
 * el panel llegue a la vidriera con la forma exacta de las del seed.
 *
 * `functions/test/foto/tuberia.test.ts` procesa la misma foto por este modulo
 * y por el seed, y exige el mismo SHA-256. Es lo que impide que las dos copias
 * de la tuberia -no hay una sola implementacion compartida, ver design.md
 * decision 4- diverjan sin que nadie lo note.
 */
import { createHash } from 'node:crypto';

import sharp from 'sharp';

// `@bouquet/contratos` NO esta en `functions/package.json` -ni en
// `dependencies` ni en `devDependencies`- A PROPOSITO. Medido el 2026-09-22:
// `firebase deploy` sube SOLO `functions/` (18 KB, sin lockfile propio), y
// Cloud Build corre `npm install` ahi aislado, sin el contexto del workspace.
// Sin un lockfile que diga "esto es un symlink local", npm intenta bajarlo
// del registro real y da `404 Not Found` -da IGUAL que este en dependencies o
// en devDependencies, las dos fallan igual, medido las dos veces-. Local
// funciona sin declararlo porque `packages/contratos` es un workspace del
// repo: npm lo symlinkea en la raiz para TODOS los workspaces, lo declaren o
// no. Y en runtime no hace falta: `esbuild` lo empaqueta ADENTRO de
// `lib/index.js` en el build (construir), asi que el deploy nunca necesita
// resolverlo por su cuenta.
import { TUBERIA_DE_FOTO } from '@bouquet/contratos';

/** Lo que le importa a quien llama: el WebP, su nombre, y datos que van a la
 *  pantalla del panel -no una decision, un dato (design.md decision 7 /
 *  requirement "La callable informa cuanto recorto"). */
export interface FotoProcesada {
  readonly webp: Buffer;
  /** Los primeros 16 caracteres del SHA-256 del WebP ya procesado. */
  readonly hash: string;
  readonly ancho: number;
  readonly alto: number;
  /** Que porcentaje del AREA original saco `trim()`. 0 cuando no encontro
   *  borde uniforme -no es un error, es un dato: ver el requisito de arriba. */
  readonly porcentajeRecortado: number;
}

function sha256(buf: Buffer): string {
  return createHash('sha256').update(buf).digest('hex');
}

/**
 * Recorta al borde, redimensiona sin agrandar y codifica a WebP. Lanza si
 * `sharp` no puede leer el buffer como imagen -eso lo atrapa `validar.ts`
 * antes de llegar aca, pero esta funcion no confia en eso: es una funcion
 * pura de bytes, sin permisos ni validacion de quien la llama (design.md
 * decision 5).
 *
 * `overrides` existe SOLO para que el test de divergencia pueda variar un
 * numero sin tocar `TUBERIA_DE_FOTO` -tocarla invalidaria la comparacion
 * contra el seed al mismo tiempo que la mide. Sin pasarlo, el comportamiento
 * es exactamente el de produccion.
 */
interface NumerosDeLaTuberia {
  umbralRecorte: number;
  alto: number;
  calidadWebp: number;
}

export async function procesarTuberia(
  original: Buffer,
  overrides?: Partial<NumerosDeLaTuberia>,
): Promise<FotoProcesada> {
  const tuberia = { ...TUBERIA_DE_FOTO, ...overrides };

  const antes = await sharp(original).metadata();
  const anchoAntes = antes.width ?? 0;
  const altoAntes = antes.height ?? 0;

  const recortado = sharp(original).trim({ threshold: tuberia.umbralRecorte });
  const { info: infoRecorte } = await recortado.toBuffer({ resolveWithObject: true });

  const areaAntes = anchoAntes * altoAntes;
  const areaDespues = infoRecorte.width * infoRecorte.height;
  const porcentajeRecortado = areaAntes > 0 ? (1 - areaDespues / areaAntes) * 100 : 0;

  const webp = await sharp(original)
    .trim({ threshold: tuberia.umbralRecorte })
    .resize({ height: tuberia.alto, withoutEnlargement: true })
    .webp({ quality: tuberia.calidadWebp })
    .toBuffer();

  const final = await sharp(webp).metadata();

  return {
    webp,
    hash: sha256(webp).slice(0, 16),
    ancho: final.width ?? 0,
    alto: final.height ?? 0,
    porcentajeRecortado,
  };
}
