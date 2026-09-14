/* La botella dibujada, para el vino que todavía no tiene foto.
 *
 * Monolineal, como pide direccion.md §6 para los pocos íconos que hay, y a la
 * misma altura que ocuparía la foto: la grilla no se desarma porque a un vino
 * le falte la imagen. Es un estado que el diseño tiene que aguantar, no un
 * error (specs/vidriera-ficha: "nunca una imagen rota").
 */

export function SiluetaDeBotella() {
  return (
    <svg className="silueta-botella" viewBox="0 0 64 220" fill="none" aria-hidden="true" focusable="false">
      <path
        vectorEffect="non-scaling-stroke"
        d="M27 4V52C27 66 10 74 10 94V212Q10 216 14 216H50Q54 216 54 212V94C54 74 37 66 37 52V4Z"
      />
      <path vectorEffect="non-scaling-stroke" d="M27 30H37M10 132H54M10 176H54" />
    </svg>
  );
}
