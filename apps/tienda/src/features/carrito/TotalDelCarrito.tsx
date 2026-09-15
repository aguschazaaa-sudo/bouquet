import { botellasEnCarrito, type CarritoResuelto } from '@bouquet/contratos';

import { Precio } from '@/shared/ui/Precio';

import { TEXTOS } from './textos';

/* El total, en cifras tabulares. Sale de `resolverCarrito` —la plata de
 * contratos—, y sólo suman las líneas vigentes. */

type Props = {
  resuelto: CarritoResuelto;
};

export function TotalDelCarrito({ resuelto }: Props) {
  // La misma cuenta que la regla de la caja: repetirla acá fue el origen de
  // que hubiera dos. Vive en contratos, junto a `estadoDeLaCaja`.
  const botellas = botellasEnCarrito(resuelto);
  const fuera = resuelto.lineas.filter((l) => l.estado !== 'vigente').length;

  return (
    <div className="total-carrito">
      <p className="total-carrito__rotulo versalita">
        {TEXTOS.total}
        <small>{TEXTOS.botellas(botellas)}</small>
      </p>
      <p className="total-carrito__monto">
        <Precio centavos={resuelto.total} />
      </p>
      {fuera ? <p className="total-carrito__nota">{TEXTOS.noSumanFuera(fuera)}</p> : null}
    </div>
  );
}
