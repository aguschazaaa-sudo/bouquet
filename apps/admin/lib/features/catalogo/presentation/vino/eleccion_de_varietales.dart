import 'package:flutter/material.dart';

import '../../../../core/contratos/producto.dart';
import 'problema_del_campo.dart';

/// Las uvas, de la **lista cerrada** y en su orden (ADR 008 §1). Un varietal
/// escrito a mano —"Cab. Sauv."— es un filtro que no encuentra nada, por eso
/// aca no se escribe: se elige.
///
/// Si un vino guardado trae una uva fuera de la lista —el Admin SDK no pasa
/// por las reglas—, aparece al final, elegida, para que se pueda sacar.
class EleccionDeVarietales extends StatelessWidget {
  const EleccionDeVarietales({
    super.key,
    required this.elegidos,
    required this.problema,
    required this.alCambiar,
  });

  final List<String> elegidos;
  final String? problema;
  final void Function(String uva, bool elegida) alCambiar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final fuera = [
      for (final v in elegidos)
        if (!varietales.contains(v)) v,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text('Uvas', style: tema.textTheme.titleSmall),
        ),
        const SizedBox(height: 2),
        Text(
          'Una sola es una cepa; dos o más, un corte.',
          style: tema.textTheme.bodySmall?.copyWith(
            color: tema.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final uva in [...varietales, ...fuera])
              FilterChip(
                label: Text(uva),
                selected: elegidos.contains(uva),
                onSelected: (elegida) => alCambiar(uva, elegida),
              ),
          ],
        ),
        ProblemaDelCampo(texto: problema),
      ],
    );
  }
}
