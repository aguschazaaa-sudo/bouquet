import 'package:flutter/material.dart';

/// El motivo corto de HU-03.7 en el renglón del catálogo: un vino
/// PUBLICADO que la tienda igual descarta. Aparte de `RenglonDeProducto`
/// para no acercarlo al tope de `widget-size-guard` -- no duplica el
/// renglón, es la pieza que le faltaba.
class MotivoCortoDeTienda extends StatelessWidget {
  const MotivoCortoDeTienda({super.key, required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 12, color: tema.colorScheme.error),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              texto,
              textAlign: TextAlign.end,
              style: tema.textTheme.labelSmall?.copyWith(
                color: tema.colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
