import { Escena } from '@/shared/movimiento/Escena';
import { Plano } from '@/shared/movimiento/Plano';

/* Escena 3 — La custodia. La que enseña.
 *
 * parallax.md §10.1 pide una escena que enseñe algo verdadero, porque es lo
 * que sostiene el interés hasta el CTA sin gritar. La composición anterior lo
 * resolvía con el color del menisco de una copa: cierto, pero abstracto, y
 * sobre el vino, que es justo lo que bouquet no puede firmar (voz.md §3.2).
 *
 * Acá enseña sobre la CUSTODIA, que es el único tramo que la marca hizo. Tres
 * mecanismos, con su porqué físico. Ninguno es una nota de cata, ninguno
 * afirma un número operativo que no podamos sostener, y los tres se pueden
 * verificar en cualquier manual.
 *
 * Es también la escena con más texto de la página, a propósito: es donde el
 * lector decidió quedarse, y donde una landing de marca normalmente no dice
 * nada.
 */

const MECANISMOS = [
  {
    nombre: 'Acostada',
    texto:
      'El corcho se mantiene húmedo mientras el vino lo toca. Seco se contrae, y por ese milímetro entra aire. Una botella parada seis meses ya no es la misma botella.',
  },
  {
    nombre: 'Temperatura pareja',
    texto:
      'Importa menos el número que el movimiento. Cada subida y bajada dilata el vidrio y el líquido a distinta velocidad, y el cuello termina bombeando aire hacia adentro.',
  },
  {
    nombre: 'Sin luz',
    texto:
      'La luz descompone, y no hace falta que sea sol: un tubo alcanza. Por eso el vidrio del vino es oscuro, y por eso una góndola iluminada es el peor lugar posible.',
  },
] as const;

export function EscenaCustodia() {
  return (
    <Escena nombre="custodia" titulo="Cómo se guarda">
      <Plano
        rol="escenario"
        foto={{
          base: 'cava',
          dosDirecciones: true,
          ancho: 1100,
          alto: 1650,
          foco: '30% 40%',
        }}
      />

      <div className="lampara" aria-hidden="true" />

      <div className="plano--contenido">
        <div className="custodia">
          {/* El scrim envuelve el bloque ENTERO, no sólo la intro: las tres
              columnas también se leen sobre la foto, y el contraste de un
              texto sobre una capa que se mueve cambia mientras scrolleás. */}
          <div className="scrim" aria-hidden="true" />

          <div className="custodia__intro">
            <p className="rotulo">Cómo se guarda</p>

            <h2 className="display custodia__titulo">
              Tres cosas, y ninguna es un secreto.
            </h2>

            <p className="prosa prosa--lead">
              No hay una técnica propia acá. Hay tres condiciones que cualquiera
              puede verificar, y el trabajo es sostenerlas todos los meses que
              haga falta.
            </p>
          </div>

          <div className="custodia__mecanismos">
            {MECANISMOS.map((m) => (
              <article className="mecanismo" key={m.nombre}>
                <h3 className="display mecanismo__nombre">{m.nombre}</h3>
                <p className="prosa mecanismo__texto">{m.texto}</p>
              </article>
            ))}
          </div>

          {/* La frase que cierra el argumento entero de la marca: el tramo que
              no firma nadie es el único que ésta puede firmar. */}
          <p className="custodia__firma">
            Nada de esto es una opinión sobre el vino. Es lo que le pasa a una
            botella mientras espera, y ese tramo —que no firma nadie— es el
            único que podemos firmar nosotros.
          </p>
        </div>
      </div>

      <div className="vinieta" aria-hidden="true" />
    </Escena>
  );
}
