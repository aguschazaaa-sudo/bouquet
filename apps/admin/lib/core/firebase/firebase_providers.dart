import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Único punto donde el panel pide la instancia de Firestore. Las
/// implementaciones de `data/` la reciben por acá en vez de llamar
/// `FirebaseFirestore.instance` directo, así un test puede reemplazar este
/// provider con `overrideWithValue(fakeFirestore)` sin tocar nada más.
///
/// No lleva `autoDispose`: es una instancia de SDK, no una suscripción — no
/// hay lectura de Firestore que "se quede viva" por este provider en sí
/// mismo (ARQUITECTURA §6.3, la nota sobre autoDispose es para streams).
final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

/// Lo mismo, para Auth.
final authProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

/// Lo mismo, para Storage — usado por EP-04 para subir el crudo de una foto.
final storageProvider = Provider<FirebaseStorage>(
  (ref) => FirebaseStorage.instance,
);

/// Lo mismo, para Cloud Functions — usado por EP-04 para llamar a la
/// callable `procesarFoto`. Sin región explícita: el SDK cliente por
/// defecto ya apunta a `us-central1`, la misma que declara
/// `functions/src/foto/procesar_foto.ts` (`{ region: 'us-central1' }`).
final functionsProvider = Provider<FirebaseFunctions>(
  (ref) => FirebaseFunctions.instance,
);
