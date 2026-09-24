import 'movimiento_de_stock.dart';

/// Leer los movimientos de stock de un vino (HU-05.4).
abstract interface class RepositorioDeMovimientos {
  /// Los últimos [cuantos] movimientos de [productoId], **el más nuevo
  /// primero**. Nunca sin límite: la colección crece sin fin, no se borra
  /// nada, y las reglas rechazan una lectura sin `limit` (ADR 016 §6).
  ///
  /// Cuesta [cuantos] lecturas como máximo, cada vez que se abre la lista.
  /// Lanza si no se pudo leer: una lista vacía es "todavía no hay
  /// movimientos", y un error no puede parecerse a eso.
  Future<List<MovimientoDeStock>> ultimos(
    String productoId, {
    int cuantos = topeDeMovimientos,
  });
}

/// Cuántos se piden por vez. Las reglas aceptan hasta 50.
const topeDeMovimientos = 20;
