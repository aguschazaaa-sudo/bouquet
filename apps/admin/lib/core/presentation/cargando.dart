import 'package:flutter/material.dart';

/// Se esta leyendo algo. Con texto, no solo el circulito: un spinner sin
/// palabras es indistinguible de una pantalla colgada, y quien usa el panel
/// no es tecnico.
class Cargando extends StatelessWidget {
  const Cargando({super.key, required this.que});

  /// Que se esta leyendo: "Buscando tus vinos…".
  final String que;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Semantics(
        liveRegion: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
            const SizedBox(height: 16),
            Text(que, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
