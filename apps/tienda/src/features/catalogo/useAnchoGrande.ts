import { useSyncExternalStore } from 'react';

/* Desde 1100 px los filtros son una columna fija; debajo, una hoja que sube
 * desde el pulgar. El corte es el mismo que en catalogo.css. En el servidor no
 * hay ancho, así que arranca en angosto y se corrige al hidratar. */

const CONSULTA = '(min-width: 1100px)';

function suscribir(avisar: () => void) {
  const medio = window.matchMedia(CONSULTA);
  medio.addEventListener('change', avisar);
  return () => medio.removeEventListener('change', avisar);
}

export function useAnchoGrande(): boolean {
  return useSyncExternalStore(
    suscribir,
    () => window.matchMedia(CONSULTA).matches,
    () => false,
  );
}
