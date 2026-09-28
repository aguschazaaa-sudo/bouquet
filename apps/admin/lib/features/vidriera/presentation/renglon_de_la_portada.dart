import 'package:flutter/material.dart';

import '../../../theme/tema.dart';
import '../domain/seleccion_de_la_portada.dart';
import 'textos_de_la_vidriera.dart';

/// Un lugar de la portada: el numero, el vino, si se ve, y los tres gestos
/// —subir, bajar, sacar—.
///
/// Subir y bajar son botones y no arrastrar: arrastrar en un teléfono se
/// confunde con scrollear, y son seis renglones. Sacar no pide confirmacion:
/// tiene vuelta atras en un toque (volver a agregarlo), y la regla del panel
/// es confirmar solo lo que no la tiene.
class RenglonDeLaPortada extends StatelessWidget {
  const RenglonDeLaPortada({
    super.key,
    required this.lugar,
    required this.posicion,
    required this.esElPrimero,
    required this.esElUltimo,
    required this.habilitado,
    required this.alSubir,
    required this.alBajar,
    required this.alSacar,
  });

  final LugarDeLaPortada lugar;

  /// Desde 1, como lo cuenta una persona.
  final int posicion;
  final bool esElPrimero;
  final bool esElUltimo;

  /// `false` mientras se guarda el cambio anterior: dos toques seguidos
  /// guardarian dos listas armadas sobre la misma de antes.
  final bool habilitado;

  final VoidCallback alSubir;
  final VoidCallback alBajar;
  final VoidCallback alSacar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final fuera = lugar.fuera;
    final nombre = lugar.producto?.nombre ?? textoVinoQueYaNoExiste;

    return ListTile(
      contentPadding: const EdgeInsets.only(left: 4),
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: tema.colorScheme.surfaceContainerHighest,
        foregroundColor: tema.colorScheme.onSurface,
        child: Text('$posicion'),
      ),
      title: Text(nombre, style: estiloDeNombre()),
      subtitle: fuera == null
          ? null
          : Text(
              textoFueraDeLaPortada(fuera),
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.error,
              ),
            ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: textoSubir,
            icon: const Icon(Icons.arrow_upward),
            onPressed: habilitado && !esElPrimero ? alSubir : null,
          ),
          IconButton(
            tooltip: textoBajar,
            icon: const Icon(Icons.arrow_downward),
            onPressed: habilitado && !esElUltimo ? alBajar : null,
          ),
          IconButton(
            tooltip: textoSacar,
            icon: const Icon(Icons.close),
            onPressed: habilitado ? alSacar : null,
          ),
        ],
      ),
    );
  }
}
