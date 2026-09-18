import 'package:flutter/material.dart';

/// La region, con **las que ya usan otros vinos** como sugerencia. Es texto
/// libre —"Gualtallary, Tupungato, Mendoza" no entra en una lista cerrada—,
/// pero sugerir es lo que evita la tercera forma de escribir Mendoza. Las
/// sugerencias salen del catalogo en memoria: cero lecturas.
class CampoDeRegion extends StatelessWidget {
  const CampoDeRegion({
    super.key,
    required this.escrita,
    required this.sugerenciasPara,
    required this.problema,
    required this.alCambiar,
  });

  final String escrita;
  final List<String> Function(String escrito) sugerenciasPara;
  final String? problema;
  final ValueChanged<String> alCambiar;

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      initialValue: TextEditingValue(text: escrita),
      optionsBuilder: (v) => v.text.trim().isEmpty
          ? const Iterable<String>.empty()
          : sugerenciasPara(v.text),
      onSelected: alCambiar,
      fieldViewBuilder: (context, control, foco, alEnviar) => TextField(
        controller: control,
        focusNode: foco,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: 'Región',
          helperText: 'Por ejemplo: Luján de Cuyo, Mendoza',
          errorText: problema,
        ),
        onChanged: alCambiar,
        onSubmitted: (_) => alEnviar(),
      ),
    );
  }
}
