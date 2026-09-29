import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/aviso.dart';
import '../../catalogo/domain/catalogo.dart';
import '../domain/borrador_de_caja.dart';
import '../domain/cajas_sugeridas.dart';
import '../domain/fallo_de_las_cajas.dart';
import '../vidriera_providers.dart';
import 'hoja_de_la_caja.dart';
import 'renglon_de_caja.dart';
import 'textos_de_la_vidriera.dart';

/// Las cajas sugeridas (HU-09.2, HU-09.3): armarlas, cambiarlas, ordenarlas
/// y sacarlas.
///
/// Todo se guarda **entero y por la callable** (ADR 024): las reglas no dejan
/// escribir el documento ni al admin. Sacar una caja no pide confirmacion:
/// ofrece "Deshacer", que vuelve a guardar la lista de antes (criterio 3 del
/// panel: se confirma solo lo que no tiene vuelta atras).
class SeccionDeCajasSugeridas extends ConsumerStatefulWidget {
  const SeccionDeCajasSugeridas({
    super.key,
    required this.cajas,
    required this.catalogo,
  });

  final CajasSugeridas cajas;
  final Catalogo catalogo;

  @override
  ConsumerState<SeccionDeCajasSugeridas> createState() =>
      _SeccionDeCajasSugeridasState();
}

class _SeccionDeCajasSugeridasState
    extends ConsumerState<SeccionDeCajasSugeridas> {
  bool _guardando = false;

  Future<FalloDeLasCajas?> _guardar(CajasSugeridas nuevas) async {
    try {
      await ref.read(repositorioDeLaVidrieraProvider).guardarCajas(nuevas);
      return null;
    } on FalloDeLasCajas catch (e) {
      return e;
    }
  }

  /// Subir, bajar, sacar y deshacer: un toque que guarda en el acto.
  Future<void> _cambiar(
    CajasSugeridas nuevas, {
    String hecho = textoCajasGuardadas,
    CajasSugeridas? paraDeshacer,
  }) async {
    // El "Deshacer" del aviso puede tocarse despues de salir de Vidriera.
    if (!mounted) return;
    final avisos = ScaffoldMessenger.of(context);
    setState(() => _guardando = true);
    final fallo = await _guardar(nuevas);
    if (mounted) setState(() => _guardando = false);
    avisos.showSnackBar(
      SnackBar(
        content: Text(fallo == null ? hecho : textoDelFalloDeLasCajas(fallo)),
        action: fallo == null && paraDeshacer != null
            ? SnackBarAction(
                label: textoDeshacer,
                onPressed: () => _cambiar(paraDeshacer),
              )
            : null,
      ),
    );
  }

  Future<void> _abrir({int? indice}) async {
    final avisos = ScaffoldMessenger.of(context);
    final cajas = widget.cajas.cajas;
    final guardo = await HojaDeLaCaja.mostrar(
      context,
      inicial: indice == null
          ? BorradorDeCaja.nueva()
          : BorradorDeCaja.desde(cajas[indice]),
      otras: [
        for (final (i, c) in cajas.indexed)
          if (i != indice) c,
      ],
      // `widget.cajas` al GUARDAR, no al abrir: si otra persona cambio las
      // cajas mientras esta hoja estaba abierta, se guarda sobre lo de ella.
      alGuardar: (caja) => _guardar(widget.cajas.con(caja, indice: indice)),
    );
    if (guardo == true) {
      avisos.showSnackBar(const SnackBar(content: Text(textoCajasGuardadas)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final c = widget.cajas;
    final habilitado = !_guardando;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(textoTituloDeLasCajas, style: tema.textTheme.titleLarge),
        ),
        const SizedBox(height: 6),
        Text(textoQueSonLasCajas, style: tema.textTheme.bodyMedium),
        const SizedBox(height: 12),
        const Aviso(texto: textoCuandoSeVenLasCajas),
        const SizedBox(height: 12),
        if (c.cajas.isEmpty) ...[
          const Aviso(texto: textoTodaviaNoHayCajas),
          const SizedBox(height: 12),
        ],
        for (final (i, caja) in c.cajas.indexed)
          RenglonDeCaja(
            caja: caja,
            lugares: lugaresDeLaCaja(caja, widget.catalogo),
            esLaPrimera: i == 0,
            esLaUltima: i == c.cajas.length - 1,
            habilitado: habilitado,
            alCambiar: () => _abrir(indice: i),
            alSubir: () => _cambiar(c.mover(i, -1)),
            alBajar: () => _cambiar(c.mover(i, 1)),
            alSacar: () => _cambiar(
              c.sin(i),
              hecho: '$textoCajaSacada $textoCuandoSeVenLasCajas',
              paraDeshacer: c,
            ),
          ),
        if (c.llena)
          Text(textoCajasLlenas, style: tema.textTheme.bodySmall)
        else
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: habilitado ? _abrir : null,
              icon: const Icon(Icons.add),
              label: const Text(textoArmarUnaCaja),
            ),
          ),
      ],
    );
  }
}
