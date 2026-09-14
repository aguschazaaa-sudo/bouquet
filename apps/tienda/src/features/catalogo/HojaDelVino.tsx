import { Fragment } from 'react';
import type { ProductoPublicado } from '@bouquet/contratos';

import { COLOR_SINGULAR, listarUvas, presentacion, TEXTOS } from './textos';

/* La hoja de datos de la ficha: lo que dice la contraetiqueta, en papel.
 * specs/vidriera-ficha pide nombre, bodega, varietales, añada, región y
 * presentación; el nombre va en el título y el precio en el mostrador. */

type Props = {
  producto: ProductoPublicado;
};

export function HojaDelVino({ producto }: Props) {
  const filas: [string, string][] = [
    [TEXTOS.filas.bodega, producto.bodega],
    [producto.esCorte ? TEXTOS.filas.corte : TEXTOS.filas.cepa, listarUvas(producto)],
    [TEXTOS.filas.anada, producto.anada === null ? TEXTOS.sinAnada : String(producto.anada)],
    [TEXTOS.filas.region, producto.region],
    [TEXTOS.filas.color, COLOR_SINGULAR[producto.color]],
    [TEXTOS.filas.organico, producto.organico ? TEXTOS.si : TEXTOS.no],
    [TEXTOS.filas.presentacion, presentacion(producto)],
  ];

  return (
    <div className="hoja-vino">
      <h2 className="rotulo">{TEXTOS.hoja}</h2>
      <dl className="hoja-vino__datos">
        {filas.map(([titulo, dato]) => (
          <Fragment key={titulo}>
            <dt className="versalita">{titulo}</dt>
            <dd>{dato}</dd>
          </Fragment>
        ))}
      </dl>
    </div>
  );
}
