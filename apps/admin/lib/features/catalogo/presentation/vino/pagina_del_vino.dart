import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/rutas.dart';
import '../../../../core/presentation/cargando.dart';
import '../../../../core/presentation/fallo_con_reintento.dart';
import '../../../../core/presentation/lista_vacia.dart';
import '../../catalogo_providers.dart';
import 'formulario_del_vino.dart';
import 'seccion_de_la_tienda.dart';

/// `/catalogo/nuevo` y `/catalogo/vinos/<id>` — cargar un vino o corregirlo.
///
/// Una pagina con URL y no una hoja: son diez campos, en un telefono no
/// entran en una hoja, y una correccion con URL se puede recargar y mandar a
/// otro de la familia (ADR 013 §6).
///
/// **El vino sale del catalogo en memoria**: abrirlo cuesta cero lecturas.
/// Mientras el catalogo carga, espera; si cargo y el id no esta, lo dice —
/// una URL con un id inventado no es un formulario vacio.
class PaginaDelVino extends ConsumerWidget {
  const PaginaDelVino({super.key, this.id});

  /// `null` para cargar uno nuevo.
  final String? id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogo = ref.watch(catalogoProvider);
    final id = this.id;
    // "Volver" navega a Catalogo en vez de hacer `pop`: la URL se puede abrir
    // directo, y ahi no hay nada que desapilar.
    void volver() => context.go(Rutas.catalogo);

    final nombre = id == null ? null : catalogo.valueOrNull?.vino(id)?.nombre;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Encabezado(
          titulo: id == null
              ? 'Cargar un vino'
              : nombre == null || nombre.isEmpty
              ? 'Corregir un vino'
              : 'Corregir $nombre',
          alVolver: volver,
        ),
        Expanded(
          child: switch (catalogo) {
            AsyncError() => FalloConReintento(
              texto:
                  'No pudimos leer tu catálogo. Puede ser la conexión, o que '
                  'tu cuenta todavía no tenga permiso.',
              alReintentar: () {
                ref.invalidate(productosProvider);
                ref.invalidate(bodegasProvider);
              },
            ),
            AsyncData() when id == null => FormularioDelVino(
              alTerminar: volver,
            ),
            AsyncData(:final value) => switch (value.vino(id!)) {
              final vino? => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: SeccionDeLaTienda(producto: vino, catalogo: value),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: FormularioDelVino(
                      // Otro vino es otro formulario: el estado no se arrastra.
                      key: ValueKey(vino.id),
                      original: vino,
                      alTerminar: volver,
                    ),
                  ),
                ],
              ),
              null => ListaVacia(
                icono: Icons.search_off,
                texto:
                    'Ese vino no existe. Puede que la dirección esté mal '
                    'escrita.',
                accion: OutlinedButton(
                  onPressed: volver,
                  child: const Text('Ir al catálogo'),
                ),
              ),
            },
            _ => const Cargando(que: 'Buscando el vino…'),
          },
        ),
      ],
    );
  }
}

/// El volver y el titulo.
class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.titulo, required this.alVolver});

  final String titulo;
  final VoidCallback alVolver;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: alVolver,
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Volver al catálogo',
          ),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                titulo,
                style: Theme.of(context).textTheme.titleLarge,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
