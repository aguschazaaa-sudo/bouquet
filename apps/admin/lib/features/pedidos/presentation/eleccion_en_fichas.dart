import 'package:flutter/material.dart';

/// Una eleccion de una lista corta y cerrada, **de un toque** (EP-07): el correo
/// de un despacho, el motivo de una entrega fallida o de una cancelacion.
///
/// Fichas y no un `SegmentedButton` como en el stock: estas listas tienen cinco
/// opciones con textos largos, y en un telefono no entran en una fila. Y **sin
/// opcion elegida al abrir**: un motivo preelegido es un motivo que nadie eligio.
class EleccionEnFichas<T> extends StatelessWidget {
  const EleccionEnFichas({
    super.key,
    required this.titulo,
    required this.opciones,
    required this.rotulo,
    required this.elegida,
    required this.alElegir,
    this.habilitado = true,
  });

  final String titulo;
  final List<T> opciones;
  final String Function(T) rotulo;
  final T? elegida;
  final ValueChanged<T> alElegir;
  final bool habilitado;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(titulo, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final o in opciones)
              ChoiceChip(
                label: Text(rotulo(o)),
                selected: o == elegida,
                onSelected: habilitado ? (_) => alElegir(o) : null,
              ),
          ],
        ),
      ],
    );
  }
}
