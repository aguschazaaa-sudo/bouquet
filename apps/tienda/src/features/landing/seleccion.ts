import { COLORES, type Color, type ProductoPublicado, type Varietal } from '@bouquet/contratos';

import type { FormaDeBotella } from './BotellaSvg';

/* Los vinos de la escena 2, sacados del catálogo publicado. ADR 008 §7.
 *
 * Eran seis inventados, y el comentario que los acompañaba ya decía cómo
 * reemplazarlos: la landing NO lee Firestore por visitante (ADR 004). La
 * proyección se lee UNA vez, al armar el build —una lectura por deploy, cero
 * por visita—, y por eso la home no entra al circuito de purga por tag de
 * ADR 005.
 *
 * Y hay UN campo que no se hornea nunca: el PRECIO. En una página estática
 * quedaría viejo hasta el próximo deploy, y el que vale es el de la ficha, que
 * sí se invalida. La defensa no es CSS: `VinoDeLaSeleccion` se arma campo por
 * campo y el precio no está. Si esta estructura crece un `precio`, la garantía
 * de estática de la landing ya es falsa y nadie se enteró —
 * apps/tienda/test/seleccion.test.ts lo mide.
 */

const LUGARES = 6;

export type VinoDeLaSeleccion = {
  readonly slug: string;
  readonly nombre: string;
  readonly bodega: string;
  /** "Malbec", o "Corte de…". Lo escribe el catálogo: la home y la ficha dicen lo mismo. */
  readonly uvas: string;
  readonly anada: number | null;
  readonly region: string;
  /** Tiñe el vidrio de la silueta cuando no hay foto. */
  readonly color: Color;
  readonly foto: string | null;
  readonly forma: FormaDeBotella;
};

/** Hombro caído. El resto del vino argentino va en bordelesa (BotellaSvg). */
const EN_BORGONONA: readonly Varietal[] = ['Pinot Noir', 'Chardonnay'];

function aVino(p: ProductoPublicado, uvas: string): VinoDeLaSeleccion {
  return {
    slug: p.slug,
    nombre: p.nombre,
    bodega: p.bodega,
    uvas,
    anada: p.anada,
    region: p.region,
    color: p.color,
    foto: p.imagenes[0] ?? null,
    forma: !p.esCorte && p.varietales.every((v) => EN_BORGONONA.includes(v)) ? 'borgonona' : 'bordelesa',
  };
}

/**
 * Los seis de la home. Ninguno agotado ni en caja —la tarjeta dibuja UNA
 * botella—, los tres colores si el catálogo los tiene, y el resto por puesto de
 * venta con desempate por id: dos builds sobre los mismos datos dan la misma
 * home.
 *
 * ⚠️ Es una regla provisoria. La escena dice "los elegimos de a uno", y eso
 * pide un dato que el modelo todavía no tiene: que el dueño marque cuáles.
 *
 * `describirUvas` llega de afuera porque es texto del catálogo, y la landing no
 * importa otra feature (ADR 006 regla 3): se la pasa `app/`.
 */
export function elegirSeleccion(
  productos: readonly ProductoPublicado[],
  describirUvas: (p: Pick<ProductoPublicado, 'varietales' | 'esCorte'>) => string,
): VinoDeLaSeleccion[] {
  const candidatos = productos
    .filter((p) => p.balde !== 'agotado' && p.botellas === 1)
    .sort((a, b) => (a.puesto ?? Infinity) - (b.puesto ?? Infinity) || a.id.localeCompare(b.id));

  const elegidos = new Set<ProductoPublicado>();
  for (const color of COLORES) {
    const primero = candidatos.find((p) => p.color === color);
    if (primero) elegidos.add(primero);
  }
  for (const p of candidatos) {
    if (elegidos.size >= LUGARES) break;
    elegidos.add(p);
  }

  return candidatos.filter((p) => elegidos.has(p)).map((p) => aVino(p, describirUvas(p)));
}
