import type { ReactNode } from 'react';
import { sumar, type CajaSugeridaResuelta, type Centavos } from '@bouquet/contratos';

import { Precio } from '@/shared/ui/Precio';

import { TEXTOS } from './textos';

/* Una caja que ofrece el vendedor: seis vinos elegidos, para no empezar de
 * cero. NO es un producto —no tiene precio propio ni stock propio—: el precio
 * es la suma de lo que trae, y tocarla LLENA EL CARRITO. Desde ahí se cambia
 * como cualquier línea.
 *
 * El botón no es de esta feature: es de `carrito/` y llega armado desde
 * `app/vinos/page.tsx`, igual que el control de la tarjeta de vino (ADR 006). */

type Props = {
  caja: CajaSugeridaResuelta;
  control?: ReactNode;
};

export function TarjetaDeCajaSugerida({ caja, control }: Props) {
  // Sólo lo que hoy se puede llevar: un lugar caído no tiene precio que sumar.
  const precio: Centavos = sumar(...caja.lugares.filter((l) => l.estado === 'vigente').map((l) => l.producto!.precio));

  return (
    // Lo que la caja no tiene lo dice el aviso de abajo, con palabras. No hay
    // modificador: una clase sin regla no se ve y no falla, que es peor.
    <li className="caja-sugerida">
      <h3 className="caja-sugerida__nombre display">{caja.nombre}</h3>
      {/* Lo dice la tarjeta porque la lista no alcanza: `Dos y dos` son cuatro
          renglones y SEIS botellas, y eso es justo lo que hay que entender.

          ⚠️ Va `botellasVigentes` y NO el tamaño de la caja: con un vino caído
          el precio es el de cinco, y un rótulo fijo de "6 botellas" se
          contradiría con el precio en la misma tarjeta. El número y la plata
          dicen lo mismo, y el aviso de abajo explica por qué. */}
      <p className="caja-sugerida__cuantas versalita">{TEXTOS.cuantasBotellas(caja.botellasVigentes)}</p>

      <ul className="caja-sugerida__vinos">
        {caja.lugares.map((lugar, i) => (
          <li
            key={`${lugar.productoId}-${i}`}
            className={`caja-sugerida__vino${lugar.estado === 'vigente' ? '' : ' caja-sugerida__vino--fuera'}`}
          >
            <span className="caja-sugerida__titulo">{lugar.producto?.nombre ?? TEXTOS.lugarSinVino}</span>
            {lugar.producto && lugar.producto.botellas > 1 ? (
              <span className="caja-sugerida__multiplo cifra">×{lugar.producto.botellas}</span>
            ) : null}
            {lugar.estado === 'agotado' || lugar.estado === 'sin-suficiente' ? (
              <span className="caja-sugerida__nota">
                {lugar.estado === 'agotado' ? TEXTOS.lugarAgotado : TEXTOS.lugarSinSuficiente}
              </span>
            ) : null}
          </li>
        ))}
      </ul>

      <div className="caja-sugerida__mostrador">
        {caja.completa ? null : <p className="caja-sugerida__aviso">{TEXTOS.cajaIncompleta}</p>}
        <p className="caja-sugerida__precio">
          <Precio centavos={precio} className="caja-sugerida__monto" />
        </p>
        {control}
      </div>
    </li>
  );
}
