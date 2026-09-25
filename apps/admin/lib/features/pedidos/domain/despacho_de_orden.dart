import '../../../core/contratos/despacho.dart';

// Lo que una Orden guarda de los pasos del eje de entrega (EP-07, ADR 019):
// por donde salio, por que no se entrego, por que se cancelo. Cada uno lo
// escribe UN paso y ningun otro: las reglas lo miden.

/// `despacho`: lo escribe el panel al despachar, y otra vez al volver a
/// despachar tras una entrega fallida.
class DespachoDeOrden {
  const DespachoDeOrden({required this.correo, this.seguimiento, this.en});

  final Correo correo;

  /// Opcional: una entrega en mano no tiene.
  final String? seguimiento;

  /// La hora **del servidor**.
  final DateTime? en;
}

/// `entregaFallida`: el motivo de la ultima entrega que no se pudo hacer.
/// **Queda escrita** aunque el pedido se vuelva a despachar.
class EntregaFallida {
  const EntregaFallida({required this.motivo, this.en});

  final MotivoDeFalla motivo;
  final DateTime? en;
}

/// Una linea que **no volvio al stock** al cancelar, con su motivo. La
/// resuelve una persona.
class LineaSinReponer {
  const LineaSinReponer({
    required this.productoId,
    required this.nombre,
    required this.cantidad,
    this.motivo,
  });

  final String productoId;
  final String nombre;

  /// Unidades de venta.
  final int cantidad;

  /// `null` si el documento trae un motivo que este panel no conoce: la linea
  /// se muestra igual.
  final MotivoSinReponer? motivo;
}

/// `cancelacion`: la escribe **solo** la callable `cancelarOrden`, en la misma
/// transaccion que devuelve el stock.
class CancelacionDeOrden {
  const CancelacionDeOrden({this.motivo, this.en, this.sinReponer = const []});

  final MotivoDeCancelacion? motivo;
  final DateTime? en;

  /// Vacio en el caso normal: todo volvio.
  final List<LineaSinReponer> sinReponer;
}
