import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/aviso.dart';
import '../../catalogo/domain/catalogo.dart';
import '../../catalogo/domain/fallo_de_catalogo.dart';
import '../../catalogo/presentation/textos_del_catalogo.dart';
import '../domain/seleccion_de_la_portada.dart';
import '../vidriera_providers.dart';
import 'hoja_para_elegir_un_vino.dart';
import 'levantado.dart';
import 'pie_de_la_lista.dart';
import 'renglon_de_la_portada.dart';
import 'textos_de_la_vidriera.dart';

/// La seleccion de la portada (HU-09.1): que vinos, en que orden, y cuales
/// no se van a ver.
///
/// **Cada gesto se guarda en el acto**, sin un boton de guardar: son seis
/// renglones, y un "Guardar" olvidado es un cambio que nadie hizo. Despues de
/// cada uno el aviso dice cuando se ve (HU-09.4): la portada no cambia al
/// guardar, y sin decirlo parece que no se guardo.
///
/// **Es un sliver.** El orden se cambia arrastrando, y para que la pagina
/// scrollee sola mientras se arrastra, la lista tiene que ser parte del scroll
/// de la pagina y no una lista adentro de otra.
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

  /// Lo que se acaba de guardar, mientras el documento no lo devuelva. Sin
  /// esto, al soltar un renglon la lista vuelve un instante al orden viejo
  /// —el que todavia trae [SeccionDeLaPortada.seleccion]— y salta.
  SeleccionDeLaPortada? _enCamino;

  SeleccionDeLaPortada get _seleccion => _enCamino ?? widget.seleccion;

  @override
  void didUpdateWidget(SeccionDeLaPortada anterior) {
    super.didUpdateWidget(anterior);
    // Llego el documento: manda el, sea lo guardado o lo de otra persona.
    if (!identical(widget.seleccion, anterior.seleccion)) _enCamino = null;
  }

  Future<void> _guardar(SeleccionDeLaPortada nueva) async {
    if (identical(nueva, _seleccion)) return;
    final avisos = ScaffoldMessenger.of(context);
    setState(() {
      _guardando = true;
      _enCamino = nueva;
    });
    try {
      await ref.read(repositorioDeLaVidrieraProvider).guardarSeleccion(nueva);
      avisos.showSnackBar(const SnackBar(content: Text(textoGuardado)));
    } on FalloDeCatalogo catch (e) {
      if (mounted) setState(() => _enCamino = null);
      avisos.showSnackBar(SnackBar(content: Text(textoDelFallo(e.error))));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  /// [hasta] cuenta con el renglon todavia en su lugar viejo: bajando, sobra
  /// uno. Las acciones de accesibilidad llegan por aca aunque la manija este
  /// esperando, y por eso se mira [_guardando].
  void _alSoltar(int desde, int hasta) {
    if (_guardando) return;
    final s = _seleccion;
    final destino = hasta > desde ? hasta - 1 : hasta;
    _guardar(s.mover(s.productoIds[desde], destino - desde));
  }

  Future<void> _agregar() async {
    final s = _seleccion;
    final id = await HojaParaElegirUnVino.mostrar(
      context,
      titulo: textoElegirParaLaPortada,
      porQueNo: (p, catalogo) {
        if (s.contiene(p.id)) return textoYaEstaEnLaPortada;
        final fuera = fueraDeLaPortada(p, catalogo);
        return fuera == null ? null : textoFueraDeLaPortada(fuera);
      },
    );
    if (id == null || !mounted) return;
    await _guardar(_seleccion.agregar(id));
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final s = _seleccion;
    final lugares = s.lugaresEn(widget.catalogo);
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
                  textoTituloDeLaPortada,
                  style: tema.textTheme.titleLarge,
                ),
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
              if (s.elegida && s.productoIds.isNotEmpty) ...[
                Text(
                  textoCuantosElegiste(s.productoIds.length),
                  style: tema.textTheme.labelLarge,
                ),
                const SizedBox(height: 4),
              ],
            ],
          ),
        ),
        SliverReorderableList(
          itemCount: lugares.length,
          onReorder: _alSoltar,
          proxyDecorator: (renglon, _, animacion) =>
              Levantado(animacion: animacion, child: renglon),
          itemBuilder: (context, i) => RenglonDeLaPortada(
            key: ValueKey(lugares[i].productoId),
            lugar: lugares[i],
            indice: i,
            habilitado: habilitado,
            alSacar: () => _guardar(s.quitar(lugares[i].productoId)),
          ),
        ),
        SliverToBoxAdapter(
          child: PieDeLaLista(
            cuantos: lugares.length,
            cadaUno: 'cada vino',
            llena: s.llena,
            textoLlena: textoPortadaLlena,
            textoAgregar: textoAgregarUnVino,
            alAgregar: habilitado ? _agregar : null,
          ),
        ),
      ],
    );
  }
}
