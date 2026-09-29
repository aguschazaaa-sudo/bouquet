import '../../stock/data/codigos_de_stock.dart' show esDeRed;
import '../domain/fallo_de_las_cajas.dart';

/// Traduce el par `(code, details)` de un `HttpsError` de
/// `guardarCajasSugeridas` a un [FalloDeLasCajas].
///
/// **Dart puro, sin el SDK de Functions**, como `codigos_de_stock.dart`:
/// `cloud_functions` depende de Flutter y `dart test` no lo carga. El
/// adaptador (`fallos_de_las_cajas.dart`) solo saca el codigo y los detalles;
/// la logica esta aca y se prueba contra lo que lanza
/// `functions/src/vidriera/guardar.ts`.
FalloDeLasCajas falloDeLasCajas(String codigo, Object? detalles) {
  final caja = detalles is Map && detalles['caja'] is String
      ? detalles['caja'] as String
      : null;
  return switch (codigo) {
    'unauthenticated' || 'permission-denied' => FalloDeLasCajas(
      ErrorDeLasCajas.sinPermiso,
      codigo: codigo,
    ),
    'failed-precondition' => FalloDeLasCajas(
      ErrorDeLasCajas.noCierra,
      caja: caja,
      codigo: codigo,
    ),
    'invalid-argument' => FalloDeLasCajas(
      ErrorDeLasCajas.noValida,
      codigo: codigo,
    ),
    _ => FalloDeLasCajas(
      esDeRed(codigo) ? ErrorDeLasCajas.sinConexion : ErrorDeLasCajas.desconocido,
      codigo: codigo,
    ),
  };
}
