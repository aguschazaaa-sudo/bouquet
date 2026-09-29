import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

/// Lo principal de una seccion y su accion: lado a lado si entran, y en un
/// telefono angosto, la accion abajo y a todo lo ancho.
///
/// Existe porque lado a lado, en un telefono de 328 px, el boton se quedaba
/// con su ancho y lo principal con las sobras: *"Bodegas — 11 cargadas"* se
/// partia en ocho renglones y *"Pedidos"* en dos (lo mostro el dueño el
/// 2026-09-29). El corte es por el ancho que recibe, no por el de la pantalla.
class RenglonConAccion extends StatelessWidget {
  const RenglonConAccion({
    super.key,
    required this.principal,
    required this.accion,
  });

  final Widget principal;

  /// Un boton. Angosto, se estira a todo lo ancho.
  final Widget accion;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, limites) {
        if (limites.maxWidth >= Medidas.anchoAngosto) {
          return Row(
            children: [
              Expanded(child: principal),
              const SizedBox(width: 12),
              accion,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [principal, const SizedBox(height: 10), accion],
        );
      },
    );
  }
}
