import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contratos/texto.dart';
import '../../../core/presentation/aviso.dart';
import '../catalogo_providers.dart';
import '../domain/bodega.dart';
import '../domain/catalogo.dart';
import '../domain/fallo_de_catalogo.dart';
import 'bodegas_parecidas.dart';
import 'textos_del_catalogo.dart';

/// Cargar una bodega (HU-02.1) o corregirle el nombre (HU-02.3).
///
/// Es una hoja y no una ruta: es **un campo**, y no tiene sentido que se
/// pueda compartir por URL.
///
/// ⚠️ **Al editar, el slug no se toca.** La bodega va a tener
/// `/bodega/<slug>` indexable y un slug que se mueve es un 404 en Google.
/// Las reglas permitirian mandarlo; la restriccion es del panel.
class HojaDeBodega extends ConsumerStatefulWidget {
  const HojaDeBodega({super.key, this.bodega});

  /// `null` para cargar una nueva.
  final Bodega? bodega;

  static Future<void> mostrar(BuildContext context, {Bodega? bodega}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => HojaDeBodega(bodega: bodega),
    );
  }

  @override
  ConsumerState<HojaDeBodega> createState() => _HojaDeBodegaState();
}

class _HojaDeBodegaState extends ConsumerState<HojaDeBodega> {
  late final _control = TextEditingController(
    text: widget.bodega?.nombre ?? '',
  );
  bool _guardando = false;
  String? _fallo;

  bool get _esNueva => widget.bodega == null;

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  Future<void> _guardar(String nombre) async {
    final slug = aSlug(nombre);
    if (slug.isEmpty) {
      setState(() => _fallo = textoNombreSinSlug);
      return;
    }
    setState(() {
      _guardando = true;
      _fallo = null;
    });
    final repositorio = ref.read(repositorioDeBodegasProvider);
    try {
      // ⚠️ `try/catch`, no `try/finally`. HU-04.4: en PadelPunilla la
      // excepcion se perdia como error async, el spinner giraba y el boton
      // volvia -- meses de fallas sin un solo reporte.
      if (_esNueva) {
        await repositorio.crear(nombre: nombre.trim(), slug: slug);
      } else {
        await repositorio.corregirNombre(
          id: widget.bodega!.id,
          nombre: nombre.trim(),
        );
      }
      if (mounted) Navigator.of(context).pop();
    } on FalloDeCatalogo catch (e) {
      if (mounted) {
        setState(() {
          _guardando = false;
          _fallo = textoDelFallo(e.error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalogo = ref.watch(catalogoProvider).valueOrNull ?? Catalogo.vacio;

    return Padding(
      // El teclado del telefono, o la hoja tapa el campo que se esta
      // escribiendo.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
          child: ValueListenableBuilder(
            valueListenable: _control,
            builder: (context, valor, _) =>
                _contenido(context, catalogo, valor.text),
          ),
        ),
      ),
    );
  }

  Widget _contenido(BuildContext context, Catalogo catalogo, String nombre) {
    final tema = Theme.of(context);
    final slug = aSlug(nombre);
    final propia = widget.bodega?.id;
    final laMisma = catalogo.conElMismoNombre(nombre, exceptoId: propia);
    final puedeGuardar =
        !_guardando && slug.isNotEmpty && laMisma == null && _cambio(nombre);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            _esNueva ? 'Cargar una bodega' : 'Corregir el nombre',
            style: tema.textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: _control,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Nombre de la bodega'),
          onSubmitted: puedeGuardar ? _guardar : null,
        ),
        const SizedBox(height: 10),
        _Direccion(slug: slug, esNueva: _esNueva),
        const SizedBox(height: 14),
        BodegasParecidas(
          laMisma: laMisma,
          parecidas: catalogo.parecidasA(nombre, exceptoId: propia),
        ),
        if (_fallo case final fallo?) ...[
          const SizedBox(height: 14),
          Aviso(texto: fallo, tono: TonoDelAviso.error),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: puedeGuardar ? () => _guardar(nombre) : null,
          child: Text(_guardando ? 'Guardando…' : 'Guardar'),
        ),
      ],
    );
  }

  /// Guardar el mismo nombre que ya tiene es una escritura que no cambia
  /// nada, y una lectura de vuelta por el stream. Dos centavos, pero sobre
  /// todo: el boton apagado dice que no hay nada que guardar.
  bool _cambio(String nombre) =>
      _esNueva || nombre.trim() != widget.bodega!.nombre;
}

/// La direccion que va a tener la bodega en la tienda, a la vista mientras se
/// escribe. Al editar se muestra y **no cambia**: que se vea fijo es el punto.
class _Direccion extends StatelessWidget {
  const _Direccion({required this.slug, required this.esNueva});

  final String slug;
  final bool esNueva;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final texto = slug.isEmpty
        ? 'Escribí un nombre para ver su dirección'
        : esNueva
        ? 'Su dirección en la tienda: /bodega/$slug'
        : 'Su dirección en la tienda no cambia: /bodega/$slug';

    return Text(
      texto,
      style: tema.textTheme.bodySmall?.copyWith(
        color: tema.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
