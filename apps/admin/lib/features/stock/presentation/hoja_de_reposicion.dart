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
import 'textos_del_stock.dart';

/// Cargar mercaderia cuando entra (HU-05.1, Workflow D).
///
/// Suma; no fija. Por eso **no pide confirmar**: una reposicion equivocada se
/// arregla con una correccion, y el numero de "Va a quedar en" se ve antes de
/// apretar (poca burocracia: se confirma lo que no tiene vuelta atras).
///
/// Devuelve el stock que quedo, o `null` si se cerro sin cargar. Quien la abre
/// avisa el resultado: la hoja se cierra apenas guarda.
class HojaDeReposicion extends ConsumerStatefulWidget {
  const HojaDeReposicion({
    super.key,
    required this.productoId,
    required this.nombre,
    required this.stock,
    required this.botellas,
  });

  final String productoId;
  final String nombre;

  /// El stock que el operador tenia en pantalla al abrirla.
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
      builder: (_) => HojaDeReposicion(
        productoId: productoId,
        nombre: nombre,
        stock: stock,
        botellas: botellas,
      ),
    );
  }

  @override
  ConsumerState<HojaDeReposicion> createState() => _HojaDeReposicionState();
}

class _HojaDeReposicionState extends ConsumerState<HojaDeReposicion> {
  final _escrito = TextEditingController();

  /// La clave de idempotencia: **UNA por hoja, y no se regenera nunca**.
  ///
  /// Tras un error ambiguo -un timeout, con la transaccion ya commiteada- el
  /// id TIENE que ser el mismo: si el operador corrige la cantidad y reintenta,
  /// la callable contesta `already-exists` en vez de sumar dos veces. Tras un
  /// rechazo definitivo no quedo marcador, asi que reusarlo no hace dano. Un
  /// id nuevo por cada cambio de cantidad -como esta hoja hizo primero- suma
  /// dos veces justo cuando el operador mas duda (hallazgo 2 de
  /// `revisor-pagos`, ADR 016).
  final String _idDelMovimiento = nuevoIdDeMovimiento();

  bool _guardando = false;
  FalloDeStock? _fallo;

  @override
  void dispose() {
    _escrito.dispose();
    super.dispose();
  }

  int? get _cantidad => leerCantidad(_escrito.text);

  bool get _sePuedeCargar {
    final n = _cantidad;
    return !_guardando &&
        n != null &&
        Reponer(n).esValida &&
        aplicarOperacion(widget.stock, Reponer(n)) is Aplica;
  }

  Future<void> _cargar() async {
    final n = _cantidad;
    if (!_sePuedeCargar || n == null) return;

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
            operacion: Reponer(n),
          );
      if (mounted) Navigator.of(context).pop(r.despues);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _guardando = false;
        _fallo = e is FalloDeStock
            ? e
            : const FalloDeStock(ErrorDeStock.desconocido);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final n = _cantidad;
    final problema = avisoDeReposicion(widget.stock, n, escrito: _escrito.text);
    final queda = problema == null
        ? comoQuedaAlReponer(widget.stock, n, botellas: widget.botellas)
        : null;
    final unidad = unidadDeVenta(widget.botellas);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              EncabezadoDeHoja(
                titulo: 'Cargar mercadería',
                nombre: widget.nombre,
              ),
              const SizedBox(height: 18),
              CampoDeCantidad(
                controlador: _escrito,
                etiqueta: '¿Cuántas $unidad entraron?',
                ayuda:
                    'Hoy hay '
                    '${describirElStock(widget.stock, botellas: widget.botellas)}.',
                problema: problema,
                habilitado: !_guardando,
                alEnviar: _sePuedeCargar ? _cargar : null,
                alCambiar: (_) => setState(() => _fallo = null),
              ),
              if (queda != null) ...[
                const SizedBox(height: 10),
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
                onPressed: _sePuedeCargar ? _cargar : null,
                child: Text(_guardando ? 'Cargando…' : 'Cargar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
