/* La silueta de la botella, de trazo constante.
 *
 * ⚠️ ESTE ENCABEZADO CITABA UNA LÍNEA DEL VAULT QUE ES FALSA.
 * Decía: *"direccion.md §1: el isotipo es una copa de trazo de grosor
 * CONSTANTE. Todo lo dibujado que la acompañe —reglas, marcos, íconos— tiene
 * que ser monolineal o pelea con la marca."*
 *
 * Medido sobre la máscara dorada del PNG del logo con la transformada de
 * distancia (`scripts/assets/generar_copa.py`, 1313 muestras de cresta): el
 * ancho de trazo va de 44px (p05) a 61px (p95), **razón 1,38**. Un monolineal
 * daría ~1,00. El isotipo modula.
 *
 * El dibujo de acá se deja monolineal igual, y ahora por una razón propia y no
 * por una regla heredada: es una silueta esquemática de repuesto, no la marca.
 * Quien cita a la marca es `components/marca/Copa.tsx`, que usa los paths
 * reales del imagotipo.
 *
 * Por qué dibujo y no foto: seis fotos de botella con recorte consistente
 * —misma altura, misma perspectiva, misma luz— no existen como stock, y
 * conseguirlas exige producción propia. El dibujo no lo mitiga: lo elimina.
 * Es el mismo argumento con el que escenas.md resolvió el par de copas.
 *
 * ⚠️ Es un marcador de posición con criterio, no la solución final. Cuando
 * existan las fotos propias del catálogo, la ventana de la tarjeta las recibe
 * sin tocar el resto de la composición: por eso el recorte es 9:16 y no
 * cuadrado.
 */

/** Las dos formas que cubren casi todo el vino argentino. */
export type FormaDeBotella = 'bordelesa' | 'borgonona';

const SILUETAS: Record<FormaDeBotella, string> = {
  // Hombro abrupto: cabernet, malbec, merlot, bordeaux en general.
  bordelesa:
    'M50 10 L50 96 C50 118 26 126 26 158 L26 378 Q26 392 40 392 ' +
    'L80 392 Q94 392 94 378 L94 158 C94 126 70 118 70 96 L70 10 Z',
  // Hombro caído: pinot noir, chardonnay, borgoña en general.
  borgonona:
    'M52 10 L52 88 C52 132 24 152 24 206 L24 378 Q24 392 38 392 ' +
    'L82 392 Q96 392 96 378 L96 206 C96 152 68 132 68 88 L68 10 Z',
};

type Props = {
  forma: FormaDeBotella;
  /**
   * Qué tan llena se dibuja, 0 a 1. Es materia, no un dato: una botella
   * cerrada está llena hasta la base del cuello, y dibujarla por la mitad la
   * hace leer como abierta. Con 1 el vino llega a y=100, justo bajo el hombro.
   */
  nivel?: number;
};

export function BotellaSvg({ forma, nivel = 0.94 }: Props) {
  const alturaLiquido = 392 - (392 - 100) * nivel;

  return (
    <svg
      viewBox="0 0 120 400"
      role="presentation"
      aria-hidden="true"
      className="botella"
      fill="none"
    >
      <defs>
        <clipPath id={`corte-${forma}`}>
          <path d={SILUETAS[forma]} />
        </clipPath>
      </defs>

      {/* El vidrio. El color lo pone la CSS desde los tokens, según varietal. */}
      <path d={SILUETAS[forma]} className="botella__vidrio" />

      {/* El vino adentro, recortado contra la silueta. */}
      <rect
        x="0"
        y={alturaLiquido}
        width="120"
        height={392 - alturaLiquido}
        clipPath={`url(#corte-${forma})`}
        className="botella__liquido"
      />

      {/* El contorno monolineal: grosor constante, como el isotipo. */}
      <path d={SILUETAS[forma]} className="botella__trazo" />

      {/* La cápsula. Una sola línea, del mismo grosor. */}
      <line x1="50" y1="52" x2="70" y2="52" className="botella__trazo" />

      {/* El cartucho de la etiqueta, vacío a propósito: la marca de la bodega
          no se dibuja, se nombra en el texto de la tarjeta. */}
      <rect
        x="33"
        y="238"
        width="54"
        height="86"
        className="botella__etiqueta"
      />
    </svg>
  );
}
