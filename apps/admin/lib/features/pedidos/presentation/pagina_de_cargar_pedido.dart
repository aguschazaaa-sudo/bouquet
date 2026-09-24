import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/rutas.dart';
import '../domain/fallo_de_pedidos.dart';
import '../domain/id_de_pedido.dart';
import '../domain/linea_a_cargar.dart';
import '../domain/pedido_a_cargar.dart';
import '../pedidos_providers.dart';
import 'campos_de_entrega.dart';
import 'encabezado_de_pedidos.dart';
import 'hoja_para_elegir_vino.dart';
import 'pie_de_carga.dart';
import 'renglon_de_linea.dart';
import 'textos_de_carga.dart';

/// `/pedidos/nuevo` — cargar un pedido que llego por WhatsApp (HU-10.1). Una
/// pantalla: los vinos, a quien y a donde, y el boton. Tiene que tardar menos que
/// anotarlo en un papel.
///
/// **El `idPedido` nace al abrirla y no se regenera nunca**: ni tras un error, ni
/// al cambiar cantidades, ni al corregir un dato. Un timeout con la transaccion ya
/// commiteada, seguido de otro toque, tiene que ser el MISMO pedido (ADR 018 §4;
/// es la leccion de `moverStock`). Tampoco se puede tocar dos veces mientras carga.
///
/// Los rechazos del servidor **corrigen el formulario en vez de perderlo**: un
/// stock que cambio baja la cantidad, un precio que cambio se actualiza, y el
/// operador vuelve a confirmar sin volver a escribir nada.
class PaginaDeCargarPedido extends ConsumerStatefulWidget {
  const PaginaDeCargarPedido({super.key});

  @override
  ConsumerState<PaginaDeCargarPedido> createState() =>
      _PaginaDeCargarPedidoState();
}

class _PaginaDeCargarPedidoState extends ConsumerState<PaginaDeCargarPedido> {
  PedidoACargar _pedido = PedidoACargar(idPedido: nuevoIdDePedido());
  bool _guardando = false;
  bool _intento = false;
  FalloDePedidos? _fallo;

  Future<void> _elegirVino() async {
    final p = await HojaParaElegirVino.mostrar(context);
    if (p == null || !mounted) return;
    setState(() {
      _pedido = _pedido.conVino(LineaACargar.de(p));
      _fallo = null;
    });
  }

  Future<void> _confirmar() async {
    if (_guardando) return;
    if (!_pedido.sePuedeConfirmar) {
      setState(() => _intento = true);
      return;
    }
    setState(() {
      _guardando = true;
      _fallo = null;
    });
    // ⚠️ `try/catch`, no `try/finally` (HU-04.4).
    try {
      final r = await ref.read(repositorioDePedidosProvider).cargar(_pedido);
      if (mounted) context.go(Rutas.pedido(r.ordenId));
    } catch (e) {
      if (!mounted) return;
      final fallo = e is FalloDePedidos
          ? e
          : const FalloDePedidos(ErrorDePedido.desconocido);
      setState(() {
        _guardando = false;
        _fallo = fallo;
        _pedido = _corregidoPor(fallo);
      });
    }
  }

  /// Lo que el rechazo permite arreglar sin volver a escribir: el stock y el
  /// precio de AHORA. La linea queda; el operador revisa y confirma.
  PedidoACargar _corregidoPor(FalloDePedidos f) {
    final id = f.productoId;
    final actual = f.actual;
    if (id == null || actual == null) return _pedido;
    return switch (f.error) {
      ErrorDePedido.sinStock => _pedido.conStockDe(id, actual),
      ErrorDePedido.cambioElPrecio => _pedido.conPrecioDe(id, actual),
      _ => _pedido,
    };
  }

  String? _nombreDe(String? productoId) {
    for (final l in _pedido.lineas) {
      if (l.productoId == productoId) return l.nombre;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final faltaAlgo = _intento && !_pedido.sePuedeConfirmar;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EncabezadoDePedidos(
          titulo: textoTituloDeCargar,
          alVolver: () => context.go(Rutas.pedidos),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              Text(textoQueSeLlevan, style: tema.textTheme.titleMedium),
              const SizedBox(height: 8),
              if (_pedido.lineas.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(textoSinVinosTodavia),
                ),
              for (final l in _pedido.lineas)
                RenglonDeLinea(
                  linea: l,
                  habilitado: !_guardando,
                  alCambiar: (n) => setState(
                    () => _pedido = _pedido.conCantidad(l.productoId, n),
                  ),
                  alSacar: () =>
                      setState(() => _pedido = _pedido.sinVino(l.productoId)),
                ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _guardando || !_pedido.admiteOtraLinea
                      ? null
                      : _elegirVino,
                  icon: const Icon(Icons.add),
                  label: const Text(textoSumarUnVino),
                ),
              ),
              const SizedBox(height: 24),
              Text(textoQuienYDonde, style: tema.textTheme.titleMedium),
              const SizedBox(height: 12),
              CamposDeEntrega(
                habilitado: !_guardando,
                problema: _intento ? _pedido.entrega.primerProblema : null,
                alCambiar: (e) =>
                    setState(() => _pedido = _pedido.conEntrega(e)),
              ),
              const SizedBox(height: 20),
              PieDeCarga(
                pedido: _pedido,
                guardando: _guardando,
                faltaAlgo: faltaAlgo,
                fallo: _fallo,
                nombreDelVino: _nombreDe(_fallo?.productoId),
                alConfirmar: _confirmar,
                alAbrirElExistente: () =>
                    context.go(Rutas.pedido(_pedido.idPedido)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
