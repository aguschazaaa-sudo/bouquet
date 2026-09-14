import { COLORES, type Color, type ProductoPublicado } from '@bouquet/contratos';

/* Filtrar y ordenar el catálogo, EN EL NAVEGADOR y sin un solo pedido de red.
 * ADR 004 §3, design.md §2.
 *
 * Puro a propósito: no toca el DOM ni la URL, así se prueba con `node --test`
 * (apps/tienda/test/filtros.test.ts), un caso por escenario de
 * specs/vidriera-catalogo.
 */

/** La clave de los cortes en el filtro de cepas. No choca con ningún varietal. */
export const CORTE = 'corte';

export const ORDENES = ['precio-asc', 'precio-desc', 'nombre', 'popularidad'] as const;
export type Orden = (typeof ORDENES)[number];

/** design.md §9: existe siempre, porque no depende de métricas. */
export const ORDEN_POR_DEFECTO: Orden = 'precio-asc';

export interface EstadoDelListado {
  readonly color: Color | 'todos';
  /** Nombres de varietal, o `CORTE`. Vacío = todas. */
  readonly cepas: readonly string[];
  readonly organico: boolean;
  readonly orden: Orden;
}

export const ESTADO_INICIAL: EstadoDelListado = { color: 'todos', cepas: [], organico: false, orden: ORDEN_POR_DEFECTO };

/** Un vino de una sola uva cae en esa uva; uno de dos o más, en los cortes. */
export const claveDeCepa = (p: Pick<ProductoPublicado, 'esCorte' | 'varietales'>) =>
  p.esCorte ? CORTE : (p.varietales[0] ?? '');

export function pasa(p: ProductoPublicado, e: EstadoDelListado): boolean {
  if (e.color !== 'todos' && p.color !== e.color) return false;
  if (e.organico && !p.organico) return false;
  if (e.cepas.length > 0 && !e.cepas.includes(claveDeCepa(p))) return false;
  return true;
}

export const filtrar = (productos: readonly ProductoPublicado[], e: EstadoDelListado) =>
  productos.filter((p) => pasa(p, e));

const porNombre = (a: ProductoPublicado, b: ProductoPublicado) => a.nombre.localeCompare(b.nombre, 'es');
const SIN_PUESTO = Number.MAX_SAFE_INTEGER;

const COMPARAR: Readonly<Record<Orden, (a: ProductoPublicado, b: ProductoPublicado) => number>> = {
  'precio-asc': (a, b) => a.precio - b.precio || porNombre(a, b),
  'precio-desc': (a, b) => b.precio - a.precio || porNombre(a, b),
  nombre: porNombre,
  popularidad: (a, b) => (a.puesto ?? SIN_PUESTO) - (b.puesto ?? SIN_PUESTO) || porNombre(a, b),
};

/** Lo agotado se ve, pero siempre al final, en cualquier orden. */
export function ordenar(productos: readonly ProductoPublicado[], orden: Orden): ProductoPublicado[] {
  const agotado = (p: ProductoPublicado) => (p.balde === 'agotado' ? 1 : 0);
  return [...productos].sort((a, b) => agotado(a) - agotado(b) || COMPARAR[orden](a, b));
}

/** Sin métricas, la popularidad no se ofrece (specs/vidriera-catalogo). */
export const ordenesDisponibles = (hayPopularidad: boolean): Orden[] =>
  ORDENES.filter((o) => o !== 'popularidad' || hayPopularidad);

/** Las uvas que están en el catálogo como cepa, de la más frecuente a la menos. */
export function cepasDelCatalogo(productos: readonly ProductoPublicado[]): string[] {
  const cuenta = new Map<string, number>();
  for (const p of productos) if (!p.esCorte) cuenta.set(claveDeCepa(p), (cuenta.get(claveDeCepa(p)) ?? 0) + 1);
  return [...cuenta.keys()].sort((a, b) => (cuenta.get(b) ?? 0) - (cuenta.get(a) ?? 0) || a.localeCompare(b, 'es'));
}

interface Opciones {
  readonly cepas: readonly string[];
  readonly hayCortes: boolean;
  readonly hayPopularidad: boolean;
}

/** Lo que llega en `?color=…&cepa=…`, validado: lo que no existe se ignora. */
export function leerDeLaUrl(busqueda: string, o: Opciones): EstadoDelListado {
  const q = new URLSearchParams(busqueda);
  const color = q.get('color');
  const orden = q.get('orden');
  const validas = (q.get('cepa') ?? '')
    .split(',')
    .filter((c) => o.cepas.includes(c) || (c === CORTE && o.hayCortes));
  return {
    color: (COLORES as readonly string[]).includes(color ?? '') ? (color as Color) : 'todos',
    cepas: [...new Set(validas)],
    organico: q.get('organico') === '1',
    orden: ordenesDisponibles(o.hayPopularidad).includes(orden as Orden) ? (orden as Orden) : ORDEN_POR_DEFECTO,
  };
}

/** El estado como `?…`, sin los valores por defecto. Vacío si no hay nada. */
export function escribirEnLaUrl(e: EstadoDelListado): string {
  const q = new URLSearchParams();
  if (e.color !== 'todos') q.set('color', e.color);
  if (e.cepas.length) q.set('cepa', e.cepas.join(','));
  if (e.organico) q.set('organico', '1');
  if (e.orden !== ORDEN_POR_DEFECTO) q.set('orden', e.orden);
  const texto = q.toString();
  return texto ? `?${texto}` : '';
}
