import 'package:cloud_functions/cloud_functions.dart';

import '../../../core/contratos/stock.dart';
import '../domain/fallo_de_stock.dart';
import '../domain/repositorio_de_stock.dart';
import 'fallos_de_stock.dart';

/// Mover el stock, contra la callable `moverStock` (EP-05, ADR 016).
///
/// **Un solo `try`/`catch` alrededor de la llamada, nunca un `try`/`finally`
/// sin `catch`** (ARQUITECTURA §5.4 regla 4, HU-04.4): el bug de PadelPunilla
/// vivio meses sin un solo reporte porque la excepcion se perdia como error
/// async no manejado.
class RepositorioDeStockFirebase implements RepositorioDeStock {
  RepositorioDeStockFirebase(this._functions);

  final FirebaseFunctions _functions;

  @override
  Future<ResultadoDelMovimiento> mover({
    required String productoId,
    required String idMovimiento,
    required OperacionDeStock operacion,
  }) async {
    final HttpsCallableResult<Object?> resultado;
    try {
      resultado = await _functions.httpsCallable('moverStock').call<Object?>({
        'productoId': productoId,
        'idMovimiento': idMovimiento,
        'operacion': operacion.aJson,
      });
    } catch (e) {
      throw comoFalloDeStock(e);
    }
    return _leer(resultado.data);
  }

  /// Lo que devuelve la callable: `{ antes, despues, repetido }`.
  ///
  /// Una respuesta con otra forma es un [FalloDeStock] `desconocido`, no un
  /// crash: la operacion PUDO haberse aplicado, y la pantalla lo dice en vez
  /// de mostrar una excepcion de tipos.
  ResultadoDelMovimiento _leer(Object? datos) {
    if (datos is Map) {
      final antes = datos['antes'];
      final despues = datos['despues'];
      final repetido = datos['repetido'];
      if (antes is num && despues is num && repetido is bool) {
        return ResultadoDelMovimiento(
          antes: antes.toInt(),
          despues: despues.toInt(),
          repetido: repetido,
        );
      }
    }
    throw const FalloDeStock(
      ErrorDeStock.desconocido,
      codigo: 'respuesta-inesperada',
    );
  }
}
