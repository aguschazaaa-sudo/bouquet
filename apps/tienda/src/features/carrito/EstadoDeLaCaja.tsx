import { cargaDelPedido, estadoDeLaCaja, type CarritoResuelto } from '@bouquet/contratos';

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
  /* Cero botellas sueltas: no hay caja en curso. Puede ser el carrito vacío o
   * un pedido de sólo cajas cerradas, que ya viaja y no tiene nada que
   * completar (ADR 009 §10). En los dos casos este bloque no dice nada. */
  if (botellas === 0) return null;

  /* Si en el pedido hay algo que viaja solo, la frase dice "sueltas": el total
   * de abajo cuenta TODAS las botellas y sin esa palabra los dos números se
   * leen como un error. Se vio en la captura, no en el diff. */
  const hayPropias = cargaDelPedido(resuelto).propias.length > 0;
  const completa = faltan === 0;
  const frase = completa
    ? cajasCompletas === 1
      ? TEXTOS.cajaCompleta
      : TEXTOS.cajasCompletas(cajasCompletas)
    : faltan <= sobran
      ? TEXTOS.faltan(faltan, hayPropias)
      : TEXTOS.sobran(sobran, hayPropias);

  return (
    <p className={`estado-caja${completa ? ' estado-caja--completa' : ''}`} aria-live="polite">
      <span className="estado-caja__avance cifra">{TEXTOS.avance(botellas, botellas + faltan)}</span>
      <span className="estado-caja__frase">{frase}</span>
    </p>
  );
}
