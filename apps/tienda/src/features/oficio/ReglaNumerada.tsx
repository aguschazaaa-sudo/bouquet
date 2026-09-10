/* El filete de ancho completo PARTIDO por el numeral romano.
 *
 * Es la hoja de la sección: no sabe qué tramo dibuja, ni cómo se llama, ni qué
 * dice. Recibe el número y si la marca firma ese tramo, y con eso alcanza.
 *
 * ⚠️ POR QUÉ EL NUMERAL VA EN EL MEDIO DE LA REGLA Y NO ARRIBA DE ELLA. Un
 * número apoyado sobre una línea es una viñeta de lista; uno que la INTERRUMPE
 * es un capítulo. Es el gesto de una tarjeta impresa de 1925, y es la pieza que
 * `direccion.md §5.1` autoriza —la regla de un solo trazo— usada como
 * estructura y no como adorno.
 *
 * ⚠️ Y POR QUÉ LOS BRAZOS SON `<span>` Y NO `<hr>`, que es lo que hacía la
 * maqueta: son las DOS MITADES de una sola regla, no dos separadores temáticos.
 * Con `<hr>` un lector de pantalla anuncia "separador, separador" alrededor de
 * cada numeral —seis veces en la página— y el corte temático real ya lo dice el
 * `<section>` de cada tramo. El dibujo es idéntico: `.filete` de `deco.css` no
 * pide un elemento en particular, pinta con `::before` y `::after`.
 */

type Props = {
  /** El romano, tal como se lee: `I`, `II`, `III`. */
  numeral: string;
  /**
   * Si la marca firma el tramo. El numeral hueco y el filete atenuado son dos
   * de los tres recursos que marcan el tramo sin firma, y los dibuja este
   * componente: por eso el booleano baja hasta acá en vez de resolverse con un
   * selector de ancestro. El tercero —el nombre del tramo— es de `Tramo`.
   */
  firmado: boolean;
};

export function ReglaNumerada({ numeral, firmado }: Props) {
  return (
    <div className={`tramo__regla${firmado ? '' : ' tramo__regla--sin-firma'}`}>
      <span className="filete filete--brazo filete--izq" aria-hidden="true" />
      <p className="tramo__numeral">{numeral}</p>
      <span className="filete filete--brazo filete--der" aria-hidden="true" />
    </div>
  );
}
