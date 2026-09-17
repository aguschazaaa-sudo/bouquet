import 'package:flutter/material.dart';

import '../../../theme/tema.dart';
import '../../../theme/tokens.dart';
import '../domain/bodega.dart';

/// Una bodega en la lista, con cuantos vinos tiene.
///
/// ⚠️ **El borrado no se ofrece si tiene vinos (HU-02.4).** No es un boton
/// apagado: no esta. `armarCatalogo` deja afuera, **sin error**, los
/// productos de una bodega que no existe, asi que borrarla **despublica en
/// silencio** (ADR 008 §2). El renglon dice en su lugar que hay que hacer.
class RenglonDeBodega extends StatelessWidget {
  const RenglonDeBodega({
    super.key,
    required this.bodega,
    required this.vinos,
    required this.alCorregir,
    required this.alBorrar,
  });

  final Bodega bodega;
  final int vinos;
  final VoidCallback alCorregir;
  final VoidCallback alBorrar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final nombre = bodega.nombre.isEmpty ? 'Sin nombre' : bodega.nombre;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Tokens.filetePapel)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombre, style: estiloDeNombre(tamano: 17)),
                const SizedBox(height: 4),
                Text(
                  _cuantosVinos(vinos),
                  style: tema.textTheme.bodySmall?.copyWith(
                    color: tema.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: alCorregir,
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Corregir el nombre de $nombre',
          ),
          if (vinos == 0)
            IconButton(
              onPressed: alBorrar,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Borrar $nombre',
            )
          else
            // El hueco del boton que no esta, para que la columna de "corregir"
            // no baile de renglon en renglon.
            const SizedBox(width: Medidas.tactil),
        ],
      ),
    );
  }

  static String _cuantosVinos(int vinos) => switch (vinos) {
    0 => 'Sin vinos todavía',
    1 => '1 vino',
    _ => '$vinos vinos',
  };
}
