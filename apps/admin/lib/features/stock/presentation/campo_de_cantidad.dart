import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Donde se escribe una cantidad de botellas o de cajas.
///
/// Teclado numerico y **solo digitos y el punto de miles**: no hay forma de
/// escribir `-3` ni `1,5`. El motivo no es prolijidad: una cantidad negativa
/// que llega a la callable es un dato que alguien toco, y lo que no se puede
/// escribir no hay que rechazarlo despues.
///
/// El estado es del padre ([controlador]) para que "Volver a contar" pueda
/// vaciarlo.
class CampoDeCantidad extends StatelessWidget {
  const CampoDeCantidad({
    super.key,
    required this.controlador,
    required this.etiqueta,
    required this.alCambiar,
    this.alEnviar,
    this.problema,
    this.ayuda,
    this.habilitado = true,
  });

  final TextEditingController controlador;
  final String etiqueta;
  final ValueChanged<String> alCambiar;

  /// Al apretar "listo" del teclado. `null` si todavia no se puede enviar.
  final VoidCallback? alEnviar;

  final String? problema;

  /// Una linea de ayuda debajo, mientras no haya problema.
  final String? ayuda;

  final bool habilitado;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controlador,
      enabled: habilitado,
      autofocus: true,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
      decoration: InputDecoration(
        labelText: etiqueta,
        helperText: ayuda,
        helperMaxLines: 2,
        errorText: problema,
        errorMaxLines: 3,
      ),
      onChanged: alCambiar,
      onSubmitted: alEnviar == null ? null : (_) => alEnviar!(),
    );
  }
}
