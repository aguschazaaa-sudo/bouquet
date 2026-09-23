import '../../../core/contratos/stock.dart';
import '../domain/fallo_de_stock.dart';

/// Traduce el par `(code, details)` de un `HttpsError` de `moverStock` a un
/// [FalloDeStock].
///
/// **Dart puro, sin el SDK de Functions**, a proposito: `cloud_functions`
/// depende de Flutter y `dart test` no lo puede cargar, asi que el adaptador
/// (`fallos_de_stock.dart`) solo saca el codigo y los detalles de la
/// excepcion y llama a esto. Es la unica parte con logica, y es la que se
/// prueba -- contra los codigos que `functions/src/stock/mover.ts` lanza de
/// verdad (`test/features/stock/codigos_de_stock_test.dart`).
FalloDeStock falloDesdeLaCallable(String codigo, Object? detalles) {
  switch (codigo) {
    case 'unauthenticated' || 'permission-denied':
      return FalloDeStock(ErrorDeStock.sinPermiso, codigo: codigo);
    case 'not-found':
      return FalloDeStock(ErrorDeStock.noExiste, codigo: codigo);
    case 'already-exists':
      return FalloDeStock(ErrorDeStock.yaEstaHecho, codigo: codigo);
    case 'failed-precondition':
      // La callable manda `details: { codigo, actual }` para los dos rechazos
      // de la cuenta. Sin ellos es un producto que no se puede mover.
      if (detalles is Map) {
        final rechazo = CodigoDeRechazo.desde(detalles['codigo']);
        final actual = detalles['actual'];
        if (rechazo != null) {
          return FalloDeStock(
            switch (rechazo) {
              CodigoDeRechazo.cambioElStock => ErrorDeStock.cambioElStock,
              CodigoDeRechazo.pasaElTope => ErrorDeStock.pasaElTope,
            },
            // En la web un entero puede llegar como double.
            actual: actual is num ? actual.toInt() : null,
            codigo: codigo,
          );
        }
      }
      return FalloDeStock(ErrorDeStock.noSePuede, codigo: codigo);
    default:
      return FalloDeStock(
        esDeRed(codigo) ? ErrorDeStock.sinConexion : ErrorDeStock.desconocido,
        codigo: codigo,
      );
  }
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
