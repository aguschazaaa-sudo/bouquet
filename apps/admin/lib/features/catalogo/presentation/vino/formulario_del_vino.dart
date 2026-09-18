import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../catalogo_providers.dart';
import '../../domain/borrador_de_vino.dart';
import '../../domain/catalogo.dart';
import '../../domain/fallo_de_catalogo.dart';
import '../../domain/producto_del_panel.dart';
import 'confirmacion_de_caja.dart';
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
  const FormularioDelVino({super.key, this.original, required this.alTerminar});

  /// El vino como se abrio, o `null` para cargar uno nuevo. Se lee **una
  /// vez**: lo que llega despues por el stream no pisa lo que se esta
  /// escribiendo.
  final ProductoDelPanel? original;

  final VoidCallback alTerminar;

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

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SeccionDelVino(
                  borrador: _borrador,
                  revision: revision,
                  catalogo: catalogo,
                  problemaDe: problemaDe,
                  alCambiar: _cambiar,
                ),
                const SizedBox(height: 28),
                const Divider(),
                const SizedBox(height: 20),
                SeccionDeLaVenta(
                  borrador: _borrador,
                  revision: revision,
                  problemaDe: problemaDe,
                  alCambiar: _cambiar,
                ),
                const SizedBox(height: 28),
                PieDelFormulario(
                  revision: revision,
                  esNuevo: _borrador.esNuevo,
                  guardando: _guardando,
                  fallo: _fallo,
                  alGuardar: () => _guardar(revision),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
