/* Las secciones de la vidriera, en el orden en que se leen.
 *
 * Son SUSTANTIVOS y son tres. Dos razones, y ninguna es estética:
 *
 * 1. voz.md §7.3 — el cliente lee "el vino", nunca "Producto". Y aunque §5
 *    manda voseo, un imperativo suelto ("Escribinos") adentro de una lista de
 *    sustantivos se lee como un botón perdido entre etiquetas. La voz de la
 *    marca vive en el cuerpo de cada página; la navegación es señalética.
 * 2. direccion.md §6 — "palabras, no íconos". Por eso el carrito dice
 *    `Carrito` y no dibuja un changuito: un changuito es la palabra de un
 *    supermercado, que es exactamente lo que §10 de voz.md prohíbe parecer.
 *
 * `Custodia` está en el léxico interno de voz.md §7.2, así que no es una
 * palabra inventada para la navegación: es la que ya usa el resto del sitio.
 */

export type Seccion = {
  /** La ruta. Tiene que existir un `app/<...>/page.tsx` que la sirva. */
  href: string;
  /** Lo que se lee en la barra. */
  nombre: string;
};

export const SECCIONES: readonly Seccion[] = [
  { href: '/vinos', nombre: 'Vinos' },
  { href: '/custodia', nombre: 'Custodia' },
  { href: '/contacto', nombre: 'Contacto' },
];

/* El carrito va aparte y a la derecha: no es una sección del catálogo, es el
 * estado del comprador. Mezclarlo en la lista lo convierte en "una página
 * más" justo cuando es la única que tiene su plata adentro. */
export const CARRITO: Seccion = { href: '/carrito', nombre: 'Carrito' };
