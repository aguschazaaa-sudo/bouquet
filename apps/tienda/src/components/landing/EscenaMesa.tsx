import { Escena } from './Escena';
import { Plano } from './Plano';

/* Escena 4 — La mesa. El cierre.
 *
 * Dos planos, el mínimo posible, a propósito. La profundidad ya se estableció
 * en la escena 1; repetir el stack completo acá la volvería decorado.
 *
 * Es el DESPUÉS de voz.md §1.2. La marca tiene dos tiempos —la custodia antes,
 * la memoria después— y el sorbo, lo único que no hizo, queda entre paréntesis
 * sostenido por los dos lados. Esta escena es el paréntesis cerrándose.
 *
 * Y es la lectura correcta de "sabor eterno": no una promesa sobre el gusto,
 * que sería imposible de sostener, sino una sobre la memoria. El sabor se va;
 * la experiencia de haberlo tomado dura.
 *
 * ⚠️ Cero caras, y es un requisito duro del asset, no una preferencia. Se
 * descarta cualquier foto con una cara visible, aunque sea de espaldas o
 * borrosa: "quién más" es del lector.
 */

export function EscenaMesa() {
  return (
    <Escena nombre="mesa" titulo="Lo que queda">
      <Plano
        rol="escenario"
        foto={{
          base: 'mesa',
          dosDirecciones: true,
          ancho: 1100,
          alto: 1650,
          foco: '50% 55%',
        }}
      />

      <div className="lampara" aria-hidden="true" />

      <div className="plano--contenido">
        <div className="mesa">
          <div className="scrim" aria-hidden="true" />

          <h2 className="display mesa__titulo">
            Después no te vas a acordar del vino.
          </h2>

          <div className="mesa__cuerpo">
            <p className="prosa prosa--lead">
              Te vas a acordar de la mesa. De quién estaba, de la hora que era,
              de que nadie tenía apuro por irse.
            </p>
            <p className="prosa">
              Por eso el trabajo termina antes de que la abras. Lo que pasa
              después ya no es nuestro, y está bien así.
            </p>
          </div>

          {/* El segundo y último CTA duro. Después de esto no hay más
              ceremonia: el cierre es una exhalación, no otra insistencia. */}
          <p>
            <a className="boton" href="/vinos">
              Ver todos los vinos
            </a>
          </p>
        </div>
      </div>

      <div className="vinieta" aria-hidden="true" />
    </Escena>
  );
}
