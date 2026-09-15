import { estadoDeLaCaja, type CarritoResuelto } from '@bouquet/contratos';

import { TEXTOS } from './textos';

/* Qué le falta al pedido para poder despacharse, en UNA frase.
 *
 * Con 7 botellas faltan 5 y sobra 1: las dos son ciertas y decir las dos no
 * ayuda a nadie. Se ofrece el camino más corto —agregar si faltan menos de las
 * que sobran, sacar si no—, que además es el que no gasta plata de más.
 *
 * El carrito vacío NO reclama: no hay caja empezada que completar.
 *
 * Sale de la proyección, no de lo guardado: una línea agotada no llena la caja,
 * y por eso este número puede ser menor que el de la barra. */

type Props = {
  resuelto: CarritoResuelto;
};

export function EstadoDeLaCaja({ resuelto }: Props) {
  const { botellas, cajasCompletas, faltan, sobran } = estadoDeLaCaja(resuelto);
  if (botellas === 0) return null;

  const completa = faltan === 0;
  const frase = completa
    ? cajasCompletas === 1
      ? TEXTOS.cajaCompleta
      : TEXTOS.cajasCompletas(cajasCompletas)
    : faltan <= sobran
      ? TEXTOS.faltan(faltan)
      : TEXTOS.sobran(sobran);

  return (
    <p className={`estado-caja${completa ? ' estado-caja--completa' : ''}`} aria-live="polite">
      <span className="estado-caja__avance cifra">{TEXTOS.avance(botellas, botellas + faltan)}</span>
      <span className="estado-caja__frase">{frase}</span>
    </p>
  );
}
