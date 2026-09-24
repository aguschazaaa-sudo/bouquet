import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;

import '../domain/fallo_de_pedidos.dart';
import 'codigos_de_pedidos.dart';

/// Traduce un error del SDK de Functions a un [FalloDePedidos].
///
/// Vive en `data/` porque es el unico lado que conoce las excepciones de
/// Firebase; `domain/` solo ve el enum. Este archivo solo SACA el codigo y los
/// detalles: la traduccion, que es lo que tiene logica, esta en
/// `codigos_de_pedidos.dart` y se prueba. Mismo reparto que `fallos_de_stock.dart`.
FalloDePedidos comoFalloDePedidos(Object error) {
  if (error is FalloDePedidos) return error;

  // `FirebaseFunctionsException` **extiende** `FirebaseException`: se mira
  // primero.
  if (error is FirebaseFunctionsException) {
    return falloDesdeLaCallable(error.code, error.details);
  }
  if (error is FirebaseException) {
    // El SDK a veces deja pasar un `FirebaseException` pelado (red caida).
    return FalloDePedidos(
      esDeRed(error.code)
          ? ErrorDePedido.sinConexion
          : ErrorDePedido.desconocido,
      codigo: error.code,
    );
  }
  return FalloDePedidos(ErrorDePedido.desconocido, codigo: error.toString());
}
