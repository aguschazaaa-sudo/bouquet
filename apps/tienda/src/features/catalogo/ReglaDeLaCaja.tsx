import { BOTELLAS_POR_CAJA } from '@bouquet/contratos';

import { TEXTOS } from './textos';

/* La regla base de la transacción, dicha como PLACA y no como nota al pie.
 *
 * Venía escrita tres veces en prosa —la cabecera de `/vinos`, el mostrador de
 * la ficha y el estado del carrito— y en los tres lugares era el texto más
 * chico de la pantalla. En la ficha convivía con un precio de 1,45 rem y un
 * `LA BOTELLA` al lado, o sea que lo más grande del mostrador prometía una
 * unidad que no se puede comprar sola. Acá el número es una CIFRA, que es
 * exactamente para lo que existe la tercera familia (tokens.md §5: "donde
 * hubiera un número que no se pudiera leer mal").
 *
 * El marco es `.cartucho-deco`, no un borde nuevo: el anillo octogonal con la
 * ranura de área cero ya está medido en `shared/deco/` y escribir otro sería
 * volver a cometer la muesca del chaflán. Se le pisan el chaflán y el padding,
 * nada más.
 *
 * ⚠️ NO se le pone `background` sin `clip-path: var(--octogono)`: el fondo
 * pinta las cuatro esquinas que el anillo deja afuera y aparecen los
 * triangulitos. Está publicado en `deco.css` y la placa lo respeta en CSS.
 *
 * Dos variantes, porque el trabajo es distinto:
 *   - `placa`  — cava, la cabecera de /vinos. La regla ANTES de elegir nada.
 *   - `franja` — papel, el mostrador de la ficha, que es sticky en el
 *     teléfono: ahí la placa se acuesta para no comerse la pantalla.
 */

type Props = {
  variante?: 'placa' | 'franja';
};

export function ReglaDeLaCaja({ variante = 'placa' }: Props) {
  return (
    <div className={`regla-caja regla-caja--${variante} cartucho-deco`}>
      <p className="regla-caja__rotulo rotulo">{TEXTOS.reglaRotulo}</p>
      <p className="regla-caja__cuenta">
        <span className="regla-caja__cifra cifra">{BOTELLAS_POR_CAJA}</span>
        <span className="regla-caja__unidad">{TEXTOS.reglaUnidad}</span>
      </p>
      <p className="regla-caja__nota">{TEXTOS.reglaNota}</p>
    </div>
  );
}
