import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../fotos/presentation/seccion_de_fotos.dart';
import '../../catalogo_providers.dart';
import '../../domain/borrador_de_vino.dart';
import '../../domain/catalogo.dart';
import '../../domain/fallo_de_catalogo.dart';
import '../../domain/producto_del_panel.dart';
import 'confirmacion_de_caja.dart';
import 'disposicion_del_formulario.dart';
import 'pie_del_formulario.dart';
import 'seccion_de_la_venta.dart';
import 'seccion_del_vino.dart';
import 'textos_del_vino.dart';

/// El formulario de un vino: cargar uno (HU-03.2, HU-03.3) o corregirlo
/// (HU-03.4). ADR 013 §4.
///
/// **No decide nada.** Guarda un `BorradorDeVino`, le pide la `Revision` en
/// cada build y hace lo que la revision dice: que mostrar, si se puede
/// guardar, si hay que confirmar la caja. Todo eso tiene tests en
/// `borrador_de_vino_test.dart`, que corren en una maquina donde esto no
/// compila.
class FormularioDelVino extends ConsumerStatefulWidget {
  const FormularioDelVino({
    super.key,
    this.original,
    required this.alTerminar,
    this.claveDeFotos,
  });

  /// El vino como se abrio, o `null` para cargar uno nuevo. Se lee **una
  /// vez**: lo que llega despues por el stream no pisa lo que se esta
  /// escribiendo.
  final ProductoDelPanel? original;

  final VoidCallback alTerminar;

  /// La clave de `SeccionDeFotos`, para que `RevisionParaPublicar` -- fuera
  /// de este `ListView`, arriba del todo -- pueda hacer
  /// `Scrollable.ensureVisible` hasta acá (`PaginaDelVino`,
  /// panel-vino "El aviso de sin foto... lleva a la solución"). `null` en
  /// un alta: ahí no hay ningun aviso que pueda necesitarla todavia.
  final GlobalKey? claveDeFotos;

  @override
  ConsumerState<FormularioDelVino> createState() => _FormularioDelVinoState();
}

class _FormularioDelVinoState extends ConsumerState<FormularioDelVino> {
  late BorradorDeVino _borrador = switch (widget.original) {
    final original? => BorradorDeVino.desde(original),
    null => const BorradorDeVino(),
  };

  /// En un alta, los campos que ya se tocaron: solo esos muestran su
  /// problema. En una correccion se muestra todo desde el principio — un vino
  /// guardado roto tiene que verse roto.
  final _tocados = <CampoDelVino>{};
  bool _guardando = false;
  String? _fallo;

  /// Refresca `_borrador.original` cuando el catalogo trae un vino
  /// cambiado por AFUERA de este formulario -tipicamente, `SeccionDeLaTienda`
  /// arriba, publicando o cambiando el precio-. Sin esto, `precioFijo`
  /// queda leyendo un `original` congelado del momento en que se abrio la
  /// pagina (hallazgo ALTO 1 de `revisor-pagos`, ADR 014). Nunca toca lo
  /// tecleado: `conOriginalActualizado` preserva cada campo del borrador.
  @override
  void didUpdateWidget(covariant FormularioDelVino oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nuevo = widget.original;
    if (nuevo != null) {
      setState(() => _borrador = _borrador.conOriginalActualizado(nuevo));
    }
  }

  void _cambiar(CampoDelVino? campo, BorradorDeVino nuevo) => setState(() {
    _borrador = nuevo;
    if (campo != null) _tocados.add(campo);
    _fallo = null;
  });

  Future<void> _guardar(Revision revision) async {
    final alta = revision.alta;
    if (revision.pideConfirmarLaCaja &&
        !await confirmarLaCaja(context, alta!.botellas)) {
      return;
    }
    setState(() {
      _guardando = true;
      _fallo = null;
    });
    final repositorio = ref.read(repositorioDeProductosProvider);
    // ⚠️ `try/catch`, no `try/finally` (HU-04.4): en PadelPunilla el error
    // se perdia como excepcion async, el spinner giraba y el boton volvia.
    try {
      if (alta != null) {
        await repositorio.crear(alta);
      } else {
        await repositorio.corregir(widget.original!.id, revision.cambios!);
      }
      if (mounted) widget.alTerminar();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _fallo = textoDelFalloDelVino(
          e is FalloDeCatalogo ? e.error : ErrorDeCatalogo.desconocido,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalogo = ref.watch(catalogoProvider).valueOrNull ?? Catalogo.vacio;
    final revision = _borrador.revisar(
      catalogo,
      anioActual: DateTime.now().year,
    );
    String? problemaDe(CampoDelVino c) =>
        !_borrador.esNuevo || _tocados.contains(c)
        ? revision.problemaDe(c)
        : null;

    final datos = SeccionDelVino(
      borrador: _borrador,
      revision: revision,
      catalogo: catalogo,
      problemaDe: problemaDe,
      alCambiar: _cambiar,
    );
    final venta = SeccionDeLaVenta(
      borrador: _borrador,
      revision: revision,
      problemaDe: problemaDe,
      alCambiar: _cambiar,
    );
    final fotos = SeccionDeFotos(
      key: widget.claveDeFotos,
      productoId: widget.original?.id ?? _slugParaFotos(revision),
      imagenes: widget.original?.imagenes ?? const [],
      guardado: widget.original != null,
      alCambiarImagenesLocales: widget.original != null
          ? null
          : (urls) => _cambiar(null, _borrador.conImagenes(urls)),
    );
    final pie = PieDelFormulario(
      revision: revision,
      esNuevo: _borrador.esNuevo,
      guardando: _guardando,
      fallo: _fallo,
      activar: _borrador.activar,
      alCambiarActivar: (v) => _cambiar(null, _borrador.conActivar(v)),
      alGuardar: () => _guardar(revision),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        Center(
          child: DisposicionDelFormulario(
            datos: datos,
            venta: venta,
            fotos: fotos,
            pie: pie,
          ),
        ),
      ],
    );
  }

  /// El slug que va a tener el documento, mientras el alta todavía es un
  /// borrador (ADR 015 §5). `null` sin nombre: ahí `aSlug` da `''`, y
  /// `SeccionDeFotos` no tiene dónde escribir en Storage todavía.
  String? _slugParaFotos(Revision revision) =>
      revision.slug.isEmpty ? null : revision.slug;
}
