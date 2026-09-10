/* Las secciones de la vidriera, en el orden en que se leen.
 *
 * Son SUSTANTIVOS y son DOS. Dos razones, y ninguna es estética:
 *
 * 1. voz.md §7.3 — el cliente lee "el vino", nunca "Producto". Y aunque §5
 *    manda voseo, un imperativo suelto ("Escribinos") adentro de una lista de
 *    sustantivos se lee como un botón perdido entre etiquetas. La voz de la
 *    marca vive en el cuerpo de cada página; la navegación es señalética.
 * 2. direccion.md §6 — "palabras, no íconos". Por eso el carrito dice
 *    `Carrito` y no dibuja un changuito: un changuito es la palabra de un
 *    supermercado, que es exactamente lo que §10 de voz.md prohíbe parecer.
 *
 * ⚠️ ERAN TRES Y AHORA SON DOS, y las dos que se fueron se fueron por motivos
 * distintos:
 *
 *   `Custodia` → nombraba sólo UN tramo del oficio —el del medio— mientras la
 *   sección terminó cubriendo los tres: elegir, guardar y abrir. La palabra
 *   sigue viva en el léxico de voz.md §7.2 y como nombre del tramo `II` adentro
 *   de `/oficio`; lo que desapareció es su uso como rótulo de navegación.
 *
 *   `Contacto` → no se fue, se PLEGÓ. El arco de la página termina en quién es
 *   "nosotros", y ése es el contenido de contacto: vive como cierre de
 *   `/oficio`, en `#mostrador`. La URL vieja sobrevive redirigiendo (308), que
 *   está declarado en `next.config.ts`, porque los textos ya escritos en
 *   voz.md §9.3 y §9.5 mandan al lector a escribir y necesitan un destino.
 */

export type Seccion = {
  /** La ruta. Tiene que existir un `app/<...>/page.tsx` que la sirva. */
  href: string;
  /** Lo que se lee en la barra. */
  nombre: string;
};

export const SECCIONES: readonly Seccion[] = [
  { href: '/vinos', nombre: 'Vinos' },
  { href: '/oficio', nombre: 'El oficio' },
];

/* El carrito va aparte y a la derecha: no es una sección del catálogo, es el
 * estado del comprador. Mezclarlo en la lista lo convierte en "una página
 * más" justo cuando es la única que tiene su plata adentro. */
export const CARRITO: Seccion = { href: '/carrito', nombre: 'Carrito' };
