import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase/firebase_providers.dart';
import 'data/repositorio_de_movimientos_firestore.dart';
import 'data/repositorio_de_ventas_sin_despachar_firestore.dart';
import 'data/repositorio_de_stock_firebase.dart';
import 'domain/movimiento_de_stock.dart';
import 'domain/repositorio_de_movimientos.dart';
import 'domain/repositorio_de_stock.dart';
import 'domain/ventas_sin_despachar.dart';

/// El unico archivo de la feature que conoce la implementacion.
/// `layer-boundary.sh` no deja que `presentation/` importe `data/`: las hojas
/// piden este provider. Mismo patron que `fotos_providers.dart`.
final repositorioDeStockProvider = Provider<RepositorioDeStock>(
  (ref) => RepositorioDeStockFirebase(ref.watch(functionsProvider)),
);

final repositorioDeMovimientosProvider = Provider<RepositorioDeMovimientos>(
  (ref) => RepositorioDeMovimientosFirestore(
    ref.watch(firestoreProvider),
    ref.watch(authProvider),
  ),
);

/// Los últimos movimientos de un vino (HU-05.4). Se pide **cuando se abre la
/// hoja**, nunca al abrir la ficha: el que no mira los movimientos no paga
/// sus lecturas. `autoDispose`: cada apertura lee de nuevo, así que un
/// movimiento recién hecho aparece.
final movimientosProvider = FutureProvider.autoDispose
    .family<List<MovimientoDeStock>, String>(
      (ref, productoId) =>
          ref.watch(repositorioDeMovimientosProvider).ultimos(productoId),
    );

final repositorioDeVentasSinDespacharProvider =
    Provider<RepositorioDeVentasSinDespachar>(
      (ref) => RepositorioDeVentasSinDespacharFirestore(
        ref.watch(firestoreProvider),
      ),
    );

/// Lo vendido y sin despachar de un vino (HU-05.2, ADR 018 §9). Se pide **cuando
/// se abre la hoja de correccion**, nunca antes: hasta 50 lecturas por apertura,
/// y contar el deposito es una operacion rara. `autoDispose`: cada apertura lee
/// de nuevo, asi que un pedido recien cargado se cuenta.
final ventasSinDespacharProvider = FutureProvider.autoDispose
    .family<VentasSinDespachar, String>(
      (ref, productoId) =>
          ref.watch(repositorioDeVentasSinDespacharProvider).de(productoId),
    );
