import 'package:flutter/material.dart';

import '../../../../core/contratos/plata.dart';

/// El precio en pesos, y **como se va a ver en la tienda** mientras se
/// escribe (ADR 013 §3).
///
/// La vista previa sale de `enPesos`, el espejo de `formatearARS` que se
/// verifica contra las fixtures del TypeScript: el operador compara lo que
/// escribio con lo que va a ver el comprador, que es la unidad externa. Un
/// `12.50` que se leyera mal se ve en el acto.
///
/// Con [fijo] —un vino que esta en la tienda— se ve y no se edita: cambiar
/// ese precio es HU-03.5, Workflow D (ADR 013 §9).
class CampoDePrecio extends StatelessWidget {
  const CampoDePrecio({
    super.key,
    required this.escrito,
    required this.leido,
    required this.problema,
    required this.fijo,
    required this.alCambiar,
  });

  final String escrito;

  /// Los centavos leidos, o `null` si todavia no se puede leer.
  final int? leido;

  final String? problema;
  final bool fijo;
  final ValueChanged<String> alCambiar;

  @override
  Widget build(BuildContext context) {
    final String? ayuda;
    if (fijo) {
      ayuda =
          'Este vino está en la tienda: su precio todavía no se cambia desde '
          'acá.';
    } else if (leido != null && leido! > 0) {
      ayuda = 'En la tienda se va a ver así: ${enPesos(leido!)}';
    } else {
      ayuda = 'En pesos, por unidad de venta. Por ejemplo 12.500 o 12.500,50.';
    }

    return TextFormField(
      initialValue: escrito,
      readOnly: fijo,
      enabled: !fijo,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: 'Precio',
        prefixText: r'$ ',
        helperText: ayuda,
        helperMaxLines: 2,
        errorText: problema,
        errorMaxLines: 3,
      ),
      onChanged: alCambiar,
    );
  }
}
