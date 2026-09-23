import 'package:flutter/material.dart';

/// Si la vidriera lo muestra. Lo normal no se anuncia con color: el que
/// resalta es el que falta terminar.
class EtiquetaEnLaTienda extends StatelessWidget {
  const EtiquetaEnLaTienda({super.key, required this.publicado});

  final bool publicado;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        // `null` y no un transparente literal: `no-hardcoded-colors.sh` no
        // deja un solo color escrito a mano fuera de `theme/`, y tiene razon
        // — la excepcion del "es solo transparente" es por donde empieza.
        color: publicado ? tema.colorScheme.surfaceContainerHighest : null,
        borderRadius: BorderRadius.circular(6),
        border: publicado
            ? null
            : Border.all(color: tema.colorScheme.onSurfaceVariant),
      ),
      child: Text(
        publicado ? 'En la tienda' : 'Sin publicar',
        style: tema.textTheme.labelSmall?.copyWith(
          color: tema.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
