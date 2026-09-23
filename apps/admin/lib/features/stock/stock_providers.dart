import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase/firebase_providers.dart';
import 'data/repositorio_de_stock_firebase.dart';
import 'domain/repositorio_de_stock.dart';

/// El unico archivo de la feature que conoce la implementacion.
/// `layer-boundary.sh` no deja que `presentation/` importe `data/`: las hojas
/// piden este provider. Mismo patron que `fotos_providers.dart`.
final repositorioDeStockProvider = Provider<RepositorioDeStock>(
  (ref) => RepositorioDeStockFirebase(ref.watch(functionsProvider)),
);
