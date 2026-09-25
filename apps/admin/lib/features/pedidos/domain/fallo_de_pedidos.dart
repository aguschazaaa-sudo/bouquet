/// Por que fallo cargar un pedido, en terminos de la pantalla y no de los
/// codigos de `HttpsError`.
enum ErrorDePedido {
  /// La callable no dejo pasar: sin sesion, o sin el claim `rol: admin`.
  sinPermiso,

  /// No hay red, o no contesto a tiempo. **Ojo:** el pedido PUDO haberse creado
  /// y la respuesta perderse. La pantalla lo dice y reintenta con el MISMO
  /// `idPedido`: si se creo, el reintento devuelve el mismo numero.
  sinConexion,

  /// No hay stock suficiente de una linea. El stock de ahora viaja en
  /// [FalloDePedidos.actual].
  sinStock,

  /// El precio de una linea cambio mientras se cargaba. El precio de ahora
  /// viaja en [FalloDePedidos.actual].
  cambioElPrecio,

  /// El vino es de muestra: su stock es inventado y no se puede vender.
  deMuestra,

  /// El vino es compuesto: no tiene stock propio.
  compuesto,

  /// El vino no tiene precio cargado: no se vende. Se carga en Catalogo.
  sinPrecio,

  /// El documento del vino tiene un dato roto y el servidor no lo vende.
  productoRoto,

  /// El vino no existe (se borro por fuera del panel).
  noExiste,

  /// El mismo `idPedido` ya se uso para OTRO pedido: con otras lineas, otra
  /// direccion u otro cliente. El formulario usa un solo id por vez que se abre,
  /// asi que llegar aca es un reintento con algo cambiado DESPUES de una
  /// respuesta perdida: **el primero si se creo**, y el numero de esa Orden viaja
  /// en [FalloDePedidos.numero]. La pantalla manda a abrirla, no a cargar otra:
  /// otra seria un pedido duplicado (ADR 018, hallazgos 3 y 5 de `revisor-pagos`).
  yaEstaHecho,

  /// EP-07: las reglas no dejaron mover el pedido. El panel solo ofrece los
  /// pasos que la tabla permite DESDE EL ESTADO QUE MUESTRA, asi que esto casi
  /// siempre es otra persona que lo movio mientras se miraba. La pantalla lo
  /// vuelve a leer.
  cambioElPedido,

  /// HU-07.6: el pedido ya salio y no se cancela (el envio ya costo). Si no
  /// llega, es una entrega fallida.
  yaSalio,

  /// EP-07: el pedido que se quiso mover o cancelar no existe.
  pedidoInexistente,

  /// HU-07.6: el pedido tiene un dato roto y el servidor no adivina que se
  /// vendio.
  pedidoRoto,

  /// El servidor rechazo la forma del pedido. El formulario valida antes de
  /// mandar, asi que llegar aca es un desajuste entre panel y servidor.
  datosInvalidos,

  desconocido,
}

/// Lo que lanzan [RepositorioDePedidos.cargar], `avanzar` y `cancelar` cuando
/// fallan.
///
/// Existe por HU-04.4, igual que `FalloDeStock`: un error asincrono que se
/// pierde deja un boton que "no hace nada" y nadie lo reporta.
final class FalloDePedidos implements Exception {
  const FalloDePedidos(
    this.error, {
    this.productoId,
    this.actual,
    this.numero,
    this.codigo,
  });

  final ErrorDePedido error;

  /// El vino de la linea que fallo, cuando el servidor lo dice. La pantalla lo
  /// resuelve a un nombre con lo que tiene en memoria: **el id no se muestra**.
  final String? productoId;

  /// El numero de AHORA (el stock en `sinStock`, el precio en
  /// `cambioElPrecio`). La pantalla se lo muestra al operador, que decide.
  final int? actual;

  /// El numero de la Orden que YA existe con este `idPedido` (`yaEstaHecho`).
  final int? numero;

  /// El codigo crudo del SDK, para el log. Nunca va a la pantalla.
  final String? codigo;

  @override
  String toString() =>
      'FalloDePedidos($error, productoId: $productoId, actual: $actual, '
      'numero: $numero, codigo: $codigo)';
}
