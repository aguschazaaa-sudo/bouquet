import type { Orden } from './filtros';
import { TEXTOS } from './textos';

/* El orden. Sin métricas, la popularidad no está en la lista (la decide quien
 * lo arma, con `ordenesDisponibles`). */

type Props = {
  ordenes: readonly Orden[];
  orden: Orden;
  alCambiar: (orden: Orden) => void;
};

export function SelectorDeOrden({ ordenes, orden, alCambiar }: Props) {
  return (
    <div className="orden-vinos">
      <label className="orden-vinos__rotulo versalita" htmlFor="orden-vinos">
        {TEXTOS.orden}
      </label>
      <select
        id="orden-vinos"
        className="orden-vinos__select versalita"
        value={orden}
        onChange={(e) => alCambiar(e.target.value as Orden)}
      >
        {ordenes.map((o) => (
          <option key={o} value={o}>
            {TEXTOS.ordenes[o]}
          </option>
        ))}
      </select>
    </div>
  );
}
