import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/rutas.dart';
import '../../../core/presentation/aviso.dart';
import '../../../core/presentation/cargando.dart';
import '../../../core/presentation/fallo_con_reintento.dart';
import '../../../core/presentation/lista_vacia.dart';
import '../catalogo_providers.dart';
import '../domain/bodega.dart';
import '../domain/catalogo.dart';
import 'borrado_de_bodega.dart';
import 'hoja_de_bodega.dart';
import 'renglon_de_bodega.dart';

/// `/catalogo/bodegas` — EP-02 entera.
///
/// **No es una seccion de la navegacion**: se llega desde Catalogo, y la
/// navegacion sigue marcando Catalogo mientras se esta aca porque no se salio
/// de ahi (`Seccion.estaActiva` mira el prefijo).
///
/// El "volver" navega a `/catalogo` en vez de hacer `pop`: alguien puede
/// abrir esta URL directo en el navegador, y ahi no hay nada que desapilar.
class PantallaDeBodegas extends ConsumerStatefulWidget {
  const PantallaDeBodegas({super.key});

  @override
  ConsumerState<PantallaDeBodegas> createState() => _PantallaDeBodegasState();
}

class _PantallaDeBodegasState extends ConsumerState<PantallaDeBodegas> {
  String? _fallo;

  Future<void> _borrar(Bodega bodega) async {
    final problema = await borrarBodega(
      context: context,
      repositorio: ref.read(repositorioDeBodegasProvider),
      bodega: bodega,
    );
    if (mounted) setState(() => _fallo = problema);
  }

  @override
  Widget build(BuildContext context) {
    final catalogo = ref.watch(catalogoProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Encabezado(
          alVolver: () => context.go(Rutas.catalogo),
          alCargar: () => HojaDeBodega.mostrar(context),
        ),
        if (_fallo case final fallo?)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Aviso(texto: fallo, tono: TonoDelAviso.error),
          ),
        Expanded(
          child: switch (catalogo) {
            AsyncError() => FalloConReintento(
              texto:
                  'No pudimos leer tus bodegas. Puede ser la conexión, o que '
                  'tu cuenta todavía no tenga permiso.',
              alReintentar: () {
                ref.invalidate(bodegasProvider);
                ref.invalidate(productosProvider);
              },
            ),
            AsyncData(:final value) => _Lista(
              catalogo: value,
              alCorregir: (b) => HojaDeBodega.mostrar(context, bodega: b),
              alBorrar: _borrar,
            ),
            _ => const Cargando(que: 'Buscando tus bodegas…'),
          },
        ),
      ],
    );
  }
}

/// El titulo, el volver y el boton de cargar una.
class _Encabezado extends StatelessWidget {
  const _Encabezado({required this.alVolver, required this.alCargar});

  final VoidCallback alVolver;
  final VoidCallback alCargar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 12),
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
                'Bodegas',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
          FilledButton.icon(
            onPressed: alCargar,
            icon: const Icon(Icons.add),
            label: const Text('Cargar'),
          ),
        ],
      ),
    );
  }
}

/// Las bodegas, o el mensaje de que todavia no hay ninguna.
class _Lista extends StatelessWidget {
  const _Lista({
    required this.catalogo,
    required this.alCorregir,
    required this.alBorrar,
  });

  final Catalogo catalogo;
  final void Function(Bodega bodega) alCorregir;
  final void Function(Bodega bodega) alBorrar;

  @override
  Widget build(BuildContext context) {
    if (catalogo.bodegas.isEmpty) {
      return const ListaVacia(
        icono: Icons.store_outlined,
        texto:
            'Todavía no cargaste ninguna bodega. Cargá la primera con el '
            'botón de arriba: cada vino necesita la suya.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: catalogo.bodegas.length,
      itemBuilder: (_, i) {
        final bodega = catalogo.bodegas[i];
        return RenglonDeBodega(
          bodega: bodega,
          vinos: catalogo.vinosDe(bodega.id),
          alCorregir: () => alCorregir(bodega),
          alBorrar: () => alBorrar(bodega),
        );
      },
    );
  }
}
