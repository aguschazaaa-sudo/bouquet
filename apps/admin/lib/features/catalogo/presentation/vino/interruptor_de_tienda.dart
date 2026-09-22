import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/presentation/aviso.dart';
import '../../catalogo_providers.dart';
import '../../domain/catalogo.dart';
import '../../domain/en_la_tienda.dart';
import '../../domain/fallo_de_catalogo.dart';
import '../../domain/producto_del_panel.dart';
import '../textos_del_catalogo.dart';
import 'textos_del_vino.dart';

/// Poner un vino en la tienda y sacarlo (HU-03.6).
///
/// **Publicar y despublicar no piden confirmación.** Publicar lo protege la
/// revisión previa -- informacion, no una pregunta de sí/no (design.md,
/// Decision #3) --; despublicar tiene vuelta atrás con un toque: el
/// `SnackBar` que sigue a sacarlo ofrece "Deshacer".
///
/// **Sin estado optimista propio, a propósito.** El SDK de Firestore aplica
/// una escritura contra su caché local **antes** de que el servidor la
/// confirme (`domain/fallo_de_catalogo.dart`, comentario de
/// `ErrorDeCatalogo.sinConexion`): el stream que pinta [producto] ya trae el
/// cambio -optimista- de vuelta casi al instante, y si las reglas lo
/// rebotan, el mismo stream lo revierte solo. Guardar un booleano local acá
/// competiría con esa reversión en vez de mostrarla.
class InterruptorDeTienda extends ConsumerStatefulWidget {
  const InterruptorDeTienda({
    super.key,
    required this.producto,
    required this.catalogo,
  });

  final ProductoDelPanel producto;
  final Catalogo catalogo;

  @override
  ConsumerState<InterruptorDeTienda> createState() =>
      _InterruptorDeTiendaState();
}

class _InterruptorDeTiendaState extends ConsumerState<InterruptorDeTienda> {
  bool _procesando = false;
  String? _fallo;

  Future<void> _cambiar(bool nuevoValor) async {
    // El "Deshacer" del SnackBar llama a esto DIRECTO, sin pasar por el
    // boton (que ya viene deshabilitado si no corresponde) -- puede llegar
    // con el State ya dispuesto (`ScaffoldMessenger` vive arriba del
    // `Navigator`: el SnackBar sobrevive a un `pop`) o con el vino ya no
    // publicable (algo cambio en el rato que estuvo abierto). Las dos son el
    // MEDIO 2 de `revisor-pagos`, ADR 014.
    if (!mounted) return;
    if (nuevoValor &&
        !revisarParaPublicar(widget.producto, widget.catalogo).aparece) {
      setState(
        () => _fallo = 'Ya no se puede volver a publicar: revisalo de nuevo.',
      );
      return;
    }
    setState(() {
      _procesando = true;
      _fallo = null;
    });
    final repositorio = ref.read(repositorioDeProductosProvider);
    // ⚠️ `try/catch`, no `try/finally` (HU-04.4): un `finally` deja el error
    // como excepcion async perdida y el boton "vuelve" sin decir nada.
    try {
      if (nuevoValor) {
        await repositorio.publicar(widget.producto.id);
      } else {
        await repositorio.despublicar(widget.producto.id);
      }
      if (!mounted) return;
      setState(() => _procesando = false);
      if (!nuevoValor) _ofrecerDeshacer();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _procesando = false;
        _fallo = textoDelFallo(
          e is FalloDeCatalogo ? e.error : ErrorDeCatalogo.desconocido,
        );
      });
    }
  }

  void _ofrecerDeshacer() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Vino sacado de la tienda.'),
        action: SnackBarAction(
          label: 'Deshacer',
          onPressed: () => _cambiar(true),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.producto.muestra) {
      return const Aviso(texto: textoVinoDeMuestra);
    }

    final publicado = widget.producto.publicado;
    final puedePublicar = revisarParaPublicar(
      widget.producto,
      widget.catalogo,
    ).aparece;
    final tema = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        publicado
            ? OutlinedButton.icon(
                onPressed: _procesando ? null : () => _cambiar(false),
                icon: const Icon(Icons.storefront_outlined),
                label: const Text('Sacar de la tienda'),
              )
            : FilledButton.icon(
                onPressed: _procesando || !puedePublicar
                    ? null
                    : () => _cambiar(true),
                icon: const Icon(Icons.storefront),
                label: const Text('Poner en la tienda'),
              ),
        const SizedBox(height: 6),
        Text(
          textoNoSeBorra,
          style: tema.textTheme.bodySmall?.copyWith(
            color: tema.colorScheme.onSurfaceVariant,
          ),
        ),
        if (_fallo case final fallo?) ...[
          const SizedBox(height: 8),
          Aviso(texto: fallo, tono: TonoDelAviso.error),
        ],
      ],
    );
  }
}
