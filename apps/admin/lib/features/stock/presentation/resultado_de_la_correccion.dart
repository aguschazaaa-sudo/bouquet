import 'package:flutter/material.dart';

import '../../../core/presentation/aviso.dart';
import '../domain/fallo_de_stock.dart';
import 'textos_del_stock.dart';

/// Lo que dice la hoja de correccion debajo del motivo (HU-05.2): como va a
/// quedar el stock si se guarda, y por que no se pudo guardar si fallo.
///
/// Salio de `HojaDeCorreccion` para que esa hoja no se quede clavada en las 200
/// lineas que `widget-size-guard` permite: con la hoja en el limite, cualquier
/// edicion siguiente la rompe.
class ResultadoDeLaCorreccion extends StatelessWidget {
  const ResultadoDeLaCorreccion({super.key, this.queda, this.fallo});

  /// `Va a quedar en 10 botellas`, o `null` mientras lo escrito no sea valido.
  final String? queda;

  /// Por que la callable rechazo el conteo, o `null` si no hubo rechazo.
  final FalloDeStock? fallo;

  @override
  Widget build(BuildContext context) {
    final queda = this.queda;
    final fallo = this.fallo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (queda != null) ...[
          const SizedBox(height: 12),
          Text(queda, style: Theme.of(context).textTheme.bodyMedium),
        ],
        if (fallo != null) ...[
          const SizedBox(height: 14),
          Aviso(texto: textoDelFalloDeStock(fallo), tono: TonoDelAviso.error),
        ],
      ],
    );
  }
}
