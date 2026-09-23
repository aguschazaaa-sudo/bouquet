import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/contratos/stock.dart';
import '../../../core/presentation/aviso.dart';
import '../domain/cantidad_escrita.dart';
import '../domain/fallo_de_stock.dart';
import '../domain/id_de_movimiento.dart';
import '../stock_providers.dart';
import 'campo_de_cantidad.dart';
import 'encabezado_de_hoja.dart';
import 'selector_de_motivo.dart';
import 'textos_del_stock.dart';

/// Corregir el stock despues de contar el deposito (HU-05.2, Workflow D).
///
/// **Fija un valor, y un valor absoluto pisa las ventas del medio.** Por eso
/// lleva [stock] -lo que el operador tenia en pantalla al abrirla, que es lo
/// que conto contra- y la callable lo rechaza si ya no es ese. Cuando lo
/// rechaza, esta hoja muestra el numero de AHORA, vacia el campo y pide contar
/// de nuevo: reintentar el mismo valor a ciegas es justo lo que el rechazo
/// evita.
///
/// El motivo se elige de una lista corta con un toque, no se escribe (poca
/// burocracia).
///
/// Devuelve el stock que quedo, o `null` si se cerro sin guardar.
class HojaDeCorreccion extends ConsumerStatefulWidget {
  const HojaDeCorreccion({
    super.key,
    required this.productoId,
    required this.nombre,
    required this.stock,
    required this.botellas,
  });

  final String productoId;
  final String nombre;
  final int stock;
  final int botellas;

  static Future<int?> mostrar(
    BuildContext context, {
    required String productoId,
    required String nombre,
    required int stock,
    required int botellas,
  }) {
    return showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (_) => HojaDeCorreccion(
        productoId: productoId,
        nombre: nombre,
        stock: stock,
        botellas: botellas,
      ),
    );
  }

  @override
  ConsumerState<HojaDeCorreccion> createState() => _HojaDeCorreccionState();
}

class _HojaDeCorreccionState extends ConsumerState<HojaDeCorreccion> {
  final _escrito = TextEditingController();
  late int _visto = widget.stock;
  MotivoDeAjuste _motivo = MotivoDeAjuste.conteo;

  /// La clave de idempotencia: UNA por hoja, sin regenerarla (ver
  /// `HojaDeReposicion`). Aca ademas `visto` ataja lo que un id repetido no:
  /// si la correccion anterior SI se aplico, el stock ya no es `visto` y la
  /// callable la rechaza en vez de pisar.
  final String _idDelMovimiento = nuevoIdDeMovimiento();

  bool _guardando = false;
  FalloDeStock? _fallo;

  @override
  void dispose() {
    _escrito.dispose();
    super.dispose();
  }

  int? get _valor => leerCantidad(_escrito.text);

  Corregir? get _operacion {
    final n = _valor;
    if (n == null) return null;
    return Corregir(visto: _visto, valor: n, motivo: _motivo);
  }

  bool get _sePuedeGuardar => !_guardando && (_operacion?.esValida ?? false);

  Future<void> _guardar() async {
    final operacion = _operacion;
    if (!_sePuedeGuardar || operacion == null) return;

    setState(() {
      _guardando = true;
      _fallo = null;
    });
    // ⚠️ `try/catch`, no `try/finally` (HU-04.4).
    try {
      final r = await ref
          .read(repositorioDeStockProvider)
          .mover(
            productoId: widget.productoId,
            idMovimiento: _idDelMovimiento,
            operacion: operacion,
          );
      if (mounted) Navigator.of(context).pop(r.despues);
    } catch (e) {
      if (!mounted) return;
      final fallo = e is FalloDeStock
          ? e
          : const FalloDeStock(ErrorDeStock.desconocido);
      setState(() {
        _guardando = false;
        _fallo = fallo;
        // El stock cambio mientras contaba: lo que conto ya no es contra lo
        // que hay. Se parte de cero con el numero de ahora.
        if (fallo.error == ErrorDeStock.cambioElStock && fallo.actual != null) {
          _visto = fallo.actual!;
          _escrito.clear();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final valor = _valor;
    final problema = avisoDeCorreccion(_visto, valor, escrito: _escrito.text);
    final queda = problema == null
        ? comoQuedaAlCorregir(_visto, valor, botellas: widget.botellas)
        : null;
    final unidad = unidadDeVenta(widget.botellas);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EncabezadoDeHoja(
                titulo: 'Corregir el stock',
                nombre: widget.nombre,
              ),
              const SizedBox(height: 18),
              CampoDeCantidad(
                controlador: _escrito,
                etiqueta: '¿Cuántas $unidad hay en el depósito?',
                ayuda:
                    'Hoy figuran '
                    '${describirElStock(_visto, botellas: widget.botellas)}.',
                problema: problema,
                habilitado: !_guardando,
                alEnviar: _sePuedeGuardar ? _guardar : null,
                alCambiar: (_) => setState(() => _fallo = null),
              ),
              const SizedBox(height: 16),
              SelectorDeMotivo(
                motivo: _motivo,
                habilitado: !_guardando,
                alCambiar: (m) => setState(() => _motivo = m),
              ),
              if (queda != null) ...[
                const SizedBox(height: 12),
                Text(queda, style: Theme.of(context).textTheme.bodyMedium),
              ],
              if (_fallo case final fallo?) ...[
                const SizedBox(height: 14),
                Aviso(
                  texto: textoDelFalloDeStock(fallo),
                  tono: TonoDelAviso.error,
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _sePuedeGuardar ? _guardar : null,
                child: Text(_guardando ? 'Guardando…' : 'Guardar el conteo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
