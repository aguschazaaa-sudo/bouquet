import type { ReactNode } from 'react';

/* Una escena: un mensaje, un foco, una lámpara.
 *
 * Declara el `view-timeline` con nombre del que cuelgan TODOS sus planos
 * (parallax.md §4.1). Lo que desincroniza una composición no es que las capas
 * vayan a distinta velocidad: es que cada una arranque y termine en un punto
 * de scroll distinto. Un solo timeline por escena elimina esa posibilidad de
 * raíz.
 *
 * La lámpara son tres números —azimut, altura y radio— y se pasan como
 * variables CSS. Una sola fuente de luz por escena, cálida, fuera de cuadro:
 * un fondo oscuro plano es un tema; un fondo iluminado es un lugar.
 */

type Props = {
  id?: string;
  /** Sufijo de la clase modificadora: `problema`, `seleccion`, … */
  nombre: string;
  /** Etiqueta accesible de la sección. */
  titulo: string;
  children: ReactNode;
};

export function Escena({ id, nombre, titulo, children }: Props) {
  return (
    <section
      id={id}
      aria-label={titulo}
      className={`escena escena--${nombre}`}
      data-escena={nombre}
    >
      {children}
    </section>
  );
}
