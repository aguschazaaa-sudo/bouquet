import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../catalogo/data/fallos_de_firestore.dart';
import '../domain/cajas_sugeridas.dart';
import '../domain/repositorio_de_la_vidriera.dart';
import '../domain/seleccion_de_la_portada.dart';
import 'fallos_de_las_cajas.dart';

/// La vidriera curada, contra Firestore y la callable de las cajas. ADR 023 y
/// ADR 024.
class RepositorioDeLaVidrieraFirestore implements RepositorioDeLaVidriera {
  const RepositorioDeLaVidrieraFirestore(this._db, this._functions);

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

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

  DocumentReference<Map<String, dynamic>> get _cajas =>
      _db.doc('cajasSugeridas/publicas');

  @override
  Stream<CajasSugeridas> cajas() => _cajas.snapshots().map(
    (d) => CajasSugeridas.desdeDocumento(d.exists ? d.data() : null),
  );

  /// **Un solo `try`/`catch` alrededor de la llamada** (HU-04.4). No lee la
  /// respuesta: el documento vuelve por [cajas], que es lo que la pantalla
  /// dibuja.
  @override
  Future<void> guardarCajas(CajasSugeridas cajas) async {
    try {
      await _functions
          .httpsCallable('guardarCajasSugeridas')
          .call<Object?>(cajas.pedido);
    } catch (e) {
      throw comoFalloDeLasCajas(e);
    }
  }
}
