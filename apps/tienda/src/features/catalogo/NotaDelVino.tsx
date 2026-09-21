import type { ProductoPublicado } from '@bouquet/contratos';

import { TEXTOS } from './textos';

/* Lo que el dueño escribió sobre esta botella (specs/vidriera-ficha).
 *
 * Dos cosas que este componente hace a propósito:
 *
 * 1. Cuando no hay descripción devuelve `null`, no un hueco: se va la sección
 *    entera, título incluido. Un vino sin nota tiene que verse completo, igual
 *    que uno sin foto — y hoy casi ninguno la tiene, porque el campo recién
 *    existe.
 *
 * 2. Renderiza TEXTO PLANO. Lo escribe una persona en un formulario del panel,
 *    no un editor de confianza: nada de `dangerouslySetInnerHTML`. React escapa
 *    el contenido, y `white-space: pre-line` respeta los saltos de línea que
 *    esa persona puso sin necesitar ninguna marca.
 *
 * El título no habla de enología: bouquet no hace el vino, lo guarda
 * (voz.md §0). Dice de dónde sale la nota, no qué sabe de vinos. */

type Props = {
  producto: ProductoPublicado;
};

export function NotaDelVino({ producto }: Props) {
  if (producto.descripcion === null) return null;

  return (
    <section className="ficha__nota papel">
      <div className="contenedor-vinos">
        <h2 className="rotulo">{TEXTOS.notaTitulo}</h2>
        <p className="ficha__nota-texto">{producto.descripcion}</p>
      </div>
    </section>
  );
}
