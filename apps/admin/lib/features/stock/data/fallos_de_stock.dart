import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;

import '../domain/fallo_de_stock.dart';
import 'codigos_de_stock.dart';

/// Traduce un error del SDK de Functions a un [FalloDeStock].
///
/// Vive en `data/` porque es el unico lado que conoce las excepciones de
/// Firebase; `domain/` solo ve el enum. Mismo reparto que
/// `fallos_de_fotos.dart`. Este archivo solo SACA el codigo y los detalles: la
/// traduccion, que es lo que tiene logica, esta en `codigos_de_stock.dart` y
/// se prueba.
FalloDeStock comoFalloDeStock(Object error) {
  if (error is FalloDeStock) return error;

  // `FirebaseFunctionsException` **extiende** `FirebaseException`: se mira
  // primero.
  if (error is FirebaseFunctionsException) {
    return falloDesdeLaCallable(error.code, error.details);
  }
  if (error is FirebaseException) {
    // El SDK a veces deja pasar un `FirebaseException` pelado (red caida).
    return FalloDeStock(
      esDeRed(error.code) ? ErrorDeStock.sinConexion : ErrorDeStock.desconocido,
      codigo: error.code,
    );
  }
  return FalloDeStock(ErrorDeStock.desconocido, codigo: error.toString());
}
