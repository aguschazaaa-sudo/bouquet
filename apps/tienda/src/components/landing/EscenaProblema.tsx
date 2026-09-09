import { Copa } from '../marca/Copa';
import { Escena } from './Escena';
import { Plano } from './Plano';

/* Escena 1 — El problema.
 *
 * La landing anterior abría con un umbral: un lugar, un ánimo, cero
 * información. Ésta abre con el problema que el lector ya vivió, porque un
 * ánimo no se discute y un problema sí se reconoce.
 *
 * El texto sale casi literal de voz.md §10.2, donde ya estaba curado y
 * enterrado en un ejemplo. Es el párrafo que dice lo único que bouquet puede
 * sostener sin mentir —no produce, custodia— y estaba sin usar.
 *
 * Cinco planos: es la única escena que gasta el stack completo. Las que
 * siguen usan tres o dos, porque la profundidad ya se estableció y repetirla
 * entera la vuelve decorado (parallax.md §3.1).
 */

export function EscenaProblema() {
  return (
    <Escena nombre="problema" titulo="Un vino puede estar bien hecho y llegar mal">
      <Plano
        rol="ambiente"
        ansiosa
        foto={{ base: 'ambiente', ancho: 1300, alto: 1450, foco: '60% 40%' }}
      />

      <Plano
        rol="escenario"
        ansiosa
        foto={{
          base: 'rack',
          dosDirecciones: true,
          ancho: 1100,
          alto: 1650,
          foco: '58% 50%',
        }}
      />

      <div className="lampara" aria-hidden="true" />

      {/* El sujeto: el culo de una botella ACOSTADA. La elección del encuadre
          no es estética — un cuello o una base no llegan al área de etiqueta,
          así que no hay que elegir entre mostrar una marca ajena o taparla con
          sombra. Se resuelve por recorte, no por desenfoque, y así el plano
          conserva la nitidez máxima que parallax.md §3.4 le exige a z2. */}
      <Plano
        rol="sujeto"
        ansiosa
        foto={{ base: 'botella', ancho: 1100, alto: 940, foco: '50% 50%' }}
      />

      <div className="plano--contenido">
        <div className="hero">
          {/* El scrim vive acá adentro, en el mismo plano que el texto. Si
              viviera en el ambiente o en el detalle, el contraste cambiaría
              mientras scrolleás y ninguna captura lo mostraría. */}
          <div className="scrim" aria-hidden="true" />

          {/* El isotipo, por primera vez en el sitio. Antes la marca era sólo
              la palabra compuesta en versalitas: el dibujo que el estudio
              entregó no aparecía en ninguna pantalla.

              Va acá arriba y no en un header porque direccion.md §4.3 resuelve
              la bajada floja del imagotipo separando las partes — el dibujo y
              el nombre se usan juntos, la bajada se compone como texto del
              sitio. Eso es exactamente esta pila. */}
          <p className="hero__marca">
            <Copa id="heroe" className="copa--faro hero__copa" nivel={0.72} />
            <span className="hero__nombre">bouquet</span>
          </p>

          <hr className="filete hero__filete" />

          <p className="hero__kicker">
            El aroma lo trae la uva. El bouquet lo gana esperando.
          </p>

          <h1 className="display hero__titulo">
            Un vino puede estar bien hecho y llegar mal.
          </h1>

          <div className="hero__lead">
            <p className="prosa prosa--lead">
              Entre la bodega y tu mesa hay meses. El vino los pasa en algún
              lado: parado en una góndola, con luz encima, al lado de una
              heladera que arranca y para.
            </p>
            <p className="prosa">
              Nosotros nos ocupamos de ese tramo. Acostado, a temperatura
              pareja, sin luz. Es todo lo que hacemos, y por eso lo hacemos
              bien.
            </p>
          </div>

          <p className="hero__pie">
            <a className="enlace-blando" href="#seleccion">
              Ver qué hay guardado
            </a>
          </p>
        </div>
      </div>

      {/* El detalle: un borde de copa desenfocado, CSS puro y cero bytes.
          parallax.md §3.3 — la oclusión es una señal de profundidad más fuerte
          que el paralaje de movimiento, y es la única que sobrevive intacta
          cuando el movimiento se apaga. */}
      <Plano rol="detalle">
        <div className="detalle-copa" aria-hidden="true" />
      </Plano>

      <div className="vinieta" aria-hidden="true" />
    </Escena>
  );
}
