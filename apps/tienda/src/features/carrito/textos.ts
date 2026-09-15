/* Las cadenas de carrito/, juntas, para que `voz` las cure sin abrir un
 * componente. El carrito vacío es literal de voz.md §9.4. */

const botellas = (n: number) => `${n} ${n === 1 ? 'botella' : 'botellas'}`;

export const TEXTOS = {
  agregar: 'Agregar',
  agregarAlCarrito: 'Agregar al carrito',
  agregarLaCaja: 'Agregar la caja',
  sacar: 'Sacar del carrito',
  unaMenos: (cosa: string) => `Una ${cosa} menos`,
  unaMas: (cosa: string) => `Una ${cosa} más`,
  cantidadDe: (nombre: string) => `Cantidad de ${nombre}`,
  enTuPedido: 'Está en tu pedido.',
  alTope: 'Está en tu pedido, y no se puede sumar más.',
  verElCarrito: 'Ver el carrito',
  quedoEnTuPedido: (nombre: string) => `${nombre} quedó en tu pedido.`,
  enElPedido: 'en tu pedido',
  titulo: 'Tu pedido',
  vacio: 'No hay nada acá todavía.',
  verLosVinos: 'Ver los vinos',
  quitar: 'Quitar',
  noSuma: 'No suma al total',
  ajustada: 'Había más de lo que se puede llevar por pedido. Te lo dejamos en el máximo.',
  yaNoEsta: 'Un vino que ya no está a la venta',
  total: 'Total',
  botellas,
  noSumanFuera: (n: number) =>
    n === 1 ? 'Un vino del pedido no suma: ya no se puede llevar.' : `${n} vinos del pedido no suman: ya no se pueden llevar.`,
  seguir: 'Seguir viendo vinos',
  laCaja: (n: number) => `la caja de ${botellas(n)}`,
  laBotella: 'la botella',

  // --- la venta por caja ---
  avance: (hay: number, meta: number) => `${hay} de ${meta}`,
  avanceLargo: (hay: number, meta: number) => `${botellas(hay)} de ${meta} en tu pedido`,
  cajaCompleta: 'La caja está completa.',
  cajasCompletas: (n: number) => `Tenés ${n} cajas completas.`,
  faltan: (n: number) =>
    n === 1 ? 'Falta una botella para cerrar la caja.' : `Faltan ${n} botellas para cerrar la caja.`,
  sobran: (n: number) =>
    n === 1 ? 'Sobra una botella. La podés sacar y la caja cierra.' : `Sobran ${n} botellas. Las podés sacar y la caja cierra.`,
} as const;
