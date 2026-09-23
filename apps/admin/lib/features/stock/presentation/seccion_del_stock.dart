import 'package:flutter/material.dart';

import '../../../core/contratos/catalogo_publico.dart';
import '../../../theme/tokens.dart';
import 'hoja_de_correccion.dart';
import 'hoja_de_reposicion.dart';
import 'textos_del_stock.dart';

/// El stock de un vino y las dos maneras de moverlo (HU-05.1 y HU-05.2).
///
/// **El numero que se ve es el EXACTO.** La vidriera muestra un balde y nunca
/// el numero (glosario); el panel si lo ve, y en la unidad de venta: un vino
/// suelto en botellas, uno que viene en caja en cajas y, al lado, las botellas
/// que son.
///
/// Recibe datos sueltos y no un `ProductoDelPanel` a proposito: esta feature
/// no importa a `catalogo`, que es quien la embebe en la ficha del vino.
///
/// El numero se actualiza solo: la ficha lo saca del catalogo que ya esta en
/// memoria, y el listener de Firestore lo cambia cuando la callable escribe.
/// Costo de mover el stock una vez: la lectura de ese documento.
class SeccionDelStock extends StatelessWidget {
  const SeccionDelStock({
    super.key,
    required this.productoId,
    required this.nombre,
    required this.stock,
    required this.botellas,
  });

  final String productoId;
  final String nombre;

  /// Unidades de venta. `null` en un compuesto, que no tiene stock propio.
  final int? stock;
  final int botellas;

  Future<void> _mover(
    BuildContext context,
    Future<int?> Function() abrir,
  ) async {
    final despues = await abrir();
    if (despues == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Listo: ahora hay '
          '${describirElStock(despues, botellas: botellas)}.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final actual = stock;

    if (actual == null) {
      return Text(
        'Este producto no lleva stock propio: lo deriva de sus componentes.',
        style: tema.textTheme.bodyMedium,
      );
    }

    final rotulo = textoDelBalde(balde(stock: actual, botellas: botellas));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Tokens.filetePapel),
        borderRadius: BorderRadius.circular(Medidas.radio),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text('Stock', style: tema.textTheme.labelLarge),
          ),
          const SizedBox(height: 4),
          Text(
            describirElStock(actual, botellas: botellas),
            style: tema.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              // Sin esto el numero baila al cambiar.
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (rotulo != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                rotulo,
                style: tema.textTheme.bodyMedium?.copyWith(
                  color: tema.colorScheme.error,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => _mover(
                  context,
                  () => HojaDeReposicion.mostrar(
                    context,
                    productoId: productoId,
                    nombre: nombre,
                    stock: actual,
                    botellas: botellas,
                  ),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Cargar mercadería'),
              ),
              OutlinedButton(
                onPressed: () => _mover(
                  context,
                  () => HojaDeCorreccion.mostrar(
                    context,
                    productoId: productoId,
                    nombre: nombre,
                    stock: actual,
                    botellas: botellas,
                  ),
                ),
                child: const Text('Corregir el stock'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
