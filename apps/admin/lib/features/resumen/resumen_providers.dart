import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase/firebase_providers.dart';
import 'data/repositorio_del_resumen_firestore.dart';
import 'domain/lo_del_dia.dart';
import 'domain/lo_que_mas_se_vende.dart';
import 'domain/repositorio_del_resumen.dart';

/// El unico archivo de la feature que conoce las implementaciones.
/// `layer-boundary.sh` no deja que `presentation/` importe `data/`.

final repositorioDelResumenProvider = Provider<RepositorioDelResumen>(
  (ref) => RepositorioDelResumenFirestore(ref.watch(firestoreProvider)),
);

// `autoDispose` A PROPOSITO, al reves que el catalogo: HU-11.2 dice *"al
// entrar"*, y un numero del dia que no se recuenta al volver es un numero de
// hace tres horas. Cada apertura del Resumen cuesta tres lecturas (ADR 025).

/// Los pedidos que falta preparar.
final porPrepararProvider = FutureProvider.autoDispose<Conteo>(
  (ref) => ref.watch(repositorioDelResumenProvider).porPreparar(),
);

/// Los pagos que Mercado Pago todavia no confirmo.
final pagosEnProcesoProvider = FutureProvider.autoDispose<Conteo>(
  (ref) => ref.watch(repositorioDelResumenProvider).pagosEnProceso(),
);

/// El ranking medido por `calcularPopularidad`.
final loQueMasSeVendeProvider = FutureProvider.autoDispose<LoQueMasSeVende>(
  (ref) => ref.watch(repositorioDelResumenProvider).loQueMasSeVende(),
);
