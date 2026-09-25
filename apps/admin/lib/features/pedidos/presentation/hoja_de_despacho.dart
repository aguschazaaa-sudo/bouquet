import 'package:flutter/material.dart';

import '../../../core/contratos/despacho.dart';
import '../domain/paso_de_entrega.dart';
import 'eleccion_en_fichas.dart';
import 'textos_de_entrega.dart';

/// Despachar un pedido: por donde sale y, si hay, el seguimiento (HU-07.2).
///
/// **No escribe nada**: devuelve el [Despachar] y quien la abre lo guarda. Asi
/// la hoja no conoce el repositorio, y un error se muestra en el pedido, que es
/// donde se vuelve a intentar.
///
/// El seguimiento es **opcional** (ADR 019 §4): una entrega en mano no tiene, y
/// una etiqueta se puede imprimir despues. Poca burocracia: el correo es un
/// toque, y lo unico obligatorio.
class HojaDeDespacho extends StatefulWidget {
  const HojaDeDespacho({super.key, required this.numero});

  final int numero;

  static Future<Despachar?> mostrar(BuildContext context, int numero) {
    return showModalBottomSheet<Despachar>(
      context: context,
      isScrollControlled: true,
      builder: (_) => HojaDeDespacho(numero: numero),
    );
  }

  @override
  State<HojaDeDespacho> createState() => _HojaDeDespachoState();
}

class _HojaDeDespachoState extends State<HojaDeDespacho> {
  final _seguimiento = TextEditingController();
  Correo? _correo;
  bool _intento = false;

  @override
  void dispose() {
    _seguimiento.dispose();
    super.dispose();
  }

  void _confirmar() {
    final correo = _correo;
    if (correo == null || !seguimientoEsValido(_seguimiento.text)) {
      setState(() => _intento = true);
      return;
    }
    Navigator.of(context).pop(
      Despachar(correo: correo, seguimiento: seguimientoDe(_seguimiento.text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final largo = !seguimientoEsValido(_seguimiento.text);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              textoTituloDeDespachar(widget.numero),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 16),
          EleccionEnFichas<Correo>(
            titulo: textoCorreo,
            opciones: Correo.values,
            rotulo: textoRotuloDelCorreo,
            elegida: _correo,
            alElegir: (c) => setState(() => _correo = c),
          ),
          if (_intento && _correo == null) ...[
            const SizedBox(height: 6),
            Text(
              textoElegiElCorreo,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _seguimiento,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _confirmar(),
            decoration: InputDecoration(
              labelText: textoSeguimiento,
              helperText: textoSeguimientoOpcional,
              helperMaxLines: 2,
              errorText: largo
                  ? textoSeguimientoLargo(largoDelSeguimiento)
                  : null,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _confirmar,
            child: const Text(textoMarcarDespachado),
          ),
        ],
      ),
    );
  }
}
