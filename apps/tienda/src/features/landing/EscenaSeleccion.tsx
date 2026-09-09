import { Escena } from '@/shared/movimiento/Escena';
import { Plano } from '@/shared/movimiento/Plano';
import { TarjetaVino } from './TarjetaVino';
import { SELECCION, LA_SELECCION_ES_DE_MUESTRA } from '@/features/landing/seleccion';

/* Escena 2 — La selección.
 *
 * Acá está el cambio de fondo respecto de la composición anterior: el vino
 * aparece SEGUNDO y aparece en plural. En las cinco escenas viejas el catálogo
 * se tocaba una sola vez, en la cuarta, con una botella y sin precio: alguien
 * scrolleaba seis pantallas de marca para ver un vino.
 *
 * Es una escena de OBJETO: rango de movimiento comprimido, tres planos, cero
 * foto de fondo. La lámina tiene menos profundidad que el lugar, y por eso se
 * lee como algo que te muestran y no como algo que habitás. La falla es a
 * favor: si la separación de velocidades no se percibe en dispositivo, la
 * escena se aplana, que es lo que ya es.
 *
 * Lleva rótulo. Las escenas de lugar (1 y 4) no: un rótulo es una cartela de
 * museo, y pertenece a algo que se exhibe, no a algo que se habita.
 */

export function EscenaSeleccion() {
  return (
    <Escena id="seleccion" nombre="seleccion" titulo="La selección">
      <Plano
        rol="ambiente"
        ansiosa
        foto={{ base: 'ambiente', ancho: 1300, alto: 1450, foco: '40% 60%' }}
      />

      <div className="lampara" aria-hidden="true" />

      <div className="plano--contenido">
        <div className="seleccion">
          <div className="seleccion__intro">
            <p className="rotulo">La selección</p>

            <h2 className="display seleccion__titulo">
              Lo que hay guardado ahora.
            </h2>

            <p className="prosa prosa--lead">
              Cada uno llegó acostado y así sigue. Los elegimos de a uno: no hay
              góndola que llenar ni un mínimo de marcas que sostener.
            </p>
          </div>

          {/* data-muestra es la puerta de verificación: mientras esté en true,
              lo que se ve son datos inventados y la home no se publica. */}
          <div
            className="seleccion__grilla"
            data-muestra={LA_SELECCION_ES_DE_MUESTRA ? 'true' : undefined}
          >
            {SELECCION.map((vino) => (
              <TarjetaVino key={vino.slug} vino={vino} />
            ))}
          </div>

          <div className="seleccion__cierre">
            {/* voz.md §6: nada de plazos ni de rankings. Lo único que se
                afirma es que la lista cambia, que es cierto por construcción. */}
            <p className="prosa">
              La lista se mueve. Lo que se agota no se repone con otra cosa
              parecida.
            </p>

            {/* Primero de los DOS únicos CTA duros de la página. */}
            <a className="boton" href="/vinos">
              <span>Ver todos los vinos</span>
            </a>
          </div>
        </div>
      </div>

      <div className="vinieta" aria-hidden="true" />
    </Escena>
  );
}
