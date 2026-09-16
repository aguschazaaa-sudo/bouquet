import '../domain/repositorio_de_sesion.dart';

/// Traduce un codigo de `FirebaseAuthException` a lo que entiende la
/// pantalla.
///
/// Devuelve `null` cuando NO es un error que mostrar: la persona cerro la
/// ventana de Google. Mostrarle "algo fallo" por cerrar una ventana es
/// mentirle.
///
/// Es Dart puro a proposito: se prueba con `dart test`, que corre en la
/// maquina de desarrollo, y no con `flutter test`, que no.
ErrorDeEntrada? errorDeEntradaPara(String codigo) => switch (codigo) {
  // Con la proteccion contra enumeracion de mails prendida (lo esta en
  // bouquet-vinos), Firebase responde `invalid-credential` para las dos
  // cosas. Los otros tres son los de proyectos sin esa proteccion y los del
  // emulador.
  'invalid-credential' ||
  'invalid-login-credentials' ||
  'wrong-password' ||
  'user-not-found' ||
  'missing-password' => ErrorDeEntrada.credencialesInvalidas,
  'invalid-email' || 'missing-email' => ErrorDeEntrada.mailInvalido,
  'user-disabled' => ErrorDeEntrada.cuentaDeshabilitada,
  'too-many-requests' => ErrorDeEntrada.demasiadosIntentos,
  'network-request-failed' => ErrorDeEntrada.sinConexion,
  'popup-blocked' => ErrorDeEntrada.ventanaBloqueada,
  'popup-closed-by-user' ||
  'cancelled-popup-request' ||
  'web-context-canceled' => null,
  'unauthorized-domain' ||
  'unauthorized-continue-uri' => ErrorDeEntrada.sitioNoHabilitado,
  'operation-not-allowed' => ErrorDeEntrada.metodoNoHabilitado,
  _ => ErrorDeEntrada.desconocido,
};
