/* oficio.ts — el contenido de la sección "El oficio", y nada más.
 *
 * POR QUÉ EL TEXTO NO VIVE ADENTRO DEL JSX, y son tres razones que apuntan al
 * mismo lado:
 *
 *   1. `widget-size-guard` bloquea presentación de más de 200 líneas, y esta
 *      sección tiene ~550 palabras de prosa. Con el texto adentro del
 *      componente, el componente nace bloqueado.
 *   2. Las verificaciones de voz son GREPS —dialecto de cata, exclamaciones,
 *      `tú`/`usted`—, y un grep necesita UN archivo al que apuntar, no cinco
 *      componentes.
 *   3. Es el patrón que `features/landing/seleccion.ts` ya usa.
 *
 * El copy salió de la maqueta que el dueño eligió MIRÁNDOLA —la carta numerada,
 * contra la etiqueta única— y pasó por el agente `voz`.
 *
 * ⚠️ LO QUE ESTA SECCIÓN NO PUEDE DECIR, y es la tesis de la página:
 * `voz.md §3.2` — *bouquet nunca firma una descripción sensorial del líquido
 * que no probó*. Todo lo que se afirma acá es un MECANISMO verificable
 * (amplitud térmica, paso por roble, temperatura de servicio, aire en la copa),
 * nunca un veredicto. El tramo III existe para decir en voz alta dónde termina
 * lo que la marca puede firmar, así que si alguien le agrega un adjetivo de
 * cata no rompe una regla de estilo: rompe el argumento de la página.
 */

/* ⚠️⚠️  EL CANAL DE CONTACTO ES PROVISORIO. BLOQUEA EL DEPLOY.  ⚠️⚠️
 *
 * El WhatsApp de abajo es el del DESARROLLADOR, no el del negocio, y el mail es
 * la forma que va a tener cuando exista el dominio: hoy no resuelve. Es el
 * mismo instrumento que usó la home con sus seis vinos inventados, hasta que
 * pasaron a salir del catálogo — una constante greppable, no una nota en un
 * documento que nadie relee.
 *
 * Se chequea desde los dos lados, y hacen falta los dos:
 *
 *     grep -rn "EL_CONTACTO_ES_PROVISORIO" apps/tienda/src   # el repo
 *     curl -s https://<host>/oficio | grep -o data-contacto-provisorio | wc -l
 *
 * El primero dice qué hay en el código de esta máquina. El segundo es el que
 * vale, porque `auditor-produccion` audita PRODUCCIÓN con `curl` y no puede
 * grepear un `.ts`: por eso `SelloDeContacto` emite el atributo en el HTML.
 * La home y /vinos emiten `data-catalogo-de-muestra` de la misma forma.
 *
 * Mientras dé `true`, esto no se publica. */
export const EL_CONTACTO_ES_PROVISORIO = true;

/* Un pedazo de párrafo. El objeto es la itálica: `.prosa em` ya la pinta.
 *
 * No se exporta: nadie afuera lo nombra —`Tramo.tsx` discrimina con un
 * `typeof`— y un `export` que nadie abre es exactamente lo que este proyecto
 * llama "escrito y no entregado". `Parrafo` sí se exporta y lo referencia; un
 * tipo exportado puede apoyarse en uno local sin problema. */
type Fragmento = string | { readonly enfasis: string };

/**
 * Un párrafo. Es un string salvo cuando lleva una itálica adentro, y entonces
 * es la lista de sus pedazos.
 *
 * No hay mini-lenguaje de marcado a propósito: un `*asterisco*` obliga a
 * escribir un parser, y un parser para once párrafos es más código que el texto
 * que interpreta.
 */
export type Parrafo = string | readonly Fragmento[];

export type Tramo = {
  /** El romano. Es contenido, no un contador de CSS: se lee en voz alta. */
  readonly numeral: string;
  /** El nombre del tramo. `Guardar` es donde `Custodia` bajó a rendir. */
  readonly nombre: string;
  readonly titulo: string;
  readonly parrafos: readonly Parrafo[];
  /**
   * ⚠️ Si la marca firma este tramo, y por qué vive en los DATOS y no en el
   * CSS: que haya un tramo sin firmar es la tesis de la página —"tres tramos,
   * firmamos dos"—, no un detalle de estilo. Un `.tramo--sin-firma` escrito a
   * mano en el JSX se puede borrar sin que nada se note; esto no.
   */
  readonly firmado: boolean;
};

export const APERTURA = {
  rotulo: 'El oficio',
  titulo: 'Tres tramos. Firmamos dos.',
  lead:
    'Entre la bodega y tu mesa hay tres tramos: el que elige, el que espera y ' +
    'el que se toma. Trabajamos los dos primeros. El tercero es tuyo, y no ' +
    'vamos a decirte cómo hacerlo.',
} as const;

export const TRAMOS: readonly Tramo[] = [
  {
    numeral: 'I',
    nombre: 'Elegir',
    titulo: 'No te decimos cuál es mejor. Te decimos con qué regla elegimos.',
    firmado: true,
    parrafos: [
      'Una recomendación sin criterio es una opinión disfrazada de dato. Así ' +
        'que en vez del veredicto publicamos la regla: si no estás de acuerdo ' +
        'con la regla, ya sabés que ese vino no es para vos.',
      'Elegimos por cosas que se pueden verificar, no por adjetivos. La altura ' +
        'del viñedo, porque la diferencia entre el día y la noche es la que ' +
        'hace la acidez. El paso por roble, que no es un sabor sino un ' +
        'intercambio lento de aire a través de la madera. Y si la botella está ' +
        'hecha para esperar o para abrirse este año, que es una decisión que la ' +
        'bodega ya tomó y se lee en cómo la hicieron.',
      [
        'Ninguna de las tres te dice si te va a gustar. Te dicen ',
        { enfasis: 'qué clase de vino es' },
        ', que es lo único que se puede saber sin abrirlo.',
      ],
    ],
  },
  {
    numeral: 'II',
    nombre: 'Guardar',
    titulo: 'El viaje dura meses, y casi todo pasa sin testigos.',
    firmado: true,
    parrafos: [
      'Desde que sale de la bodega hasta que la abrís pueden pasar seis meses ' +
        'o seis años. En el medio la botella cambia de manos cuatro o cinco ' +
        'veces: un camión, un depósito, otro camión, un salón de ventas. ' +
        'Ninguno de esos tramos aparece en la etiqueta.',
      'Cada uno tiene su forma de arruinarla. Un camión cerrado al sol de ' +
        'enero pasa los cuarenta grados adentro. Una góndola la deja parada ' +
        'abajo de un tubo encendido doce horas por día, que seca el corcho y ' +
        'descompone el vino al mismo tiempo.',
      'Y un depósito sin climatizar sigue a la calle. Acá la calle se mueve ' +
        'veinte grados entre la siesta y la madrugada: es la misma amplitud ' +
        'que en un viñedo de altura hace la acidez. Le da carácter a la uva y ' +
        'le hace daño a la botella. Córdoba es un buen lugar para tomar vino y ' +
        'uno difícil para dejarlo esperando.',
      'Por eso lo compramos, lo traemos y lo guardamos nosotros. Acostado, a ' +
        'temperatura pareja y sin luz, todos los meses que haga falta. No es ' +
        'una técnica. Es no soltarlo.',
    ],
  },
  {
    numeral: 'III',
    nombre: 'Abrir',
    titulo: 'Del tercer tramo sabemos tres cosas, y ninguna es sobre el gusto.',
    firmado: false,
    parrafos: [
      'La temperatura cambia más que casi todo lo demás, y casi siempre está ' +
        'mal. Un tinto servido a temperatura de living en verano llega diez ' +
        'grados más caliente de lo que le sirve, y el alcohol se adelanta a ' +
        'todo el resto. Veinte minutos en la heladera antes de abrirlo lo ' +
        'arreglan.',
      'El aire lo sigue cambiando adentro de la copa, y por eso el primer ' +
        'sorbo y el último no son el mismo vino. No hace falta decantador: ' +
        'alcanza con servir y esperar un rato.',
      'Y la copa importa por el tamaño, no por la marca. Lo que se busca es ' +
        'lugar arriba para que el aroma se junte.',
      'Ninguna de las tres te dice a qué sabe. Eso lo decidís vos. Y quién ' +
        'esté sentado va a cambiar el recuerdo más que cualquier cosa que ' +
        'hayamos hecho nosotros.',
    ],
  },
];

/* Un canal de contacto. Tampoco se exporta: sólo lo usa el `SELLO` de abajo,
 * en este mismo archivo. */
type Canal = {
  readonly href: string;
  readonly texto: string;
};

/* El cierre. `voz.md §4.2`: del otro lado hay una persona — así que el bloque
 * ofrece canales directos y NO ofrece un formulario. Un formulario dice lo
 * contrario de la única frase que este bloque tiene para decir. */
export const SELLO = {
  rotulo: 'El mostrador',
  linea: 'Del otro lado hay una persona.',
  canales: [
    /* ⚠️ Provisorios los dos: ver `EL_CONTACTO_ES_PROVISORIO` arriba. El número
     * va con espacios en el texto porque se lee, y sin ninguno en el `href`
     * porque `wa.me` no acepta separadores. */
    { href: 'https://wa.me/5493548600375', texto: 'WhatsApp +54 9 3548 60-0375' },
    { href: 'mailto:hola@bouquet.com.ar', texto: 'hola@bouquet.com.ar' },
  ] as readonly Canal[],
  pendiente: 'No hay formulario: escribís y contesta alguien.',
} as const;
