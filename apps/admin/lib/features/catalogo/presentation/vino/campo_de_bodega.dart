import 'package:flutter/material.dart';

import '../../domain/bodega.dart';
import '../hoja_de_bodega.dart';

/// La bodega, **elegida de la lista**: `fichaVino.bodegaId` apunta a un
/// documento, y un nombre escrito a mano seria un vino de una bodega que no
/// existe — que `armarCatalogo` deja afuera de la tienda sin avisar.
///
/// Si no esta, se carga desde aca sin salir del alta, y queda elegida
/// (ADR 013 §10). La lista se filtra escribiendo: son ~30 en el MVP.
class CampoDeBodega extends StatelessWidget {
  const CampoDeBodega({
    super.key,
    required this.bodegas,
    required this.elegida,
    required this.problema,
    required this.alElegir,
  });

  final List<Bodega> bodegas;
  final String? elegida;
  final String? problema;
  final ValueChanged<String> alElegir;

  Future<void> _cargarUna(BuildContext context) async {
    final id = await HojaDeBodega.mostrar(context);
    if (id != null) alElegir(id);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownMenu<String>(
          // La clave rehace el menu cuando la eleccion cambia desde afuera
          // —la bodega recien cargada—: `initialSelection` solo se lee al
          // crearlo.
          key: ValueKey(elegida),
          initialSelection: elegida,
          label: const Text('Bodega'),
          expandedInsets: EdgeInsets.zero,
          enableFilter: true,
          requestFocusOnTap: true,
          errorText: problema,
          menuHeight: 320,
          dropdownMenuEntries: [
            for (final b in bodegas)
              DropdownMenuEntry(
                value: b.id,
                label: b.nombre.isEmpty ? 'Bodega sin nombre' : b.nombre,
              ),
          ],
          onSelected: (id) {
            if (id != null) alElegir(id);
          },
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _cargarUna(context),
            icon: const Icon(Icons.add),
            label: const Text('La bodega no está: cargarla'),
          ),
        ),
      ],
    );
  }
}
