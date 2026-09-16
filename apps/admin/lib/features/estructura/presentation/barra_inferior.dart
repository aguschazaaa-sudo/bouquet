import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'secciones.dart';

/// Las secciones abajo, en el telefono: se alcanzan con el pulgar.
class BarraInferior extends StatelessWidget {
  const BarraInferior({super.key, required this.ubicacion});

  final String ubicacion;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Material(
      color: esquema.inverseSurface,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 68,
          child: Row(
            children: [
              for (final seccion in secciones)
                Expanded(
                  child: _Destino(
                    seccion: seccion,
                    activa: seccion.estaActiva(ubicacion),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Destino extends StatelessWidget {
  const _Destino({required this.seccion, required this.activa});

  final Seccion seccion;
  final bool activa;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final color = activa
        ? esquema.secondary
        : esquema.onInverseSurface.withValues(alpha: 0.76);
    return Semantics(
      button: true,
      selected: activa,
      label: seccion.titulo,
      excludeSemantics: true,
      child: InkWell(
        onTap: () => context.go(seccion.ruta),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(activa ? seccion.iconoActivo : seccion.icono, color: color),
            const SizedBox(height: 4),
            Text(
              seccion.titulo,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: activa ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
