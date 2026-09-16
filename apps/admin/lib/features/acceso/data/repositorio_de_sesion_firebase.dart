import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;

import '../domain/repositorio_de_sesion.dart';
import '../domain/sesion.dart';
import 'codigos_de_auth.dart';

/// El acceso al panel, sobre Firebase Auth.
///
/// Las cuentas NO nacen aca: las crea `scripts/acceso/acceso.mjs`, sin
/// contrasena. La contrasena nace con el correo de restablecimiento, que de
/// paso verifica el mail — y con el mail verificado, entrar despues con Google
/// no desvincula la contrasena (medido en el emulador, design.md §1).
class RepositorioDeSesionFirebase implements RepositorioDeSesion {
  RepositorioDeSesionFirebase(this._auth);

  final FirebaseAuth _auth;

  /// A donde vuelve el boton "Continuar" del correo de contrasena. Tiene que
  /// estar entre los dominios autorizados de Auth, y los canales de preview no
  /// lo estan: por eso es fijo y no sale de la URL actual.
  static const _volverAlPanel = 'https://bouquet-vinos.web.app/entrar';

  @override
  Stream<Sesion> cambios() => _auth.idTokenChanges().asyncMap(_leer);

  Future<Sesion> _leer(User? usuario) async {
    if (usuario == null) return const SinSesion();
    final mail = usuario.email ?? '';
    try {
      final token = await usuario.getIdTokenResult();
      return sesionDesde(mail: mail, claims: token.claims);
    } catch (e) {
      debugPrint('No se pudo leer el token de $mail: $e');
      return Inaccesible(mail);
    }
  }

  @override
  Future<void> entrarConMail({
    required String mail,
    required String contrasena,
  }) => _traducir(
    () => _auth.signInWithEmailAndPassword(
      email: mail.trim(),
      password: contrasena,
    ),
  );

  @override
  Future<bool> entrarConGoogle() async {
    final google = GoogleAuthProvider()
      ..setCustomParameters({'prompt': 'select_account'});
    try {
      if (kIsWeb) {
        await _auth.signInWithPopup(google);
      } else {
        await _auth.signInWithProvider(google);
      }
      return true;
    } on FirebaseAuthException catch (e) {
      final error = errorDeEntradaPara(e.code);
      if (error == null) return false;
      debugPrint('Entrar con Google fallo: ${e.code}');
      throw FalloDeEntrada(error, e.code);
    }
  }

  @override
  Future<void> pedirMailDeContrasena(String mail) async {
    await _auth.setLanguageCode('es');
    try {
      await _traducir(
        () => _auth.sendPasswordResetEmail(
          email: mail.trim(),
          actionCodeSettings: ActionCodeSettings(url: _volverAlPanel),
        ),
      );
    } on FalloDeEntrada catch (e) {
      // Sin la proteccion contra enumeracion (el emulador, por ejemplo),
      // Firebase avisa que el mail no existe. La pantalla tiene que decir lo
      // mismo que con un mail habilitado.
      if (e.codigo == 'user-not-found') return;
      rethrow;
    }
  }

  @override
  Future<void> renovarPermiso() async {
    final usuario = _auth.currentUser;
    if (usuario == null) return;
    await _traducir(() => usuario.getIdTokenResult(true));
  }

  @override
  Future<void> salir() => _auth.signOut();

  Future<void> _traducir(Future<void> Function() operacion) async {
    try {
      await operacion();
    } on FirebaseAuthException catch (e) {
      debugPrint('Auth respondio ${e.code}');
      throw FalloDeEntrada(
        errorDeEntradaPara(e.code) ?? ErrorDeEntrada.desconocido,
        e.code,
      );
    }
  }
}
