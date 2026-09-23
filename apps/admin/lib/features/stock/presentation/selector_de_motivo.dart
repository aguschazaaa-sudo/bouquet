import 'package:flutter/material.dart';

import '../../../core/contratos/stock.dart';
import 'textos_del_stock.dart';

/// El motivo de una correccion de stock, de un toque.
///
/// Una lista corta y cerrada, **no un campo de texto**: poca burocracia
/// (overview del panel, criterio 4 — *un motivo es un toque, no un
/// formulario*). Y cerrada por otra razon: un motivo escrito a mano no se
/// puede contar despues, y el registro de movimientos existe justamente para
/// explicar una diferencia.
class SelectorDeMotivo extends StatelessWidget {
  const SelectorDeMotivo({
    super.key,
    required this.motivo,
    required this.alCambiar,
    this.habilitado = true,
  });

  final MotivoDeAjuste motivo;
  final ValueChanged<MotivoDeAjuste> alCambiar;
  final bool habilitado;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('¿Por qué cambia?', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        SegmentedButton<MotivoDeAjuste>(
          showSelectedIcon: false,
          segments: [
            for (final m in MotivoDeAjuste.values)
              ButtonSegment(value: m, label: Text(rotuloDelMotivo(m))),
          ],
          selected: {motivo},
          onSelectionChanged: habilitado ? (s) => alCambiar(s.first) : null,
        ),
      ],
    );
  }
}
