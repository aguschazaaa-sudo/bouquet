import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/rutas.dart';
import '../../../core/presentation/marca.dart';

/// Lo que ve quien abre una ruta que no existe. Es el control negativo de la
/// verificacion: una ruta inventada NO muestra una seccion.
class PaginaNoEncontrada extends StatelessWidget {
  const PaginaNoEncontrada({super.key});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Marca(),
                const SizedBox(height: 28),
                Semantics(
                  header: true,
                  child: Text(
                    'Esa página no existe',
                    style: tema.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Puede que el enlace esté mal copiado. Desde el catálogo '
                  'llegás a todo el panel.',
                  style: tema.textTheme.bodyLarge?.copyWith(height: 1.5),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => context.go(Rutas.catalogo),
                  child: const Text('Ir al catálogo'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
