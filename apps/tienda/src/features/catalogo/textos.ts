import type { Color, ProductoPublicado } from '@bouquet/contratos';

/* Las cadenas de catalogo/, juntas. ADR 008, voz.md.
 *
 * En un solo archivo para que `voz` las cure sin abrir un componente
 * (CLAUDE.md: todo texto que llega a un comprador pasa por `voz`). Los
 * componentes de la feature no escriben texto propio. Los textos del balde no
 * están acá: viven en contratos (`textoDelBalde`), junto al cálculo.
 */

const listaY = (a: readonly string[]) =>
  a.length <= 1 ? a.join('') : `${a.slice(0, -1).join(', ')} y ${a[a.length - 1]}`;

/** "Malbec, Cabernet Sauvignon y Tannat". */
export const listarUvas = (p: Pick<ProductoPublicado, 'varietales'>) => listaY(p.varietales);

const vinos = (n: number) => (n === 1 ? 'vino' : 'vinos');

export const TEXTOS = {
  titulo: 'Los vinos',
  bajada: 'Elegí por color o por cepa. Lo agregás desde acá, y la cantidad se cambia sin abrir la ficha.',
  sinFoto: 'Sin foto todavía',
  organico: 'Orgánico',
  color: 'Color',
  colores: { todos: 'Todos', tinto: 'Tintos', blanco: 'Blancos', rosado: 'Rosados' },
  filtros: 'Filtros',
  cepa: 'Cepa',
  cortes: 'Cortes',
  notaCortes: 'De dos o más cepas. Un Malbec con Cabernet va acá, no en Malbec.',
  soloOrganicos: 'Sólo orgánicos',
  quitarFiltros: 'Quitar los filtros',
  cerrar: 'Cerrar',
  orden: 'Orden',
  ordenes: {
    'precio-asc': 'Menor precio',
    'precio-desc': 'Mayor precio',
    nombre: 'De la A a la Z',
    popularidad: 'Más vendidos',
  },
  cuenta: (n: number) => vinos(n),
  verLosVinos: (n: number) => (n ? `Ver ${n} ${vinos(n)}` : 'Ver la lista'),
  sinResultados: 'Con esos filtros no queda ningún vino.',
  sacandoUno: 'Sacando uno, aparecen:',
  relajar: {
    color: 'Ver todos los colores',
    cepa: 'Quitar la cepa',
    organico: 'Quitar «Sólo orgánicos»',
  },
  cuantos: (n: number) => `${n} ${vinos(n)}`,
  volver: 'Los vinos',
  cajaDe: (n: number) => `Caja de ${n}`,
  precioYCompra: 'Precio y compra',
  hoja: 'Los datos',
  custodiaTitulo: 'Hasta que sale',
  custodia: 'La botella espera acostada, a temperatura pareja y sin luz.',
  filas: {
    bodega: 'Bodega',
    cepa: 'Cepa',
    corte: 'Corte',
    anada: 'Añada',
    region: 'Región',
    color: 'Color',
    organico: 'Orgánico',
    presentacion: 'Presentación',
  },
  si: 'Sí',
  no: 'No',
  sinAnada: 'Sin añada',

  // --- la venta por caja y el carril ---
  seVendeDeA: (n: number) => `El vino se vende en cajas de ${n} botellas. Elegí las que quieras y armá la tuya.`,
  cajasTitulo: 'Cajas armadas',
  cuantasBotellas: (n: number) => `${n} botellas`,
  cajasBajada: 'Si no querés elegir de a uno, empezá por una de éstas. Después la cambiás.',
  cajaIncompleta: 'Hoy no está completa',
  lugarAgotado: 'Se agotó',
  lugarSinSuficiente: 'No alcanza para otra',
  lugarSinVino: 'Ya no está',
} as const;

export const COLOR_SINGULAR: Readonly<Record<Color, string>> = {
  tinto: 'Tinto',
  blanco: 'Blanco',
  rosado: 'Rosado',
};

/** "Malbec", o "Corte de Malbec, Cabernet Sauvignon y Tannat". */
export function describirUvas(p: Pick<ProductoPublicado, 'varietales' | 'esCorte'>): string {
  return p.esCorte ? `Corte de ${listaY(p.varietales)}` : (p.varietales[0] ?? '');
}

/**
 * La unidad de venta, al lado del precio. TODAS las tarjetas la dicen, no sólo
 * la caja: si la caja fuera la única con aclaración, se leería como oferta.
 */
export function unidadDeVenta(p: Pick<ProductoPublicado, 'botellas'>): string {
  return p.botellas > 1 ? `la caja de ${p.botellas} botellas` : 'la botella';
}

export function presentacion(p: Pick<ProductoPublicado, 'botellas' | 'volumenMl'>): string {
  return p.botellas > 1
    ? `Caja de ${p.botellas} botellas de ${p.volumenMl} ml. Viene sólo así.`
    : `Una botella de ${p.volumenMl} ml`;
}
