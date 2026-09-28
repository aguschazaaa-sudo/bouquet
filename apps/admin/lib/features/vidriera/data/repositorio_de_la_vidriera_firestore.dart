import 'package:cloud_firestore/cloud_firestore.dart';

import '../../catalogo/data/fallos_de_firestore.dart';
import '../domain/repositorio_de_la_vidriera.dart';
import '../domain/seleccion_de_la_portada.dart';

/// La vidriera curada, contra Firestore. ADR 023.
class RepositorioDeLaVidrieraFirestore implements RepositorioDeLaVidriera {
  const RepositorioDeLaVidrieraFirestore(this._db);

  final FirebaseFirestore _db;

  /// El unico documento que las reglas dejan escribir en `seleccion`.
  DocumentReference<Map<String, dynamic>> get _seleccion =>
      _db.doc('seleccion/publica');

  @override
  Stream<SeleccionDeLaPortada> seleccion() => _seleccion.snapshots().map(
    (d) => SeleccionDeLaPortada.desdeDocumento(d.exists ? d.data() : null),
  );

  /// Un `set` entero, y a proposito: la seleccion es UNA lista ordenada y
  /// `firestore.rules` cierra el documento en `{productoIds}`. Con
  /// `arrayUnion`/`arrayRemove` (ARQUITECTURA §5.3) no se puede reordenar, y
  /// el orden es parte de lo que elige el dueño.
  ///
  /// Si dos personas la cambian a la vez, gana la ultima: son seis vinos, y
  /// la pantalla muestra al instante lo que quedo guardado.
  @override
  Future<void> guardarSeleccion(SeleccionDeLaPortada seleccion) async {
    try {
      await _seleccion.set({'productoIds': seleccion.productoIds});
    } catch (e) {
      throw comoFalloDeCatalogo(e);
    }
  }
}
