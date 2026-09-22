import 'package:flutter/material.dart';

import '../../../core/presentation/aviso.dart';
import '../domain/foto_del_vino.dart';
import 'textos_de_fotos.dart';

/// El aviso de una foto recién subida, si corresponde: no recortó nada, o
/// quedó más chica que el objetivo de 1200 (spec "El panel avisa cuando una
/// foto no se recortó o quedó chica"). **No bloquea**: es informativo, la
/// decisión es del operador que está mirando la previsualización.
///
/// Sólo existe para una [FotoDelVino] -- lo que devolvió `procesarFoto` al
/// subir. Una foto de antes de esta sesión no trae esa info (el documento
/// no la persiste, `foto_del_vino.dart`), así que `RenglonDeFoto` no
/// compone este widget para ésas.
class AvisoDeLaFoto extends StatelessWidget {
  const AvisoDeLaFoto({super.key, required this.foto});

  final FotoDelVino foto;

  @override
  Widget build(BuildContext context) {
    // El fondo sin recortar es lo primero que se ve mal, así que gana sobre
    // el aviso de altura si -por lo que sea- los dos aplicaran a la vez.
    final texto = foto.porcentajeRecortado == 0
        ? textoNoRecorto
        : foto.alto < 1200
        ? textoQuedoChica
        : null;

    if (texto == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Aviso(texto: texto),
    );
  }
}
