import type { ReactNode } from 'react';
import type { CajaSugeridaResuelta } from '@bouquet/contratos';

import { TarjetaDeCajaSugerida } from './TarjetaDeCajaSugerida';
import { TEXTOS } from './textos';

/* El carril de cajas armadas, arriba de la grilla: las cajas sobre el
 * mostrador y las botellas en el estante.
 *
 * NO responde a los filtros. Los filtros son de botellas —color, cepa,
 * orgánico—, y una caja es múltiple en los tres: decir que una caja "es
 * blanca" sería mentira. Se quedan donde están, que es lo que hace una casa de
 * vinos con la caja que ya armó.
 *
 * Si no hay ninguna caja válida no se renderiza NADA: un carril vacío con su
 * título arriba es peor que no tenerlo. */

type Props = {
  cajas: readonly CajaSugeridaResuelta[];
  controles: Readonly<Record<string, ReactNode>>;
};

export function CarrilDeCajas({ cajas, controles }: Props) {
  if (cajas.length === 0) return null;

  return (
    <section className="carril" aria-labelledby="carril-titulo">
      <div className="carril__encabezado">
        <h2 className="carril__titulo versalita" id="carril-titulo">
          {TEXTOS.cajasTitulo}
        </h2>
        <p className="carril__bajada">{TEXTOS.cajasBajada}</p>
      </div>
      <ul className="carril__pista">
        {cajas.map((caja) => (
          <TarjetaDeCajaSugerida key={caja.slug} caja={caja} control={controles[caja.slug]} />
        ))}
      </ul>
    </section>
  );
}
