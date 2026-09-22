import 'package:flutter/material.dart';

import '../../../../core/presentation/aviso.dart';
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
  });

  final ProductoDelPanel producto;
  final Catalogo catalogo;

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
      return const Aviso(texto: textoSinFotoAlPublicar);
    }
    return const SizedBox.shrink();
  }
}
