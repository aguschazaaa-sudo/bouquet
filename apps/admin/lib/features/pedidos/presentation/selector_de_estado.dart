import 'package:flutter/material.dart';

import '../../../core/contratos/estado_entrega.dart';
import 'textos_de_pedidos.dart';

/// Los seis estados de entrega como fichas (HU-06.1): uno a la vez. El que se
/// elige es el `where` de la consulta de la bandeja.
///
/// Sin contadores en las fichas a proposito: cada numero seria **una lectura
/// mas por estado** (ADR 018, *Presupuesto*), y la lista de abajo ya dice si
/// esta vacia.
class SelectorDeEstado extends StatelessWidget {
  const SelectorDeEstado({
    super.key,
    required this.elegido,
    required this.alElegir,
  });

  final EstadoEntrega elegido;
  final ValueChanged<EstadoEntrega> alElegir;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final estado in EstadoEntrega.values)
          ChoiceChip(
            label: Text(textoDelEstado(estado)),
            selected: estado == elegido,
            onSelected: (_) => alElegir(estado),
          ),
      ],
    );
  }
}
