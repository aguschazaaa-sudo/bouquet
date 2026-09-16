import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app/enrutador.dart';
import 'firebase_options.dart';
import 'theme/tema.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // URLs como `/pedidos` y no `/#/pedidos`: se recargan, se comparten y el
  // hosting reescribe todo a index.html (firebase.json).
  usePathUrlStrategy();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const ProviderScope(child: BouquetAdminApp()));
}

/// La raiz de la app: el tema de la mezcla C y el enrutador que decide que
/// pantalla ve cada sesion.
class BouquetAdminApp extends ConsumerWidget {
  const BouquetAdminApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'bouquet — panel',
      debugShowCheckedModeBanner: false,
      theme: temaDelPanel(),
      routerConfig: ref.watch(enrutadorProvider),
      locale: const Locale('es', 'AR'),
      supportedLocales: const [Locale('es', 'AR'), Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
    );
  }
}
