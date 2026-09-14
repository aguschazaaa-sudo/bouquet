import Link from 'next/link';
import type { ReactNode } from 'react';
import type { ProductoPublicado } from '@bouquet/contratos';

import { Precio } from '@/shared/ui/Precio';

import { DatosDelVino } from './DatosDelVino';
import { EstadoDelVino } from './EstadoDelVino';
import { unidadDeVenta } from './textos';
import { VentanaDeBotella } from './VentanaDeBotella';

/* La tarjeta: un retrato vertical, la botella casi entera y la tipografía
 * abajo (direccion.md §7.1). Sin card, sin sombra: la ventana y un filete.
 *
 * El control de compra NO es de esta feature: es de `carrito/` y llega armado
 * desde `app/vinos/page.tsx` (design.md §9). ADR 006 prohíbe que una feature
 * importe a otra, y una tarjeta que supiera de localStorage sería el catálogo
 * con el carrito adentro. */

type Props = {
  producto: ProductoPublicado;
  control?: ReactNode;
  prioridad?: boolean;
};

export function TarjetaDeVino({ producto, control, prioridad = false }: Props) {
  const agotado = producto.balde === 'agotado';

  return (
    <li className={`vino${agotado ? ' vino--agotado' : ''}`}>
      <Link className="vino__enlace" href={`/vinos/${producto.slug}`}>
        <VentanaDeBotella producto={producto} decorativa prioridad={prioridad} />
        <h2 className="vino__nombre display">{producto.nombre}</h2>
        <DatosDelVino producto={producto} />
      </Link>
      <div className="vino__mostrador">
        <EstadoDelVino producto={producto} />
        <div className="vino__renglon">
          <p className="vino__precio">
            <Precio centavos={producto.precio} className="vino__monto" />
            <span className="vino__unidad versalita">{unidadDeVenta(producto)}</span>
          </p>
          {agotado ? null : control}
        </div>
      </div>
    </li>
  );
}
