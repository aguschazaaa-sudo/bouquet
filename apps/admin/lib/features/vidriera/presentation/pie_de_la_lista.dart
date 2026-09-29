import 'package:flutter/material.dart';

import 'textos_de_la_vidriera.dart';

/// Lo que va debajo de las dos listas de Vidriera, la portada y las cajas:
/// como se cambia el orden, y agregar otro o por que ya no se puede.
///
/// Como se ordena se dice solo con dos o mas: con uno no hay orden que
/// cambiar, y la manija sola no avisa que se arrastra.
class PieDeLaLista extends StatelessWidget {
  const PieDeLaLista({
    super.key,
    required this.cuantos,
    required this.cadaUno,
    required this.llena,
    required this.textoLlena,
    required this.textoAgregar,
    required this.alAgregar,
  });

  final int cuantos;

  /// *"cada vino"* o *"cada caja"*, para [textoComoOrdenar].
  final String cadaUno;

  final bool llena;
  final String textoLlena;
  final String textoAgregar;

  /// `null` mientras se guarda el cambio anterior.
  final VoidCallback? alAgregar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (cuantos > 1) ...[
            Text(
              textoComoOrdenar(cadaUno),
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (llena)
            Text(textoLlena, style: tema.textTheme.bodySmall)
          else
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: alAgregar,
                icon: const Icon(Icons.add),
                label: Text(textoAgregar),
              ),
            ),
        ],
      ),
    );
  }
}
