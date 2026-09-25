import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contratos/estado_publico.dart';
import '../../../core/presentation/aviso.dart';
import '../domain/fallo_de_pedidos.dart';
import '../domain/nota_del_pedido.dart';
import '../domain/orden.dart';
import '../domain/paso_de_entrega.dart';
import '../pedidos_providers.dart';
import 'botones_del_pedido.dart';
import 'dialogo_de_entrega.dart';
import 'hoja_de_cancelacion.dart';
import 'hoja_de_despacho.dart';
import 'hoja_de_falla.dart';
import 'hoja_de_nota.dart';
import 'seccion_de_items.dart';
import 'seccion_de_la_entrega.dart';
import 'seccion_de_notas.dart';
import 'seccion_de_quien_y_donde.dart';
import 'textos_de_entrega.dart';
import 'textos_de_notas.dart';
import 'textos_de_pedidos.dart';

/// El cuerpo del detalle de un pedido (HU-06.2) y lo que se le puede hacer
/// (EP-07) y sus notas (HU-07.7): el estado arriba —de la proyeccion, nunca de
/// mirar los dos campos—, que sigue, lo que ya paso, las notas, que lleva y a
/// quien.
///
/// Cada cambio **se guarda y despues se vuelve a leer** ([alCambiar]): la
/// pantalla muestra lo que tiene el servidor, no lo que el panel cree que
/// escribio. Cuesta una lectura por cambio. Un rechazo que dice que lo que se ve
/// ya no es lo que hay (otra persona lo movio) tambien relee.
///
/// Los resultados van en un `SnackBar`; un error que pide actuar —sin conexion—
/// queda escrito arriba de los botones hasta el proximo intento (HU-04.4).
class DetalleDelPedido extends ConsumerStatefulWidget {
  const DetalleDelPedido({
    super.key,
    required this.orden,
    required this.alCambiar,
  });

  final Orden orden;
  final VoidCallback alCambiar;

  @override
  ConsumerState<DetalleDelPedido> createState() => _DetalleDelPedidoState();
}

class _DetalleDelPedidoState extends ConsumerState<DetalleDelPedido> {
  bool _ocupado = false;
  FalloDePedidos? _fallo;
  String Function(FalloDePedidos) _textoDelFallo = textoDelFalloDeEntrega;

  Orden get _orden => widget.orden;

  Future<void> _elegir(AccionDelPedido a) async {
    final n = _orden.numero;
    switch (a) {
      case AccionDelPedido.preparar:
        await _avanzar(const Preparar());
      case AccionDelPedido.despachar:
        final paso = await HojaDeDespacho.mostrar(context, n);
        if (paso != null) await _avanzar(paso);
      case AccionDelPedido.entregar:
        if (await DialogoDeEntrega.mostrar(context, n)) {
          await _avanzar(const Entregar());
        }
      case AccionDelPedido.noSeEntrego:
        final paso = await HojaDeFalla.mostrar(context, n);
        if (paso != null) await _avanzar(paso);
      case AccionDelPedido.cancelar:
        final motivo = await HojaDeCancelacion.mostrar(context, _orden);
        if (motivo == null) return;
        await _hacer(() async {
          final r = await ref
              .read(repositorioDePedidosProvider)
              .cancelar(_orden.id, motivo);
          return textoCancelado(
            r.numero,
            repetido: r.repetido,
            sinReponer: r.sinReponer.length,
          );
        });
    }
  }

  Future<void> _anotar() async {
    final texto = await HojaDeNota.mostrar(
      context,
      numero: _orden.numero,
      actual: _orden.notasOperador,
    );
    if (texto == null) return;
    final nota = notaAGuardar(texto);
    // Sin cambios no se escribe: una escritura que no cambia nada igual cuesta.
    if (nota == _orden.notasOperador) return;
    await _hacer(() async {
      await ref.read(repositorioDePedidosProvider).anotar(_orden.id, nota);
      return textoNotaGuardada(_orden.numero, borrada: nota == null);
    }, textoDelFallo: textoDelFalloDeNota);
  }

  Future<void> _avanzar(PasoDeEntrega paso) => _hacer(() async {
    await ref.read(repositorioDePedidosProvider).avanzar(_orden.id, paso);
    return textoPasoHecho(paso, _orden.numero);
  });

  /// ⚠️ `try/catch`, no `try/finally` (HU-04.4): un error que se pierde deja un
  /// boton que "no hace nada".
  Future<void> _hacer(
    Future<String> Function() cambio, {
    String Function(FalloDePedidos) textoDelFallo = textoDelFalloDeEntrega,
  }) async {
    if (_ocupado || !mounted) return;
    setState(() {
      _ocupado = true;
      _fallo = null;
    });
    final avisos = ScaffoldMessenger.of(context);
    try {
      final hecho = await cambio();
      avisos.showSnackBar(SnackBar(content: Text(hecho)));
      if (mounted) setState(() => _ocupado = false);
      widget.alCambiar();
    } catch (e) {
      final f = e is FalloDePedidos
          ? e
          : const FalloDePedidos(ErrorDePedido.desconocido);
      if (!mounted) return;
      setState(() {
        _ocupado = false;
        _fallo = hayQueReleer(f) ? null : f;
        _textoDelFallo = textoDelFallo;
      });
      if (hayQueReleer(f)) {
        avisos.showSnackBar(
          SnackBar(
            content: Text(textoDelFallo(f)),
            duration: const Duration(seconds: 8),
          ),
        );
        widget.alCambiar();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final rotulo = rotulosEstadoPublico[_orden.estadoPublico]!.operador;
    final fallo = _fallo;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        Text(
          rotulo,
          style: tema.textTheme.titleMedium?.copyWith(
            color: _orden.requiereAccion ? tema.colorScheme.primary : null,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          textoDelOrigen(_orden.origen),
          style: tema.textTheme.bodySmall?.copyWith(
            color: tema.colorScheme.onSurfaceVariant,
          ),
        ),
        // Sin un estado de cobro: no lo sigue el sistema (ADR 018 §3).
        if (_orden.cobroPorFuera) ...[
          const SizedBox(height: 12),
          const Aviso(texto: textoElCobroVaPorFuera),
        ],
        const SizedBox(height: 16),
        SeccionDeLaEntrega(orden: _orden, ahora: DateTime.now()),
        if (fallo != null) ...[
          Aviso(tono: TonoDelAviso.error, texto: _textoDelFallo(fallo)),
          const SizedBox(height: 12),
        ],
        BotonesDelPedido(orden: _orden, ocupado: _ocupado, alElegir: _elegir),
        const SizedBox(height: 24),
        SeccionDeNotas(orden: _orden, ocupado: _ocupado, alEditar: _anotar),
        const SizedBox(height: 24),
        SeccionDeItems(orden: _orden),
        const SizedBox(height: 24),
        SeccionDeQuienYDonde(orden: _orden),
      ],
    );
  }
}
