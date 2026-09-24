import 'package:flutter/material.dart';

/// Un dato del pedido: lo que es y lo que dice (HU-06.2). Etiqueta chica arriba y
/// el valor abajo, con el valor **seleccionable**: el operador copia el telefono
/// o la direccion para pegarlos en otro lado.
class DatoDelPedido extends StatelessWidget {
  const DatoDelPedido({super.key, required this.etiqueta, required this.valor});

  final String etiqueta;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        container: true,
        label: '$etiqueta: $valor',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              etiqueta,
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            SelectableText(valor, style: tema.textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}
