import 'package:flutter/material.dart';

/// El titulo de una pagina de pedidos con su "volver" (HU-06.2, HU-10.1).
///
/// El volver **navega a `/pedidos`** en vez de hacer `pop`: el detalle se puede
/// abrir directo por URL, y ahi no hay nada que desapilar. Mismo criterio que
/// `PaginaDelVino`.
class EncabezadoDePedidos extends StatelessWidget {
  const EncabezadoDePedidos({
    super.key,
    required this.titulo,
    required this.alVolver,
  });

  final String titulo;
  final VoidCallback alVolver;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: alVolver,
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Volver a los pedidos',
          ),
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                titulo,
                style: Theme.of(context).textTheme.titleLarge,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
