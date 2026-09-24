import 'dart:math';

/// Un `idPedido` nuevo: 32 caracteres hexadecimales, que entran en los 16 a 64
/// de `[A-Za-z0-9_-]` que acepta `parsearPedidoDelPanel`.
///
/// Es la clave de idempotencia de `crearOrdenDelPanel` **y el id de la Orden**.
/// Se genera **al abrir el formulario**, no al apretar el boton: un doble toque
/// o un reintento tras un timeout reusan el mismo y la callable los reconoce
/// como UN pedido. Si se generara al apretar, cada toque seria un pedido
/// distinto y el stock se descontaria dos veces.
///
/// `Random.secure()` y no `Random()`: dos personas con el formulario abierto a
/// la vez no pueden chocar de id.
///
/// Es la misma cuenta que `nuevoIdDeMovimiento`, escrita otra vez a
/// proposito: importarla seria acoplar `pedidos/` con `stock/` por tres
/// lineas. Si aparece un tercero, se mueve a `core/`.
String nuevoIdDePedido([Random? azar]) {
  final r = azar ?? Random.secure();
  final bytes = List<int>.generate(16, (_) => r.nextInt(256));
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}
