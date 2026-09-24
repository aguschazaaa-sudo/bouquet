import 'package:flutter/material.dart';

import '../../../core/contratos/plata.dart';
import '../../../theme/tema.dart';
import '../../../theme/tokens.dart';
import '../domain/linea_a_cargar.dart';
import 'textos_de_carga.dart';

/// Una linea del pedido que se esta cargando (HU-10.1): el vino, su cantidad con
/// **mas y menos** y como sacarlo.
///
/// La cantidad **no pasa del stock que se ve**: el boton de mas se apaga en el
/// maximo y el renglon lo dice (*"Es todo el stock que hay"*). Pasarse no es
/// posible, y lo que no se puede escribir no hay que rechazarlo despues.
///
/// Los botones van a `Medidas.tactil`: los usa gente parada, con el telefono en
/// una mano.
class RenglonDeLinea extends StatelessWidget {
  const RenglonDeLinea({
    super.key,
    required this.linea,
    required this.alCambiar,
    required this.alSacar,
    this.habilitado = true,
  });

  final LineaACargar linea;
  final ValueChanged<int> alCambiar;
  final VoidCallback alSacar;
  final bool habilitado;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final enElMaximo = linea.cantidad >= linea.maximo;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Tokens.regla)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(linea.nombre, style: estiloDeNombre()),
                const SizedBox(height: 2),
                Text(
                  textoDeCuantoQueda(linea),
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (enElMaximo)
                  Text(
                    textoEsTodoElStock,
                    style: tema.textTheme.bodySmall?.copyWith(
                      color: tema.colorScheme.primary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Una menos',
                    constraints: const BoxConstraints(
                      minWidth: Medidas.tactil,
                      minHeight: Medidas.tactil,
                    ),
                    onPressed: habilitado && linea.cantidad > 1
                        ? () => alCambiar(linea.cantidad - 1)
                        : null,
                    icon: const Icon(Icons.remove),
                  ),
                  Semantics(
                    label: '${linea.cantidad} unidades',
                    excludeSemantics: true,
                    child: SizedBox(
                      width: 32,
                      child: Text(
                        '${linea.cantidad}',
                        textAlign: TextAlign.center,
                        style: tema.textTheme.titleMedium,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Una más',
                    constraints: const BoxConstraints(
                      minWidth: Medidas.tactil,
                      minHeight: Medidas.tactil,
                    ),
                    onPressed: habilitado && !enElMaximo
                        ? () => alCambiar(linea.cantidad + 1)
                        : null,
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              Text(enPesos(linea.subtotal), style: tema.textTheme.bodyLarge),
              TextButton(
                onPressed: habilitado ? alSacar : null,
                child: const Text(textoSacarDelPedido),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
