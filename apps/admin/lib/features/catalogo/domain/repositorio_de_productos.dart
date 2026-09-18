import 'escrituras_del_vino.dart';
import 'producto_del_panel.dart';

/// Lo que el panel sabe hacer con los productos: leerlos, darlos de alta y
/// corregirlos (HU-03.2 a HU-03.4). **No los borra**: despublica (HU-03.6,
/// hallazgo 1 de `revisor-pagos` en ADR 008). Y la reposicion de stock nunca
/// va a estar aca — la escribe una callable del servidor, porque las reglas
/// no distinguen un `increment(10)` de un valor absoluto calculado sobre un
/// dato viejo (ADR 008 §1).
abstract interface class RepositorioDeProductos {
  /// Los productos, **publicados y no publicados**, cada vez que cambian.
  ///
  /// Sin `where('publicado','==',true)` a proposito: los que faltan terminar
  /// de cargar son justamente los que el operador necesita encontrar.
  Stream<List<ProductoDelPanel>> cambios();

  /// Crea el vino en `productos/{slug}`. Falla con
  /// `ErrorDeCatalogo.yaExiste` si el documento existe: **nunca sobrescribe**.
  Future<void> crear(AltaDeVino alta);

  /// Escribe solo lo que cambio. Los varietales, con `arrayUnion` y
  /// `arrayRemove` (ARQUITECTURA §5.3).
  Future<void> corregir(String id, CambiosDeVino cambios);
}
