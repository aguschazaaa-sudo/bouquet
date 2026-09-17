import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/producto_del_panel.dart';
import '../domain/repositorio_de_productos.dart';
import 'campos.dart';

/// Los productos, contra Firestore. **Solo lectura**: el alta y la edicion
/// entran con HU-03.2, y el stock no va a pasar por aca nunca — lo escribe
/// una callable del servidor (ADR 008 §1).
class RepositorioDeProductosFirestore implements RepositorioDeProductos {
  const RepositorioDeProductosFirestore(this._db);

  final FirebaseFirestore _db;

  static const _coleccion = 'productos';

  @override
  Stream<List<ProductoDelPanel>> cambios() => _db
      .collection(_coleccion)
      .snapshots()
      .map((s) => s.docs.map(_desdeElDocumento).toList());

  /// ⚠️ **Ningun documento se descarta, ni el roto.** La vidriera si los
  /// descarta y los reporta en `descartes` (ADR 008 §2), y eso hoy **solo se
  /// lee en el log del build**: un vino publicado que no aparece en la tienda
  /// es invisible para el operador. El panel lo muestra con lo que se pudo
  /// leer, y HU-03.7 va a decir ademas por que la vidriera lo dejo afuera.
  ///
  /// Los valores por omision son los **seguros**: `publicado` en `false`
  /// —nunca afirmar que algo esta a la venta— y `precio` en 0, que ya es lo
  /// que el hallazgo 2 de `revisor-pagos` no deja publicar.
  static ProductoDelPanel _desdeElDocumento(
    QueryDocumentSnapshot<Map<String, dynamic>> d,
  ) {
    final datos = d.data();
    final ficha = mapaDe(datos['fichaVino']);
    final presentacion = mapaDe(datos['presentacion']);

    return ProductoDelPanel(
      id: d.id,
      slug: textoDe(datos['slug']),
      nombre: textoDe(datos['nombre']),
      precio: enteroDe(datos['precio']) ?? 0,
      publicado: boolDe(datos['publicado']),
      bodegaId: textoDe(ficha['bodegaId']),
      botellas: enteroDe(presentacion['botellas']) ?? 1,
      // `null` es "no tiene stock propio", que es lo correcto para un
      // compuesto y tambien para un documento al que le falta el campo: el
      // panel dice "sin dato", no "cero", que significaria agotado.
      stock: enteroDe(datos['stock']),
    );
  }
}
