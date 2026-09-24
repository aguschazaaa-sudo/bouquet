import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/movimiento_de_stock.dart';
import '../domain/repositorio_de_movimientos.dart';
import 'documento_del_movimiento.dart';

/// Los movimientos de stock, leídos de `productos/{id}/movimientos` (HU-05.4).
///
/// `orderBy('en')` sobre **un solo campo** no pide índice compuesto: el índice
/// de un campo lo arma Firestore solo (CLAUDE.md: cero índices compuestos).
/// Un documento sin `en` no entra en el orden; `moverStock` lo escribe siempre
/// con la hora del servidor.
///
/// **No atrapa los errores**: los deja subir, para que la pantalla los dibuje
/// como un fallo y no como "todavía no hay movimientos".
class RepositorioDeMovimientosFirestore implements RepositorioDeMovimientos {
  RepositorioDeMovimientosFirestore(this._db, this._auth);

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  @override
  Future<List<MovimientoDeStock>> ultimos(
    String productoId, {
    int cuantos = topeDeMovimientos,
  }) async {
    final instantanea = await _db
        .collection('productos')
        .doc(productoId)
        .collection('movimientos')
        .orderBy('en', descending: true)
        .limit(cuantos)
        .get();
    final miUid = _auth.currentUser?.uid;
    return [
      for (final d in instantanea.docs)
        movimientoDesde(
          d.id,
          d.data(),
          // `is`, no `as`: un `en` que no sea Timestamp (un script, un
          // futuro escritor con un bug) no puede esconder la lista entera.
          en: switch (d.data()['en']) {
            final Timestamp t => t.toDate(),
            _ => null,
          },
          miUid: miUid,
        ),
    ];
  }
}
