import 'dart:typed_data';

import 'package:flutter/material.dart';

/// El widget hoja: dibuja una foto EXACTAMENTE como la va a componer la
/// vidriera, para que el operador la juzgue mirándola en vez de que un
/// umbral decida por él.
///
/// `VentanaDeBotella.tsx` apoya la foto sobre el papel de la ventana con
/// `mix-blend-mode: multiply` -- así el blanco de un packshot se absorbe y
/// el fondo de una foto de cámara queda como un rectángulo oscuro. Acá se
/// repite con `colorBlendMode: BlendMode.multiply` sobre
/// `colorScheme.surfaceContainerHighest`, que ES `Tokens.papelVentana`
/// (`theme/tema.dart`) -- la misma fórmula que `--papel-ventana` de
/// `apps/tienda/src/shared/tokens/tokens.css:48`, documentada con el riesgo
/// de desincronización junto a esa constante (design.md decisión 7 de
/// `panel-fotos-de-un-vino`).
///
/// **El panel no adivina si la foto sirve: la muestra** (proposal.md). Se
/// midió que ningún umbral sobre el archivo separa un packshot de una foto
/// de cámara -- un packshot legítimo puntuó peor que el control negativo --
/// así que la única señal que no miente es mirar la composición real.
class VentanaDePrevisualizacion extends StatelessWidget {
  /// Bytes locales recién elegidos, antes de subir.
  const VentanaDePrevisualizacion.bytes(Uint8List bytes, {super.key})
    : _bytes = bytes,
      _url = null;

  /// La URL en Storage de una foto ya subida.
  const VentanaDePrevisualizacion.url(String url, {super.key})
    : _url = url,
      _bytes = null;

  final Uint8List? _bytes;
  final String? _url;

  @override
  Widget build(BuildContext context) {
    final papel = Theme.of(context).colorScheme.surfaceContainerHighest;
    final bytes = _bytes;

    final imagen = bytes != null
        ? Image.memory(
            bytes,
            fit: BoxFit.contain,
            color: papel,
            colorBlendMode: BlendMode.multiply,
          )
        : Image.network(
            _url!,
            fit: BoxFit.contain,
            color: papel,
            colorBlendMode: BlendMode.multiply,
            errorBuilder: (context, error, pila) =>
                Icon(Icons.broken_image_outlined, color: papel),
          );

    return Semantics(
      image: true,
      label: 'Cómo se va a ver esta foto en la tienda, sobre el papel',
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          color: papel,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(10),
          child: imagen,
        ),
      ),
    );
  }
}
