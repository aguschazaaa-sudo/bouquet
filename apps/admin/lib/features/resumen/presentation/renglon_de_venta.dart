import 'package:flutter/material.dart';

import '../../../theme/tema.dart';
import 'textos_del_resumen.dart';

/// Un puesto del ranking (HU-11.3): el numero, el vino y cuantas unidades se
/// vendieron. Tocarlo abre el vino, para reponerlo o cambiarle el precio; un
/// vino que ya no esta en el catalogo no abre nada.
class RenglonDeVenta extends StatelessWidget {
  const RenglonDeVenta({
    super.key,
    required this.posicion,
    required this.nombre,
    required this.unidades,
    this.alAbrir,
  });

  /// Desde 1, como lo cuenta una persona.
  final int posicion;
  final String nombre;
  final int unidades;
  final VoidCallback? alAbrir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.only(left: 4, right: 8),
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: tema.colorScheme.surfaceContainerHighest,
        foregroundColor: tema.colorScheme.onSurface,
        child: Text('$posicion'),
      ),
      title: Text(nombre, style: estiloDeNombre()),
      trailing: Text(
        textoUnidades(unidades),
        style: tema.textTheme.bodyMedium?.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
      onTap: alAbrir,
    );
  }
}
