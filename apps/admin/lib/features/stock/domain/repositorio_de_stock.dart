import '../../../core/contratos/stock.dart';

/// Lo que devolvio la callable `moverStock`.
class ResultadoDelMovimiento {
  const ResultadoDelMovimiento({
    required this.antes,
    required this.despues,
    required this.repetido,
  });

  /// El stock antes del movimiento, en unidades de venta.
  final int antes;

  /// El stock que quedo.
  final int despues;

  /// `true` si este movimiento ya estaba aplicado y no se toco nada: un
  /// reintento (un timeout, un doble toque) que la callable reconocio por su
  /// `idMovimiento`. Para el operador es un exito igual.
  final bool repetido;
}

/// Mover el stock de un vino: reponer y corregir (EP-05, ADR 016).
///
/// **El panel NO escribe `stock`**: las reglas de Firestore lo congelan
/// (ADR 008 §1). Esto llama a la callable del servidor, que lo hace adentro
/// de una transaccion con un marcador de idempotencia.
///
/// Lanza [FalloDeStock] -- nunca otra cosa, nunca en silencio (HU-04.4: un
/// fallo que no llega a la pantalla es un fallo que nadie reporta).
abstract interface class RepositorioDeStock {
  /// [idMovimiento] es la clave de idempotencia: el mismo id con la misma
  /// operacion dos veces es UN movimiento. Nace al abrir la hoja
  /// (`nuevoIdDeMovimiento`) y vale para TODOS los intentos de esa hoja: con
  /// otra operacion y el mismo id la callable contesta `already-exists`.
  Future<ResultadoDelMovimiento> mover({
    required String productoId,
    required String idMovimiento,
    required OperacionDeStock operacion,
  });
}
