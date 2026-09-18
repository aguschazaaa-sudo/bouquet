import 'package:flutter/material.dart';

/// La confirmacion de HU-03.3: **solo para una caja**. Criterio 3 del mapa del
/// panel —"se confirma solo lo que no tiene vuelta atras"—, y de las dos cosas
/// sin vuelta atras, la botella suelta es el caso normal y ya lo dice la
/// pantalla: confirmarla en cada uno de los 200 vinos del MVP no evita ninguna
/// perdida (ADR 013 §8).
///
/// Devuelve `true` solo si se confirmo. Cerrar el dialogo de cualquier otra
/// forma es "no".
Future<bool> confirmarLaCaja(BuildContext context, int botellas) async {
  final confirmo = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('¿Es una caja de $botellas?'),
      content: Text(
        'Después no se puede cambiar: una botella que pasa a caja es otro '
        'producto.\n\n'
        'El stock se va a contar en cajas de $botellas, la caja viaja sola en '
        'su propio bulto y no cuenta para armar la caja de seis.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Revisar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text('Sí, caja de $botellas'),
        ),
      ],
    ),
  );
  return confirmo ?? false;
}
