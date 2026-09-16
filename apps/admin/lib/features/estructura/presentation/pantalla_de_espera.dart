import 'package:flutter/material.dart';

import '../../../core/presentation/marca.dart';

/// `/espera`: mientras Firebase lee la sesion guardada. Ninguna seccion se
/// muestra antes de saber quien entro.
class PantallaDeEspera extends StatelessWidget {
  const PantallaDeEspera({super.key});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Marca(tamano: 20),
            const SizedBox(height: 28),
            const SizedBox.square(
              dimension: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Revisando tu cuenta…',
              style: tema.textTheme.bodyMedium?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
