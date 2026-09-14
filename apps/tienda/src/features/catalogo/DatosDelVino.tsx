import type { ProductoPublicado } from '@bouquet/contratos';

import { describirUvas, TEXTOS } from './textos';

/* La línea de datos: bodega · uvas y añada · región. En versalitas, que es lo
 * que hace una etiqueta de vino (direccion.md §4.4). Los separadores los pone
 * el CSS, así un dato que falte no deja un punto huérfano. */

type Props = {
  producto: Pick<ProductoPublicado, 'bodega' | 'varietales' | 'esCorte' | 'anada' | 'region'>;
  className?: string;
};

export function DatosDelVino({ producto, className }: Props) {
  const clases = ['vino-datos', 'versalita', className].filter(Boolean).join(' ');
  return (
    <p className={clases}>
      <span>{producto.bodega}</span>
      <span>
        {describirUvas(producto)} {producto.anada ?? TEXTOS.sinAnada}
      </span>
      <span>{producto.region}</span>
    </p>
  );
}
