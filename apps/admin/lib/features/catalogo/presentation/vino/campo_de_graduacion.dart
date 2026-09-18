import 'package:flutter/material.dart';

/// La graduacion, en grados como la dice la etiqueta. Se guarda en decimas
/// (ADR 013 §2), pero eso no es asunto de quien la escribe.
class CampoDeGraduacion extends StatelessWidget {
  const CampoDeGraduacion({
    super.key,
    required this.escrito,
    required this.problema,
    required this.alCambiar,
  });

  final String escrito;
  final String? problema;
  final ValueChanged<String> alCambiar;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: escrito,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: 'Graduación (opcional)',
        suffixText: '%',
        helperText: 'Como dice la etiqueta: 13,5',
        errorText: problema,
        errorMaxLines: 2,
      ),
      onChanged: alCambiar,
    );
  }
}
