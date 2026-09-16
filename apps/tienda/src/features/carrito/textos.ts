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
  terminar: 'Terminar la compra',
  laCaja: (n: number) => `la caja de ${botellas(n)}`,
  laBotella: 'la botella',

  // --- la venta por caja ---
  avance: (hay: number, meta: number) => `${hay} de ${meta}`,
  avanceLargo: (hay: number, meta: number) => `${botellas(hay)} sueltas de ${meta} en tu pedido`,
  botellasEnTuPedido: (n: number) => `${botellas(n)} en tu pedido`,
  /* Lo que dice la barra cuando no falta nada que completar: incluye el pedido
   * que es sólo una caja cerrada, donde no hay ninguna caja armándose. */
  listoParaViajar: 'Listo para viajar.',
  /* Para un vino que trae su propia caja, en su línea del pedido. Contesta la
   * pregunta que deja el contador: por qué estas botellas no suman a las seis
   * (ADR 009 §10). */
  viajaSola: 'Viaja sola: no cuenta para las seis.',
  cajaCompleta: 'La caja está completa.',
  cajasCompletas: (n: number) => `Tenés ${n} cajas completas.`,
  /* ⚠️ `sueltas` se prende SÓLO si el pedido tiene algo que viaja solo, y se vio
   * mirando la captura: con 4 sueltas y una caja de 2, la pantalla dice `4 de 6`
   * arriba y `6 botellas` en el total. Las dos son ciertas y juntas se leen como
   * un error. La palabra desambigua sin agregar un renglón. Cuando no hay packs
   * no se dice: ahí "botella" ya significa suelta y "suelta" sería ruido. */
  faltan: (n: number, sueltas = false) =>
    n === 1
      ? `Falta una botella${sueltas ? ' suelta' : ''} para cerrar la caja.`
      : `Faltan ${n} botellas${sueltas ? ' sueltas' : ''} para cerrar la caja.`,
  sobran: (n: number, sueltas = false) =>
    n === 1
      ? `Sobra una botella${sueltas ? ' suelta' : ''}. La podés sacar y la caja cierra.`
      : `Sobran ${n} botellas${sueltas ? ' sueltas' : ''}. Las podés sacar y la caja cierra.`,
} as const;
