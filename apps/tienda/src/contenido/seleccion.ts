import type { FormaDeBotella } from '@/components/landing/BotellaSvg';

/* ⚠️⚠️  DATOS DE MUESTRA. NADA DE ESTO ES REAL.  ⚠️⚠️
 *
 * Los nombres de vino y de bodega son INVENTADOS. Sirven para mirar la
 * composición, no para publicarla. voz.md §6 prohíbe afirmar lo que no se
 * puede sostener, y un nombre de bodega escrito a mano en un archivo de
 * diseño es exactamente por donde entra un hecho falso a producción.
 *
 * Antes de cualquier deploy hay que reemplazar esto por la proyección
 * publicada del catálogo. La sustitución es barata a propósito: la landing
 * NO lee Firestore por visitante (ADR 004). Los datos se hornean en build
 * —una lectura por deploy, cero por visita— y por eso la home no entra al
 * circuito de purga por tag de ADR 005.
 *
 * Se puede verificar que se hizo con:
 *     grep -rn "LA_SELECCION_ES_DE_MUESTRA" apps/tienda/src
 * Mientras devuelva `true`, la home no se publica.
 *
 * Y hay UN campo que no se hornea nunca, ni para descartarlo después: el
 * PRECIO. La defensa contra la fuga no es CSS, es que el build no lea el
 * campo. Si esta estructura crece un `precio`, la garantía de estática de la
 * landing ya es falsa y nadie se enteró.
 */
export const LA_SELECCION_ES_DE_MUESTRA = true;

export type VinoDeLaSeleccion = {
  slug: string;
  nombre: string;
  bodega: string;
  varietal: string;
  anada: number;
  region: string;
  forma: FormaDeBotella;
  /** Tinte del vidrio. Materia, no dato: define qué token lo pinta. */
  vidrio: 'tinto' | 'blanco' | 'rosado';
  /**
   * La tercera línea de la tarjeta, y la única que sólo bouquet puede
   * escribir: un hecho de CUSTODIA, no una nota de cata.
   *
   * voz.md §3.2 — bouquet nunca firma una descripción sensorial del líquido
   * que no probó. Pero sí puede decir desde cuándo está acostada, porque eso
   * lo hizo. Es la diferencia entre repetir la gacetilla de otro y decir algo
   * propio y falsable.
   */
  guarda: string;
};

export const SELECCION: readonly VinoDeLaSeleccion[] = [
  {
    slug: 'muestra-01',
    nombre: 'Cuesta del Sauce',
    bodega: 'Finca Los Álamos',
    varietal: 'Malbec',
    anada: 2019,
    region: 'Valle de Uco, Mendoza',
    forma: 'bordelesa',
    vidrio: 'tinto',
    guarda: 'Acostada desde marzo',
  },
  {
    slug: 'muestra-02',
    nombre: 'Piedra Partida',
    bodega: 'Bodega del Zonda',
    varietal: 'Cabernet Franc',
    anada: 2020,
    region: 'Pedernal, San Juan',
    forma: 'bordelesa',
    vidrio: 'tinto',
    guarda: 'Once meses en reposo',
  },
  {
    slug: 'muestra-03',
    nombre: 'Vuelta de Año',
    bodega: 'Casa Verano',
    varietal: 'Chardonnay',
    anada: 2022,
    region: 'Tupungato, Mendoza',
    forma: 'borgonona',
    vidrio: 'blanco',
    guarda: 'Llegó en junio, sin luz',
  },
  {
    slug: 'muestra-04',
    nombre: 'El Callejón',
    bodega: 'Viñedo Alto Grande',
    varietal: 'Pinot Noir',
    anada: 2021,
    region: 'Valle de Río Negro',
    forma: 'borgonona',
    vidrio: 'tinto',
    guarda: 'A temperatura pareja desde enero',
  },
  {
    slug: 'muestra-05',
    nombre: 'Segunda Tarde',
    bodega: 'Finca Los Álamos',
    varietal: 'Rosado de Malbec',
    anada: 2023,
    region: 'Luján de Cuyo, Mendoza',
    forma: 'bordelesa',
    vidrio: 'rosado',
    guarda: 'La más joven que guardamos',
  },
  {
    slug: 'muestra-06',
    nombre: 'La Que Esperaba',
    bodega: 'Bodega del Zonda',
    varietal: 'Cabernet Sauvignon',
    anada: 2017,
    region: 'Valle Calchaquí, Salta',
    forma: 'bordelesa',
    vidrio: 'tinto',
    guarda: 'Cuatro años acostada acá',
  },
];
