import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/rutas.dart';
import '../domain/numero_buscado.dart';
import '../domain/repositorio_de_pedidos.dart';
import '../pedidos_providers.dart';
import 'textos_de_pedidos.dart';

/// Buscar un pedido por su numero (HU-06.4): *"hola, ¿como va el 123?"*.
///
/// **Una lectura por busqueda**, y solo al apretar *Buscar* o Enter: buscar
/// mientras se escribe costaria una lectura por tecla. Si lo encuentra **abre el
/// detalle con la Orden ya leida** (`extra`), asi que abrirlo no cuesta otra.
///
/// Lo que no es un numero no se busca: se dice ([textoNoEsUnNumero]). Un numero
/// que no existe tampoco es un error: se dice ([textoNoHayPedido]).
class BuscadorDePedido extends ConsumerStatefulWidget {
  const BuscadorDePedido({super.key});

  @override
  ConsumerState<BuscadorDePedido> createState() => _BuscadorDePedidoState();
}

class _BuscadorDePedidoState extends ConsumerState<BuscadorDePedido> {
  final _texto = TextEditingController();
  bool _buscando = false;
  String? _aviso;

  @override
  void dispose() {
    _texto.dispose();
    super.dispose();
  }

  /// ⚠️ `try/catch`, no `try/finally` (HU-04.4): un error que se pierde deja un
  /// boton que "no hace nada".
  Future<void> _buscar() async {
    if (_buscando) return;
    final numero = numeroBuscado(_texto.text);
    if (numero == null) {
      setState(() => _aviso = textoNoEsUnNumero);
      return;
    }
    setState(() {
      _buscando = true;
      _aviso = null;
    });
    String? aviso;
    try {
      final r = await ref.read(repositorioDePedidosProvider).porNumero(numero);
      if (!mounted) return;
      switch (r) {
        case PedidoEncontrado(:final orden):
          _texto.clear();
          context.go(Rutas.pedido(orden.id), extra: orden);
        case PedidoInexistente():
          aviso = textoNoHayPedido(numero);
        case PedidoIncompleto():
          aviso = textoPedidoConNumeroIncompleto(numero);
      }
    } catch (_) {
      aviso = textoNoSePudoBuscar;
    }
    if (mounted) {
      setState(() {
        _buscando = false;
        _aviso = aviso;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: _texto,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _buscar(),
            onChanged: (_) {
              if (_aviso != null) setState(() => _aviso = null);
            },
            decoration: InputDecoration(
              hintText: textoBuscarPorNumero,
              prefixIcon: Icon(Icons.search, color: esquema.onSurfaceVariant),
              errorText: _aviso,
              errorMaxLines: 2,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: OutlinedButton(
            onPressed: _buscando ? null : _buscar,
            child: Text(_buscando ? textoBuscando : textoBuscar),
          ),
        ),
      ],
    );
  }
}
