import { EL_CONTACTO_ES_PROVISORIO, SELLO } from './oficio';

/* El cierre de la página: el mostrador.
 *
 * Es el bloque al que llega `/contacto`, que ahora redirige a `/oficio#mostrador`
 * — de ahí el `id`, que no es decorativo: es el destino de una redirección
 * permanente y de los textos ya escritos en `voz.md §9.3` y `§9.5`.
 *
 * ⚠️ NO HAY FORMULARIO, Y NO ES UNA OMISIÓN. `voz.md §4.2` dice que del otro
 * lado hay una persona, y un formulario dice exactamente lo contrario: mete una
 * cola de espera entre el que pregunta y el que contesta. Si alguien agrega un
 * `<form>` acá, el bloque deja de decir la única cosa que tiene para decir.
 *
 * ⚠️ Y EL ATRIBUTO `data-contacto-provisorio` ES EL GATE, EMITIDO AL HTML.
 * Un `grep` sobre el repo dice qué hay en el código de ESTA máquina;
 * `auditor-produccion` audita PRODUCCIÓN con `curl` y no puede grepear un `.ts`.
 * Así que el gate viaja en el HTML servido:
 *
 *     curl -s https://<host>/oficio | grep -o data-contacto-provisorio | wc -l
 *
 * ⚠️ EL ATRIBUTO SE PONE CON UN SPREAD CONDICIONAL Y NO CON UN TERNARIO A
 * `undefined`, Y ESA DIFERENCIA ES TODO EL GATE.
 *
 * `data-x={cond ? 'true' : undefined}` **no alcanza**. React omite el atributo
 * en el DOM, sí, pero el App Router además serializa el payload RSC adentro del
 * mismo HTML, y ahí la prop viaja igual: `"data-contacto-provisorio":
 * "$undefined"`. O sea que el `curl … | grep` encuentra el string **en los dos
 * estados** y el gate no distingue nada.
 *
 * No es teórico: se midió con la constante en `false` y el `grep -c` seguía
 * dando **1**. Con el spread la clave no existe en el objeto de props, así que
 * no está ni en el DOM ni en el payload — medido, **0**.
 *
 * Y el comando se cuenta con `grep -o … | wc -l`, no con `grep -c`: el HTML de
 * Next viene en UNA sola línea, y `grep -c` cuenta líneas con coincidencia, así
 * que devuelve 1 aunque el atributo aparezca cinco veces.
 *
 * `EscenaSeleccion` resolvió lo suyo con `data-muestra`, pero ese atributo es
 * incondicional: este es el primero que tiene que APAGARSE, y por eso el
 * problema aparece acá primero.
 */

export function SelloDeContacto() {
  return (
    <section
      className="sello cartucho-deco cartucho-deco--trazado"
      id="mostrador"
      aria-labelledby="mostrador-rotulo"
      {...(EL_CONTACTO_ES_PROVISORIO
        ? { 'data-contacto-provisorio': 'true' }
        : {})}
    >
      <p className="rotulo sello__rotulo" id="mostrador-rotulo">
        {SELLO.rotulo}
      </p>

      <p className="display sello__linea">{SELLO.linea}</p>

      <hr className="filete filete--corto" />

      <div className="sello__canales">
        {SELLO.canales.map((canal) => (
          <a key={canal.href} href={canal.href}>
            {canal.texto}
          </a>
        ))}
      </div>

      <p className="sello__pendiente">{SELLO.pendiente}</p>
    </section>
  );
}
