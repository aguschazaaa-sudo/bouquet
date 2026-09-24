import 'package:flutter/material.dart';

import '../../../core/contratos/plata.dart';
import '../../../theme/tema.dart';
import '../../../theme/tokens.dart';
import '../domain/orden.dart';
import 'textos_de_pedidos.dart';

/// Que lleva el pedido (HU-06.2): cada vino con su cantidad y su precio, y el
/// total de lista.
///
/// **Todo sale del snapshot de `items[]`, nunca del producto de hoy**: el precio
/// del vino cambia y el que se anoto no. No lee ni un documento de `productos`.
///
/// El total dice *"Total de lista"*, no *"cobrado"*: el cobro de un pedido de
/// WhatsApp va por fuera y el panel no lo sigue (ADR 018 §6).
class SeccionDeItems extends StatelessWidget {
  const SeccionDeItems({super.key, required this.orden});

  final Orden orden;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(textoQueLleva, style: tema.textTheme.titleMedium),
        const SizedBox(height: 8),
        for (final item in orden.items)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Tokens.regla)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.nombre, style: estiloDeNombre()),
                      const SizedBox(height: 2),
                      Text(
                        '${item.cantidad} × ${enPesos(item.precioUnitario)}'
                        '${item.botellas > 1 ? ' · caja de ${item.botellas}' : ''}',
                        style: tema.textTheme.bodySmall?.copyWith(
                          color: tema.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(enPesos(item.subtotal), style: tema.textTheme.bodyLarge),
              ],
            ),
          ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                '$textoTotalDeLista · ${textoBotellas(orden.botellasEnTotal)}',
                style: tema.textTheme.titleMedium,
              ),
            ),
            Text(enPesos(orden.total), style: tema.textTheme.titleMedium),
          ],
        ),
      ],
    );
  }
}
