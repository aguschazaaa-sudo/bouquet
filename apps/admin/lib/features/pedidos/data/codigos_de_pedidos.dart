import '../domain/fallo_de_pedidos.dart';

/// Traduce el par `(code, details)` de un `HttpsError` de `crearOrdenDelPanel` a
/// un [FalloDePedidos].
///
/// **Dart puro, sin el SDK de Functions**, a proposito: `cloud_functions`
/// depende de Flutter y `dart test` no lo puede cargar, asi que el adaptador
/// (`fallos_de_pedidos.dart`) solo saca el codigo y los detalles de la
/// excepcion y llama a esto. Es la unica parte con logica, y es la que se
/// prueba -- contra los codigos que `functions/src/pedidos/crear.ts` lanza de
/// verdad (`test/features/pedidos/codigos_de_pedidos_test.dart`).
FalloDePedidos falloDesdeLaCallable(String codigo, Object? detalles) {
  switch (codigo) {
    case 'unauthenticated' || 'permission-denied':
      return FalloDePedidos(ErrorDePedido.sinPermiso, codigo: codigo);
    case 'not-found':
      return FalloDePedidos(
        ErrorDePedido.noExiste,
        productoId: _productoId(detalles),
        codigo: codigo,
      );
    case 'already-exists':
      // Trae `{ codigo: 'otro-pedido', numero }`: la Orden que ya existe.
      final numero = detalles is Map ? detalles['numero'] : null;
      return FalloDePedidos(
        ErrorDePedido.yaEstaHecho,
        numero: numero is num ? numero.toInt() : null,
        codigo: codigo,
      );
    case 'invalid-argument':
      return FalloDePedidos(ErrorDePedido.datosInvalidos, codigo: codigo);
    case 'failed-precondition':
      // La callable manda `details: { codigo, productoId, actual?, motivo? }`.
      // Sin ellos es un rechazo que este panel no sabe nombrar.
      if (detalles is Map) {
        final error = switch (detalles['codigo']) {
          'sin-stock' => ErrorDePedido.sinStock,
          'cambio-el-precio' => ErrorDePedido.cambioElPrecio,
          'de-muestra' => ErrorDePedido.deMuestra,
          'compuesto' => ErrorDePedido.compuesto,
          'sin-precio' => ErrorDePedido.sinPrecio,
          'producto-roto' => ErrorDePedido.productoRoto,
          'no-existe' => ErrorDePedido.noExiste,
          _ => null,
        };
        if (error != null) {
          final actual = detalles['actual'];
          return FalloDePedidos(
            error,
            productoId: _productoId(detalles),
            // En la web un entero puede llegar como double.
            actual: actual is num ? actual.toInt() : null,
            codigo: codigo,
          );
        }
      }
      return FalloDePedidos(ErrorDePedido.desconocido, codigo: codigo);
    default:
      return FalloDePedidos(
        esDeRed(codigo) ? ErrorDePedido.sinConexion : ErrorDePedido.desconocido,
        codigo: codigo,
      );
  }
}

String? _productoId(Object? detalles) {
  if (detalles is! Map) return null;
  final id = detalles['productoId'];
  return id is String ? id : null;
}

/// Los codigos que dicen "no llego", no "me dijeron que no".
bool esDeRed(String? codigo) => switch (codigo) {
  'unavailable' ||
  'deadline-exceeded' ||
  'cancelled' ||
  'canceled' ||
  'retry-limit-exceeded' => true,
  _ => false,
};
