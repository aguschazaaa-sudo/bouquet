import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/rutas.dart';
import '../../../core/presentation/cargando.dart';
import '../../../core/presentation/fallo_con_reintento.dart';
import '../../../core/presentation/lista_vacia.dart';
import '../domain/orden.dart';
import '../domain/repositorio_de_pedidos.dart';
import '../pedidos_providers.dart';
import 'detalle_del_pedido.dart';
import 'encabezado_de_pedidos.dart';
import 'textos_de_pedidos.dart';

/// `/pedidos/<id>` — un pedido entero (HU-06.2): numero, que lleva, quien lo
/// recibe, a donde va y en que estado esta, y lo que se le puede hacer (EP-07).
///
/// **Desde la bandeja no lee nada**: recibe la Orden que la lista ya trajo
/// ([ordenInicial], por `extra` del enrutador). Abierto por URL directa —o
/// recargando— lee **un** documento. **Despues de un cambio lee uno**: la
/// Orden que vino de la lista ya no es la de ahora, y lo que se muestra es lo que
/// tiene el servidor. Un id que no existe, o un documento que no se puede leer
/// como pedido, **se dice**: una URL inventada no es una pantalla en blanco.
class PaginaDelPedido extends ConsumerStatefulWidget {
  const PaginaDelPedido({super.key, required this.id, this.ordenInicial});

  final String id;

  /// La Orden ya cargada, si se llego desde la bandeja. Solo se usa si es la de
  /// [id], y hasta el primer cambio: un `extra` de otra navegacion no puede
  /// mostrar el pedido equivocado, ni uno viejo.
  final Orden? ordenInicial;

  @override
  ConsumerState<PaginaDelPedido> createState() => _PaginaDelPedidoState();
}

class _PaginaDelPedidoState extends ConsumerState<PaginaDelPedido> {
  /// `true` desde el primer cambio: de ahi en mas manda la lectura.
  bool _releer = false;

  /// La ultima Orden que se mostro. Mientras se relee sigue en pantalla, en vez
  /// de un "Buscando…" que se llevaria el aviso de lo que acaba de pasar.
  Orden? _ultima;

  void _volverALeer() {
    setState(() => _releer = true);
    ref.invalidate(pedidoProvider(widget.id));
  }

  @override
  Widget build(BuildContext context) {
    void volver() => context.go(Rutas.pedidos);
    final inicial = widget.ordenInicial;
    final desdeLaLista = !_releer && inicial?.id == widget.id ? inicial : null;
    var detalle = desdeLaLista != null
        ? AsyncData<DetalleDePedido>(PedidoEncontrado(desdeLaLista))
        : ref.watch(pedidoProvider(widget.id));
    final ultima = _ultima;
    if (detalle.isLoading && ultima != null) {
      detalle = AsyncData(PedidoEncontrado(ultima));
    }
    if (detalle case AsyncData(value: PedidoEncontrado(:final orden))) {
      _ultima = orden;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EncabezadoDePedidos(
          titulo: switch (detalle.valueOrNull) {
            PedidoEncontrado(:final orden) => textoDelNumero(orden.numero),
            _ => textoTituloDelDetalle,
          },
          alVolver: volver,
        ),
        Expanded(
          child: switch (detalle) {
            AsyncError() => FalloConReintento(
              texto: textoNoSePudoLeerElPedido,
              alReintentar: () => ref.invalidate(pedidoProvider(widget.id)),
            ),
            AsyncData(value: PedidoEncontrado(:final orden)) =>
              DetalleDelPedido(
                key: ValueKey(orden.id),
                orden: orden,
                alCambiar: _volverALeer,
              ),
            AsyncData(value: PedidoIncompleto()) => ListaVacia(
              icono: Icons.report_problem_outlined,
              texto: textoPedidoIncompleto,
              accion: OutlinedButton(
                onPressed: volver,
                child: const Text(textoVolverALosPedidos),
              ),
            ),
            AsyncData() => ListaVacia(
              icono: Icons.search_off,
              texto: textoPedidoInexistente,
              accion: OutlinedButton(
                onPressed: volver,
                child: const Text(textoVolverALosPedidos),
              ),
            ),
            _ => const Cargando(que: textoCargandoPedidos),
          },
        ),
      ],
    );
  }
}
