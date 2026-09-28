import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/aviso.dart';
import '../../catalogo/domain/catalogo.dart';
import '../../catalogo/domain/fallo_de_catalogo.dart';
import '../../catalogo/presentation/textos_del_catalogo.dart';
import '../domain/seleccion_de_la_portada.dart';
import '../vidriera_providers.dart';
import 'hoja_para_elegir_vino_de_la_portada.dart';
import 'renglon_de_la_portada.dart';
import 'textos_de_la_vidriera.dart';

/// La seleccion de la portada (HU-09.1): que vinos, en que orden, y cuales
/// no se van a ver.
///
/// **Cada gesto se guarda en el acto**, sin un boton de guardar: son seis
/// renglones, y un "Guardar" olvidado es un cambio que nadie hizo. Despues de
/// cada uno el aviso dice cuando se ve (HU-09.4): la portada no cambia al
/// guardar, y sin decirlo parece que no se guardo.
class SeccionDeLaPortada extends ConsumerStatefulWidget {
  const SeccionDeLaPortada({
    super.key,
    required this.seleccion,
    required this.catalogo,
  });

  final SeleccionDeLaPortada seleccion;
  final Catalogo catalogo;

  @override
  ConsumerState<SeccionDeLaPortada> createState() => _SeccionDeLaPortadaState();
}

class _SeccionDeLaPortadaState extends ConsumerState<SeccionDeLaPortada> {
  bool _guardando = false;

  Future<void> _guardar(SeleccionDeLaPortada nueva) async {
    if (identical(nueva, widget.seleccion)) return;
    final avisos = ScaffoldMessenger.of(context);
    setState(() => _guardando = true);
    try {
      await ref.read(repositorioDeLaVidrieraProvider).guardarSeleccion(nueva);
      avisos.showSnackBar(const SnackBar(content: Text(textoGuardado)));
    } on FalloDeCatalogo catch (e) {
      avisos.showSnackBar(SnackBar(content: Text(textoDelFallo(e.error))));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _agregar() async {
    final id = await HojaParaElegirVinoDeLaPortada.mostrar(
      context,
      widget.seleccion,
    );
    if (id == null || !mounted) return;
    await _guardar(widget.seleccion.agregar(id));
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final s = widget.seleccion;
    final lugares = s.lugaresEn(widget.catalogo);
    final habilitado = !_guardando;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(textoTituloDeLaPortada, style: tema.textTheme.titleLarge),
        ),
        const SizedBox(height: 6),
        Text(textoQueEsLaPortada, style: tema.textTheme.bodyMedium),
        const SizedBox(height: 12),
        const Aviso(texto: textoCuandoSeVeLaPortada),
        if (s.usaLaReglaEn(widget.catalogo)) ...[
          const SizedBox(height: 8),
          Aviso(
            texto: s.elegida && s.productoIds.isNotEmpty
                ? textoNingunoSeVe
                : textoTodaviaNoElegiste,
          ),
        ],
        const SizedBox(height: 12),
        if (s.elegida && s.productoIds.isNotEmpty)
          Text(
            textoCuantosElegiste(s.productoIds.length),
            style: tema.textTheme.labelLarge,
          ),
        for (final (i, lugar) in lugares.indexed)
          RenglonDeLaPortada(
            lugar: lugar,
            posicion: i + 1,
            esElPrimero: i == 0,
            esElUltimo: i == lugares.length - 1,
            habilitado: habilitado,
            alSubir: () => _guardar(s.mover(lugar.productoId, -1)),
            alBajar: () => _guardar(s.mover(lugar.productoId, 1)),
            alSacar: () => _guardar(s.quitar(lugar.productoId)),
          ),
        const SizedBox(height: 12),
        if (s.llena)
          Text(textoPortadaLlena, style: tema.textTheme.bodySmall)
        else
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: habilitado ? _agregar : null,
              icon: const Icon(Icons.add),
              label: const Text(textoAgregarUnVino),
            ),
          ),
      ],
    );
  }
}
