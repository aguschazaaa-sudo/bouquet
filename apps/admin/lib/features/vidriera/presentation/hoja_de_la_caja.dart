import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/aviso.dart';
import '../../../core/presentation/cargando.dart';
import '../../catalogo/catalogo_providers.dart';
import '../../catalogo/domain/catalogo.dart';
import '../domain/borrador_de_caja.dart';
import '../domain/cajas_sugeridas.dart';
import '../domain/fallo_de_las_cajas.dart';
import 'hoja_para_elegir_un_vino.dart';
import 'lugar_de_la_hoja.dart';
import 'textos_de_la_vidriera.dart';

/// Armar o cambiar una caja sugerida (HU-09.2, HU-09.3): un nombre y seis
/// lugares.
///
/// **Dice cuantos lugares faltan todo el tiempo**, no al tocar Guardar, y no
/// ofrece un vino que viene en caja: son las dos cosas que la historia pide
/// ver antes de guardar. Si el guardado falla, la hoja **no se cierra** y el
/// borrador queda: rearmar seis lugares por un corte de red es trabajo tirado.
///
/// Devuelve `true` si guardo.
class HojaDeLaCaja extends ConsumerStatefulWidget {
  const HojaDeLaCaja({
    super.key,
    required this.inicial,
    required this.otras,
    required this.alGuardar,
  });

  final BorradorDeCaja inicial;

  /// Las demas cajas, para avisar un nombre repetido.
  final List<CajaSugerida> otras;

  /// Guarda la lista entera con esta caja adentro. `null` si guardo.
  final Future<FalloDeLasCajas?> Function(CajaSugerida caja) alGuardar;

  static Future<bool?> mostrar(
    BuildContext context, {
    required BorradorDeCaja inicial,
    required List<CajaSugerida> otras,
    required Future<FalloDeLasCajas?> Function(CajaSugerida caja) alGuardar,
  }) => showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) =>
        HojaDeLaCaja(inicial: inicial, otras: otras, alGuardar: alGuardar),
  );

  @override
  ConsumerState<HojaDeLaCaja> createState() => _HojaDeLaCajaState();
}

class _HojaDeLaCajaState extends ConsumerState<HojaDeLaCaja> {
  late BorradorDeCaja _b = widget.inicial;
  late final _nombre = TextEditingController(text: widget.inicial.nombre);
  bool _guardando = false;
  FalloDeLasCajas? _fallo;

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  Future<void> _elegir(int lugar) async {
    final id = await HojaParaElegirUnVino.mostrar(
      context,
      titulo: textoElegirParaLaCaja,
      porQueNo: (p, catalogo) {
        final fuera = fueraAlElegir(p, catalogo);
        return fuera == null ? null : textoFueraDeLaCaja(fuera);
      },
    );
    if (id == null || !mounted) return;
    setState(() => _b = _b.conVino(lugar, id));
  }

  Future<void> _guardar() async {
    setState(() {
      _guardando = true;
      _fallo = null;
    });
    final fallo = await widget.alGuardar(_b.caja);
    if (!mounted) return;
    if (fallo == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _guardando = false;
      _fallo = fallo;
    });
  }

  /// Cada lugar lleno con su estado en la tienda, contando las copias del
  /// mismo vino como las cuenta la tienda.
  List<LugarDeLaCaja?> _lugares(Catalogo catalogo) {
    final llenos = [
      for (final l in _b.lugares)
        if (l != null) l,
    ];
    final estados = lugaresDeLaCaja(
      CajaSugerida(slug: '', nombre: '', productoIds: llenos),
      catalogo,
    );
    var siguiente = 0;
    return [
      for (final l in _b.lugares) l == null ? null : estados[siguiente++],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final catalogo = ref.watch(catalogoProvider).valueOrNull;
    final problema = _b.problema(widget.otras);

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.9,
      child: catalogo == null
          ? const Cargando(que: 'Buscando tus vinos…')
          : ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                16 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              children: [
                Text(
                  widget.inicial.nombre.isEmpty
                      ? textoNuevaCaja
                      : textoCambiarCaja,
                  style: tema.textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nombre,
                  enabled: !_guardando,
                  maxLength: largoDelNombreDeCaja,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: textoNombreDeLaCaja,
                    helperText: textoAyudaDelNombre,
                  ),
                  onChanged: (v) => setState(() => _b = _b.conNombre(v)),
                ),
                for (final (i, lugar) in _lugares(catalogo).indexed)
                  LugarDeLaHoja(
                    numero: i + 1,
                    lugar: lugar,
                    habilitado: !_guardando,
                    alElegir: () => _elegir(i),
                    alVaciar: () => setState(() => _b = _b.sinVino(i)),
                  ),
                const SizedBox(height: 8),
                if (problema != null)
                  Text(
                    textoDelProblema(problema, _b.faltan),
                    style: tema.textTheme.bodyMedium,
                  ),
                if (_fallo case final f?) ...[
                  const SizedBox(height: 8),
                  Aviso(
                    texto: textoDelFalloDeLasCajas(f),
                    tono: TonoDelAviso.error,
                  ),
                ],
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: problema == null && !_guardando ? _guardar : null,
                  child: const Text(textoGuardarCaja),
                ),
              ],
            ),
    );
  }
}
