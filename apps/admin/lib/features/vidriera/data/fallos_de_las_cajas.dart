import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;

import '../../stock/data/codigos_de_stock.dart' show esDeRed;
import '../domain/fallo_de_las_cajas.dart';
import 'codigos_de_las_cajas.dart';

/// Traduce un error del SDK de Functions a un [FalloDeLasCajas]. Solo saca el
/// codigo y los detalles: la traduccion esta en `codigos_de_las_cajas.dart`,
/// que se prueba. Mismo reparto que `fallos_de_stock.dart`.
FalloDeLasCajas comoFalloDeLasCajas(Object error) {
  if (error is FalloDeLasCajas) return error;

  // `FirebaseFunctionsException` **extiende** `FirebaseException`: se mira
  // primero.
  if (error is FirebaseFunctionsException) {
    return falloDeLasCajas(error.code, error.details);
  }
  if (error is FirebaseException) {
    return FalloDeLasCajas(
      esDeRed(error.code)
          ? ErrorDeLasCajas.sinConexion
          : ErrorDeLasCajas.desconocido,
      codigo: error.code,
    );
  }
  return FalloDeLasCajas(
    ErrorDeLasCajas.desconocido,
    codigo: error.toString(),
  );
}
