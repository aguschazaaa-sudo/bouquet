import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/aviso.dart';
import '../stock_providers.dart';
import 'textos_de_ventas_sin_despachar.dart';

/// Lo que hay vendido y sin despachar de un vino, dicho antes de contar el
/// deposito (HU-05.2, ADR 018 §9, hallazgo 1 de `revisor-pagos`).
///
/// Es un **aviso**, no una baranda: no impide corregir. Cuenta lo que ya esta
/// descontado del stock y **sigue en la estanteria**: contarlo sin restarlo
/// pisa la venta.
///
/// - Mientras lee, no dibuja nada: no es lo que el operador vino a hacer.
/// - Si no puede leer, **lo dice**. Un *"no hay"* que en realidad es *"no pude
///   ver"* es un falso tranquilizador (mismo criterio que `FalloConReintento`).
class AvisoDeVentasSinDespachar extends ConsumerWidget {
  const AvisoDeVentasSinDespachar({
    super.key,
    required this.productoId,
    required this.botellas,
  });

  final String productoId;
  final int botellas;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ventas = ref.watch(ventasSinDespacharProvider(productoId));
    return switch (ventas) {
      AsyncData(:final value) when value.hayQueAvisar => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Aviso(
          texto: textoDeVentasSinDespachar(value, botellas: botellas),
          tono: TonoDelAviso.informacion,
        ),
      ),
      AsyncError() => const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Aviso(
          texto: textoNoSePudoVerLoVendido,
          tono: TonoDelAviso.informacion,
        ),
      ),
      _ => const SizedBox.shrink(),
    };
  }
}
