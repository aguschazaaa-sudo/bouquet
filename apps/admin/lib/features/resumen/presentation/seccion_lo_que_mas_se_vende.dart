import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/rutas.dart';
import '../../../core/presentation/aviso.dart';
import '../../catalogo/domain/catalogo.dart';
import '../../pedidos/domain/hace_cuanto.dart';
import '../domain/lo_que_mas_se_vende.dart';
import '../resumen_providers.dart';
import 'renglon_de_venta.dart';
import 'textos_del_resumen.dart';

/// Que vinos se venden mas (HU-11.3), medido por `calcularPopularidad` sobre
/// los pedidos de la ventana.
///
/// **Sin medicion no hay ranking**: el documento simulado del seed se dice
/// como *"todavía no hay ventas medidas"*, no se dibuja (EP-11). Una lectura
/// por apertura; los nombres salen del catalogo en memoria.
class SeccionLoQueMasSeVende extends ConsumerWidget {
  const SeccionLoQueMasSeVende({super.key, required this.catalogo});

  final Catalogo catalogo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tema = Theme.of(context);
    final estado = ref.watch(loQueMasSeVendeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            textoTituloLoQueMasSeVende,
            style: tema.textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 12),
        ...switch (estado) {
          AsyncData(value: final lo) => _loQueHay(context, tema, lo),
          AsyncError() => [
            const Aviso(
              texto: textoNoSeLeyoLoQueMasSeVende,
              tono: TonoDelAviso.error,
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => ref.invalidate(loQueMasSeVendeProvider),
                icon: const Icon(Icons.refresh),
                label: const Text(textoVolverALeer),
              ),
            ),
          ],
          _ => [const LinearProgressIndicator()],
        },
      ],
    );
  }

  List<Widget> _loQueHay(
    BuildContext context,
    ThemeData tema,
    LoQueMasSeVende lo,
  ) => switch (lo) {
    SinMedir() => [const Aviso(texto: textoSinMedir)],
    Ilegible() => [
      const Aviso(texto: textoIlegible, tono: TonoDelAviso.error),
    ],
    Medido(:final puestos, :final ventanaDias) when puestos.isEmpty => [
      Text(textoSinVentasEnLaVentana(ventanaDias)),
    ],
    Medido(:final puestos, :final ventanaDias, :final ventas, :final calculadaEn) => [
      Text(
        textoDeLaVentana(
          dias: ventanaDias,
          ventas: ventas,
          cuando: haceCuanto(calculadaEn, DateTime.now()),
        ),
        style: tema.textTheme.bodySmall,
      ),
      const SizedBox(height: 4),
      for (final (i, puesto) in puestos.indexed)
        RenglonDeVenta(
          posicion: i + 1,
          nombre: catalogo.vino(puesto.productoId)?.nombre ??
              textoVinoQueYaNoEsta,
          unidades: puesto.unidades,
          alAbrir: catalogo.vino(puesto.productoId) == null
              ? null
              : () => context.go(Rutas.vino(puesto.productoId)),
        ),
    ],
  };
}
