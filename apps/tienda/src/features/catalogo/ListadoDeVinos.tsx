'use client';

import { useCallback, useEffect, useMemo, useState, type ReactNode } from 'react';
import type { ProductoPublicado } from '@bouquet/contratos';

import { BarraDelPulgar } from './BarraDelPulgar';
import {
  cepasDelCatalogo,
  ESTADO_INICIAL,
  escribirEnLaUrl,
  filtrar,
  leerDeLaUrl,
  ordenar,
  ordenesDisponibles,
  type EstadoDelListado,
} from './filtros';
import { PanelDeFiltros } from './PanelDeFiltros';
import { PestanasDeColor } from './PestanasDeColor';
import { SinResultados } from './SinResultados';
import { TarjetaDeVino } from './TarjetaDeVino';

/* El listado: filtra y ordena en el navegador, sin un pedido de red (ADR 004
 * §3). El estado vive en la URL por `replaceState`.
 *
 * La página NO lee `searchParams`, a propósito: así hay una sola entrada de
 * caché para `/vinos` (design.md §2). El servidor pinta el estado por defecto y
 * la URL se aplica recién al hidratar. Una visita que llega con filtros ve un
 * instante la lista entera, y es el precio de no multiplicar la caché.
 *
 * Los controles de compra llegan armados desde `app/` (design.md §9): este
 * archivo no sabe que existe un carrito. */

type Props = {
  productos: readonly ProductoPublicado[];
  hayPopularidad: boolean;
  controles: Readonly<Record<string, ReactNode>>;
};

export function ListadoDeVinos({ productos, hayPopularidad, controles }: Props) {
  const cepas = useMemo(() => cepasDelCatalogo(productos), [productos]);
  const hayCortes = useMemo(() => productos.some((p) => p.esCorte), [productos]);
  const [estado, setEstado] = useState<EstadoDelListado>(ESTADO_INICIAL);
  const [abierto, setAbierto] = useState(false);

  useEffect(() => {
    setEstado(leerDeLaUrl(window.location.search, { cepas, hayCortes, hayPopularidad }));
  }, [cepas, hayCortes, hayPopularidad]);

  const cambiar = (cambio: Partial<EstadoDelListado>) => {
    const nuevo = { ...estado, ...cambio };
    setEstado(nuevo);
    window.history.replaceState(null, '', `${window.location.pathname}${escribirEnLaUrl(nuevo)}`);
  };
  const cerrar = useCallback(() => setAbierto(false), []);

  const visibles = useMemo(() => ordenar(filtrar(productos, estado), estado.orden), [productos, estado]);
  const activos = estado.cepas.length + (estado.organico ? 1 : 0);

  return (
    <div className="catalogo">
      <PestanasDeColor productos={productos} estado={estado} alCambiar={(color) => cambiar({ color })} />
      <div className="catalogo__cuerpo">
        <PanelDeFiltros
          productos={productos}
          cepas={cepas}
          hayCortes={hayCortes}
          estado={estado}
          abierto={abierto}
          cantidad={visibles.length}
          alCambiar={cambiar}
          alCerrar={cerrar}
        />
        <div className="catalogo__resultados">
          <BarraDelPulgar
            cantidad={visibles.length}
            activos={activos}
            abierto={abierto}
            ordenes={ordenesDisponibles(hayPopularidad)}
            orden={estado.orden}
            alOrdenar={(orden) => cambiar({ orden })}
            alAbrirFiltros={() => setAbierto(true)}
          />
          {visibles.length ? (
            <ul className="catalogo__grilla">
              {visibles.map((p, i) => (
                <TarjetaDeVino key={p.id} producto={p} control={controles[p.id]} prioridad={i < 3} />
              ))}
            </ul>
          ) : (
            <SinResultados productos={productos} estado={estado} alCambiar={cambiar} />
          )}
        </div>
      </div>
    </div>
  );
}
