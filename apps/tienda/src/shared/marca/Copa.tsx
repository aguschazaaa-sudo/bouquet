import type { CSSProperties } from 'react';

import trazado from './copa.paths.json';

/* La copa de la marca, dibujada.
 *
 * Los paths salen de `scripts/assets/generar_copa.py`, que los deriva del PNG
 * RGB del imagotipo y VERIFICA el trazado midiendo IoU contra la mascara del
 * propio PNG: copa 0,9881 y vino 0,9945, con control positivo (1,0000) y
 * negativo (0,3831). No es un calco a ojo.
 *
 * ⚠️ El isotipo NO es monolineal, y direccion.md §1 dice que si.
 * Medido con la transformada de distancia sobre la mascara dorada: el ancho de
 * trazo va de 44px (p05) a 61px (p95) — razon 1,38. Un monolineal daria ~1,00.
 * Esa linea del vault produjo `--filete: 1px` con el comentario "grosor
 * constante, siempre" y el encabezado de BotellaSvg.tsx. La correccion vive en
 * tokens.css: el sitio tiene DOS pesos de linea, porque la marca los tiene.
 *
 * Por que la copa y no una botella: es lo unico que bouquet firma. La botella
 * es de la bodega; la copa es el gesto de la marca — y su voluta es, literal,
 * el aroma subiendo, que es lo que quiere decir "bouquet".
 */

type Props = {
  /** Prefijo de los ids del SVG. Obligatorio: puede haber varias copas en la
   *  pagina y dos `<clipPath>` con el mismo id hacen que gane siempre el
   *  primero, asi que la segunda copa saldria sin vino. */
  id: string;
  /** Cuanto vino tiene, 0 a 1. Lo ignora cuando `progresivo`. */
  nivel?: number;
  /** El nivel lo maneja el scroll de la pagina. Ver `.copa--progresiva`. */
  progresivo?: boolean;
  /** Con texto alternativo deja de ser decorativa y pasa a ser `img`. */
  etiqueta?: string;
  className?: string;
};

const CAJA = trazado.vinoCaja;

export function Copa({
  id,
  nivel = 0.62,
  progresivo = false,
  etiqueta,
  className,
}: Props) {
  const clases = ['copa', progresivo ? 'copa--progresiva' : '', className]
    .filter(Boolean)
    .join(' ');

  return (
    <svg
      className={clases}
      viewBox={trazado.viewBox}
      fill="none"
      role={etiqueta ? 'img' : 'presentation'}
      aria-label={etiqueta}
      aria-hidden={etiqueta ? undefined : true}
      style={
        {
          // El alto de la caja del vino viaja como variable para que el
          // llenado se exprese en unidades de usuario del propio viewBox.
          '--vino-alto': `${CAJA.alto}px`,
          ...(progresivo ? {} : { '--nivel': nivel }),
        } as CSSProperties
      }
    >
      <defs>
        {/* El liquido se recorta contra la forma que el vino tiene EN EL LOGO.
            Asi el nivel sube y baja sin que aparezca vino en un lugar donde el
            imagotipo no lo dibuja. */}
        <clipPath id={`${id}-vino`}>
          <path d={trazado.vino} />
        </clipPath>
      </defs>

      <g clipPath={`url(#${id}-vino)`}>
        <rect
          className="copa__liquido"
          x={CAJA.x}
          y={CAJA.y}
          width={CAJA.ancho}
          height={CAJA.alto}
        />
      </g>

      {/* El trazo va ULTIMO: el vino se apoya contra el vidrio por dentro, y si
          el liquido se pintara encima le comeria el filo al dibujo. */}
      <path className="copa__trazo" d={trazado.copa} />
    </svg>
  );
}
