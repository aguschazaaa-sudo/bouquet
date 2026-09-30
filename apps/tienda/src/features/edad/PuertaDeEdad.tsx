'use client';

import { useEffect, useRef, useState, type ReactNode, type TransitionEvent } from 'react';

import { CLAVE_EDAD, marcaDeMayoria } from './edad';
import { TEXTOS } from './textos';

/* El telón de la puerta de edad. ARQUITECTURA §9.5 la obliga; parallax.md
 * §10.2 la diseña: es la primera pieza de la experiencia, no un trámite
 * delante de ella, y se LEVANTA.
 *
 * ⚠️ LA RESTRICCIÓN QUE ORDENA EL COMPONENTE: es un overlay sobre contenido que
 * ya está en el HTML, nunca un bloqueo del render. `children` —el sitio
 * entero— se renderiza SIEMPRE, con el telón puesto o no. Si el contenido no
 * estuviera en el HTML, Google no lo vería y la vidriera volvería a ser
 * invisible, que es el problema que la decisión de Next.js vino a resolver.
 *
 * Por qué envuelve al sitio en vez de ir al lado: el requisito 3 de §10.2
 * bloquea el scroll con `inert` sobre el contenido —no con `overflow: hidden`
 * en el `body`, que en iOS pierde la posición—, y para eso hace falta un
 * elemento que lo contenga todo.
 *
 * ⚠️ Y `inert` se pone DESDE EL EFECTO, no como prop. Con la prop, el servidor
 * —que no sabe quién ya entró— lo renderizaría en todas las respuestas: quien
 * vuelve tendría la página muerta hasta que hidrate, y sin JavaScript para
 * siempre, porque un `<noscript>` puede esconder el telón pero no le saca un
 * atributo al contenido. Antes de hidratar el telón ya tapa todo, así que lo
 * único que queda abierto en ese rato es el tabulador.
 *
 * El sello llega como slot, igual que el contador de la barra: la copa se
 * dibuja en el servidor y sus trazados no viajan en el JavaScript del cliente.
 */

type Fase = 'puesta' | 'rechazada' | 'subiendo' | 'afuera';

type Props = {
  /** La marca que encabeza el telón. */
  sello: ReactNode;
  /** El sitio entero. Se renderiza siempre, debajo del telón. */
  children: ReactNode;
};

/** Red de seguridad por si `transitionend` no llega (una extensión que apaga
 *  las transiciones, la pestaña en segundo plano). Más larga que el telón, que
 *  dura 800 ms: el número de verdad está en `edad.css` y no se repite acá. */
const SI_NO_TERMINA_MS = 1500;

export function PuertaDeEdad({ sello, children }: Props) {
  const [fase, setFase] = useState<Fase>('puesta');
  const sitio = useRef<HTMLDivElement>(null);
  const principal = useRef<HTMLButtonElement>(null);
  const reloj = useRef<number | null>(null);

  useEffect(() => {
    // El script en línea de `edad.ts` ya leyó la marca antes del primer
    // pintado. Si estaba, el telón nunca se vio: se desmonta y listo.
    if (document.documentElement.dataset.edad === 'ok') {
      setFase('afuera');
      return;
    }
    sitio.current?.setAttribute('inert', '');
  }, []);

  // El foco va al botón que corresponde a cada fase, como en cualquier
  // diálogo: con el sitio inerte, el teclado sólo recorre el telón.
  useEffect(() => {
    if (fase === 'puesta' || fase === 'rechazada') principal.current?.focus();
  }, [fase]);

  useEffect(
    () => () => {
      if (reloj.current !== null) window.clearTimeout(reloj.current);
    },
    [],
  );

  function entrar() {
    // `localStorage` tira en el modo privado de algunos navegadores. Que el
    // telón no se recuerde es molesto; que la página no abra es un sitio roto.
    try {
      window.localStorage.setItem(CLAVE_EDAD, marcaDeMayoria(new Date()));
    } catch {
      // Se entra igual: sólo que la próxima visita vuelve a preguntar.
    }
    // El sitio se libera al empezar a subir, no al terminar: lo que el telón
    // ya destapó se puede usar mientras sigue subiendo.
    sitio.current?.removeAttribute('inert');
    setFase('subiendo');
    reloj.current = window.setTimeout(irse, SI_NO_TERMINA_MS);
  }

  function irse() {
    if (reloj.current !== null) {
      window.clearTimeout(reloj.current);
      reloj.current = null;
    }
    document.documentElement.dataset.edad = 'ok';
    setFase('afuera');
  }

  // `transitionend` burbujea: el color de un botón al pasarle por encima
  // también lo dispara. Sólo cuenta la transición del telón mismo.
  function alTerminar(e: TransitionEvent<HTMLDivElement>) {
    if (fase === 'subiendo' && e.target === e.currentTarget) irse();
  }

  const rechazada = fase === 'rechazada';

  return (
    <>
      <div ref={sitio} className="sitio">
        {children}
      </div>

      {fase !== 'afuera' && (
        <div
          className="puerta"
          data-fase={fase}
          role="dialog"
          aria-modal="true"
          aria-labelledby="puerta-titulo"
          aria-describedby="puerta-texto"
          onTransitionEnd={alTerminar}
        >
          <div className="grano" aria-hidden="true" />
          <div className="puerta__escenario">
            <div className="puerta__placa cartucho-deco">
              <div className="puerta__sello">
                {sello}
                <span className="puerta__marca versalita">{TEXTOS.marca}</span>
              </div>

              {/* h2 y no h1: el h1 es de la página que está debajo, que
                  sigue entera en el HTML. */}
              <h2 className="puerta__titulo display" id="puerta-titulo">
                {rechazada ? TEXTOS.rechazoTitulo : TEXTOS.titulo}
              </h2>
              <p className="puerta__texto prosa" id="puerta-texto">
                {rechazada ? TEXTOS.rechazo : TEXTOS.documento}
              </p>

              <div className="puerta__acciones">
                {rechazada ? (
                  <button
                    ref={principal}
                    type="button"
                    className="puerta__salida"
                    onClick={() => setFase('puesta')}
                  >
                    {TEXTOS.meEquivoque}
                  </button>
                ) : (
                  <>
                    <button ref={principal} type="button" className="boton" onClick={entrar}>
                      <span>{TEXTOS.soyMayor}</span>
                    </button>
                    <button
                      type="button"
                      className="puerta__salida"
                      onClick={() => setFase('rechazada')}
                    >
                      {TEXTOS.todaviaNo}
                    </button>
                  </>
                )}
              </div>
            </div>
          </div>
        </div>
      )}
    </>
  );
}
