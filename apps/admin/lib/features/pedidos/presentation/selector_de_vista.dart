import 'package:flutter/material.dart';

import '../domain/vista_de_bandeja.dart';
import 'textos_de_pedidos.dart';

/// Las tres fichas de la bandeja (ADR 027): *Para hacer*, *En camino* y
/// *Terminados*. Una a la vez: la elegida es el `where` de la consulta.
///
/// Sin contadores en las fichas a proposito: cada numero seria **una consulta
/// mas por ficha** (ADR 018, *Presupuesto*), y la lista de abajo ya dice si esta
/// vacia.
class SelectorDeVista extends StatelessWidget {
  const SelectorDeVista({
    super.key,
    required this.elegida,
    required this.alElegir,
  });

  final VistaDeBandeja elegida;
  final ValueChanged<VistaDeBandeja> alElegir;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final vista in VistaDeBandeja.values)
          ChoiceChip(
            label: Text(textoDeLaVista(vista)),
            selected: vista == elegida,
            onSelected: (_) => alElegir(vista),
          ),
      ],
    );
  }
}
