/// Por que fallo mover el stock, en terminos de la pantalla y no de los codigos
/// de `HttpsError`.
enum ErrorDeStock {
  /// La callable no dejo pasar: sin sesion, o sin el claim `rol: admin`.
  sinPermiso,

  /// No hay red, o no contesto a tiempo. **Ojo:** la operacion PUDO haberse
  /// aplicado y la respuesta perderse -- la pantalla lo dice, y no reintenta
  /// a ciegas.
  sinConexion,

  /// Corregir: el stock ya no es el que el operador vio. El numero de ahora
  /// viaja en [FalloDeStock.actual].
  cambioElStock,

  /// Reponer: la suma pasaria del maximo. El stock de ahora viaja en
  /// [FalloDeStock.actual].
  pasaElTope,

  /// El servidor no puede mover el stock de este vino: es un producto
  /// compuesto, que no lo tiene propio, o su stock esta mal cargado.
  noSePuede,

  /// El vino no existe (se borro el documento por fuera del panel).
  noExiste,

  /// El mismo `idMovimiento` ya se uso para OTRA operacion. La hoja usa un
  /// solo id por vez que se abre, asi que llegar aca es un reintento con otra
  /// cantidad DESPUES de una respuesta perdida: el intento anterior si se
  /// aplico. La pantalla manda a mirar el stock antes de volver a intentar.
  yaEstaHecho,

  desconocido,
}

/// Lo que lanza [RepositorioDeStock] cuando mover el stock falla.
///
/// Existe por HU-04.4, igual que `FalloDeFotos`: un error asincrono que se
/// pierde deja un boton que "no hace nada" y nadie lo reporta.
final class FalloDeStock implements Exception {
  const FalloDeStock(this.error, {this.actual, this.codigo});

  final ErrorDeStock error;

  /// El stock que la callable leyo al rechazar (`cambioElStock`, `pasaElTope`).
  /// La pantalla se lo muestra al operador, que decide: reintentar a ciegas
  /// es justo lo que el rechazo evito.
  final int? actual;

  /// El codigo crudo del SDK, para el log. Nunca va a la pantalla.
  final String? codigo;

  @override
  String toString() => 'FalloDeStock($error, actual: $actual, codigo: $codigo)';
}
