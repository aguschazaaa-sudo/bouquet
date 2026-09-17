import 'producto_del_panel.dart';

/// Lo que el panel sabe hacer con los productos. Hoy **solo leer**: el alta y
/// la edicion entran con HU-03.2 en adelante, y la reposicion de stock nunca
/// va a estar aca — la escribe una callable del servidor, porque las reglas
/// no distinguen un `increment(10)` de un valor absoluto calculado sobre un
/// dato viejo (ADR 008 §1).
abstract interface class RepositorioDeProductos {
  /// Los productos, **publicados y no publicados**, cada vez que cambian.
  ///
  /// Sin `where('publicado','==',true)` a proposito: los que faltan terminar
  /// de cargar son justamente los que el operador necesita encontrar.
  Stream<List<ProductoDelPanel>> cambios();
}
