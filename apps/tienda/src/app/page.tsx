import { Copa } from '@/shared/marca/Copa';
import { EscenaProblema } from '@/features/landing/EscenaProblema';
import { EscenaSeleccion } from '@/features/landing/EscenaSeleccion';
import { EscenaCustodia } from '@/features/landing/EscenaCustodia';
import { EscenaMesa } from '@/features/landing/EscenaMesa';
import { PieDeLanding } from '@/features/landing/PieDeLanding';

/* La home.
 *
 * Cuatro escenas, no cinco. El presupuesto de parallax.md §4.5 permite cinco;
 * la cuarta que sobraba era una escena de marca más, y el pedido era menos
 * ceremonia y más vino.
 *
 * El arco no es un recorrido de ánimos, es la secuencia de preguntas que hace
 * alguien que podría comprar:
 *
 *   1. ¿por qué debería importarme?  → el problema, que el lector reconoce
 *   2. ¿qué tenés?                   → seis vinos, arriba, no enterrados
 *   3. ¿por qué vos y no la góndola? → tres mecanismos con su porqué físico
 *   4. ¿y después?                   → la mesa, que es lo que queda
 *
 * CTA duro exactamente dos veces (escenas 2 y 4), un CTA blando en la 1, y
 * nada más: coquetear es insinuar, no gritar.
 *
 * Cero lecturas de Firestore por visitante. La página es HTML estático que
 * sólo cambia cuando cambia el diseño, así que no entra al circuito de purga
 * por tag de ADR 005 y no toca el presupuesto de 50.000 lecturas/día.
 */

export default function Home() {
  return (
    <>
      <a className="saltar" href="#seleccion">
        Saltar a la selección
      </a>

      <main>
        <EscenaProblema />
        <EscenaSeleccion />
        <EscenaCustodia />
        <EscenaMesa />
      </main>

      <PieDeLanding />

      {/* El progreso de la página, dicho con el objeto de la marca: el vino
          sube en la copa a medida que bajás. Es CSS puro sobre
          `animation-timeline: scroll(root)` — cero JavaScript, cero estado.

          direccion.md §6 pide "palabras, no íconos", y esto no lo contradice:
          no es un ícono de interfaz, es el imagotipo haciendo lo único que un
          recipiente puede hacer. Donde el timeline no existe (Firefox, que lo
          tiene detrás de flag) queda con su nivel por defecto, lleno. */}
      <Copa
        id="progreso"
        progresivo
        className="marca-progreso"
        etiqueta="Progreso de la página"
      />

      {/* El grano va último y por encima de todo: disuelve las bandas que un
          degradé oscuro produce en una pantalla de 8 bits. Es un recurso
          estético que paga una deuda técnica. */}
      <div className="grano" aria-hidden="true" />
    </>
  );
}
