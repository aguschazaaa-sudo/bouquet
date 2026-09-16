import 'sesion.dart';

/// Por que no se pudo entrar, en terminos de la pantalla y no de Firebase.
enum ErrorDeEntrada {
  /// Mail o contrasena equivocados. Un solo caso a proposito: decir cual de
  /// los dos fallo le cuenta a un extrano que mails tienen cuenta.
  credencialesInvalidas,
  mailInvalido,
  cuentaDeshabilitada,
  demasiadosIntentos,
  sinConexion,
  ventanaBloqueada,

  /// La direccion desde la que se abrio el panel no esta entre los dominios
  /// autorizados de Auth. Pasa en los canales de preview con Google.
  sitioNoHabilitado,
  metodoNoHabilitado,
  desconocido,
}

/// Lo que lanza el repositorio cuando una operacion de acceso falla.
final class FalloDeEntrada implements Exception {
  const FalloDeEntrada(this.error, [this.codigo]);

  final ErrorDeEntrada error;

  /// El codigo crudo de Firebase, para el log. Nunca va a la pantalla.
  final String? codigo;

  @override
  String toString() => 'FalloDeEntrada($error, $codigo)';
}

/// Todo lo que el panel sabe hacer con una cuenta. La implementacion vive en
/// `data/`; las pantallas la piden por `acceso_providers.dart`.
abstract interface class RepositorioDeSesion {
  /// La sesion, cada vez que cambia: al entrar, al salir y al renovarse el
  /// token.
  Stream<Sesion> cambios();

  /// Lanza [FalloDeEntrada].
  Future<void> entrarConMail({
    required String mail,
    required String contrasena,
  });

  /// Devuelve `false` si la persona cerro la ventana sin elegir cuenta, que
  /// no es un error. Lanza [FalloDeEntrada].
  Future<bool> entrarConGoogle();

  /// Manda el correo para crear o cambiar la contrasena. No distingue un mail
  /// que no existe: la respuesta tiene que ser la misma. Lanza
  /// [FalloDeEntrada].
  Future<void> pedirMailDeContrasena(String mail);

  /// Renueva el token a la fuerza, para que llegue un claim recien dado.
  /// Lanza [FalloDeEntrada].
  Future<void> renovarPermiso();

  Future<void> salir();
}
