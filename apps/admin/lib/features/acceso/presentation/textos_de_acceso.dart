import '../domain/repositorio_de_sesion.dart';

/// Lo que dice la pantalla cuando no se pudo entrar. Para gente no tecnica:
/// que paso y que hacer, sin codigos.
String textoDelError(ErrorDeEntrada error) => switch (error) {
  ErrorDeEntrada.credencialesInvalidas =>
    'El mail o la contraseña no coinciden. Si nunca creaste una contraseña, '
        'usá el enlace de abajo.',
  ErrorDeEntrada.mailInvalido => 'Ese mail no parece estar bien escrito.',
  ErrorDeEntrada.cuentaDeshabilitada =>
    'Esta cuenta está suspendida. Hablá con el dueño de la tienda.',
  ErrorDeEntrada.demasiadosIntentos =>
    'Hubo demasiados intentos seguidos. Esperá unos minutos y probá de nuevo.',
  ErrorDeEntrada.sinConexion =>
    'No hay conexión. Revisá internet y probá de nuevo.',
  ErrorDeEntrada.ventanaBloqueada =>
    'El navegador bloqueó la ventana de Google. Permití las ventanas '
        'emergentes para este sitio y probá de nuevo.',
  ErrorDeEntrada.sitioNoHabilitado =>
    'Desde esta dirección no se puede entrar con Google. Entrá con tu mail, '
        'o abrí el panel desde bouquet-vinos.web.app.',
  ErrorDeEntrada.metodoNoHabilitado =>
    'Esta forma de entrar no está habilitada. Avisale al desarrollador.',
  ErrorDeEntrada.desconocido =>
    'Algo falló y no sabemos qué. Probá de nuevo en un rato; si sigue, '
        'avisale al desarrollador.',
};

const textoMailEnviado =
    'Si ese mail tiene acceso, te mandamos un correo para crear o cambiar la '
    'contraseña. Revisá también el correo no deseado.';

const textoFaltanDatos = 'Escribí tu mail y tu contraseña.';

const textoFaltaMail = 'Escribí tu mail.';
