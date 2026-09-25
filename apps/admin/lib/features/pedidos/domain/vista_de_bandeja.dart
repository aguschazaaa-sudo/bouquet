import '../../../core/contratos/estado_entrega.dart';

/// Que mira la bandeja: lo que espera algo del operador (HU-06.3), o un estado
/// de entrega (HU-06.1). Es la clave de la familia del provider, asi que
/// **tiene igualdad por valor**: dos `DeUnEstado(sin_preparar)` son la misma
/// bandeja, y volver a elegirla no la relee.
sealed class VistaDeBandeja {
  const VistaDeBandeja();

  /// Las vistas en el orden de las fichas: *"Requieren acción"* primero, que es
  /// con la que abre la pantalla.
  static final List<VistaDeBandeja> todas = List.unmodifiable([
    const RequierenAccion(),
    for (final e in EstadoEntrega.values) DeUnEstado(e),
  ]);
}

/// Lo que espera algo del operador, de cualquier estado (HU-06.3).
class RequierenAccion extends VistaDeBandeja {
  const RequierenAccion();

  @override
  bool operator ==(Object other) => other is RequierenAccion;

  @override
  int get hashCode => (RequierenAccion).hashCode;
}

/// Los pedidos de un estado de entrega (HU-06.1).
class DeUnEstado extends VistaDeBandeja {
  const DeUnEstado(this.estado);

  final EstadoEntrega estado;

  @override
  bool operator ==(Object other) =>
      other is DeUnEstado && other.estado == estado;

  @override
  int get hashCode => Object.hash(DeUnEstado, estado);
}
