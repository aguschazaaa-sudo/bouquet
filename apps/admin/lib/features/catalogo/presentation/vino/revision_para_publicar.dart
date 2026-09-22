import 'package:flutter/material.dart';

import '../../../../core/presentation/aviso.dart';
import '../../../fotos/presentation/textos_de_fotos.dart'
    show textoIrACargarFoto;
import '../../domain/catalogo.dart';
import '../../domain/en_la_tienda.dart';
import '../../domain/producto_del_panel.dart';
import 'textos_del_vino.dart';

/// Lo que dice el panel ANTES de publicar (HU-03.6): por qué no se puede
/// todavía -- el motivo, nunca una lista escrita a mano en la pantalla -- y
/// el aviso de "se va a ver sin foto", que no frena.
///
/// Llama SIEMPRE a `revisarParaPublicar`, nunca a `revisarParaLaTienda`: acá
/// se revisa como si `publicado` ya fuera `true`, para no tapar el motivo
/// real detrás de "no publicado" (ver el comentario de
/// `domain/en_la_tienda.dart`).
class RevisionParaPublicar extends StatelessWidget {
  const RevisionParaPublicar({
    super.key,
    required this.producto,
    required this.catalogo,
    this.alIrAFotos,
  });

  final ProductoDelPanel producto;
  final Catalogo catalogo;

  /// panel-vino, "El aviso de sin foto que ya existe lleva a la solución":
  /// hasta `panel-fotos-de-un-vino` esta alarma no tenía respuesta posible.
  /// `null` sólo se usaría si algún día se llamara a este widget sin la
  /// sección de fotos en la misma página -- hoy no pasa.
  final VoidCallback? alIrAFotos;

  @override
  Widget build(BuildContext context) {
    final revision = revisarParaPublicar(producto, catalogo);
    final motivo = revision.motivo;

    if (motivo != null) {
      return Aviso(
        texto: textoDelMotivoParaPublicar(motivo),
        tono: TonoDelAviso.error,
      );
    }
    if (revision.sinFoto) {
      final irAFotos = alIrAFotos;
      if (irAFotos == null) return const Aviso(texto: textoSinFotoAlPublicar);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Aviso(texto: textoSinFotoAlPublicar),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: irAFotos,
              child: const Text(textoIrACargarFoto),
            ),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}
