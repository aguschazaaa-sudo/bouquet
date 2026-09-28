import 'package:flutter/material.dart';

import '../../../core/presentation/aviso.dart';

/// Los errores de subir, quitar o cambiar la foto principal, uno debajo del
/// otro con el nombre del archivo que falló (spec "Una subida que falla se
/// ve, y dice cuál falló"). Aparte de `SeccionDeFotos` sólo por el límite de
/// 200 líneas -sigue siendo la misma pantalla, se compone ahí mismo-.
class FallosDeFotos extends StatelessWidget {
  const FallosDeFotos({super.key, required this.fallos});

  final List<(String nombre, String texto)> fallos;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (nombre, texto) in fallos)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Aviso(texto: '$nombre: $texto', tono: TonoDelAviso.error),
          ),
      ],
    );
  }
}
