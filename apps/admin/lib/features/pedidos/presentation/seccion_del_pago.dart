import 'package:flutter/material.dart';

import '../../../core/contratos/pedido.dart';
import '../../../core/contratos/plata.dart';
import '../../../core/presentation/aviso.dart';
import '../domain/hace_cuanto.dart';
import '../domain/orden.dart';
import 'boton_de_revisar_pago.dart';
import 'dato_del_pedido.dart';
import 'textos_de_pago.dart';

/// Lo que Mercado Pago dijo del cobro de un pedido de la tienda (HU-08.1), y
/// el botón para volver a preguntarle (HU-08.3).
///
/// **Sólo aparece en un pedido de la vidriera**: uno de WhatsApp se cobra por
/// fuera y Mercado Pago no sabe nada de él -- `Orden.pago` ahí es siempre
/// `null` (ADR 018 §3, ADR 022).
///
/// El monto es el que informó el proveedor, no el de lista: si no coincide
/// con `Orden.total`, se avisa -- el servidor no marca un pedido pagado por
/// un monto distinto, y eso lo tiene que ver quien opera, no adivinarlo.
class SeccionDelPago extends StatelessWidget {
  const SeccionDelPago({
    super.key,
    required this.orden,
    required this.ahora,
    required this.alCambiar,
  });

  final Orden orden;

  /// La hora de quien mira, para decir *"hace 2 h"*. Por parámetro, no leída
  /// acá.
  final DateTime ahora;

  final VoidCallback alCambiar;

  @override
  Widget build(BuildContext context) {
    if (orden.origen != Origen.vidriera) return const SizedBox.shrink();
    final tema = Theme.of(context);
    final pago = orden.pago;
    final distinto = pago != null && pago.monto != orden.total;
    final alerta = orden.alertaDePago;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(textoTituloDelPago, style: tema.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(
          textoEstadoDelPago(orden.estadoPago),
          style: tema.textTheme.bodyLarge,
        ),
        const SizedBox(height: 6),
        if (pago != null) ...[
          DatoDelPedido(
            etiqueta: textoParaConciliar,
            valor: textoOperacion(pago.operacionId),
          ),
          DatoDelPedido(
            etiqueta: textoMontoInformado,
            valor: enPesos(pago.monto),
          ),
          // Un reembolso parcial deja el pago acreditado: esto es lo único
          // que dice que ya se devolvió una parte.
          if (pago.reembolsado > 0)
            DatoDelPedido(
              etiqueta: textoDevuelto,
              valor: enPesos(pago.reembolsado),
            ),
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              '$textoConsultado · ${haceCuanto(pago.consultadoEn, ahora)}',
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ] else
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              textoSinPagoRegistrado,
              style: tema.textTheme.bodyMedium,
            ),
          ),
        if (distinto) ...[
          Aviso(
            tono: TonoDelAviso.error,
            texto: textoMontoNoCoincide(pago.monto, orden.total),
          ),
          const SizedBox(height: 10),
        ],
        // Plata que se movió en Mercado Pago y el pedido no refleja: un
        // segundo cobro, un monto distinto, un contracargo (ADR 022).
        if (alerta != null) ...[
          Aviso(tono: TonoDelAviso.error, texto: textoDeLaAlerta(alerta)),
          const SizedBox(height: 10),
        ],
        if (orden.sePuedeRevisarElPago)
          BotonDeRevisarPago(ordenId: orden.id, alCambiar: alCambiar),
        const SizedBox(height: 16),
      ],
    );
  }
}
