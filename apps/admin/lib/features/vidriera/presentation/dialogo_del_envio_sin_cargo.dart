import 'package:flutter/material.dart';

import '../../catalogo/domain/numeros_escritos.dart';
import '../domain/envio_sin_cargo.dart';
import 'textos_del_envio.dart';

/// Escribir desde que monto la entrega sale sin cargo (HU-11.1, ADR 026).
/// Devuelve el monto en **centavos**, o `null` si se cancelo.
///
/// Lee lo escrito con `leerUmbral` —el formato del precio de un vino, en
/// pesos enteros— y marca el campo si no se puede leer. Lo que el monto
/// SIGNIFICA (una caja, la mitad del anterior) lo juzga el servidor al
/// guardar, no este dialogo.
class DialogoDelEnvioSinCargo extends StatefulWidget {
  const DialogoDelEnvioSinCargo({super.key, this.actual});

  /// El umbral guardado, en centavos, para empezar desde ahi.
  final int? actual;

  static Future<int?> mostrar(BuildContext context, {int? actual}) =>
      showDialog<int>(
        context: context,
        builder: (_) => DialogoDelEnvioSinCargo(actual: actual),
      );

  @override
  State<DialogoDelEnvioSinCargo> createState() =>
      _DialogoDelEnvioSinCargoState();
}

class _DialogoDelEnvioSinCargoState extends State<DialogoDelEnvioSinCargo> {
  late final _campo = TextEditingController(
    text: switch (widget.actual) {
      final int c => pesosParaEscribir(c),
      null => '',
    },
  );
  String? _problema;

  @override
  void dispose() {
    _campo.dispose();
    super.dispose();
  }

  void _guardar() {
    final lectura = leerUmbral(_campo.text);
    final valor = lectura.valor;
    if (valor != null) {
      Navigator.of(context).pop(valor);
      return;
    }
    setState(() => _problema = lectura.problema ?? textoEscribiUnMonto);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(textoTituloDelEnvio),
      content: TextField(
        controller: _campo,
        autofocus: true,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _guardar(),
        decoration: InputDecoration(
          labelText: textoCampoDelMonto,
          helperText: textoAyudaDelMonto,
          prefixText: r'$ ',
          errorText: _problema,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(textoCancelar),
        ),
        FilledButton(onPressed: _guardar, child: const Text(textoGuardarMonto)),
      ],
    );
  }
}
