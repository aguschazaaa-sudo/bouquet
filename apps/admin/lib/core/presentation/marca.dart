import 'package:flutter/material.dart';

import '../../theme/tema.dart';

/// `BOUQUET` en la serif de la marca, con una bajada opcional.
///
/// No es el logo: el logo es arte vectorizado (direccion.md §1.2). Es el
/// nombre compuesto, que alcanza para una herramienta de uso diario.
class Marca extends StatelessWidget {
  const Marca({super.key, this.color, this.bajada, this.tamano = 17});

  /// `null` toma el color primario del tema. Sobre la banda va el dorado.
  final Color? color;
  final String? bajada;
  final double tamano;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final bajada = this.bajada;
    return Semantics(
      label: bajada == null ? 'bouquet' : 'bouquet, $bajada',
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'BOUQUET',
            style: estiloDeNombre(tamano: tamano, peso: FontWeight.w600)
                .copyWith(
                  letterSpacing: tamano * 0.24,
                  color: color ?? tema.colorScheme.primary,
                ),
          ),
          if (bajada != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                bajada.toUpperCase(),
                style: tema.textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.6,
                  color: color ?? tema.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
