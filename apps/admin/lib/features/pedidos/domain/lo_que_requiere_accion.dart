import '../../../core/contratos/estado_entrega.dart';
import '../../../core/contratos/estado_pago.dart';
import '../../../core/contratos/estado_publico.dart';

/// Un tramo de la consulta de *"Requieren acción"* (HU-06.3): un estado de
/// entrega y, si no son todos, los estados de pago que lo hacen esperar algo del
/// operador.
///
/// [pagos] es `null` cuando **todos** los pagos de ese estado requieren acción
/// (hoy, `fallida`): la consulta no filtra por pago y cuesta un disjunto en vez
/// de seis.
class TramoQueRequiereAccion {
  const TramoQueRequiereAccion({required this.entrega, this.pagos});

  final EstadoEntrega entrega;
  final List<EstadoPago>? pagos;

  /// Cuantos disjuntos le suma a la consulta: Firestore expande el `in` y
  /// admite hasta 30 en total.
  int get disjuntos => pagos?.length ?? 1;
}

/// Los tramos que arman la consulta, **sacados de la proyeccion**, no escritos a
/// mano: un par que requiere accion es uno cuyo `proyectarEstadoPublico` cae en
/// `estadosPublicosQueRequierenAccion`. Si ADR 002 cambia la tabla o el
/// conjunto, la consulta cambia sola; dos listas del mismo dato se
/// desincronizan.
///
/// En el orden de `EstadoEntrega.values`, y los pagos en el de
/// `EstadoPago.values`: la consulta sale igual cada vez.
List<TramoQueRequiereAccion> tramosQueRequierenAccion() => [
  for (final entrega in EstadoEntrega.values)
    if (_pagosQueRequierenAccion(entrega) case final pagos
        when pagos.isNotEmpty)
      TramoQueRequiereAccion(
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
