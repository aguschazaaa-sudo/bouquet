import 'package:flutter/material.dart';

import '../../../core/presentation/seccion_vacia.dart';

/// `/pedidos`. Vacia en este cambio: los pedidos llegan en el hito 2,
/// empezando por los de WhatsApp (EP-10).
class PantallaDePedidos extends StatelessWidget {
  const PantallaDePedidos({super.key});

  @override
  Widget build(BuildContext context) {
    return const SeccionVacia(
      titulo: 'Pedidos',
      icono: Icons.receipt_long_outlined,
      explicacion:
          'Acá van a aparecer los pedidos de la tienda y los que cargues de '
          'WhatsApp, para prepararlos y despacharlos. Esta parte todavía se '
          'está construyendo.',
    );
  }
}
