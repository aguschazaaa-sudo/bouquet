import type { ProductoPublicado } from '@bouquet/contratos';

import { filtrar, type EstadoDelListado } from './filtros';
import { TEXTOS } from './textos';

/* Cuando una combinación no deja ningún vino: decir qué filtro sobra, con
 * cuántos vinos aparecen si se saca, y ofrecer quitarlos todos
 * (specs/vidriera-catalogo, "Sin resultados"). */

type Props = {
  productos: readonly ProductoPublicado[];
  estado: EstadoDelListado;
  alCambiar: (cambio: Partial<EstadoDelListado>) => void;
};

type Salida = { clave: string; texto: string; cambio: Partial<EstadoDelListado>; cuantos: number };

export function SinResultados({ productos, estado, alCambiar }: Props) {
  const candidatas: Omit<Salida, 'cuantos'>[] = [];
  if (estado.color !== 'todos') candidatas.push({ clave: 'color', texto: TEXTOS.relajar.color, cambio: { color: 'todos' } });
  if (estado.cepas.length) candidatas.push({ clave: 'cepa', texto: TEXTOS.relajar.cepa, cambio: { cepas: [] } });
  if (estado.organico) candidatas.push({ clave: 'organico', texto: TEXTOS.relajar.organico, cambio: { organico: false } });
  const salidas: Salida[] = candidatas
    .map((c) => ({ ...c, cuantos: filtrar(productos, { ...estado, ...c.cambio }).length }))
    .filter((s) => s.cuantos > 0);

  return (
    <div className="sin-resultados">
      <h2 className="display">{TEXTOS.sinResultados}</h2>
      {salidas.length ? <p className="prosa">{TEXTOS.sacandoUno}</p> : null}
      <ul className="sin-resultados__salidas">
        {salidas.map((s) => (
          <li key={s.clave}>
            <button type="button" className="enlace-blando" onClick={() => alCambiar(s.cambio)}>
              {s.texto} · <span className="cifra">{TEXTOS.cuantos(s.cuantos)}</span>
            </button>
          </li>
        ))}
      </ul>
      <button type="button" className="boton" onClick={() => alCambiar({ color: 'todos', cepas: [], organico: false })}>
        <span>{TEXTOS.quitarFiltros}</span>
      </button>
    </div>
  );
}
