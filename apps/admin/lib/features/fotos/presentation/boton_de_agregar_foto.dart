import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../domain/fallo_de_fotos.dart';
import '../domain/formato_de_foto.dart';
import '../domain/foto_del_vino.dart';
import '../fotos_providers.dart';
import 'textos_de_fotos.dart';

/// Elegir una o varias fotos -- de la galería, o una con la cámara -- y
/// subirlas (spec "El operador sube fotos de un vino").
///
/// Mide el peso, el formato y el tope de diez **antes** de tocar la red:
/// el repositorio (grupo 5) también valida peso y formato, pero hacerlo acá
/// deja la pantalla sin spinner para un archivo que ya se sabe que va a
/// rebotar (spec "un PDF o una foto de más de 5 MB no gastan la subida ni
/// la callable"). El tope de diez el repositorio no lo mide -- es sólo del
/// panel (spec "Un vino no pasa de diez fotos", `topeDeFotos`).
class BotonDeAgregarFoto extends ConsumerStatefulWidget {
  const BotonDeAgregarFoto({
    super.key,
    required this.productoId,
    required this.cuantasTiene,
    required this.alSubir,
    required this.alFallar,
    this.agregarAlDocumento = true,
  });

  final String productoId;
  final int cuantasTiene;
  final void Function(FotoDelVino foto) alSubir;
  final void Function(String nombre, String texto) alFallar;

  /// `false` en un alta todavia sin guardar (ADR 015 §5): el documento no
  /// existe, asi que el repositorio no intenta el `arrayUnion`.
  final bool agregarAlDocumento;

  @override
  ConsumerState<BotonDeAgregarFoto> createState() => _BotonDeAgregarFotoState();
}

class _BotonDeAgregarFotoState extends ConsumerState<BotonDeAgregarFoto> {
  bool _subiendo = false;

  Future<void> _procesar(List<XFile> elegidas) async {
    if (elegidas.isEmpty || !mounted) return;
    setState(() => _subiendo = true);

    var cuantasTiene = widget.cuantasTiene;
    for (final archivo in elegidas) {
      final Uint8List bytes = await archivo.readAsBytes();

      if (cuantasTiene >= topeDeFotos) {
        widget.alFallar(archivo.name, textoTopeDeFotos);
        continue;
      }
      if (bytes.length >= topeDeBytes) {
        widget.alFallar(archivo.name, textoPesaDeMas(bytes.length));
        continue;
      }
      if (detectarFormato(bytes) == null) {
        widget.alFallar(
          archivo.name,
          textoDelFalloDeFotos(ErrorDeFotos.noEsImagen),
        );
        continue;
      }

      try {
        final foto = await ref
            .read(repositorioDeFotosProvider)
            .subir(
              productoId: widget.productoId,
              bytes: bytes,
              nombreOriginal: archivo.name,
              agregarAlDocumento: widget.agregarAlDocumento,
            );
        widget.alSubir(foto);
        cuantasTiene++;
      } on FalloDeFotos catch (e) {
        widget.alFallar(e.nombreDeArchivo, textoDelFalloDeFotos(e.error));
      }
    }
    if (mounted) setState(() => _subiendo = false);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: _subiendo
              ? null
              : () => ImagePicker().pickMultiImage().then(_procesar),
          icon: _subiendo
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_photo_alternate_outlined),
          label: Text(_subiendo ? textoSubiendo : textoElegirDeGaleria),
        ),
        OutlinedButton.icon(
          onPressed: _subiendo
              ? null
              : () => ImagePicker()
                    .pickImage(source: ImageSource.camera)
                    .then((f) => _procesar(f == null ? [] : [f])),
          icon: const Icon(Icons.photo_camera_outlined),
          label: Text(textoTomarFoto),
        ),
      ],
    );
  }
}
