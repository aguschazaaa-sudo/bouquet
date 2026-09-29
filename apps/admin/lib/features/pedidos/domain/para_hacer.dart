import '../../../core/contratos/estado_entrega.dart';
import '../../../core/contratos/estado_pago.dart';
import '../../../core/contratos/estado_publico.dart';

/// Un tramo de la consulta de *Para hacer* (ADR 027, antes *"Requieren acción"*
/// de HU-06.3): un estado de entrega y, si no son todos, los estados de pago que
/// lo traen a la ficha.
///
/// [pagos] es `null` cuando entran **todos** los pagos de ese estado: la
/// consulta no filtra por pago y cuesta un disjunto en vez de seis.
class TramoParaHacer {
  const TramoParaHacer({required this.entrega, this.pagos});

  final EstadoEntrega entrega;
  final List<EstadoPago>? pagos;

  /// Cuantos disjuntos le suma a la consulta: Firestore expande el `in` y
  /// admite hasta 30 en total.
  int get disjuntos => pagos?.length ?? 1;
}

/// Los estados de entrega que entran **enteros** en *Para hacer*, con cualquier
/// pago: lo que todavia no salio -`preparando` es de antes de ADR 027 y espera
/// lo mismo- y lo que volvio sin entregar. Un pedido de la tienda que todavia
/// espera el pago tambien esta aca: el detalle dice que falta, y asi no queda
/// en ninguna ficha.
const entregasParaHacer = {
  EstadoEntrega.sin_preparar,
  EstadoEntrega.preparando,
  EstadoEntrega.fallida,
};

/// Los tramos que arman la consulta: los de [entregasParaHacer] enteros, y de
/// los demas estados **los pares que la proyeccion marca con accion**
/// (`estadosPublicosQueRequierenAccion`: entregado sin cobrar, cancelado con
/// pago). Sacados de la proyeccion, no escritos a mano: si ADR 002 cambia la
/// tabla, la consulta cambia sola.
///
/// En el orden de `EstadoEntrega.values`, y los pagos en el de
/// `EstadoPago.values`: la consulta sale igual cada vez.
List<TramoParaHacer> tramosParaHacer() => [
  for (final entrega in EstadoEntrega.values)
    if (entregasParaHacer.contains(entrega))
      TramoParaHacer(entrega: entrega)
    else if (_pagosQueRequierenAccion(entrega) case final pagos
        when pagos.isNotEmpty)
      TramoParaHacer(
        entrega: entrega,
        pagos: pagos.length == EstadoPago.values.length ? null : pagos,
      ),
];

List<EstadoPago> _pagosQueRequierenAccion(EstadoEntrega entrega) => [
  for (final pago in EstadoPago.values)
    if (estadosPublicosQueRequierenAccion.contains(
      proyectarEstadoPublico(pago, entrega),
    ))
      pago,
];
