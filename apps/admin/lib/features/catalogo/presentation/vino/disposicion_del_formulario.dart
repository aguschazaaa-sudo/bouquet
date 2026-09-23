import 'package:flutter/material.dart';

/// Cómo se acomodan las secciones del formulario del vino según el ancho
/// disponible (spec "El uso del espacio", ADR 015 §5): en escritorio los
/// datos y las fotos comparten fila; debajo de [_anchoDeCorte] -tablet, y el
/// panel también corre en Android- se apilan en una sola columna, igual que
/// antes del 2026-09-22.
class DisposicionDelFormulario extends StatelessWidget {
  const DisposicionDelFormulario({
    super.key,
    required this.datos,
    required this.venta,
    required this.fotos,
    required this.pie,
  });

  final Widget datos;
  final Widget venta;
  final Widget fotos;
  final Widget pie;

  static const _anchoDeCorte = 900.0;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      // 1100 y no 640 (lo que era antes): con dos columnas el ancho extra
      // se usa, no queda vacío al lado de una sola.
      constraints: const BoxConstraints(maxWidth: 1100),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < _anchoDeCorte) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                datos,
                const SizedBox(height: 28),
                const Divider(),
                const SizedBox(height: 20),
                venta,
                const SizedBox(height: 28),
                const Divider(),
                const SizedBox(height: 20),
                fotos,
                const SizedBox(height: 28),
                pie,
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          datos,
                          const SizedBox(height: 28),
                          const Divider(),
                          const SizedBox(height: 20),
                          venta,
                        ],
                      ),
                    ),
                    const SizedBox(width: 40),
                    Expanded(child: fotos),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              pie,
            ],
          );
        },
      ),
    );
  }
}
