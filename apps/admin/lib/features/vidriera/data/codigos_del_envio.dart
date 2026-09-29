import '../../stock/data/codigos_de_stock.dart' show esDeRed;
import '../domain/envio_sin_cargo.dart';

/// Traduce el `code` de un `HttpsError` de `fijarEnvioSinCargo` a un
/// [FalloDelEnvio].
///
/// **Dart puro, sin el SDK de Functions**, como `codigos_de_las_cajas.dart`:
/// `cloud_functions` depende de Flutter y `dart test` no lo carga. Se prueba
/// contra lo que lanza `functions/src/config/fijar.ts`.
FalloDelEnvio falloDelEnvio(String codigo) => switch (codigo) {
  'unauthenticated' ||
  'permission-denied' => FalloDelEnvio(ErrorDelEnvio.sinPermiso, codigo: codigo),
  'invalid-argument' => FalloDelEnvio(ErrorDelEnvio.noValido, codigo: codigo),
  _ => FalloDelEnvio(
    esDeRed(codigo) ? ErrorDelEnvio.sinConexion : ErrorDelEnvio.desconocido,
    codigo: codigo,
  ),
};
