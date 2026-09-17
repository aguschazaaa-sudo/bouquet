import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/fallo_de_catalogo.dart';

/// Traduce un error del SDK a algo que una pantalla puede decir.
///
/// Vive en `data/` porque es el unico lado que conoce los codigos de
/// Firestore; `domain/` solo ve el enum. Mismo reparto que
/// `codigos_de_auth.dart` en la feature de acceso.
FalloDeCatalogo comoFalloDeCatalogo(Object error) {
  if (error is FalloDeCatalogo) return error;
  if (error is! FirebaseException) {
    return FalloDeCatalogo(ErrorDeCatalogo.desconocido, error.toString());
  }
  return switch (error.code) {
    // Las reglas lo rechazaron. En el panel esto es casi siempre el claim que
    // todavia no llego al token, o un documento que no cumple la forma.
    'permission-denied' => FalloDeCatalogo(
      ErrorDeCatalogo.sinPermiso,
      error.code,
    ),
    // `unavailable` es sin red; `deadline-exceeded` es la red que no contesta
    // a tiempo. Para quien mira la pantalla son lo mismo.
    'unavailable' || 'deadline-exceeded' => FalloDeCatalogo(
      ErrorDeCatalogo.sinConexion,
      error.code,
    ),
    _ => FalloDeCatalogo(ErrorDeCatalogo.desconocido, error.code),
  };
}
