import { useEffect, useRef } from 'react';
import type { ProductoPublicado } from '@bouquet/contratos';

import { claveDeCepa, CORTE, filtrar, type EstadoDelListado } from './filtros';
import { OpcionDeFiltro } from './OpcionDeFiltro';
import { TEXTOS } from './textos';
import { useAnchoGrande } from './useAnchoGrande';

/* Cepa, corte y orgánico. En el teléfono es una hoja que sube desde la barra
 * del pulgar; desde 1100 px, una columna fija (design.md §9). Cerrada en
 * angosto queda `inert`: fuera de pantalla y fuera del orden del teclado. */

type Props = {
  productos: readonly ProductoPublicado[];
  cepas: readonly string[];
  hayCortes: boolean;
  estado: EstadoDelListado;
  abierto: boolean;
  cantidad: number;
  alCambiar: (cambio: Partial<EstadoDelListado>) => void;
  alCerrar: () => void;
};

const aId = (texto: string) =>
  texto.normalize('NFD').replace(/[̀-ͯ]/g, '').toLowerCase().replace(/[^a-z0-9]+/g, '-');

export function PanelDeFiltros({ productos, cepas, hayCortes, estado, abierto, cantidad, alCambiar, alCerrar }: Props) {
  const ancho = useAnchoGrande();
  const panel = useRef<HTMLElement>(null);
  const comoHoja = abierto && !ancho;

  useEffect(() => {
    if (!comoHoja) return;
    panel.current?.querySelector('input')?.focus({ preventScroll: true });
    const alTeclear = (e: KeyboardEvent) => {
      if (e.key === 'Escape') alCerrar();
    };
    window.addEventListener('keydown', alTeclear);
    return () => window.removeEventListener('keydown', alTeclear);
  }, [comoHoja, alCerrar]);

  // Cuántos quedarían con cada uva, con el resto de los filtros puestos.
  const sinCepa = filtrar(productos, { ...estado, cepas: [] });
  const cuantos = (clave: string) => sinCepa.filter((p) => claveDeCepa(p) === clave).length;
  const alternar = (clave: string) =>
    alCambiar({
      cepas: estado.cepas.includes(clave) ? estado.cepas.filter((c) => c !== clave) : [...estado.cepas, clave],
    });
  const hayFiltros = estado.cepas.length > 0 || estado.organico || estado.color !== 'todos';

  return (
    <>
      <div
        className={`panel-filtros__velo${comoHoja ? ' panel-filtros__velo--visible' : ''}`}
        onClick={alCerrar}
        aria-hidden="true"
      />
      <aside
        ref={panel}
        id="panel-filtros"
        className={`panel-filtros${abierto ? ' panel-filtros--abierto' : ''}`}
        aria-labelledby="titulo-filtros"
        inert={!ancho && !abierto}
      >
        <div className="panel-filtros__cabeza">
          <h2 className="display" id="titulo-filtros">
            {TEXTOS.filtros}
          </h2>
          <button type="button" className="panel-filtros__cerrar versalita" onClick={alCerrar}>
            {TEXTOS.cerrar}
          </button>
        </div>

        <fieldset className="panel-filtros__grupo">
          <legend className="rotulo">{TEXTOS.cepa}</legend>
          {cepas.map((c) => (
            <OpcionDeFiltro
              key={c}
              id={`cepa-${aId(c)}`}
              texto={c}
              cantidad={cuantos(c)}
              marcada={estado.cepas.includes(c)}
              alCambiar={() => alternar(c)}
            />
          ))}
        </fieldset>

        {hayCortes ? (
          <fieldset className="panel-filtros__grupo">
            <legend className="rotulo">{TEXTOS.cortes}</legend>
            <p className="panel-filtros__nota">{TEXTOS.notaCortes}</p>
            <OpcionDeFiltro
              id="cepa-cortes"
              texto={TEXTOS.cortes}
              cantidad={cuantos(CORTE)}
              marcada={estado.cepas.includes(CORTE)}
              alCambiar={() => alternar(CORTE)}
            />
          </fieldset>
        ) : null}

        <fieldset className="panel-filtros__grupo">
          <legend className="rotulo">{TEXTOS.organico}</legend>
          <OpcionDeFiltro
            id="filtro-organico"
            texto={TEXTOS.soloOrganicos}
            cantidad={filtrar(productos, { ...estado, organico: true }).length}
            marcada={estado.organico}
            alCambiar={() => alCambiar({ organico: !estado.organico })}
          />
        </fieldset>

        <div className="panel-filtros__pie">
          {hayFiltros ? (
            <button
              type="button"
              className="panel-filtros__limpiar versalita"
              onClick={() => alCambiar({ color: 'todos', cepas: [], organico: false })}
            >
              {TEXTOS.quitarFiltros}
            </button>
          ) : (
            <span />
          )}
          <button type="button" className="boton panel-filtros__ver" onClick={alCerrar}>
            <span>{TEXTOS.verLosVinos(cantidad)}</span>
          </button>
        </div>
      </aside>
    </>
  );
}
