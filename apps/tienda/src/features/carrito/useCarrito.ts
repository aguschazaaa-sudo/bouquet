import { useSyncExternalStore } from 'react';
import type { Carrito } from '@bouquet/contratos';

import { CARRITO_DEL_SERVIDOR, carritoActual, suscribir } from './almacen';

/* El carrito como estado de React. En el servidor y durante la hidratación
 * vale vacío; después, lo que diga localStorage. Así el HTML del servidor y el
 * primer render del navegador coinciden. */
export function useCarrito(): Carrito {
  return useSyncExternalStore(suscribir, carritoActual, () => CARRITO_DEL_SERVIDOR);
}

const nada = () => () => {};

/** false en el servidor y en la hidratación; true después. */
export function useHidratado(): boolean {
  return useSyncExternalStore(
    nada,
    () => true,
    () => false,
  );
}
