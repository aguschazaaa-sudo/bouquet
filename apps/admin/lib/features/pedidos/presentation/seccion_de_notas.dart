import 'package:flutter/material.dart';

import '../domain/orden.dart';
import 'textos_de_notas.dart';

/// Las notas internas de un pedido (HU-07.7): lo que quien lo retome tiene que
/// saber. Se ven siempre —tambien *"Sin notas."*—, porque una seccion que
/// aparece solo cuando hay nota no dice que se puede escribir una.
///
/// **No escribe**: [alEditar] abre la hoja y quien la abre guarda, igual que
/// los botones del pedido. Asi el error se muestra en un solo lugar.
class SeccionDeNotas extends StatelessWidget {
  const SeccionDeNotas({
    super.key,
    required this.orden,
    required this.ocupado,
    required this.alEditar,
  });

  final Orden orden;

  /// Hay un cambio guardandose: no se abre otra escritura encima.
  final bool ocupado;
  final VoidCallback alEditar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final nota = orden.notasOperador;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(textoNotas, style: tema.textTheme.titleMedium),
        const SizedBox(height: 2),
        Text(
          textoNotasSoloFamilia,
          style: tema.textTheme.bodySmall?.copyWith(
            color: tema.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        if (nota == null)
          Text(
            textoSinNotas,
            style: tema.textTheme.bodyLarge?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
            ),
          )
        else
          SelectableText(nota, style: tema.textTheme.bodyLarge),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: ocupado ? null : alEditar,
            icon: const Icon(Icons.edit_note),
            label: Text(nota == null ? textoEscribirNota : textoEditarNota),
          ),
        ),
      ],
    );
  }
}
