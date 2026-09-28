import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/firebase/firebase_providers.dart';
import 'data/repositorio_de_sesion_firebase.dart';
import 'domain/repositorio_de_sesion.dart';
import 'domain/sesion.dart';

/// El unico lugar que conoce la implementacion. `layer-boundary.sh` no deja
/// que `presentation/` importe `data/`: las pantallas piden este provider.
final repositorioDeSesionProvider = Provider<RepositorioDeSesion>(
  (ref) => RepositorioDeSesionFirebase(ref.watch(authProvider)),
);

/// La sesion de quien abrio el panel. Sin `autoDispose`: vive lo que vive la
/// app, y la escuchan el enrutador y las pantallas a la vez.
///
/// Para que llegue un claim recien dado: `renovarPermiso()` y despues
/// `ref.invalidate(sesionProvider)`. La suscripcion nueva lee el token ya
/// renovado, sin depender de que Firebase vuelva a emitir.
final sesionProvider = StreamProvider<Sesion>(
  (ref) => ref.watch(repositorioDeSesionProvider).cambios(),
);

/// Si quien abrio el panel avisa por WhatsApp (HU-07.3). `false` mientras la
/// sesion se resuelve: un boton que aparece y desaparece es peor que uno que
/// tarda.
final avisaPorWhatsappProvider = Provider<bool>(
  (ref) => switch (ref.watch(sesionProvider).valueOrNull) {
    Operador(:final avisaPorWhatsapp) => avisaPorWhatsapp,
    _ => false,
  },
);
