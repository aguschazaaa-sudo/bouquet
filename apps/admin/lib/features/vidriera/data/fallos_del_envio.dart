import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;

import '../../stock/data/codigos_de_stock.dart' show esDeRed;
import '../domain/envio_sin_cargo.dart';
import 'codigos_del_envio.dart';

/// Traduce un error del SDK de Functions a un [FalloDelEnvio]. Solo saca el
/// codigo: la traduccion esta en `codigos_del_envio.dart`, que se prueba.
/// Mismo reparto que `fallos_de_las_cajas.dart`.
FalloDelEnvio comoFalloDelEnvio(Object error) {
  if (error is FalloDelEnvio) return error;

  // `FirebaseFunctionsException` **extiende** `FirebaseException`: se mira
  // primero.
  if (error is FirebaseFunctionsException) return falloDelEnvio(error.code);
  if (error is FirebaseException) {
    return FalloDelEnvio(
      esDeRed(error.code) ? ErrorDelEnvio.sinConexion : ErrorDelEnvio.desconocido,
      codigo: error.code,
    );
  }
  return FalloDelEnvio(ErrorDelEnvio.desconocido, codigo: error.toString());
}
