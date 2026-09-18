import 'package:flutter/material.dart';

import '../../../../core/contratos/producto.dart';
import 'problema_del_campo.dart';

/// Tinto, blanco o rosado. Arranca **sin elegir**: un tinto por omision seria
/// un rosado mal cargado que nadie ve, y la vidriera filtra por color.
class EleccionDeColor extends StatelessWidget {
  const EleccionDeColor({
    super.key,
    required this.elegido,
    required this.problema,
    required this.alElegir,
  });

  final ColorDelVino? elegido;
  final String? problema;
  final ValueChanged<ColorDelVino> alElegir;

  @override
  Widget build(BuildContext context) {
    final elegido = this.elegido;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text('Color', style: Theme.of(context).textTheme.titleSmall),
        ),
        const SizedBox(height: 10),
        SegmentedButton<ColorDelVino>(
          segments: [
            for (final c in ColorDelVino.values)
              ButtonSegment(value: c, label: Text(c.rotulo)),
          ],
          selected: {?elegido},
          emptySelectionAllowed: true,
          showSelectedIcon: false,
          onSelectionChanged: (s) {
            if (s.isNotEmpty) alElegir(s.first);
          },
        ),
        ProblemaDelCampo(texto: problema),
      ],
    );
  }
}
