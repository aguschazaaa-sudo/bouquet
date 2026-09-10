import { SelloDeContacto } from './SelloDeContacto';
import { Tramo } from './Tramo';
import { APERTURA, TRAMOS } from './oficio';

/* La sección "El oficio": la apertura, los tres tramos y el sello.
 *
 * Es la pieza que compone, y no hace nada más — la composición es bottom-up y
 * ésta es la última capa antes de la ruta.
 *
 * ⚠️ NO IMPORTA NADA DE `features/landing/`, y no es una casualidad: ADR 006
 * regla 3 lo prohíbe y `frontera-features.sh` lo mide. La sección dice cosas
 * que la home también dice —la custodia, la mesa— y las dice con su propio
 * texto y sus propios componentes, porque quien llega acá desde un WhatsApp
 * nunca vio la home. Reusar `EscenaCustodia` habría atado dos páginas que
 * tienen que poder cambiar por separado.
 *
 * El arco es el `voz.md §1.2` completo: el ANTES del Cuidador (elegir, guardar)
 * y el DESPUÉS del Amante (abrir), con el sorbo entre paréntesis. Y termina en
 * quién es "nosotros", que es exactamente el contenido de contacto: por eso las
 * dos secciones se resolvieron con una sola pieza.
 *
 * Cero lecturas de Firestore por visitante, y es cero por construcción: el
 * contenido vive en `oficio.ts`, así que la página es HTML estático y no entra
 * al circuito de purga por tag del ADR 004.
 */

export function SeccionOficio() {
  return (
    <main className="oficio">
      <div className="oficio__eje">
        <header className="apertura">
          <p className="rotulo apertura__rotulo">{APERTURA.rotulo}</p>

          {/* El `h1` dice cuántos tramos hay y cuántos firma la marca. La tesis
              de la página está en el título y no en una nota al pie, así que un
              lector que sólo lee los titulares ya se la lleva. */}
          <h1 className="display apertura__titulo">{APERTURA.titulo}</h1>

          <hr className="filete filete--corto" />

          <p className="prosa prosa--lead apertura__lead">{APERTURA.lead}</p>
        </header>

        {/* La `key` es el numeral: es único y es del dato, no del índice. */}
        {TRAMOS.map((tramo) => (
          <Tramo key={tramo.numeral} tramo={tramo} />
        ))}

        <SelloDeContacto />
      </div>
    </main>
  );
}
