import type { Orden } from './filtros';
import { SelectorDeOrden } from './SelectorDeOrden';
import { TEXTOS } from './textos';

/* La barra del mostrador. En el teléfono vive abajo, al alcance del pulgar:
 * filtros, cuántos vinos hay y el orden. Desde 1100 px se vuelve la cabeza de
 * la grilla y el botón de filtros se va, porque el panel ya está a la vista. */

type Props = {
  cantidad: number;
  activos: number;
  abierto: boolean;
  ordenes: readonly Orden[];
  orden: Orden;
  alOrdenar: (orden: Orden) => void;
  alAbrirFiltros: () => void;
};

export function BarraDelPulgar({ cantidad, activos, abierto, ordenes, orden, alOrdenar, alAbrirFiltros }: Props) {
  return (
    <div className="barra-pulgar">
      <button
        type="button"
        className="barra-pulgar__filtros versalita"
        aria-controls="panel-filtros"
        aria-expanded={abierto}
        onClick={alAbrirFiltros}
      >
        {TEXTOS.filtros}
        {activos ? <span className="cifra">{activos}</span> : null}
      </button>
      <p className="barra-pulgar__cuenta" aria-live="polite">
        <span className="cifra">{cantidad}</span> {TEXTOS.cuenta(cantidad)}
      </p>
      <SelectorDeOrden ordenes={ordenes} orden={orden} alCambiar={alOrdenar} />
    </div>
  );
}
