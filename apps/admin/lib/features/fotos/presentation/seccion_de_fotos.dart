import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/aviso.dart';
import '../domain/fallo_de_fotos.dart';
import '../domain/foto_del_vino.dart';
import '../domain/foto_principal.dart';
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
/// `productoId == null` es "el nombre todavía no da una dirección" -- ni
/// Storage ni `procesarFoto` tienen dónde escribir sin ella. **Ya no** exige
/// que el vino esté guardado (ADR 015 §5, revierte la exclusión original de
/// `spec panel-vino "Un alta sin guardar"`): `procesarFoto` nunca tocó
/// Firestore, sólo pide que la ruta `productos/{id}/...` exista en el
/// bucket, y el `arrayUnion` que sí necesita el documento se salta con
/// [guardado] en `false`.
class SeccionDeFotos extends ConsumerStatefulWidget {
  const SeccionDeFotos({
    super.key,
    required this.productoId,
    required this.imagenes,
    this.guardado = true,
    this.alCambiarImagenesLocales,
  });

  /// El id del documento en una corrección, o el slug que va a tener -todavía
  /// sin guardar- en un alta.
  final String? productoId;

  /// Las fotos YA PERSISTIDAS en `productos/{productoId}.imagenes`. Vacía
  /// siempre en un alta: ahí no hay nada persistido todavía.
  final List<String> imagenes;

  /// `false` en un alta: [productoId] es un slug, no un documento que
  /// exista, así que subir no agrega a Firestore y quitar es sólo local.
  final bool guardado;

  /// La lista completa de URLs subidas en esta sesión, cada vez que cambia.
  /// Sólo se usa cuando [guardado] es `false`: `FormularioDelVino` la guarda
  /// en `BorradorDeVino.imagenes` para mandarla en el mismo alta.
  final ValueChanged<List<String>>? alCambiarImagenesLocales;

  @override
  ConsumerState<SeccionDeFotos> createState() => _SeccionDeFotosState();
}

class _SeccionDeFotosState extends ConsumerState<SeccionDeFotos> {
  final _subidasEnEstaSesion = <String, FotoDelVino>{};

  /// Sólo se usa cuando `widget.guardado` es `false`: en una corrección la
  /// lista persistida (`widget.imagenes`) ya es la fuente de verdad.
  final _agregadasLocalmente = <String>[];
  final _quitando = <String>{};
  bool _cambiandoPrincipal = false;
  final _fallos = <(String nombre, String texto)>[];

  void _agregar(FotoDelVino foto) {
    setState(() {
      _subidasEnEstaSesion[foto.url] = foto;
      if (!widget.guardado) _agregadasLocalmente.add(foto.url);
    });
    if (!widget.guardado) {
      widget.alCambiarImagenesLocales?.call(List.of(_agregadasLocalmente));
    }
  }

  Future<void> _quitar(String productoId, String url) async {
    if (!widget.guardado) {
      setState(() {
        _agregadasLocalmente.remove(url);
        _subidasEnEstaSesion.remove(url);
      });
      widget.alCambiarImagenesLocales?.call(List.of(_agregadasLocalmente));
      return;
    }
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

  /// HU-04.2. En un alta sin guardar se reordena la lista local, sin tocar la
  /// base; en un vino guardado lo hace el repositorio con una transacción que
  /// relee `imagenes`, nunca con la lista de esta pantalla (§5.3).
  Future<void> _hacerPrincipal(String productoId, String url) async {
    if (!widget.guardado) {
      final nueva = conPrincipal(_agregadasLocalmente, url);
      if (nueva == null) return;
      setState(() {
        _agregadasLocalmente
          ..clear()
          ..addAll(nueva);
      });
      widget.alCambiarImagenesLocales?.call(List.of(nueva));
      return;
    }
    setState(() => _cambiandoPrincipal = true);
    try {
      await ref
          .read(repositorioDeFotosProvider)
          .hacerPrincipal(productoId: productoId, url: url);
    } on FalloDeFotos catch (e) {
      if (mounted) {
        setState(
          () => _fallos.add((
            textoNoSePudoCambiarLaPrincipal,
            textoDelFalloDeFotos(e.error),
          )),
        );
      }
    } finally {
      if (mounted) setState(() => _cambiandoPrincipal = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final productoId = widget.productoId;
    final imagenes = widget.guardado ? widget.imagenes : _agregadasLocalmente;

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
          const Aviso(texto: textoEscribiElNombrePrimero)
        else ...[
          if (imagenes.isEmpty) const Aviso(texto: textoSinFotosTodavia),
          // Una fila por foto, como el catálogo (`RenglonDeProducto`): esta
          // sección vive adentro del `ListView` real de `FormularioDelVino`
          // (spec panel-vino "La página del vino tiene una sección de
          // fotos"), así que crecer verticalmente con la cantidad de fotos
          // no desborda nada -- ya hay un scroll de verdad más arriba.
          for (final (posicion, url) in imagenes.indexed)
            RenglonDeFoto(
              key: ValueKey(url),
              url: url,
              recienSubida: _subidasEnEstaSesion[url],
              quitando: _quitando.contains(url),
              alQuitar: () => _quitar(productoId, url),
              // Con una sola foto no hay nada que elegir (spec "La principal
              // se marca sólo cuando hay para elegir").
              esPrincipal: imagenes.length > 1 && posicion == 0,
              alUsarComoPrincipal: imagenes.length > 1 && posicion > 0
                  ? () => _hacerPrincipal(productoId, url)
                  : null,
              cambiandoPrincipal: _cambiandoPrincipal,
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
            agregarAlDocumento: widget.guardado,
            alSubir: _agregar,
            alFallar: (nombre, texto) =>
                setState(() => _fallos.add((nombre, texto))),
          ),
        ],
      ],
    );
  }
}
