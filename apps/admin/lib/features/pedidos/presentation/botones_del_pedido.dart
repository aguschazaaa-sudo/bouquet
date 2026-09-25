import 'package:flutter/material.dart';

import '../../../core/presentation/aviso.dart';
import '../domain/orden.dart';
import '../domain/paso_de_entrega.dart';
import 'textos_de_entrega.dart';

/// Lo que se puede hacer con un pedido ahora, un boton por accion (EP-07).
///
/// **Solo ofrece lo que la tabla del contrato permite desde el estado que se
/// ve** (`accionesDe`): un pedido entregado no muestra nada, uno despachado no
/// muestra cancelar. La primera accion hacia adelante es la principal; cancelar
/// va al final, con el color de error y separada, para que no se toque por
/// apuro.
///
/// Si despachar es lo que sigue pero **falta el pago** (un pedido de la tienda),
/// no se esconde en silencio: se dice por que.
class BotonesDelPedido extends StatelessWidget {
  const BotonesDelPedido({
    super.key,
    required this.orden,
    required this.ocupado,
    required this.alElegir,
  });

  final Orden orden;

  /// Mientras se guarda un cambio: ningun boton responde, asi no se toca dos
  /// veces.
  final bool ocupado;
  final ValueChanged<AccionDelPedido> alElegir;

  @override
  Widget build(BuildContext context) {
    final acciones = accionesDe(orden);
    final hacia = acciones.where((a) => a != AccionDelPedido.cancelar).toList();
    final cancelar = acciones.contains(AccionDelPedido.cancelar);
    final esperaElPago = despachoEsperaElPago(orden);
    if (acciones.isEmpty && !esperaElPago) return const SizedBox.shrink();

    final tema = Theme.of(context);
    VoidCallback? al(AccionDelPedido a) => ocupado ? null : () => alElegir(a);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(textoQueSigue, style: tema.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (esperaElPago) ...[
          const Aviso(texto: textoEsperaElPago),
          const SizedBox(height: 8),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (i, a) in hacia.indexed)
              i == 0
                  ? FilledButton(
                      onPressed: al(a),
                      child: Text(textoDeLaAccion(a)),
                    )
                  : OutlinedButton(
                      onPressed: al(a),
                      child: Text(textoDeLaAccion(a)),
                    ),
          ],
        ),
        if (ocupado) ...[
          const SizedBox(height: 12),
          const LinearProgressIndicator(),
        ],
        if (cancelar) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: tema.colorScheme.error,
              ),
              onPressed: al(AccionDelPedido.cancelar),
              icon: const Icon(Icons.cancel_outlined),
              label: Text(textoDeLaAccion(AccionDelPedido.cancelar)),
            ),
          ),
        ],
      ],
    );
  }
}
