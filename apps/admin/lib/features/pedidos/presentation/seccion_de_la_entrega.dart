import 'package:flutter/material.dart';

import '../../../core/contratos/estado_entrega.dart';
import '../../../core/presentation/aviso.dart';
import '../domain/hace_cuanto.dart';
import '../domain/orden.dart';
import 'dato_del_pedido.dart';
import 'textos_de_entrega.dart';

/// Lo que ya paso en el eje de entrega de un pedido (EP-07): por donde salio,
/// por que no se entrego, por que se cancelo.
///
/// Lo mas importante de esta seccion son **las lineas que no volvieron al
/// stock** de un pedido cancelado: lo tiene que resolver una persona, y queda
/// escrito en la Orden, asi que se ve cada vez que se abre -- no solo en un
/// aviso que se va.
///
/// **Una fila sin dato no se dibuja**, igual que en `SeccionDeQuienYDonde`.
class SeccionDeLaEntrega extends StatelessWidget {
  const SeccionDeLaEntrega({
    super.key,
    required this.orden,
    required this.ahora,
  });

  final Orden orden;

  /// La hora de quien mira, para decir *"hace 2 h"*. Por parametro, no leida
  /// aca.
  final DateTime ahora;

  @override
  Widget build(BuildContext context) {
    final despacho = orden.despacho;
    final falla = orden.estadoEntrega == EstadoEntrega.fallida
        ? orden.entregaFallida
        : null;
    final cancelacion = orden.estadoEntrega == EstadoEntrega.cancelada
        ? orden.cancelacion
        : null;
    final sinReponer = cancelacion?.sinReponer ?? const [];
    if (despacho == null && falla == null && cancelacion == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (despacho != null)
          DatoDelPedido(
            etiqueta: '$textoSalioPor · ${haceCuanto(despacho.en, ahora)}',
            valor: textoDelDespacho(
              correo: despacho.correo,
              seguimiento: despacho.seguimiento,
            ),
          ),
        if (falla != null)
          DatoDelPedido(
            etiqueta:
                '$textoPorQueNoSeEntrego · ${haceCuanto(falla.en, ahora)}',
            valor: textoDelMotivoDeFalla(falla.motivo),
          ),
        if (cancelacion?.motivo case final motivo?)
          DatoDelPedido(
            etiqueta: textoPorQueSeCancelo,
            valor: textoDelMotivoDeCancelacion(motivo),
          ),
        if (sinReponer.isNotEmpty)
          Aviso(
            tono: TonoDelAviso.error,
            texto: [
              textoNoVolvieron,
              for (final l in sinReponer)
                textoLineaSinReponer(l.nombre, l.cantidad, l.motivo),
            ].join('\n'),
          ),
      ],
    );
  }
}
