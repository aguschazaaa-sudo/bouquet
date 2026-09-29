import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase/firebase_providers.dart';
import 'data/repositorio_de_la_vidriera_firestore.dart';
import 'domain/cajas_sugeridas.dart';
import 'domain/envio_sin_cargo.dart';
import 'domain/repositorio_de_la_vidriera.dart';
import 'domain/seleccion_de_la_portada.dart';

/// El unico archivo de la feature que conoce las implementaciones.
/// `layer-boundary.sh` no deja que `presentation/` importe `data/`.

final repositorioDeLaVidrieraProvider = Provider<RepositorioDeLaVidriera>(
  (ref) => RepositorioDeLaVidrieraFirestore(
    ref.watch(firestoreProvider),
    ref.watch(functionsProvider),
  ),
);

/// Sin `autoDispose`, como el catalogo: volver a Vidriera no relee. Es un
/// documento, asi que el ahorro es chico; lo que importa es que la pantalla
/// no parpadee "cargando" en cada vuelta.
final seleccionDeLaPortadaProvider = StreamProvider<SeleccionDeLaPortada>(
  (ref) => ref.watch(repositorioDeLaVidrieraProvider).seleccion(),
);

/// Las cajas sugeridas (HU-09.2, HU-09.3). Un documento, como la seleccion.
final cajasSugeridasProvider = StreamProvider<CajasSugeridas>(
  (ref) => ref.watch(repositorioDeLaVidrieraProvider).cajas(),
);

/// El umbral de la entrega sin cargo (HU-11.1, ADR 026). Un documento, como
/// la seleccion.
final envioSinCargoProvider = StreamProvider<EnvioSinCargo>(
  (ref) => ref.watch(repositorioDeLaVidrieraProvider).envioSinCargo(),
);
