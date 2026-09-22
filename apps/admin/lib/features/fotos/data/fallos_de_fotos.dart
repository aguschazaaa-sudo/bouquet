import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseException;

import '../domain/fallo_de_fotos.dart';

/// Traduce un error de alguno de los tres SDK que toca
/// `RepositorioDeFotosFirebase` -Storage, la callable `procesarFoto`,
/// Firestore- a un [FalloDeFotos] que nombra la foto que fallo (HU-04.4).
///
/// Vive en `data/` porque es el unico lado que conoce los codigos de
/// Firebase; `domain/` solo ve el enum. Mismo reparto que
/// `fallos_de_firestore.dart` de `catalogo/` y `codigos_de_auth.dart` de
/// `acceso/`.
///
/// `FirebaseFunctionsException` **extiende** `FirebaseException`, asi que se
/// mira primero: sus codigos son los de `HttpsError` que lanza
/// `functions/src/foto/procesar_foto.ts` (`unauthenticated`,
/// `permission-denied`, `invalid-argument`, `not-found`), y son un universo
/// distinto de los que usan `firebase_storage` y `cloud_firestore`.
FalloDeFotos comoFalloDeFotos(Object error, String nombreDeArchivo) {
  if (error is FalloDeFotos) return error;

  if (error is FirebaseFunctionsException) {
    return FalloDeFotos(
      _desdeLaCallable(error.code),
      nombreDeArchivo,
      error.code,
    );
  }
  if (error is FirebaseException) {
    return FalloDeFotos(
      _desdeStorageOFirestore(error.code),
      nombreDeArchivo,
      error.code,
    );
  }
  return FalloDeFotos(
    ErrorDeFotos.desconocido,
    nombreDeArchivo,
    error.toString(),
  );
}

/// Los codigos que `procesarFoto` lanza con `HttpsError`, en el orden de sus
/// guardas (`procesar_foto.ts`): autenticacion, claim, ruta/peso/formato, y
/// recien despues la transformacion.
///
/// El panel YA valida formato y peso localmente ANTES de llamar a la
/// callable (`RepositorioDeFotosFirebase.subir`), asi que si de todos modos
/// llega `invalid-argument` o `not-found` lo mas probable es que el crudo
/// haya cambiado o desaparecido entre la subida y la llamada, o que `sharp`
/// no haya podido procesar el archivo real -- de ahi `fallaLaTransformacion`
/// y no `noEsImagen`/`pesaDeMas`, que son los motivos que el panel arma el
/// mismo, sin llegar a la red (ver `RepositorioDeFotosFirebase`).
ErrorDeFotos _desdeLaCallable(String? codigo) => switch (codigo) {
  'unauthenticated' || 'permission-denied' => ErrorDeFotos.sinPermiso,
  'invalid-argument' => ErrorDeFotos.fallaLaTransformacion,
  'not-found' => ErrorDeFotos.fallaLaTransformacion,
  'unavailable' ||
  'deadline-exceeded' ||
  'cancelled' => ErrorDeFotos.sinConexion,
  _ => ErrorDeFotos.desconocido,
};

/// `firebase_storage` (subir el crudo) y `cloud_firestore`
/// (`arrayUnion`/`arrayRemove` sobre `productos/{id}`) comparten esta forma
/// de codigos.
ErrorDeFotos _desdeStorageOFirestore(String? codigo) => switch (codigo) {
  // `unauthorized` es el codigo de `firebase_storage` cuando `storage.rules`
  // rechaza la escritura -- para esta ruta, casi siempre el claim, porque el
  // panel ya filtro formato y peso antes de llegar a Storage.
  'permission-denied' || 'unauthorized' => ErrorDeFotos.sinPermiso,
  'unavailable' ||
  'deadline-exceeded' ||
  'retry-limit-exceeded' ||
  'canceled' => ErrorDeFotos.sinConexion,
  _ => ErrorDeFotos.desconocido,
};
