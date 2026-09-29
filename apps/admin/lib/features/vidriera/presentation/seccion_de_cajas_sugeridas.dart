import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/aviso.dart';
import '../../catalogo/domain/catalogo.dart';
import '../domain/borrador_de_caja.dart';
import '../domain/cajas_sugeridas.dart';
import '../domain/fallo_de_las_cajas.dart';
import '../vidriera_providers.dart';
import 'hoja_de_la_caja.dart';
import 'levantado.dart';
import 'pie_de_la_lista.dart';
import 'renglon_de_caja.dart';
import 'textos_de_la_vidriera.dart';

/// Las cajas sugeridas (HU-09.2, HU-09.3): armarlas, cambiarlas, ordenarlas
/// arrastrando y sacarlas. Un sliver, como la portada.
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

  /// Lo que se mando a guardar, mientras el documento no lo devuelva. La
  /// callable tarda uno o dos segundos: sin esto, la caja que se solto vuelve
  /// a su lugar viejo todo ese rato y despues salta al nuevo.
  CajasSugeridas? _enCamino;

  CajasSugeridas get _cajas => _enCamino ?? widget.cajas;

  @override
  void didUpdateWidget(SeccionDeCajasSugeridas anterior) {
    super.didUpdateWidget(anterior);
    // Llego el documento: manda el, sea lo guardado o lo de otra persona.
    if (!identical(widget.cajas, anterior.cajas)) _enCamino = null;
  }

  Future<FalloDeLasCajas?> _guardar(CajasSugeridas nuevas) async {
    try {
      await ref.read(repositorioDeLaVidrieraProvider).guardarCajas(nuevas);
      return null;
    } on FalloDeLasCajas catch (e) {
      return e;
    }
  }

  /// Ordenar, sacar y deshacer: un gesto que guarda en el acto.
  Future<void> _cambiar(
    CajasSugeridas nuevas, {
    String hecho = textoCajasGuardadas,
    CajasSugeridas? paraDeshacer,
  }) async {
    // El "Deshacer" del aviso puede tocarse despues de salir de Vidriera.
    if (!mounted || identical(nuevas, _cajas)) return;
    final avisos = ScaffoldMessenger.of(context);
    setState(() {
      _guardando = true;
      _enCamino = nuevas;
    });
    final fallo = await _guardar(nuevas);
    if (mounted) {
      setState(() {
        _guardando = false;
        if (fallo != null) _enCamino = null;
      });
    }
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

  /// [hasta] cuenta con la caja todavia en su lugar viejo: bajando, sobra
  /// uno. Las acciones de accesibilidad llegan aunque la manija espere.
  void _alSoltar(int desde, int hasta) {
    if (_guardando) return;
    final destino = hasta > desde ? hasta - 1 : hasta;
    _cambiar(_cajas.mover(desde, destino - desde));
  }

  Future<void> _abrir({int? indice}) async {
    final avisos = ScaffoldMessenger.of(context);
    final cajas = _cajas.cajas;
    final guardo = await HojaDeLaCaja.mostrar(
      context,
      inicial: indice == null
          ? BorradorDeCaja.nueva()
          : BorradorDeCaja.desde(cajas[indice]),
      otras: [
        for (final (i, c) in cajas.indexed)
          if (i != indice) c,
      ],
      // `_cajas` al GUARDAR, no al abrir: si otra persona cambio las cajas
      // mientras esta hoja estaba abierta, se guarda sobre lo de ella.
      alGuardar: (caja) => _guardar(_cajas.con(caja, indice: indice)),
    );
    if (guardo == true) {
      avisos.showSnackBar(const SnackBar(content: Text(textoCajasGuardadas)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final c = _cajas;
    final habilitado = !_guardando;

    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  textoTituloDeLasCajas,
                  style: tema.textTheme.titleLarge,
                ),
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
            ],
          ),
        ),
        SliverReorderableList(
          itemCount: c.cajas.length,
          onReorder: _alSoltar,
          proxyDecorator: (renglon, _, animacion) => Levantado(
            animacion: animacion,
            margenAbajo: RenglonDeCaja.separacion,
            child: renglon,
          ),
          itemBuilder: (context, i) => RenglonDeCaja(
            // Por identidad y no por nombre: el documento no garantiza
            // nombres unicos, y dos claves iguales tiran abajo la lista.
            key: ObjectKey(c.cajas[i]),
            caja: c.cajas[i],
            lugares: lugaresDeLaCaja(c.cajas[i], widget.catalogo),
            indice: i,
            habilitado: habilitado,
            alCambiar: () => _abrir(indice: i),
            alSacar: () => _cambiar(
              c.sin(i),
              hecho: '$textoCajaSacada $textoCuandoSeVenLasCajas',
              paraDeshacer: c,
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: PieDeLaLista(
            cuantos: c.cajas.length,
            cadaUno: 'cada caja',
            llena: c.llena,
            textoLlena: textoCajasLlenas,
            textoAgregar: textoArmarUnaCaja,
            alAgregar: habilitado ? _abrir : null,
          ),
        ),
      ],
    );
  }
}
