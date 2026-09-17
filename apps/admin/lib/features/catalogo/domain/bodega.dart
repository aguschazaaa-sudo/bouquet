/// Una bodega. La forma esta cerrada en `{nombre, slug}` por
/// `firestore.rules`: la vidriera las lee ENTERAS en cada reconstruccion del
/// catalogo, y cada campo de mas es peso en esa lectura (ADR 008).
///
/// `muestra` existe en las reglas y no aca a proposito: lo escribe solo el
/// servidor y el panel no lo muestra ni lo manda. Si algun dia hace falta
/// distinguir las de prueba, entra como campo del modelo y no como un `get`
/// suelto en una pantalla.
class Bodega {
  const Bodega({required this.id, required this.nombre, required this.slug});

  final String id;
  final String nombre;

  /// Derivado del nombre con `aSlug` al crearla, y **no cambia despues**: la
  /// bodega va a tener `/bodega/<slug>` indexable, y un slug que se mueve es
  /// un 404 en Google. Mismo criterio que el de un producto publicado.
  final String slug;

  @override
  bool operator ==(Object other) =>
      other is Bodega &&
      other.id == id &&
      other.nombre == nombre &&
      other.slug == slug;

  @override
  int get hashCode => Object.hash(id, nombre, slug);

  @override
  String toString() => 'Bodega($id, $nombre, $slug)';
}
