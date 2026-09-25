import 'package:flutter/material.dart';

import '../../../core/contratos/despacho.dart';
import '../domain/paso_de_entrega.dart';
import 'eleccion_en_fichas.dart';
import 'textos_de_entrega.dart';

/// Registrar que una entrega no se pudo hacer, con su motivo (HU-07.5).
///
/// El motivo es **obligatorio** y es un toque. Uno de ellos es el legal —*no
/// habia un mayor de 18*— porque `entregada` quiere decir que firmo uno
/// (ARQUITECTURA §9.5). Devuelve el [NoSeEntrego] y quien la abre lo guarda.
class HojaDeFalla extends StatefulWidget {
  const HojaDeFalla({super.key, required this.numero});

  final int numero;

  static Future<NoSeEntrego?> mostrar(BuildContext context, int numero) {
    return showModalBottomSheet<NoSeEntrego>(
      context: context,
      isScrollControlled: true,
      builder: (_) => HojaDeFalla(numero: numero),
    );
  }

  @override
  State<HojaDeFalla> createState() => _HojaDeFallaState();
}

class _HojaDeFallaState extends State<HojaDeFalla> {
  MotivoDeFalla? _motivo;
  bool _intento = false;

  void _confirmar() {
    final motivo = _motivo;
    if (motivo == null) {
      setState(() => _intento = true);
      return;
    }
    Navigator.of(context).pop(NoSeEntrego(motivo));
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              textoTituloDeFalla(widget.numero),
              style: tema.textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 16),
          EleccionEnFichas<MotivoDeFalla>(
            titulo: textoMotivoDeFalla,
            opciones: MotivoDeFalla.values,
            rotulo: textoDelMotivoDeFalla,
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
          Text(textoDespuesDeLaFalla, style: tema.textTheme.bodySmall),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _confirmar,
            child: const Text(textoMarcarNoEntregado),
          ),
        ],
      ),
    );
  }
}
