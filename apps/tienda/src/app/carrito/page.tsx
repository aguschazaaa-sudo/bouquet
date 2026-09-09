import type { Metadata } from 'next';

import { PaginaEnObra } from '@/shared/ui/PaginaEnObra';

/* /carrito — el carrito vacío.
 *
 * ⚠️ Esto NO es un placeholder como las otras tres: es el estado vacío REAL, y
 * va a seguir siéndolo cuando el carrito funcione. El texto no lo escribí yo,
 * está curado en voz.md §9.4 y se copia literal:
 *
 *   > No hay nada acá todavía.
 *   > `Ver los vinos`
 *
 * Con su razón al lado, que es la que hay que respetar cuando alguien quiera
 * "mejorarlo": *"un carrito vacío no es el momento de ser encantador — es el
 * momento de dar la salida"*. Por eso no lleva cuerpo.
 *
 * El carrito vive en `localStorage` y no hay colección `carritos` (ADR 004 y
 * ARQUITECTURA §4.4), así que cuando esta página lea de verdad va a leer del
 * navegador: cero lecturas de Firestore, hoy y después.
 */

export const metadata: Metadata = {
  title: 'Tu pedido — bouquet',
  /* `robots: noindex` porque un carrito es de una persona, no del buscador. */
  robots: { index: false, follow: true },
};

export default function Carrito() {
  return (
    <PaginaEnObra
      rotulo="Tu pedido"
      titulo="No hay nada acá todavía."
      salida={{ href: '/vinos', texto: 'Ver los vinos' }}
    />
  );
}
