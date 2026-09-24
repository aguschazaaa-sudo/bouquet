import 'dart:async';

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

/// Cuanto vive lo leido de los pedidos abiertos. Contar el deposito entero abre la
/// hoja de correccion de muchos vinos seguidos: leerlo por cada uno eran ~10.000
/// lecturas con 200 vinos. **Dos minutos**: alcanza para un conteo, y un pedido
/// cargado hace menos que eso puede no verse en el aviso (es un aviso, no una
/// baranda).
const vidaDePedidosAbiertos = Duration(minutes: 2);

/// Los pedidos abiertos, leidos UNA vez y compartidos (HU-05.2, ADR 018 §9). Se
/// pide **cuando se abre la hoja de correccion**, nunca antes.
///
/// Se queda vivo [vidaDePedidosAbiertos] **solo si la lectura salio bien**: un
/// error no se cachea, asi que volver a abrir la hoja reintenta.
final pedidosAbiertosProvider = FutureProvider.autoDispose<PedidosAbiertos>((
  ref,
) async {
  final enlace = ref.keepAlive();
  final reloj = Timer(vidaDePedidosAbiertos, enlace.close);
  ref.onDispose(reloj.cancel);
  try {
    return await ref.watch(repositorioDeVentasSinDespacharProvider).abiertos();
  } catch (_) {
    enlace.close();
    rethrow;
  }
});

/// Lo que hay en pedidos abiertos de UN vino, sacado de lo ya leido: no lee nada.
final ventasSinDespacharProvider = Provider.autoDispose
    .family<AsyncValue<VentasSinDespachar>, String>(
      (ref, productoId) => ref
          .watch(pedidosAbiertosProvider)
          .whenData((abiertos) => abiertos.de(productoId)),
    );
