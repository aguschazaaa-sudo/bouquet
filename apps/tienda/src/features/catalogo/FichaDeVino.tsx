import Link from 'next/link';
import type { ReactNode } from 'react';
import type { ProductoPublicado } from '@bouquet/contratos';

import { Precio } from '@/shared/ui/Precio';

import { DatosDelVino } from './DatosDelVino';
import { EstadoDelVino } from './EstadoDelVino';
import { HojaDelVino } from './HojaDelVino';
import { ReglaDeLaCaja } from './ReglaDeLaCaja';
import { COLOR_SINGULAR, TEXTOS, unidadDeVenta } from './textos';
import { VentanaDeBotella } from './VentanaDeBotella';

/* La ficha: el vino se presenta a media luz, y sus datos y su precio en claro
 * (direccion.md §3). Sale de la misma proyección que /vinos, sin una lectura
 * más (specs/vidriera-ficha).
 *
 * El mostrador —precio, balde y el control de compra— va pegado al borde de
 * abajo en el teléfono y encaja en su lugar al llegar. El control es de
 * `carrito/` y llega armado desde `app/` (design.md §9). Si se agotó, no hay
 * control: el balde ya dice "Se agotó". */

type Props = {
  producto: ProductoPublicado;
  control?: ReactNode;
};

export function FichaDeVino({ producto, control }: Props) {
  const agotado = producto.balde === 'agotado';

  return (
    <article className="ficha">
      <section className="ficha__cava">
        <div className="contenedor-vinos">
          <Link className="ficha__volver enlace-blando" href="/vinos">
            {TEXTOS.volver}
          </Link>
          <div className="ficha__heroe">
            <VentanaDeBotella producto={producto} tamano="ficha" prioridad />
            <div>
              <h1 className="ficha__nombre display">{producto.nombre}</h1>
              <DatosDelVino producto={producto} />
              <p className="ficha__marcas versalita">
                <span>{COLOR_SINGULAR[producto.color]}</span>
                {producto.organico ? <span>{TEXTOS.organico}</span> : null}
                {producto.botellas > 1 ? <span>{TEXTOS.cajaDe(producto.botellas)}</span> : null}
              </p>
            </div>
          </div>
        </div>
      </section>

      <section className="ficha__mostrador papel" aria-label={TEXTOS.precioYCompra}>
        <div className="contenedor-vinos ficha__fila">
          <div className="ficha__precio">
            <Precio centavos={producto.precio} className="ficha__monto" />
            <span className="ficha__unidad versalita">{unidadDeVenta(producto)}</span>
            <EstadoDelVino producto={producto} />
          </div>
          {/* La regla va ENTRE el precio y el control, no debajo de los dos:
              es la condición bajo la cual ese precio se puede pagar, y el
              lugar donde se lee es el camino del ojo del monto al botón.
              Enterarse de que el vino va de a seis después de agregar es
              enterarse tarde.

              Le pasa las botellas porque la regla NO es la misma para los dos:
              un vino que trae su caja viaja solo, y la placa lo dice así en vez
              de pedirle al comprador que complete algo que no le toca. */}
          <ReglaDeLaCaja variante="franja" botellas={producto.botellas} />
          {agotado ? null : control}
        </div>
      </section>

      <section className="ficha__papel papel">
        <div className="contenedor-vinos ficha__grilla">
          <HojaDelVino producto={producto} />
          <div>
            <h2 className="rotulo">{TEXTOS.custodiaTitulo}</h2>
            <p className="ficha__custodia">{TEXTOS.custodia}</p>
          </div>
        </div>
      </section>
    </article>
  );
}
