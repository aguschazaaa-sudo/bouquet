import 'package:flutter/material.dart';

import '../../../core/contratos/despacho.dart';
import '../domain/orden.dart';
import 'eleccion_en_fichas.dart';
import 'textos_de_entrega.dart';

/// Cancelar un pedido que todavia no salio (HU-07.6, Workflow D).
///
/// **Pide confirmar**, porque no tiene vuelta atras (poca burocracia: se
/// confirma solo lo que no se deshace). Y antes de confirmar **dice que vuelve al
/// stock**, con las cantidades del pedido: es lo que la cancelacion hace, y lo
/// hace el servidor. Si algo no puede volver, lo dice el pedido despues.
///
/// Devuelve el motivo elegido; quien la abre llama a la callable.
class HojaDeCancelacion extends StatefulWidget {
  const HojaDeCancelacion({super.key, required this.orden});

  final Orden orden;

  static Future<MotivoDeCancelacion?> mostrar(
    BuildContext context,
    Orden orden,
  ) {
    return showModalBottomSheet<MotivoDeCancelacion>(
      context: context,
      isScrollControlled: true,
      builder: (_) => HojaDeCancelacion(orden: orden),
    );
  }

  @override
  State<HojaDeCancelacion> createState() => _HojaDeCancelacionState();
}

class _HojaDeCancelacionState extends State<HojaDeCancelacion> {
  MotivoDeCancelacion? _motivo;
  bool _intento = false;

  void _confirmar() {
    final motivo = _motivo;
    if (motivo == null) {
      setState(() => _intento = true);
      return;
    }
    Navigator.of(context).pop(motivo);
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              textoTituloDeCancelar(widget.orden.numero),
              style: tema.textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 12),
          Text(textoVuelvenAlStock, style: tema.textTheme.labelLarge),
          const SizedBox(height: 4),
          for (final i in widget.orden.items)
            Text(textoLineaQueVuelve(i.cantidad, i.nombre, i.botellasEnTotal)),
          const SizedBox(height: 16),
          EleccionEnFichas<MotivoDeCancelacion>(
            titulo: textoMotivoDeCancelacion,
            opciones: MotivoDeCancelacion.values,
            rotulo: textoDelMotivoDeCancelacion,
            elegida: _motivo,
            alElegir: (m) => setState(() => _motivo = m),
          ),
          if (_intento && _motivo == null) ...[
            const SizedBox(height: 6),
            Text(
              textoElegiUnMotivo,
              style: TextStyle(color: tema.colorScheme.error),
            ),
          ],
          const SizedBox(height: 12),
          Text(textoCancelarNoSeDeshace, style: tema.textTheme.bodySmall),
          const SizedBox(height: 20),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: tema.colorScheme.error,
              foregroundColor: tema.colorScheme.onError,
            ),
            onPressed: _confirmar,
            child: const Text(textoConfirmarCancelacion),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(textoTodaviaNo),
          ),
        ],
      ),
    );
  }
}
