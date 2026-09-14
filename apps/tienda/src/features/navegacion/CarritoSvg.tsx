/* El glifo del carrito: una bolsa de papel madera, no un changuito.
 *
 * secciones.ts ya había descartado el ícono de supermercado por nombre —
 * "un changuito es la palabra de un supermercado, que es exactamente lo que
 * voz.md prohíbe parecer". Pero direccion.md §6 no prohíbe TODO ícono: dice
 * "Palabras. Y los pocos íconos, monolineales como el isotipo". Este es uno
 * de esos pocos, y dibuja la bolsa de papel madera con manija: la que de
 * verdad usa una vinoteca, no una canasta ni un changuito con ruedas.
 *
 * ⚠️ Cuatro versiones anteriores fallaron:
 * 1. Un asa REDONDA de lado a lado se leía como el asa de una canasta.
 * 2. Dos asas chicas y planas se leían como el moño de una caja de regalo.
 * 3. Una sola asa plana y RECTANGULAR —dos rectángulos apilados— se leía
 *    como un pendrive.
 * 4. Y las tres eran demasiado desnudas para la marca: "un art deco no es
 *    tan minimalista". El cuerpo pasa a chaflanado —el MISMO octógono de
 *    `--octogono` en deco.css, no un rectángulo con las esquinas cortadas a
 *    ojo— y el asa a trapecio, angosta arriba: el mismo lenguaje de faceta
 *    recta que ya tiene el cartucho de la barra, no una curva.
 *
 * Por eso el trazo NO usa `stroke-linejoin: round` como BotellaSvg: ésa dibuja
 * vidrio, blando a propósito. Esto dibuja facetas, y una faceta con la punta
 * redondeada deja de leerse como corte. `miter` + `butt`, filo real.
 *
 * Monolineal de verdad —trazo, no relleno—, a diferencia de la Copa: ésa cita
 * el imagotipo real (que modula 1,38x, ver Copa.tsx). Ésta es vocabulario
 * propio, con el mismo grosor constante.
 */

type Props = {
  className?: string;
};

export function CarritoSvg({ className }: Props) {
  const clases = ['carrito-svg', className].filter(Boolean).join(' ');

  return (
    <svg
      className={clases}
      viewBox="0 0 12 20"
      role="presentation"
      aria-hidden="true"
      fill="none"
    >
      {/* El cuerpo: chaflanado como el cartucho, alto y angosto — entra una
          botella parada, no una caja cuadrada. */}
      <path
        className="carrito-svg__trazo"
        d="M3.5 6 L8.5 6 L10 7.5 L10 16.5 L8.5 18 L3.5 18 L2 16.5 L2 7.5 Z"
      />

      {/* La manija: un trapecio, angosto arriba — la misma faceta recta que
          el cuerpo, no un arco de canasta. */}
      <path className="carrito-svg__trazo" d="M3.8 6 L4.6 2.3 L7.4 2.3 L8.2 6" />
    </svg>
  );
}
