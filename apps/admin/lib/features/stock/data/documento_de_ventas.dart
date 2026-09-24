/// Cuanto de un vino hay en un conjunto de pedidos abiertos, leido **sin Firebase
/// adentro** para que `dart test` lo pueda cargar (`cloud_firestore` arrastra
/// Flutter).
library;

import '../domain/ventas_sin_despachar.dart';

/// Suma las unidades de [productoId] entre los `items` de [pedidos].
///
/// **Nunca lanza**: un pedido de una forma rara no puede esconder el aviso. Lo que
/// no se puede leer (un `items` que no es lista, una `cantidad` que no es entero
/// positivo, un item que no es un mapa) simplemente no suma. Es la postura del
/// panel con los documentos rotos, y aca duele menos: lo que se pierde es un
/// aviso de mas, no una fila de la bandeja.
///
/// [completo] es `false` si [pedidos] llego al [tope]: la consulta pudo dejar
/// afuera pedidos abiertos, asi que el numero es un piso y no un total.
VentasSinDespachar ventasSinDespacharDe(
  String productoId,
  List<Map<String, Object?>> pedidos, {
  int tope = topeDePedidosAbiertos,
}) {
  var unidades = 0;
  for (final pedido in pedidos) {
    final items = pedido['items'];
    if (items is! List) continue;
    for (final item in items) {
      if (item is! Map || item['productoId'] != productoId) continue;
      final cantidad = item['cantidad'];
      if (cantidad is int && cantidad > 0) unidades += cantidad;
    }
  }
  return VentasSinDespachar(
    unidades: unidades,
    completo: pedidos.length < tope,
  );
}
