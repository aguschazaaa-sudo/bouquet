import { textoDelBalde, type ProductoPublicado } from '@bouquet/contratos';

import { TEXTOS } from './textos';

/* El balde y la marca de orgánico. voz.md §9.2: `disponible` no dice nada —un
 * cartel en todos lados enseña que los carteles no significan nada—, y ningún
 * texto afirma cuántas quedan. El texto sale de contratos, junto al cálculo. */

type Props = {
  producto: Pick<ProductoPublicado, 'balde' | 'organico'>;
};

export function EstadoDelVino({ producto }: Props) {
  const balde = textoDelBalde(producto.balde);
  return (
    <p className="vino-estado">
      {balde ? <span className={`vino-estado__balde vino-estado__balde--${producto.balde}`}>{balde}</span> : null}
      {producto.organico ? <span className="vino-estado__organico">{TEXTOS.organico}</span> : null}
    </p>
  );
}
