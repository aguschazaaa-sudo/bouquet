import { ReglaNumerada } from './ReglaNumerada';
import type { Parrafo, Tramo as DatosDelTramo } from './oficio';

/* Un tramo entero: la regla con su numeral, el nombre, el título y la prosa.
 *
 * No elige qué tramo es ni en qué orden va: recibe uno de los tres de
 * `oficio.ts` y lo dibuja. Los tres usan el mismo componente, incluido el que
 * la marca no firma — si el tercero tuviera su propio componente, la diferencia
 * dejaría de ser un dato y pasaría a ser dos caminos de código que se van
 * separando solos.
 */

type Props = {
  tramo: DatosDelTramo;
};

/* Los pedazos de un párrafo. Un párrafo es un string salvo cuando lleva una
 * itálica adentro, y entonces es la lista de sus pedazos: el objeto es la
 * itálica, y `.prosa em` de `tipografia.css` ya la pinta.
 *
 * La `key` por índice es correcta acá y no una concesión: la lista es una
 * constante del módulo, no se reordena, no se filtra y no crece en runtime. */
function fragmentos(parrafo: Parrafo) {
  if (typeof parrafo === 'string') return parrafo;

  return parrafo.map((pedazo, i) =>
    typeof pedazo === 'string' ? (
      pedazo
    ) : (
      <em key={i}>{pedazo.enfasis}</em>
    ),
  );
}

export function Tramo({ tramo }: Props) {
  return (
    <section className={`tramo${tramo.firmado ? '' : ' tramo--sin-firma'}`}>
      <ReglaNumerada numeral={tramo.numeral} firmado={tramo.firmado} />

      {/* El nombre es el rótulo del tramo, no su título: ubica antes de que el
          título empiece a argumentar. `Guardar` es el tramo donde `Custodia`
          bajó a rendir cuando dejó de ser el nombre de la sección. */}
      <p className="rotulo tramo__nombre">{tramo.nombre}</p>

      <h2 className="display tramo__titulo">{tramo.titulo}</h2>

      <div className="tramo__cuerpo">
        {tramo.parrafos.map((parrafo, i) => (
          <p className="prosa" key={i}>
            {fragmentos(parrafo)}
          </p>
        ))}
      </div>
    </section>
  );
}
