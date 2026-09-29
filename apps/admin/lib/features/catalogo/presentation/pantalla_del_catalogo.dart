import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/rutas.dart';
import '../../../core/presentation/campo_de_busqueda.dart';
import '../../../core/presentation/cargando.dart';
import '../../../core/presentation/fallo_con_reintento.dart';
import '../../../core/presentation/lista_vacia.dart';
import '../../../core/presentation/renglon_con_accion.dart';
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
///
/// **Un solo scroll**: el encabezado se va con la lista. Fijo arriba, en un
/// telefono se comia mas de la mitad de la pantalla y la lista quedaba en una
/// ranura (lo mostro el dueño el 2026-09-29).
class PantallaDelCatalogo extends ConsumerWidget {
  const PantallaDelCatalogo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogo = ref.watch(catalogoProvider);
    final busqueda = ref.watch(busquedaProvider);
    final soloPorReponer = ref.watch(soloPorReponerProvider);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                CampoDeBusqueda(
                  valor: busqueda,
                  etiqueta: 'Buscar un vino o una bodega',
                  alCambiar: (texto) =>
                      ref.read(busquedaProvider.notifier).state = texto,
                ),
                const SizedBox(height: 12),
                RenglonConAccion(
                  principal: AccesoABodegas(
                    cuantas: catalogo.valueOrNull?.bodegas.length ?? 0,
                    alIr: context.go,
                  ),
                  // La unica puerta a `/catalogo/nuevo` (HU-03.2).
                  accion: FilledButton.icon(
                    onPressed: () => context.go(Rutas.nuevoVino),
                    icon: const Icon(Icons.add),
                    label: const Text('Cargar un vino'),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  // HU-05.3: el numero es lo que dice si vale la pena tocarlo.
                  child: FilterChip(
                    label: Text(
                      'Por reponer (${catalogo.valueOrNull?.cuantosPorReponer ?? 0})',
                    ),
                    selected: soloPorReponer,
                    onSelected: (v) =>
                        ref.read(soloPorReponerProvider.notifier).state = v,
                  ),
                ),
              ],
            ),
          ),
        ),
        switch (catalogo) {
          // El error va PRIMERO: un stream que fallo y se pinta como una
          // lista vacia manda a cargar de nuevo lo que ya existe.
          AsyncError() => SliverFillRemaining(
            hasScrollBody: false,
            child: FalloConReintento(
              texto:
                  'No pudimos leer tu catálogo. Puede ser la conexión, o que '
                  'tu cuenta todavía no tenga permiso.',
              alReintentar: () {
                ref.invalidate(productosProvider);
                ref.invalidate(bodegasProvider);
              },
            ),
          ),
          AsyncData(:final value) => _Encontrados(
            catalogo: value,
            busqueda: busqueda,
            soloPorReponer: soloPorReponer,
            alVerTodos: () =>
                ref.read(soloPorReponerProvider.notifier).state = false,
            alLimpiar: () => ref.read(busquedaProvider.notifier).state = '',
            alAbrir: (id) => context.go(Rutas.vino(id)),
          ),
          _ => const SliverFillRemaining(
            hasScrollBody: false,
            child: Cargando(que: 'Buscando tus vinos…'),
          ),
        },
      ],
    );
  }
}

/// La lista ya filtrada, con cuantos quedaron. Un sliver, como la lista.
class _Encontrados extends StatelessWidget {
  const _Encontrados({
    required this.catalogo,
    required this.busqueda,
    required this.soloPorReponer,
    required this.alVerTodos,
    required this.alLimpiar,
    required this.alAbrir,
  });

  final Catalogo catalogo;
  final String busqueda;

  /// El filtro de HU-05.3, encima de la busqueda.
  final bool soloPorReponer;
  final VoidCallback alVerTodos;
  final VoidCallback alLimpiar;
  final ValueChanged<String> alAbrir;

  @override
  Widget build(BuildContext context) {
    final renglones = catalogo.filtrar(
      busqueda,
      soloPorReponer: soloPorReponer,
    );
    final tema = Theme.of(context);

    // Con el filtro puesto, "no hay ninguno" es una BUENA noticia y se dice
    // como tal: el vacio generico ("ningun vino coincide") suena a que algo
    // fallo, y manda a buscar de nuevo lo que simplemente no falta.
    if (soloPorReponer && renglones.isEmpty) {
      return SliverToBoxAdapter(
        child: ListaVacia(
          icono: Icons.check_circle_outline,
          texto: busqueda.isEmpty
              ? 'No hay nada por reponer: todos tus vinos tienen stock.'
              : 'Ningún vino por reponer coincide con lo que buscaste.',
          accion: OutlinedButton(
            onPressed: alVerTodos,
            child: const Text('Ver todos'),
          ),
        ),
      );
    }

    return SliverMainAxisGroup(
      slivers: [
        if (renglones.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            sliver: SliverToBoxAdapter(
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
        ListaDelCatalogo(
          renglones: renglones,
          catalogo: catalogo,
          hayVinos: catalogo.renglones.isNotEmpty,
          alLimpiarLaBusqueda: alLimpiar,
          alAbrir: alAbrir,
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
