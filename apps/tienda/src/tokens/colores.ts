/* El espejo en TypeScript de los colores que un literal de CSS no alcanza.
 *
 * Existe por un caso concreto: `metadata.themeColor` de Next se serializa a
 * una etiqueta <meta> en el HTML, así que necesita una cadena, no una
 * `var(--tinta)`. Lo mismo va a pasar con cualquier otro valor que salga del
 * documento en vez de la hoja de estilos (Open Graph, un SVG generado, el
 * fondo de un PDF de comprobante).
 *
 * ⚠️ ES UN ESPEJO, Y LOS ESPEJOS SE DESINCRONIZAN. La fuente sigue siendo
 * `tokens.css`. Si alguien cambia el fondo allá y no acá, la barra del
 * navegador queda de otro color que la página y nadie lo va a notar hasta que
 * lo vea en un teléfono.
 *
 * Se verifica así, y tiene que devolver la misma cadena de los dos lados:
 *     grep -o '\--tinta: #[0-9a-f]*' apps/tienda/src/tokens/tokens.css
 *     grep -o "tinta: '#[0-9a-f]*'"  apps/tienda/src/tokens/colores.ts
 *
 * Pendiente, con disparador: cuando aparezca el segundo o el tercer valor
 * espejado, esto deja de ser un archivo a mano y pasa a generarse desde
 * tokens.css, igual que `_verdad.md` se genera desde el código. Con uno solo
 * no paga el generador.
 */

export const COLORES = {
  /** El fondo del modo cava. Espejo de `--tinta` en tokens.css. */
  tinta: '#1a1210',
} as const;
