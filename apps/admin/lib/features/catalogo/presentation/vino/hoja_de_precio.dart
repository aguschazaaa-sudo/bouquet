import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/contratos/plata.dart';
import '../../../../core/presentation/aviso.dart';
import '../../catalogo_providers.dart';
import '../../domain/cambio_de_precio.dart';
import '../../domain/fallo_de_catalogo.dart';
import '../../domain/numeros_escritos.dart';
import '../../domain/producto_del_panel.dart';
import '../textos_del_catalogo.dart';
import 'campo_de_precio.dart';

/// Cambiar el precio de un vino que está en la tienda (HU-03.5, Workflow D).
///
/// Es una acción APARTE del formulario de la ficha: `borrador_de_vino.dart`
/// sigue sin dejar tocar el precio de un publicado (design.md, Decision #4).
/// Si el precio nuevo se aparta mucho -- `cambio_de_precio.dart`, evaluado
/// sobre el VALOR NUEVO -- pide confirmar mostrando los dos precios en
/// pesos antes de guardar; si no, guarda directo.
///
/// Devuelve `true` si guardó. Quien la abre es responsable de avisar el
/// atraso de ~13 minutos DESPUÉS: ese aviso es del llamador, no de la hoja
/// (siempre se muestra igual, la hoja se cierra apenas guarda).
class HojaDePrecio extends ConsumerStatefulWidget {
  const HojaDePrecio({
    super.key,
    required this.producto,
    required this.preciosPublicados,
  });

  final ProductoDelPanel producto;

  /// Los precios, en centavos, de TODOS los productos publicados del
  /// catálogo tal como están hoy.
  final List<int> preciosPublicados;

  static Future<bool?> mostrar(
    BuildContext context, {
    required ProductoDelPanel producto,
    required List<int> preciosPublicados,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => HojaDePrecio(
        producto: producto,
        preciosPublicados: preciosPublicados,
      ),
    );
  }

  @override
  ConsumerState<HojaDePrecio> createState() => _HojaDePrecioState();
}

class _HojaDePrecioState extends ConsumerState<HojaDePrecio> {
  late String _escrito = pesosParaEscribir(widget.producto.precio);
  bool _guardando = false;
  String? _fallo;

  /// Precio anterior y publicados releidos del catalogo VIVO, no del
  /// snapshot con que se abrio la hoja (MEDIO 3 de `revisor-pagos`,
  /// ADR 014). Cero lecturas: el catalogo ya esta en memoria.
  ({int anterior, List<int> publicados}) _leer() {
    final catalogo = ref.read(catalogoProvider).valueOrNull;
    final vivo = catalogo?.vino(widget.producto.id);
    return (
      anterior: vivo?.precio ?? widget.producto.precio,
      publicados: catalogo == null
          ? widget.preciosPublicados
          : [
              for (final r in catalogo.renglones)
                if (r.producto.publicado) r.producto.precio,
            ],
    );
  }

  Future<void> _guardar(int nuevo) async {
    final frescos = _leer();
    if (pideConfirmarElCambio(
      precioNuevo: nuevo,
      precioAnterior: frescos.anterior,
      preciosPublicados: frescos.publicados,
    )) {
      final confirmo = await _confirmar(frescos.anterior, nuevo);
      if (confirmo != true || !mounted) return;
    }
    setState(() {
      _guardando = true;
      _fallo = null;
    });
    final repositorio = ref.read(repositorioDeProductosProvider);
    // ⚠️ `try/catch`, no `try/finally` (HU-04.4).
    try {
      await repositorio.cambiarPrecio(widget.producto.id, nuevo);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _fallo = textoDelFallo(
          e is FalloDeCatalogo ? e.error : ErrorDeCatalogo.desconocido,
        );
      });
    }
  }

  Future<bool?> _confirmar(int anterior, int nuevo) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cambiar el precio?'),
        content: Text(
          'De ${enPesos(anterior)} a ${enPesos(nuevo)}. Es un cambio grande: '
          'revisalo antes de confirmar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Revisar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Sí, cambiar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = leerPesos(_escrito);
    String? problema;
    if (l.estaVacia) {
      problema = 'Falta el precio.';
    } else if (l.problema != null) {
      problema = l.problema;
    } else if (l.valor == 0) {
      problema = 'El precio tiene que ser mayor que cero.';
    }
    final puedeGuardar = !_guardando && (l.valor ?? 0) > 0;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Cambiar el precio',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.producto.nombre,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              CampoDePrecio(
                escrito: _escrito,
                leido: l.valor,
                problema: problema,
                fijo: false,
                alCambiar: (v) => setState(() {
                  _escrito = v;
                  _fallo = null;
                }),
              ),
              if (_fallo case final fallo?) ...[
                const SizedBox(height: 14),
                Aviso(texto: fallo, tono: TonoDelAviso.error),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: puedeGuardar ? () => _guardar(l.valor!) : null,
                child: Text(_guardando ? 'Guardando…' : 'Guardar el precio'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
