/* La última cosa que pasó en el carrito, para la línea de aviso del listado.
 * Un almacén mínimo, fuera de React, para que el control de cualquier tarjeta
 * pueda avisar sin que el listado sepa que existe un carrito. */

export type Aviso = { readonly id: number; readonly texto: string };

let ultimo: Aviso | null = null;
let siguiente = 1;
const oyentes = new Set<() => void>();

export function avisar(texto: string) {
  ultimo = { id: siguiente++, texto };
  oyentes.forEach((o) => o());
}

export const avisoActual = () => ultimo;

export function suscribirAviso(oyente: () => void) {
  oyentes.add(oyente);
  return () => {
    oyentes.delete(oyente);
  };
}
