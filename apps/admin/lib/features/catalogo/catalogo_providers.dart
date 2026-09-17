import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase/firebase_providers.dart';
import 'data/repositorio_de_bodegas_firestore.dart';
import 'data/repositorio_de_productos_firestore.dart';
import 'domain/bodega.dart';
import 'domain/catalogo.dart';
import 'domain/producto_del_panel.dart';
import 'domain/repositorio_de_bodegas.dart';
import 'domain/repositorio_de_productos.dart';

/// El unico archivo de la feature que conoce las implementaciones.
/// `layer-boundary.sh` no deja que `presentation/` importe `data/`: las
/// pantallas piden estos providers.

final repositorioDeBodegasProvider = Provider<RepositorioDeBodegas>(
  (ref) => RepositorioDeBodegasFirestore(ref.watch(firestoreProvider)),
);

final repositorioDeProductosProvider = Provider<RepositorioDeProductos>(
  (ref) => RepositorioDeProductosFirestore(ref.watch(firestoreProvider)),
);

/// ⚠️ **Ninguno de estos lleva `autoDispose`, y es una decision de plata.**
///
/// Con `autoDispose`, salir de Catalogo cancela la suscripcion y volver
/// **relee los 230 documentos** del MVP (200 productos + 30 bodegas). Diez
/// idas y vueltas serian 2.300 lecturas de una sola persona en una sola
/// sesion. Sin el, las 230 se pagan una vez y cada cambio cuesta **una**: la
/// del documento que cambio. ARQUITECTURA §6.3.
///
/// La suscripcion se cierra con el `ProviderContainer`, o sea con la pestaña.
final bodegasProvider = StreamProvider<List<Bodega>>(
  (ref) => ref.watch(repositorioDeBodegasProvider).cambios(),
);

final productosProvider = StreamProvider<List<ProductoDelPanel>>(
  (ref) => ref.watch(repositorioDeProductosProvider).cambios(),
);

/// El cruce de los dos, que es lo que miran las pantallas.
///
/// Mientras cualquiera de los dos carga, esto carga. Si cualquiera falla,
/// esto falla — y con el error, para que la pantalla lo pueda decir en vez de
/// mostrar una lista vacia indistinguible de "todavia no cargaste nada".
final catalogoProvider = Provider<AsyncValue<Catalogo>>((ref) {
  final productos = ref.watch(productosProvider);
  final bodegas = ref.watch(bodegasProvider);

  // El orden importa: primero el error, despues la carga. Al reves, un stream
  // que fallo mientras el otro sigue cargando se leeria como "cargando" para
  // siempre.
  if (productos.hasError) {
    return AsyncValue.error(productos.error!, productos.stackTrace!);
  }
  if (bodegas.hasError) {
    return AsyncValue.error(bodegas.error!, bodegas.stackTrace!);
  }
  if (productos.isLoading || bodegas.isLoading) {
    return const AsyncValue.loading();
  }

  return AsyncValue.data(
    Catalogo.armar(
      productos: productos.requireValue,
      bodegas: bodegas.requireValue,
    ),
  );
});

/// Lo que hay escrito en el buscador de Catalogo (HU-03.1).
///
/// Un provider y no un `StatefulWidget` para que la busqueda **sobreviva a ir
/// a Bodegas y volver**: el operador que estaba mirando "malbec" no tiene que
/// volver a escribirlo.
final busquedaProvider = StateProvider<String>((ref) => '');
