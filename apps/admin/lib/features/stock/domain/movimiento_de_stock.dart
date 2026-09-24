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
    this.venta,
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

  /// Si el movimiento es una **venta** de `crearOrdenDelPanel` (ADR 018 §8) y
  /// no algo que el operador pidio: cuanto se vendio y de que pedido. Vive
  /// aparte de [operacion] a proposito: `OperacionDeStock` es lo que el operador
  /// PIDE a `moverStock`, y una venta no se pide desde una hoja.
  final VentaDePedido? venta;

  /// Lo hizo quien está mirando. El movimiento guarda el uid y nada más:
  /// **no hay forma de decir el nombre de otra persona**, así que la pantalla
  /// distingue *vos* de *otra persona*.
  final bool esMio;
}

/// Lo que una venta le saco al stock de un vino: cuantas unidades y de que
/// pedido (ADR 018 §8). Es el `operacion` de un movimiento `venta-<idPedido>`.
class VentaDePedido {
  const VentaDePedido({required this.cantidad, required this.numero});

  /// Unidades de venta que se vendieron.
  final int cantidad;

  /// El numero del pedido, el que dice el comprador. `null` si el movimiento no
  /// lo trae: se muestra la venta igual, sin numero.
  final int? numero;
}
