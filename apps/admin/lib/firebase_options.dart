// La conexion del panel con `bouquet-vinos`.
//
// Es la forma que genera `flutterfire configure`, escrita a partir de
// `firebase apps:sdkconfig WEB 1:540462799612:web:0587ab1204ff326191d579`
// (la app "bouquet panel", registrada el 2026-09-16). La API key web es
// publica por diseno: lo que protege los datos son las reglas y el claim.
//
// Android no esta: la APK entra en el hito 2, con su propia app registrada y
// la huella SHA-1 de la clave con la que se firma (HU-01.1).

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    throw UnsupportedError(
      'El panel todavia no esta configurado para $defaultTargetPlatform: '
      'la app de Android se registra en el hito 2.',
    );
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBDunrsRHAOHpKAu2PWq2beIHGKjb3q0Ys',
    appId: '1:540462799612:web:0587ab1204ff326191d579',
    messagingSenderId: '540462799612',
    projectId: 'bouquet-vinos',
    authDomain: 'bouquet-vinos.firebaseapp.com',
    storageBucket: 'bouquet-vinos.firebasestorage.app',
  );
}
