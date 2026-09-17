import 'package:flutter/material.dart';

/// Una lista que esta vacia **y dice por que**, con lo que se puede hacer al
/// respecto si hay algo.
///
/// Distinta de `SeccionVacia`, que anuncia una seccion entera que todavia no
/// se construyo. Esta es para una lista que funciona y hoy no tiene nada, o
/// que no tiene nada **para esta busqueda** — que son dos mensajes distintos
/// y quien los escribe tiene que elegir cual.
class ListaVacia extends StatelessWidget {
  const ListaVacia({
    super.key,
    required this.icono,
    required this.texto,
    this.accion,
  });

  final IconData icono;
  final String texto;

  /// El boton, si hay algo que hacer. Sin accion, es solo el mensaje.
  final Widget? accion;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Decorativo: lo que dice el mensaje ya lo dice el texto, y un
              // lector de pantalla que lea "icono" no aporta nada.
              ExcludeSemantics(
                child: Icon(
                  icono,
                  size: 40,
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                texto,
                textAlign: TextAlign.center,
                style: tema.textTheme.bodyLarge?.copyWith(height: 1.5),
              ),
              if (accion case final boton?) ...[
                const SizedBox(height: 20),
                boton,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
