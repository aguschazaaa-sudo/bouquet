import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/fallo_de_pedidos.dart';
import '../pedidos_providers.dart';
import 'textos_de_pago.dart';

/// "Volver a consultar a Mercado Pago" (HU-08.3): sólo lo dibuja
/// `SeccionDelPago` cuando `Orden.sePuedeRevisarElPago`.
///
/// Se ocupa **solo** -- no comparte el `_ocupado` de las acciones de entrega
/// del detalle, es una consulta aparte -- y pide releer el pedido
/// ([alCambiar]) cuando Mercado Pago devolvió algún pago: sin ninguno no hay
/// nada nuevo que leer (presupuesto de lecturas). Reintentar es seguro
/// (`RepositorioDePedidos.revisarPago`).
class BotonDeRevisarPago extends ConsumerStatefulWidget {
  const BotonDeRevisarPago({
    super.key,
    required this.ordenId,
    required this.alCambiar,
  });

  final String ordenId;

  /// El mismo mecanismo que usan cancelar y las demás acciones del detalle
  /// para volver a leer el pedido.
  final VoidCallback alCambiar;

  @override
  ConsumerState<BotonDeRevisarPago> createState() =>
      _BotonDeRevisarPagoState();
}

class _BotonDeRevisarPagoState extends ConsumerState<BotonDeRevisarPago> {
  bool _ocupado = false;

  Future<void> _revisar() async {
    if (_ocupado || !mounted) return;
    setState(() => _ocupado = true);
    final avisos = ScaffoldMessenger.of(context);
    try {
      final r = await ref
          .read(repositorioDePedidosProvider)
          .revisarPago(widget.ordenId);
      if (!mounted) return;
      setState(() => _ocupado = false);
      avisos.showSnackBar(
        SnackBar(content: Text(textoDelResultadoDeRevision(r))),
      );
      // Si Mercado Pago devolvió algún pago, el servidor pudo escribir algo
      // que la pantalla no tiene AUNQUE el estado no se mueva: lo devuelto de
      // un reembolso parcial, o la alerta de un segundo cobro (ADR 022). Una
      // lectura por toque, y el toque es a mano. Sin pagos no hay nada nuevo.
      if (r.encontrados > 0) widget.alCambiar();
    } catch (e) {
      if (!mounted) return;
      setState(() => _ocupado = false);
      final f = e is FalloDePedidos
          ? e
          : const FalloDePedidos(ErrorDePedido.desconocido);
      avisos.showSnackBar(
        SnackBar(
          content: Text(textoDelFalloDePago(f)),
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: _ocupado ? null : _revisar,
        icon: _ocupado
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.sync),
        label: const Text(textoBotonRevisarPago),
      ),
    );
  }
}
