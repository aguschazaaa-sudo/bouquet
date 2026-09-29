import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/aviso.dart';
import '../domain/envio_sin_cargo.dart';
import '../vidriera_providers.dart';
import 'confirmacion_del_envio.dart';
import 'dialogo_del_envio_sin_cargo.dart';
import 'textos_del_envio.dart';

/// Desde que monto la entrega sale sin cargo (HU-11.1, ADR 026). Toca plata.
///
/// Se guarda por la callable `fijarEnvioSinCargo`, la unica puerta de
/// `config`. **La baranda contra el dedo gordo corre en el servidor** —el
/// monto por debajo de una caja tipica, o menos de la mitad del anterior—: si
/// pregunta, esta seccion muestra la pregunta con los dos montos y solo con
/// *"Guardar igual"* vuelve a llamar, confirmado. Apagar no pregunta: cobrar
/// la entrega no regala nada.
class SeccionDelEnvioSinCargo extends ConsumerStatefulWidget {
  const SeccionDelEnvioSinCargo({super.key, required this.envio});

  final EnvioSinCargo envio;

  @override
  ConsumerState<SeccionDelEnvioSinCargo> createState() =>
      _SeccionDelEnvioSinCargoState();
}

class _SeccionDelEnvioSinCargoState
    extends ConsumerState<SeccionDelEnvioSinCargo> {
  bool _guardando = false;

  Future<void> _fijar() async {
    final monto = await DialogoDelEnvioSinCargo.mostrar(
      context,
      actual: widget.envio.desde,
    );
    if (monto == null || !mounted) return;
    await _guardar(monto);
  }

  Future<void> _guardar(int? desde) async {
    var resultado = await _llamar(desde, confirmado: false);
    if (resultado is PideConfirmar && desde != null) {
      if (!mounted) return;
      final si = await ConfirmacionDelEnvio.mostrar(
        context,
        monto: desde,
        pregunta: resultado,
      );
      if (!si || !mounted) return;
      resultado = await _llamar(desde, confirmado: true);
    }
    if (resultado is Fijado && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            resultado.desde == null
                ? textoEnvioApagadoGuardado
                : textoEnvioGuardado,
          ),
        ),
      );
    }
  }

  /// Una llamada, con el fallo dicho en la pantalla. `null` si fallo.
  Future<ResultadoDeFijar?> _llamar(
    int? desde, {
    required bool confirmado,
  }) async {
    final avisos = ScaffoldMessenger.of(context);
    setState(() => _guardando = true);
    try {
      return await ref
          .read(repositorioDeLaVidrieraProvider)
          .fijarEnvioSinCargo(desde, confirmado: confirmado);
    } on FalloDelEnvio catch (e) {
      avisos.showSnackBar(
        SnackBar(content: Text(textoDelFalloDelEnvio(e.error))),
      );
      return null;
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final envio = widget.envio;
    final desde = envio.desde;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(textoTituloDelEnvio, style: tema.textTheme.titleLarge),
        ),
        const SizedBox(height: 4),
        Text(textoQueEsElEnvio, style: tema.textTheme.bodySmall),
        const SizedBox(height: 12),
        if (envio.roto)
          const Aviso(texto: textoEnvioRoto, tono: TonoDelAviso.error)
        else
          Text(
            desde == null ? textoEnvioApagado : textoEnvioDesde(desde),
            style: tema.textTheme.bodyLarge,
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            FilledButton.tonal(
              onPressed: _guardando ? null : _fijar,
              child: Text(desde == null ? textoFijarMonto : textoCambiarMonto),
            ),
            if (desde != null || envio.roto)
              TextButton(
                onPressed: _guardando ? null : () => _guardar(null),
                child: const Text(textoCobrarSiempre),
              ),
          ],
        ),
      ],
    );
  }
}
