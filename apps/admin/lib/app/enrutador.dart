import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/acceso/acceso_providers.dart';
import '../features/acceso/domain/sesion.dart';
import '../features/acceso/presentation/pantalla_de_entrada.dart';
import '../features/acceso/presentation/pantalla_sin_acceso.dart';
import '../features/catalogo/presentation/pantalla_de_bodegas.dart';
import '../features/catalogo/presentation/pantalla_del_catalogo.dart';
import '../features/catalogo/presentation/vino/pagina_del_vino.dart';
import '../features/estructura/presentation/estructura_del_panel.dart';
import '../features/estructura/presentation/pagina_no_encontrada.dart';
import '../features/estructura/presentation/pantalla_de_espera.dart';
import '../features/pedidos/domain/orden.dart';
import '../features/pedidos/presentation/pagina_de_cargar_pedido.dart';
import '../features/pedidos/presentation/pagina_del_pedido.dart';
import '../features/pedidos/presentation/pantalla_de_pedidos.dart';
import 'destino.dart';
import 'rutas.dart';

/// La raiz de composicion del panel: el unico archivo que conoce las
/// pantallas de todas las features a la vez.
///
/// Quien decide a donde va cada uno es `destinoPara`, que es Dart puro y
/// tiene sus tests. Aca solo se la conecta: cada cambio de sesion avisa al
/// enrutador por `refreshListenable`, y el enrutador vuelve a preguntar.
final enrutadorProvider = Provider<GoRouter>((ref) {
  final sesion = ValueNotifier<Sesion>(const Resolviendo());
  ref.onDispose(sesion.dispose);

  ref.listen<AsyncValue<Sesion>>(sesionProvider, (_, estado) {
    // Un stream que fallo se trata como "nadie entro": la pantalla de
    // entrada es el lugar donde se puede volver a intentar.
    sesion.value = estado.hasError
        ? const SinSesion()
        : estado.valueOrNull ?? const Resolviendo();
  }, fireImmediately: true);

  final enrutador = GoRouter(
    refreshListenable: sesion,
    redirect: (_, estado) => destinoPara(sesion.value, estado.uri),
    errorBuilder: (_, _) => const PaginaNoEncontrada(),
    routes: [
      GoRoute(path: '/', redirect: (_, _) => Rutas.catalogo),
      GoRoute(path: Rutas.entrar, builder: (_, _) => const PantallaDeEntrada()),
      GoRoute(
        path: Rutas.sinAcceso,
        builder: (_, _) => const PantallaSinAcceso(),
      ),
      GoRoute(path: Rutas.espera, builder: (_, _) => const PantallaDeEspera()),
      ShellRoute(
        builder: (_, estado, child) =>
            EstructuraDelPanel(ubicacion: estado.uri.path, child: child),
        routes: [
          GoRoute(
            path: Rutas.catalogo,
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: PantallaDelCatalogo()),
            routes: [
              // Hija, no seccion: la navegacion sigue marcando Catalogo.
              // Va con transicion por omision -- entrar a Bodegas ES ir a
              // otro lado, a diferencia de cambiar de pestaña.
              GoRoute(
                path: 'bodegas',
                builder: (_, _) => const PantallaDeBodegas(),
              ),
              GoRoute(path: 'nuevo', builder: (_, _) => const PaginaDelVino()),
              GoRoute(
                path: 'vinos/:id',
                builder: (_, estado) =>
                    PaginaDelVino(id: estado.pathParameters['id']),
              ),
            ],
          ),
          GoRoute(
            path: Rutas.pedidos,
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: PantallaDePedidos()),
            routes: [
              // `nuevo` ANTES que `:id`, para que la palabra no se lea como un
              // id (HU-10.1).
              GoRoute(
                path: 'nuevo',
                builder: (_, _) => const PaginaDeCargarPedido(),
              ),
              // El detalle recibe la Orden que la bandeja ya cargo por `extra`:
              // desde la lista no lee nada. Por URL directa lee un documento.
              GoRoute(
                path: ':id',
                builder: (_, estado) => PaginaDelPedido(
                  id: estado.pathParameters['id']!,
                  ordenInicial: switch (estado.extra) {
                    final Orden o => o,
                    _ => null,
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
  ref.onDispose(enrutador.dispose);
  return enrutador;
});
