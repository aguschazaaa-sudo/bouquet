/// Lo que hay en un conjunto de pedidos abiertos, leido **sin Firebase adentro**
/// para que `dart test` lo pueda cargar (`cloud_firestore` arrastra Flutter).
library;

import '../domain/ventas_sin_despachar.dart';

/// Suma las unidades de cada vino entre los `items` de [pedidos].
///
/// **Nunca lanza**: un pedido de una forma rara no puede esconder el aviso. Lo que
/// no se puede leer (un `items` que no es lista, una `cantidad` que no es entero
/// positivo, un item que no es un mapa, un `productoId` que no es texto)
/// simplemente no suma. Es la postura del panel con los documentos rotos, y aca
/// duele menos: lo que se pierde es un aviso de mas, no una fila de la bandeja.
///
/// [PedidosAbiertos.completo] es `false` si [pedidos] llego al [tope]: la consulta
/// pudo dejar afuera pedidos abiertos, asi que el numero es un piso y no un total.
PedidosAbiertos pedidosAbiertosDe(
  List<Map<String, Object?>> pedidos, {
  int tope = topeDePedidosAbiertos,
}) {
  final unidades = <String, int>{};
  for (final pedido in pedidos) {
    final items = pedido['items'];
    if (items is! List) continue;
    for (final item in items) {
      if (item is! Map) continue;
      final id = item['productoId'];
      final cantidad = item['cantidad'];
      if (id is! String || cantidad is! int || cantidad < 1) continue;
      unidades[id] = (unidades[id] ?? 0) + cantidad;
    }
  }
  return PedidosAbiertos(
    unidadesPorVino: unidades,
    completo: pedidos.length < tope,
  );
}
