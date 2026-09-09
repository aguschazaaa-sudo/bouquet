import Link from 'next/link';

import { Copa } from '@/shared/marca/Copa';

import { EnlaceDeSeccion } from './EnlaceDeSeccion';
import { CARRITO, SECCIONES } from './secciones';

/* La barra principal: un cartucho fijo, no una franja pegada al borde.
 *
 * POR QUÉ NO PELEA CON EL PARALLAX. `parallax.md §3.1` ya había resuelto que
 * la nav es capa **UI, fija, sin parallax de ningún tipo**. Y técnicamente no
 * puede romperse: el motor de este sitio son timelines de scroll de CSS sobre
 * el scroller nativo del root, no un `transform` sobre un contenedor. Ese
 * `transform` es lo que crearía un containing block y dejaría de fijar a los
 * `position: fixed` de adentro — acá no existe. La prueba ya estaba corriendo
 * antes que esta barra: `.grano` (z9) y `.marca-progreso` (z8) son fijos y se
 * pintan sobre las cuatro escenas sin un solo artefacto.
 *
 * Y hace más que no molestar: `parallax.md §3.3` mide que la **oclusión** es
 * la señal de profundidad más fuerte que tiene el sistema visual, más que el
 * paralaje de movimiento. Un marco quieto con los planos deslizándose por
 * detrás es un proscenio: la página se lee como una ventana. Es la profundidad
 * más barata del sitio y —lo que importa— **funciona quieta**, así que
 * sobrevive en Firefox y con `prefers-reduced-motion`, donde no hay movimiento
 * que valga.
 *
 * POR QUÉ CARTUCHO Y NO FRANJA. Reusa `.cartucho-deco`, que ya existe y ya
 * está justificado en `direccion.md §5.1` como "la geometría de una etiqueta
 * de vino". Flotando con aire contra los bordes, el parallax sangra por las
 * cuatro esquinas: una franja al ras taparía justamente el borde de la escena,
 * que es donde el movimiento se lee mejor.
 *
 * EL WORDMARK NO ESTÁ SIEMPRE, Y ES A PROPÓSITO. La primera escena de la home
 * ya trae el suyo en `.hero__marca`. Dos wordmarks en la misma pantalla es un
 * error de composición, no una redundancia inofensiva. Así que en la home el
 * de la barra entra recién cuando el del héroe se va — con el mismo reloj de
 * scroll, cero JavaScript.
 *
 * Y no deja el hueco reservado: colapsa el ancho, así que arriba de todo la
 * placa queda CENTRADA sobre sus tres secciones y el carrito, y se ensancha
 * sola a medida que bajás. Reservar el hueco dejaba la placa visiblemente
 * corrida en el primer píxel de la página, que es el que más gente ve. El
 * detalle está en `navegacion.css`.
 */

export function BarraPrincipal() {
  return (
    <header className="barra">
      <nav className="barra__cartucho cartucho-deco" aria-label="Principal">
        <Link className="barra__marca" href="/">
          <Copa id="barra" nivel={0.62} className="barra__copa" />
          <span className="barra__nombre versalita">bouquet</span>
        </Link>

        <ul className="barra__secciones">
          {SECCIONES.map((seccion) => (
            <li key={seccion.href}>
              <EnlaceDeSeccion seccion={seccion} />
            </li>
          ))}
        </ul>

        <div className="barra__carrito">
          <EnlaceDeSeccion seccion={CARRITO} />
        </div>
      </nav>
    </header>
  );
}
