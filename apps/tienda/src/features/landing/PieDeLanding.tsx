/* El pie.
 *
 * Después del CTA no hay más ceremonia. Un filete dorado arriba, el wordmark
 * chico y el mínimo legal. Sin segundo CTA, sin oferta, sin newsletter: el
 * cierre es una exhalación, no otra insistencia.
 *
 * ⚠️ Lo legal es la única zona donde la dirección de lenguaje NO manda
 * (voz.md §12). La leyenda de abajo es la fórmula estándar; el resto de los
 * requisitos —inscripción en el INV, habilitación, política de datos— los
 * escribe quien corresponda y todavía están abiertos en ARQUITECTURA §11.
 *
 * ⚠️ Tampoco hay acá una promesa de entrega. voz.md §6 prohíbe "envío en 24
 * horas" salvo que la Zona lo garantice, y no existe todavía ni la entidad
 * Zona ni un dato que sostenga una ventana. Cuando exista, este pie es su
 * lugar.
 */

export function PieDeLanding() {
  return (
    <footer className="pie">
      <p className="pie__marca">bouquet</p>

      <p className="pie__legal">
        Beber con moderación. Prohibida su venta a menores de 18 años.
      </p>

      <p className="pie__legal">
        En la entrega se pide documento. Es la ley, y también es la parte fácil.
      </p>
    </footer>
  );
}
