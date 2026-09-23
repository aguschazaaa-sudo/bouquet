import 'package:flutter/material.dart';

/// El titulo de una hoja de stock y, abajo, de que vino se trata.
///
/// El nombre va siempre: con la hoja abierta encima del formulario, quien
/// mueve stock tiene que poder leer **a cual** vino se lo esta moviendo sin
/// mirar detras. Y el titulo es un `header` semantico: el lector de pantalla
/// lo anuncia al abrirse la hoja.
class EncabezadoDeHoja extends StatelessWidget {
  const EncabezadoDeHoja({
    super.key,
    required this.titulo,
    required this.nombre,
  });

  final String titulo;
  final String nombre;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(titulo, style: Theme.of(context).textTheme.titleLarge),
        ),
        const SizedBox(height: 4),
        Text(nombre),
      ],
    );
  }
}
