import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/rutas.dart';
import '../../../core/contratos/estado_publico.dart';
import '../../../core/presentation/aviso.dart';
import '../../../core/presentation/cargando.dart';
import '../../../core/presentation/fallo_con_reintento.dart';
import '../../../core/presentation/lista_vacia.dart';
import '../domain/orden.dart';
import '../domain/repositorio_de_pedidos.dart';
import '../pedidos_providers.dart';
import 'encabezado_de_pedidos.dart';
import 'seccion_de_items.dart';
import 'seccion_de_quien_y_donde.dart';
import 'textos_de_pedidos.dart';

/// `/pedidos/<id>` — un pedido entero (HU-06.2): numero, que lleva, quien lo
/// recibe, a donde va y en que estado esta.
///
/// **Desde la bandeja no lee nada**: recibe la Orden que la lista ya trajo
/// ([ordenInicial], por `extra` del enrutador). Abierto por URL directa —o
/// recargando— lee **un** documento. Un id que no existe, o un documento que no
/// se puede leer como pedido, **se dice**: una URL inventada no es una pantalla
/// en blanco.
class PaginaDelPedido extends ConsumerWidget {
  const PaginaDelPedido({super.key, required this.id, this.ordenInicial});

  final String id;

  /// La Orden ya cargada, si se llego desde la bandeja. Solo se usa si es la de
  /// [id]: un `extra` de otra navegacion no puede mostrar el pedido equivocado.
  final Orden? ordenInicial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    void volver() => context.go(Rutas.pedidos);
    final desdeLaLista = ordenInicial?.id == id ? ordenInicial : null;
    final detalle = desdeLaLista != null
        ? AsyncData<DetalleDePedido>(PedidoEncontrado(desdeLaLista))
        : ref.watch(pedidoProvider(id));

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
              alReintentar: () => ref.invalidate(pedidoProvider(id)),
            ),
            AsyncData(value: PedidoEncontrado(:final orden)) => _Detalle(
              orden: orden,
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

/// El cuerpo: el estado arriba (sale de la proyeccion, nunca de mirar los dos
/// campos) y despues las tres secciones.
class _Detalle extends StatelessWidget {
  const _Detalle({required this.orden});

  final Orden orden;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final rotulo = rotulosEstadoPublico[orden.estadoPublico]!.operador;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        Text(
          rotulo,
          style: tema.textTheme.titleMedium?.copyWith(
            color: orden.requiereAccion ? tema.colorScheme.primary : null,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          textoDelOrigen(orden.origen),
          style: tema.textTheme.bodySmall?.copyWith(
            color: tema.colorScheme.onSurfaceVariant,
          ),
        ),
        // Sin un estado de cobro: no lo sigue el sistema (ADR 018 §3).
        if (orden.cobroPorFuera) ...[
          const SizedBox(height: 12),
          const Aviso(texto: textoElCobroVaPorFuera),
        ],
        const SizedBox(height: 20),
        SeccionDeItems(orden: orden),
        const SizedBox(height: 24),
        SeccionDeQuienYDonde(orden: orden),
      ],
    );
  }
}
