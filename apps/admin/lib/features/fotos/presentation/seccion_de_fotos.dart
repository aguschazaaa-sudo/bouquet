import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/aviso.dart';
import '../domain/fallo_de_fotos.dart';
import '../domain/foto_del_vino.dart';
import '../fotos_providers.dart';
import 'boton_de_agregar_foto.dart';
import 'renglon_de_foto.dart';
import 'textos_de_fotos.dart';

/// La sección de fotos de la página del vino (HU-04.1, HU-04.3): las que ya
/// tiene, más la forma de sumar otra.
///
/// Guarda, sólo para esta sesión, lo que devolvió `procesarFoto` de cada
/// foto recién subida: el documento no persiste `ancho`/`alto`/
/// `porcentajeRecortado` (`domain/foto_del_vino.dart`), así que una foto de
/// antes de abrir esta página no tiene aviso posible.
///
/// `productoId == null` es "el vino todavía no se guardó" (spec panel-vino,
/// "Un alta sin guardar"): ni la ruta de Storage ni el `arrayUnion` tienen
/// dónde escribir sin el slug, así que acá se corta antes de ofrecer nada.
class SeccionDeFotos extends ConsumerStatefulWidget {
  const SeccionDeFotos({
    super.key,
    required this.productoId,
    required this.imagenes,
  });

  final String? productoId;
  final List<String> imagenes;

  @override
  ConsumerState<SeccionDeFotos> createState() => _SeccionDeFotosState();
}

class _SeccionDeFotosState extends ConsumerState<SeccionDeFotos> {
  final _subidasEnEstaSesion = <String, FotoDelVino>{};
  final _quitando = <String>{};
  final _fallos = <(String nombre, String texto)>[];

  Future<void> _quitar(String productoId, String url) async {
    setState(() => _quitando.add(url));
    try {
      await ref
          .read(repositorioDeFotosProvider)
          .quitar(productoId: productoId, url: url);
    } on FalloDeFotos catch (e) {
      if (mounted) {
        setState(
          () => _fallos.add((e.nombreDeArchivo, textoDelFalloDeFotos(e.error))),
        );
      }
    } finally {
      if (mounted) setState(() => _quitando.remove(url));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final productoId = widget.productoId;
    final imagenes = widget.imagenes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            textoTituloDeLaSeccion,
            style: tema.textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 10),
        if (productoId == null)
          const Aviso(texto: textoGuardarPrimero)
        else ...[
          if (imagenes.isEmpty) const Aviso(texto: textoSinFotosTodavia),
          // Una fila por foto, como el catálogo (`RenglonDeProducto`): esta
          // sección vive adentro del `ListView` real de `FormularioDelVino`
          // (spec panel-vino "La página del vino tiene una sección de
          // fotos"), así que crecer verticalmente con la cantidad de fotos
          // no desborda nada -- ya hay un scroll de verdad más arriba.
          for (final url in imagenes)
            RenglonDeFoto(
              key: ValueKey(url),
              url: url,
              recienSubida: _subidasEnEstaSesion[url],
              quitando: _quitando.contains(url),
              alQuitar: () => _quitar(productoId, url),
            ),
          if (imagenes.isNotEmpty) const SizedBox(height: 8),
          for (final (nombre, texto) in _fallos)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Aviso(texto: '$nombre: $texto', tono: TonoDelAviso.error),
            ),
          BotonDeAgregarFoto(
            productoId: productoId,
            cuantasTiene: imagenes.length,
            alSubir: (foto) =>
                setState(() => _subidasEnEstaSesion[foto.url] = foto),
            alFallar: (nombre, texto) =>
                setState(() => _fallos.add((nombre, texto))),
          ),
        ],
      ],
    );
  }
}
