import 'package:flutter/material.dart';

import '../../../theme/tema.dart';
import '../domain/cajas_sugeridas.dart';
import 'textos_de_la_vidriera.dart';

/// Un lugar de la caja que se esta armando: vacio ("Elegí un vino") o con su
/// vino, y si la tienda lo va a llenar. Tocarlo elige otro; la cruz lo vacia.
class LugarDeLaHoja extends StatelessWidget {
  const LugarDeLaHoja({
    super.key,
    required this.numero,
    required this.lugar,
    required this.habilitado,
    required this.alElegir,
    required this.alVaciar,
  });

  /// Desde 1, como lo cuenta una persona.
  final int numero;

  /// `null` si el lugar esta vacio.
  final LugarDeLaCaja? lugar;

  final bool habilitado;
  final VoidCallback alElegir;
  final VoidCallback alVaciar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final l = lugar;
    final fuera = l?.fuera;

    return ListTile(
      enabled: habilitado,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: tema.colorScheme.surfaceContainerHighest,
        foregroundColor: tema.colorScheme.onSurface,
        child: Text('$numero'),
      ),
      title: l == null
          ? Text(
              textoLugarVacio,
              style: TextStyle(color: tema.colorScheme.primary),
            )
          : Text(
              l.producto?.nombre ?? textoVinoQueYaNoExiste,
              style: estiloDeNombre(),
            ),
      subtitle: fuera == null
          ? null
          : Text(
              textoFueraDeLaCaja(fuera),
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.error,
              ),
            ),
      trailing: l == null
          ? const Icon(Icons.add)
          : IconButton(
              tooltip: textoVaciarLugar,
              icon: const Icon(Icons.close),
              onPressed: habilitado ? alVaciar : null,
            ),
      onTap: alElegir,
    );
  }
}
