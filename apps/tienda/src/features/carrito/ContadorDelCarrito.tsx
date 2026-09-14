'use client';

import { unidadesEnCarrito } from '@bouquet/contratos';

import { TEXTOS } from './textos';
import { useCarrito } from './useCarrito';

/* El número de la barra: la suma de las cantidades, leída de localStorage.
 * Vive en el layout, o sea en TODAS las rutas y en todas las visitas, y por eso
 * no lee Firestore (ADR 006, presupuesto de lecturas: 0). Llega a la barra como
 * slot desde `app/layout.tsx`: navegacion/ no sabe que existe un carrito. */

export function ContadorDelCarrito() {
  const n = unidadesEnCarrito(useCarrito());
  if (n === 0) return null;
  return (
    <span className="contador-carrito cifra">
      {n}
      <span className="sr"> {TEXTOS.enElPedido}</span>
    </span>
  );
}
