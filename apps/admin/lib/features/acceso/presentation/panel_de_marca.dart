import 'package:flutter/material.dart';

import '../../../core/presentation/marca.dart';
import '../../../theme/tema.dart';

/// El lado oscuro de la pantalla de entrada: una columna en la compu, una
/// banda en el telefono. Es la unica superficie de tinta fuera de la
/// navegacion.
class PanelDeMarca extends StatelessWidget {
  const PanelDeMarca({super.key, required this.ancho});

  final bool ancho;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final texto = esquema.onInverseSurface;

    if (!ancho) {
      return Container(
        color: esquema.inverseSurface,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        child: SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Marca(
              color: esquema.secondary,
              bajada: 'Panel de la tienda',
            ),
          ),
        ),
      );
    }

    return Container(
      color: esquema.inverseSurface,
      padding: const EdgeInsets.all(56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Marca(color: esquema.secondary, tamano: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Icon(
                  Icons.wine_bar_outlined,
                  size: 56,
                  color: esquema.secondary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'El panel de la tienda',
                style: estiloDeNombre(
                  tamano: 34,
                  peso: FontWeight.w400,
                ).copyWith(color: texto, height: 1.15),
              ),
              const SizedBox(height: 12),
              Text(
                'Catálogo, stock y pedidos, desde la compu o el teléfono.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: texto.withValues(alpha: 0.76),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
