import 'package:flutter/material.dart';

import '../domain/envio_sin_cargo.dart';
import 'textos_del_envio.dart';

/// La pregunta de la baranda del servidor (ARQUITECTURA §9.4, ADR 026):
/// `fijarEnvioSinCargo` no guardo porque el monto parece un dedo gordo, y el
/// dueño decide. Se confirma porque un umbral bajo **regala plata** en cada
/// pedido: es la clase de paso que el criterio del panel si pide.
///
/// Devuelve `true` solo si eligio *"Guardar igual"*; cerrarla sin elegir es
/// no guardar.
class ConfirmacionDelEnvio extends StatelessWidget {
  const ConfirmacionDelEnvio({super.key, required this.texto});

  final String texto;

  static Future<bool> mostrar(
    BuildContext context, {
    required int monto,
    required PideConfirmar pregunta,
  }) async =>
      await showDialog<bool>(
        context: context,
        builder: (_) =>
            ConfirmacionDelEnvio(texto: textoDeLaPregunta(monto, pregunta)),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(textoAntesDeGuardar),
      content: Text(texto),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(textoCorregirlo),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text(textoGuardarIgual),
        ),
      ],
    );
  }
}
