import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/rutas.dart';
import '../../../core/presentation/campo_de_busqueda.dart';
import '../../../core/presentation/cargando.dart';
import '../../../core/presentation/fallo_con_reintento.dart';
import '../catalogo_providers.dart';
import '../domain/catalogo.dart';
import 'acceso_a_bodegas.dart';
import 'lista_del_catalogo.dart';

/// `/catalogo` — ver todos los vinos y buscarlos (HU-03.1).
///
/// Muestra **los publicados y los que no**: los que faltan terminar de cargar
/// son justamente los que hay que encontrar.
///
/// El buscador arriba de todo es la direccion visual que eligio el dueno —*"me
/// parece más eficiente la búsqueda de A"*, ADR 011 §4—, no una decision de
/// esta pantalla.
class PantallaDelCatalogo extends ConsumerWidget {
  const PantallaDelCatalogo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogo = ref.watch(catalogoProvider);
    final busqueda = ref.watch(busquedaProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            children: [
              CampoDeBusqueda(
                valor: busqueda,
                etiqueta: 'Buscar un vino o una bodega',
                alCambiar: (texto) =>
                    ref.read(busquedaProvider.notifier).state = texto,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: AccesoABodegas(
                      cuantas: catalogo.valueOrNull?.bodegas.length ?? 0,
                      alIr: context.go,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // La unica puerta a `/catalogo/nuevo` (HU-03.2).
                  FilledButton.icon(
                    onPressed: () => context.go(Rutas.nuevoVino),
                    icon: const Icon(Icons.add),
                    label: const Text('Cargar un vino'),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: switch (catalogo) {
            // El error va PRIMERO: un stream que fallo y se pinta como una
            // lista vacia manda a cargar de nuevo lo que ya existe.
            AsyncError() => FalloConReintento(
              texto:
                  'No pudimos leer tu catálogo. Puede ser la conexión, o que '
                  'tu cuenta todavía no tenga permiso.',
              alReintentar: () {
                ref.invalidate(productosProvider);
                ref.invalidate(bodegasProvider);
              },
            ),
            AsyncData(:final value) => _Encontrados(
              catalogo: value,
              busqueda: busqueda,
              alLimpiar: () => ref.read(busquedaProvider.notifier).state = '',
              alAbrir: (id) => context.go(Rutas.vino(id)),
            ),
            _ => const Cargando(que: 'Buscando tus vinos…'),
          },
        ),
      ],
    );
  }
}

/// La lista ya filtrada, con cuantos quedaron.
class _Encontrados extends StatelessWidget {
  const _Encontrados({
    required this.catalogo,
    required this.busqueda,
    required this.alLimpiar,
    required this.alAbrir,
  });

  final Catalogo catalogo;
  final String busqueda;
  final VoidCallback alLimpiar;
  final ValueChanged<String> alAbrir;

  @override
  Widget build(BuildContext context) {
    final renglones = catalogo.filtrar(busqueda);
    final tema = Theme.of(context);

    return Column(
      children: [
        if (renglones.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Semantics(
                // Se anuncia al filtrar: quien no ve la pantalla necesita
                // enterarse de que la lista cambio.
                liveRegion: true,
                child: Text(
                  _cuantos(renglones.length, catalogo.renglones.length),
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
          ),
        Expanded(
          child: ListaDelCatalogo(
            renglones: renglones,
            hayVinos: catalogo.renglones.isNotEmpty,
            alLimpiarLaBusqueda: alLimpiar,
            alAbrir: alAbrir,
          ),
        ),
      ],
    );
  }

  static String _cuantos(int mostrados, int total) {
    if (mostrados == total) {
      return total == 1 ? '1 vino' : '$total vinos';
    }
    return '$mostrados de $total';
  }
}
