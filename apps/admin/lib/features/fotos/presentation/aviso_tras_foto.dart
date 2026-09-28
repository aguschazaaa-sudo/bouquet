import 'package:flutter/material.dart';

import 'textos_de_fotos.dart';

/// HU-09.4: después de subir, elegir principal o quitar una foto, avisa que
/// la tienda tarda en mostrar el cambio -- pero SÓLO si el vino ya está
/// publicado. Uno que todavía no se publicó no se ve en la tienda todavía,
/// así que ahí no hay nada que avisar (`SeccionDeFotos` es la única que
/// llama esto, una vez por cada acción que sí terminó bien).
void avisarTrasFoto(BuildContext context, bool publicado) {
  if (!publicado) return;
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text(textoFotoActualizada)));
}
