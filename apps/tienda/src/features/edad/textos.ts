/* El copy del telón. La pregunta, la línea del documento y los dos botones
 * salen tal cual de voz.md §9.1, que ya los tenía curados: la segunda línea
 * convierte una barrera legal en una señal de que el negocio está en regla, y
 * `Todavía no` dice que la puerta se va a poder abrir algún día.
 *
 * La respuesta a `Todavía no` se escribió con este componente y la revisó
 * `voz`; quedó en §9.1 junto al resto. Sin reproche y sin cerrar la puerta:
 * el hecho y la salida, igual que §9.7. */

export const TEXTOS = {
  marca: 'bouquet',
  titulo: 'Para entrar hay que ser mayor de 18.',
  documento: 'En la entrega se pide documento. Es la ley, y también es la parte fácil.',
  soyMayor: 'Soy mayor de 18',
  todaviaNo: 'Todavía no',

  rechazoTitulo: 'Entonces, todavía no.',
  rechazo: 'Volvé cuando cumplas 18. Vamos a seguir acá.',
  meEquivoque: 'Me equivoqué',
} as const;
