import '../../../core/contratos/stock.dart';

/// Un movimiento de stock ya hecho: lo que `moverStock` dejó guardado en
/// `productos/{id}/movimientos/{idMovimiento}` (HU-05.4, ADR 016 §3 y §6).
///
/// Es sólo lectura: el panel no crea, corrige ni borra movimientos, lo dicen
/// las reglas.
class MovimientoDeStock {
  const MovimientoDeStock({
    required this.id,
    required this.en,
    required this.antes,
    required this.despues,
    required this.operacion,
    required this.esMio,
  });

  final String id;

  /// La hora **del servidor**. `null` sólo si el documento no la trae.
  final DateTime? en;

  /// El stock antes y después, en unidades de venta. `null` si el documento
  /// no los trae como números: se muestra, pero sin cuentas.
  final int? antes;
  final int? despues;

  /// Qué se hizo. `null` si es de una forma que este panel no conoce: un
  /// movimiento de una versión más nueva se muestra igual, sin detalle.
  final OperacionDeStock? operacion;

  /// Lo hizo quien está mirando. El movimiento guarda el uid y nada más:
  /// **no hay forma de decir el nombre de otra persona**, así que la pantalla
  /// distingue *vos* de *otra persona*.
  final bool esMio;
}
