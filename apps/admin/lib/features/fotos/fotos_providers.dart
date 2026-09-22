import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase/firebase_providers.dart';
import 'data/repositorio_de_fotos_firebase.dart';
import 'domain/repositorio_de_fotos.dart';

/// El unico archivo de la feature que conoce las implementaciones.
/// `layer-boundary.sh` no deja que `presentation/` importe `data/`: las
/// pantallas piden este provider. Mismo patron que `catalogo_providers.dart`.
final repositorioDeFotosProvider = Provider<RepositorioDeFotos>(
  (ref) => RepositorioDeFotosFirebase(
    ref.watch(storageProvider),
    ref.watch(functionsProvider),
    ref.watch(firestoreProvider),
  ),
);
