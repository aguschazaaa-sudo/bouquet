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

/// Traduce un rechazo de `cancelarOrden` (HU-07.6). Otra callable, otros
/// codigos: un `not-found` aca es el PEDIDO, no un vino.
FalloDePedidos falloDeCancelar(String codigo, Object? detalles) {
  switch (codigo) {
    case 'unauthenticated' || 'permission-denied':
      return FalloDePedidos(ErrorDePedido.sinPermiso, codigo: codigo);
    case 'not-found':
      // Solo con el `codigo` que manda `cancelar.ts` es el PEDIDO. Un `not-found`
      // pelado es la callable que no existe -un panel publicado antes que la
      // funcion-, y decir "este pedido ya no existe" seria falso (hallazgo de
      // `revisor-pagos`, ADR 019).
      final esElPedido = detalles is Map && detalles['codigo'] == 'no-existe';
      return FalloDePedidos(
        esElPedido
            ? ErrorDePedido.pedidoInexistente
            : ErrorDePedido.desconocido,
        codigo: codigo,
      );
    case 'invalid-argument':
      return FalloDePedidos(ErrorDePedido.datosInvalidos, codigo: codigo);
    case 'failed-precondition':
      final error = switch (detalles is Map ? detalles['codigo'] : null) {
        'ya-salio' => ErrorDePedido.yaSalio,
        'orden-rota' => ErrorDePedido.pedidoRoto,
        _ => ErrorDePedido.desconocido,
      };
      return FalloDePedidos(error, codigo: codigo);
    default:
      return FalloDePedidos(
        esDeRed(codigo) ? ErrorDePedido.sinConexion : ErrorDePedido.desconocido,
        codigo: codigo,
      );
  }
}

/// Traduce el error de una ESCRITURA directa en la Orden (EP-07). Las reglas
/// contestan `permission-denied` tanto a una cuenta sin permiso como a un paso
/// que ya no vale desde el estado de ahora; el panel solo ofrece pasos validos
/// desde lo que muestra, asi que lo probable es lo segundo, y la pantalla
/// vuelve a leer el pedido en los dos casos.
FalloDePedidos falloDeEscritura(String codigo) =>
    FalloDePedidos(switch (codigo) {
      'permission-denied' => ErrorDePedido.cambioElPedido,
      'not-found' => ErrorDePedido.pedidoInexistente,
      _ when esDeRed(codigo) => ErrorDePedido.sinConexion,
      _ => ErrorDePedido.desconocido,
    }, codigo: codigo);

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
