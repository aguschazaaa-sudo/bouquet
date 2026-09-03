import 'package:cloud_firestore/cloud_firestore.dart';
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
