import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/aviso.dart';
import '../../../core/presentation/cargando.dart';
import '../domain/movimiento_de_stock.dart';
import '../stock_providers.dart';
import 'encabezado_de_hoja.dart';
import 'textos_de_movimientos.dart';

/// Quién movió el stock de un vino y cuándo (HU-05.4): los últimos, el más
/// nuevo arriba.
///
/// **Una hoja y no una lista en la ficha**: la sección de stock vive en una
/// `Column` sin scroll, encima del formulario, y veinte renglones ahí
/// desbordarían la pantalla. Además cerrada no lee nada: abrir la ficha de un
/// vino no cuesta lecturas de más. Abierta cuesta como mucho
/// `topeDeMovimientos` (ADR 016 §6), cada vez que se abre.
class HojaDeMovimientos extends ConsumerWidget {
  const HojaDeMovimientos({
    super.key,
    required this.productoId,
    required this.nombre,
    required this.botellas,
  });

  final String productoId;
  final String nombre;
  final int botellas;

  static Future<void> mostrar(
    BuildContext context, {
    required String productoId,
    required String nombre,
    required int botellas,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => HojaDeMovimientos(
        productoId: productoId,
        nombre: nombre,
        botellas: botellas,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movimientos = ref.watch(movimientosProvider(productoId));
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EncabezadoDeHoja(titulo: textoTituloDeMovimientos, nombre: nombre),
            const SizedBox(height: 12),
            Flexible(
              child: switch (movimientos) {
                AsyncData(:final value) when value.isEmpty => const Aviso(
                  texto: textoSinMovimientos,
                ),
                AsyncData(:final value) => ListView(
                  shrinkWrap: true,
                  children: [
                    for (final m in value)
                      _RenglonDeMovimiento(m, botellas: botellas),
                  ],
                ),
                AsyncError() => Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Aviso(
                      texto: textoNoSePudieronLeer,
                      tono: TonoDelAviso.error,
                    ),
                    TextButton(
                      onPressed: () =>
                          ref.invalidate(movimientosProvider(productoId)),
                      child: const Text('Volver a intentar'),
                    ),
                  ],
                ),
                _ => const Cargando(que: 'Buscando los movimientos…'),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RenglonDeMovimiento extends StatelessWidget {
  const _RenglonDeMovimiento(this.movimiento, {required this.botellas});

  final MovimientoDeStock movimiento;
  final int botellas;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context).textTheme;
    final cuantos = deCuantoACuanto(movimiento, botellas: botellas);
    final quedo = [
      if (cuantos != null) cuantos,
      quien(movimiento),
      cuando(movimiento.en?.toLocal(), ahora: DateTime.now()),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            queSeHizo(movimiento, botellas: botellas),
            style: tema.bodyLarge,
          ),
          Text(quedo, style: tema.bodyMedium),
        ],
      ),
    );
  }
}
