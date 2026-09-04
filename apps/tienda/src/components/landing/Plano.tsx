import type { ReactNode } from 'react';

/* Un plano de una escena.
 *
 * parallax.md §3.1 fija el stack y qué va en cada capa. La velocidad NO se
 * elige acá: sale de la ecuación v = 1 − z/D y vive como un token
 * (--amp-*) en tokens.css. Este componente sólo dice a qué profundidad está
 * la capa; el motor que la mueve está en estilos/sistema.css y es UNO SOLO
 * para todas, con el mismo reloj y el mismo rango.
 *
 * Por eso no existe una prop `velocidad`: si existiera, existiría también la
 * forma de desincronizar una capa de las otras, que es exactamente el defecto
 * que separa un parallax premium de un capricho.
 */

/** Los cinco planos del stack. `contenido` es el único que va en el flujo. */
export type RolDePlano =
  | 'ambiente'
  | 'escenario'
  | 'sujeto'
  | 'contenido'
  | 'detalle';

export type FotoDePlano = {
  /** Nombre base en /public/landing, sin dirección de arte ni extensión. */
  base: string;
  /**
   * Si hay dos direcciones de arte (`-v` y `-h`). parallax.md §6.5: un arte
   * compuesto para 9:19,5 recortado a 21:9 pierde la composición, así que se
   * eligen con <picture> + media y el navegador no descarga la que no usa.
   * Con `false` se sirve una sola pieza para las dos formas.
   */
  dosDirecciones?: boolean;
  /** Punto focal declarado. Nunca centrado a ciegas (parallax.md §6.5). */
  foco?: string;
  ancho: number;
  alto: number;
};

type Props = {
  rol: RolDePlano;
  foto?: FotoDePlano;
  /**
   * Carga ansiosa. parallax.md §6.3: escenas 1 y 2 ansiosas; de la 3 en
   * adelante `lazy` y `fetchpriority="low"`, porque una capa a pantalla
   * completa que aparece a mitad del scroll es la peor forma de pop-in.
   */
  ansiosa?: boolean;
  children?: ReactNode;
};

export function Plano({ rol, foto, ansiosa = false, children }: Props) {
  const raiz = foto?.dosDirecciones ? `/landing/${foto.base}` : null;
  const unica = foto ? `/landing/${foto.base}${raiz ? '-v' : ''}.webp` : null;

  return (
    <div className={`plano plano--${rol}`} data-rol={rol}>
      {foto && unica ? (
        <picture>
          {raiz ? (
            <source media="(orientation: landscape)" srcSet={`${raiz}-h.webp`} />
          ) : null}
          {/* alt vacío a propósito: son capas decorativas. El mensaje entero
              vive en el plano de contenido, que es texto real. */}
          <img
            src={unica}
            alt=""
            width={foto.ancho}
            height={foto.alto}
            style={{ objectPosition: foto.foco ?? '50% 50%' }}
            loading={ansiosa ? 'eager' : 'lazy'}
            fetchPriority={ansiosa ? 'high' : 'low'}
            decoding="async"
            aria-hidden="true"
          />
        </picture>
      ) : null}
      {children}
    </div>
  );
}
