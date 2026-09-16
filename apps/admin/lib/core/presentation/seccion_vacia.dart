import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// Una seccion que existe y todavia no tiene contenido, y lo dice.
///
/// No simula datos: un catalogo con vinos inventados en produccion se lee
/// como que algo se cargo solo.
class SeccionVacia extends StatelessWidget {
  const SeccionVacia({
    super.key,
    required this.titulo,
    required this.explicacion,
    required this.icono,
  });

  final String titulo;
  final String explicacion;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  titulo,
                  style: tema.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: esquema.surface,
                  borderRadius: BorderRadius.circular(Medidas.radioSuperficie),
                  border: Border.all(color: esquema.outlineVariant),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: esquema.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icono, color: esquema.primary),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        explicacion,
                        style: tema.textTheme.bodyLarge?.copyWith(height: 1.5),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
