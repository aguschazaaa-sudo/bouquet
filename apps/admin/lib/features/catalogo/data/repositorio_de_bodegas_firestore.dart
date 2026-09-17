import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/bodega.dart';
import '../domain/fallo_de_catalogo.dart';
import '../domain/repositorio_de_bodegas.dart';
import 'campos.dart';
import 'fallos_de_firestore.dart';

/// Las bodegas, contra Firestore. `firestore.rules` cierra la forma en
/// `{nombre, slug}` (+ `muestra`, que escribe solo el servidor).
class RepositorioDeBodegasFirestore implements RepositorioDeBodegas {
  const RepositorioDeBodegasFirestore(this._db);

  final FirebaseFirestore _db;

  static const _coleccion = 'bodegas';

  /// El campo por el que un producto apunta a su bodega. Escrito una sola vez
  /// para que la query de [tieneVinos] y cualquier futura no puedan
  /// divergir en una letra.
  static const campoDeLaBodegaEnElProducto = 'fichaVino.bodegaId';

  @override
  Stream<List<Bodega>> cambios() => _db
      .collection(_coleccion)
      .snapshots()
      .map((s) => s.docs.map(_desdeElDocumento).toList());

  /// ⚠️ **Un documento sin `nombre` NO se descarta.** Las reglas lo impiden
  /// desde el cliente, pero el Admin SDK no pasa por las reglas. La vidriera
  /// lo descarta —`armarCatalogo` reporta *`bodegas/<id>: nombre falta`*— y
  /// el panel lo muestra con el nombre vacio, porque una bodega invisible es
  /// una bodega que nadie puede arreglar.
  static Bodega _desdeElDocumento(
    QueryDocumentSnapshot<Map<String, dynamic>> d,
  ) {
    final datos = d.data();
    return Bodega(
      id: d.id,
      nombre: textoDe(datos['nombre']),
      slug: textoDe(datos['slug']),
    );
  }

  /// El id del documento **es el slug**. Asi dos bodegas no pueden compartir
  /// slug ni por accidente, y la transaccion hace que dos personas de la
  /// familia cargando la misma bodega a la vez no se pisen: la segunda ve
  /// `ErrorDeCatalogo.yaExiste`, no un documento sobrescrito.
  ///
  /// ⚠️ Un `set()` suelto **sobrescribiria en silencio**. Las reglas no lo
  /// impiden: para ellas escribir sobre un documento que existe es un
  /// `update` legitimo.
  @override
  Future<void> crear({required String nombre, required String slug}) async {
    final ref = _db.collection(_coleccion).doc(slug);
    try {
      await _db.runTransaction((tx) async {
        final actual = await tx.get(ref);
        if (actual.exists) {
          throw const FalloDeCatalogo(ErrorDeCatalogo.yaExiste);
        }
        tx.set(ref, {'nombre': nombre, 'slug': slug});
      });
    } catch (e) {
      throw comoFalloDeCatalogo(e);
    }
  }

  /// Manda **solo** `nombre`. El slug no viaja: no cambia nunca.
  @override
  Future<void> corregirNombre({
    required String id,
    required String nombre,
  }) async {
    try {
      await _db.collection(_coleccion).doc(id).update({'nombre': nombre});
    } catch (e) {
      throw comoFalloDeCatalogo(e);
    }
  }

  /// `Source.server` a proposito: preguntarle a la cache derrotaria el unico
  /// motivo por el que esta consulta existe, que es cerrar la ventana entre
  /// que se abrio la pantalla y se apreto el boton.
  ///
  /// Sin red esto **falla** en vez de contestar que no hay vinos, y el
  /// borrado no ocurre. Es lo correcto para algo que no tiene vuelta atras.
  @override
  Future<bool> tieneVinos(String bodegaId) async {
    try {
      final r = await _db
          .collection('productos')
          .where(campoDeLaBodegaEnElProducto, isEqualTo: bodegaId)
          .limit(1)
          .get(const GetOptions(source: Source.server));
      return r.docs.isNotEmpty;
    } catch (e) {
      throw comoFalloDeCatalogo(e);
    }
  }

  @override
  Future<void> borrar(String id) async {
    try {
      await _db.collection(_coleccion).doc(id).delete();
    } catch (e) {
      throw comoFalloDeCatalogo(e);
    }
  }
}
