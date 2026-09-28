import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase/firebase_providers.dart';
import 'data/repositorio_de_la_vidriera_firestore.dart';
import 'domain/repositorio_de_la_vidriera.dart';
import 'domain/seleccion_de_la_portada.dart';

/// El unico archivo de la feature que conoce las implementaciones.
/// `layer-boundary.sh` no deja que `presentation/` importe `data/`.

final repositorioDeLaVidrieraProvider = Provider<RepositorioDeLaVidriera>(
  (ref) => RepositorioDeLaVidrieraFirestore(ref.watch(firestoreProvider)),
);

/// Sin `autoDispose`, como el catalogo: volver a Vidriera no relee. Es un
/// documento, asi que el ahorro es chico; lo que importa es que la pantalla
/// no parpadee "cargando" en cada vuelta.
final seleccionDeLaPortadaProvider = StreamProvider<SeleccionDeLaPortada>(
  (ref) => ref.watch(repositorioDeLaVidrieraProvider).seleccion(),
);
