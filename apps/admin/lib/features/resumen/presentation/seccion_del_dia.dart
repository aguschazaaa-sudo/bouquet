import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/rutas.dart';
import '../../catalogo/catalogo_providers.dart';
import '../../catalogo/domain/catalogo.dart';
import '../domain/lo_del_dia.dart';
import '../resumen_providers.dart';
import 'cifra_del_dia.dart';
import 'textos_del_resumen.dart';

/// Lo que hay que saber para arrancar el dia (HU-11.2): cuantos pedidos hay
/// por preparar, cuantos pagos siguen en proceso y que se agoto.
///
/// Los dos conteos son dos lecturas; lo agotado sale del catalogo en memoria,
/// gratis (ADR 025). Cada numero lleva a donde se resuelve: los pedidos a
/// Pedidos —que abre en *"Requieren acción"*—, lo agotado a Catalogo con el
/// filtro *"Por reponer"* ya puesto.
class SeccionDelDia extends ConsumerWidget {
  const SeccionDelDia({super.key, required this.catalogo});

  final Catalogo catalogo;

  /// Con este ancho entran las tres cifras en una fila; abajo, una por fila.
  static const _anchoParaTres = 600.0;
  static const _espacio = 12.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final porPreparar = ref.watch(porPrepararProvider);
    final enProceso = ref.watch(pagosEnProcesoProvider);
    final agotados = agotadosEnLaTienda(catalogo);
    final hayQueReponer = catalogo.cuantosPorReponer > 0;

    final cifras = [
      CifraDelDia(
        titulo: textoPorPreparar,
        explicacion: textoQueEsPorPreparar,
        cifra: _texto(porPreparar),
        fallo: porPreparar.hasError,
        accion: textoVerPedidos,
        alTocar: () => context.go(Rutas.pedidos),
      ),
      CifraDelDia(
        titulo: textoPagosEnProceso,
        explicacion: textoQueEsEnProceso,
        cifra: _texto(enProceso),
        fallo: enProceso.hasError,
      ),
      CifraDelDia(
        titulo: textoAgotados,
        explicacion: textoQueEsAgotados,
        cifra: '${agotados.length}',
        accion: hayQueReponer ? textoVerQueReponer : null,
        alTocar: hayQueReponer
            ? () {
                ref.read(soloPorReponerProvider.notifier).state = true;
                context.go(Rutas.catalogo);
              }
            : null,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(textoTituloDelDia, style: tema.textTheme.titleLarge),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, limites) {
            final columnas = limites.maxWidth >= _anchoParaTres ? 3 : 1;
            final ancho =
                (limites.maxWidth - _espacio * (columnas - 1)) / columnas;
            return Wrap(
              spacing: _espacio,
              runSpacing: _espacio,
              children: [
                for (final c in cifras) SizedBox(width: ancho, child: c),
              ],
            );
          },
        ),
        if (agotados.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            textoSeAgotaron([for (final p in agotados) p.nombre]),
            style: tema.textTheme.bodyMedium,
          ),
        ],
        if (porPreparar.hasError || enProceso.hasError)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                ref.invalidate(porPrepararProvider);
                ref.invalidate(pagosEnProcesoProvider);
              },
              icon: const Icon(Icons.refresh),
              label: const Text(textoVolverAContar),
            ),
          ),
      ],
    );
  }

  /// `null` mientras se cuenta; el error lo dice `CifraDelDia.fallo`.
  static String? _texto(AsyncValue<Conteo> conteo) => switch (conteo) {
    AsyncData(:final value) => textoDelConteo(value),
    _ => null,
  };
}
