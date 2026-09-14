'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import type { ReactNode } from 'react';

import { CarritoSvg } from './CarritoSvg';
import { CARRITO } from './secciones';

/* El enlace al carrito: separado de EnlaceDeSeccion porque es el único que
 * lleva ícono, y sólo él.
 *
 * POR QUÉ. En 320-375px la fila entera no entraba, y lo que cedía era la
 * copa de la marca —`.barra__marca` tiene `min-width: 0` a propósito para que
 * el wordmark colapse con el scroll, y ese mismo `min-width: 0` dejaba que
 * flexbox comprimiera TODA la marca, copa incluida, cuando faltaba espacio.
 * Medido por CDP a 325px: la copa (14px) quedaba en 3,97px; a 320px, en 0.
 *
 * El arreglo tiene dos partes. `.barra__marca` pasa a `flex-shrink: 0` —la
 * marca no se comprime más, nunca— y ésta achica lo que sí puede achicarse:
 * "CARRITO" era el bloque más grande de la fila (~68px de los ~319px que
 * pedía todo el cartucho). Bajo 480px —el mismo corte donde ya se esconde
 * "bouquet"— el texto se oculta VISUALMENTE y el ícono queda solo.
 *
 * ⚠️ "Visualmente" y no `display: none`. El wordmark de la marca sí usa
 * `display: none` en ese corte, y eso le saca el nombre accesible al enlace
 * completo —la Copa ya es `aria-hidden`—. Acá el texto sigue en el DOM y lo
 * lee un lector de pantalla; sólo se recorta a 1px con la técnica sr-only
 * (`.barra__texto-carrito` en navegacion.css). El carrito es el paso antes de
 * pagar: un enlace sin nombre ahí es peor que uno sin nombre a "/".
 */

type Props = {
  /** El contador del carrito, como slot (ver BarraPrincipal). */
  contador?: ReactNode;
};

export function EnlaceCarrito({ contador }: Props) {
  const ruta = usePathname();
  const activa = ruta === CARRITO.href || ruta.startsWith(`${CARRITO.href}/`);

  return (
    <Link
      className="barra__enlace barra__enlace--carrito versalita"
      href={CARRITO.href}
      aria-current={activa ? 'page' : undefined}
    >
      <CarritoSvg className="barra__icono-carrito" />
      <span className="barra__texto-carrito">{CARRITO.nombre}</span>
      {contador}
    </Link>
  );
}
