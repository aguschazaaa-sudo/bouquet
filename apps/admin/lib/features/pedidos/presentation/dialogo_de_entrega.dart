import 'package:flutter/material.dart';

import 'textos_de_entrega.dart';

/// Confirmar que un pedido llego (HU-07.4).
///
/// Se confirma porque `entregada` no tiene vuelta atras (ADR 002). Y la
/// confirmacion **es la declaracion legal**: `entregada` quiere decir que lo
/// recibio y firmo un mayor de 18 (ARQUITECTURA §9.5), asi que el boton lo dice
/// con esas palabras en vez de un *"Aceptar"*. Si no fue asi, la salida es la
/// entrega fallida, con su motivo.
class DialogoDeEntrega extends StatelessWidget {
  const DialogoDeEntrega({super.key, required this.numero});

  final int numero;

  /// `true` solo si se confirmo.
  static Future<bool> mostrar(BuildContext context, int numero) async {
    final si = await showDialog<bool>(
      context: context,
      builder: (_) => DialogoDeEntrega(numero: numero),
    );
    return si ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(textoTituloDeEntrega(numero)),
      content: const Text(textoCondicionDeEntrega),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(textoTodaviaNo),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text(textoConfirmarEntrega),
        ),
      ],
    );
  }
}
