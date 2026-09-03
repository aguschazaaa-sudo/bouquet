import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// TODO(paso siguiente de ARQUITECTURA §12): falta `Firebase.initializeApp()`
// contra `firebase_options.dart`. Ese archivo lo genera `flutterfire
// configure` contra un proyecto Firebase real y toca `firebase.json` /
// `.firebaserc` — los dos están fuera del alcance de esta tarea (que es
// estructura y capas data/domain, no deploy) y en la lista de "no tocar".
// Sin esa pieza, `FirebaseFirestore.instance` (usado en
// core/firebase/firebase_providers.dart) va a fallar en tiempo de
// ejecución — esperado hasta que exista el proyecto conectado.
//
// La dirección visual tampoco corrió todavía: no existen
// docs/vault/design/direccion.md ni tokens.md tokens (ver /disenio). Por
// eso este archivo usa los defaults de Material y no declara un solo
// color — no-hardcoded-colors.sh lo bloquearía igual.

void main() {
  runApp(const ProviderScope(child: BouquetAdminApp()));
}

/// La raíz de la app. Placeholder a propósito: la UI con diseño real es
/// otra tarea, posterior a `/disenio`.
class BouquetAdminApp extends StatelessWidget {
  const BouquetAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'bouquet — panel',
      home: _PantallaPlaceholder(),
    );
  }
}

class _PantallaPlaceholder extends StatelessWidget {
  const _PantallaPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('bouquet — panel')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Estructura y capas data/domain listas.\n'
            'La dirección visual todavía no corrió (/disenio).',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
