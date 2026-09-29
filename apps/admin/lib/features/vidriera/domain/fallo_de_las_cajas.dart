/// Por que no se guardaron las cajas, en terminos de la pantalla.
enum ErrorDeLasCajas {
  /// La cuenta no tiene el rol, o la sesion vencio.
  sinPermiso,

  /// No llego: sin red, o la red no contesto a tiempo.
  sinConexion,

  /// Una caja no cierra: un vino que ya no existe o que viene en su propia
  /// caja. El panel no los ofrece, asi que esto es lo que cambio mientras se
  /// armaba —o una caja vieja que ya estaba rota—.
  noCierra,

  /// El pedido no tiene la forma: dos cajas que se llaman igual, un nombre
  /// sin letras. El borrador lo frena antes; llegar aca es otra persona que
  /// guardo al mismo tiempo.
  noValida,

  desconocido,
}

/// Lo que lanza el repositorio cuando `guardarCajasSugeridas` falla. HU-04.4:
/// un fallo que no se ve genera la sensacion de que "no anda".
final class FalloDeLasCajas implements Exception {
  const FalloDeLasCajas(this.error, {this.caja, this.codigo});

  final ErrorDeLasCajas error;

  /// El nombre de la caja que no cerro, si la callable lo dijo.
  final String? caja;

  /// El codigo crudo, para el log. Nunca va a la pantalla.
  final String? codigo;

  @override
  String toString() => 'FalloDeLasCajas($error, $caja, $codigo)';
}
