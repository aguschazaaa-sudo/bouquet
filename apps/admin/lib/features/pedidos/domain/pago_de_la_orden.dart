/// Lo que Mercado Pago dijo del cobro de una Orden, la ULTIMA vez que el
/// servidor le pregunto (HU-08.1, ADR 022). Lo escribe **solo** el servidor,
/// en `ordenes/{id}.pago`, la primera vez que aplica una consulta.
///
/// Ausente hasta esa primera consulta: un pedido de WhatsApp (`origen ==
/// whatsapp`, `estadoPago == por_fuera`) nunca lo tiene, porque nadie le
/// pregunta nada a Mercado Pago por el.
class PagoDeLaOrden {
  const PagoDeLaOrden({
    required this.proveedor,
    required this.operacionId,
    required this.estadoDelProveedor,
    required this.detalle,
    required this.monto,
    this.reembolsado = 0,
    this.consultadoEn,
  });

  /// Quien cobro. Hoy solo `'mercadopago'`; se deja como texto, no como un
  /// enum de un solo valor.
  final String proveedor;

  /// El numero de operacion del proveedor. Es lo que se concilia (HU-08.1):
  /// la pantalla lo muestra tal cual, no lo interpreta.
  final String operacionId;

  /// El estado CRUDO del proveedor (`approved`, `in_process`, `rejected`...).
  /// **No es** el `EstadoPago` de la Orden: ese lo traduce el servidor segun
  /// la tabla de transiciones (ADR 002) y puede no moverse aunque este
  /// cambie.
  final String estadoDelProveedor;

  /// El detalle crudo del proveedor (`accredited`, `cc_rejected_high_risk`...).
  /// `null` si no trajo uno.
  final String? detalle;

  /// Lo que el proveedor dice que se cobro. Centavos, entero.
  final int monto;

  /// Lo que ya se devolvio de ese pago, en centavos (0 si nada). Un reembolso
  /// PARCIAL deja el pago acreditado y mueve solo esto (ADR 022 §3).
  final int reembolsado;

  /// La hora DEL SERVIDOR de la ultima consulta. `null` solo si el documento
  /// no la trae: se perdona, como `despacho.en`.
  final DateTime? consultadoEn;
}
