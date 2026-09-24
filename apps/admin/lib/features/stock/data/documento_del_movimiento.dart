/// El documento de un movimiento, leído **sin Firebase adentro**.
///
/// Vive aparte del repositorio para que `dart test` lo pueda cargar:
/// `cloud_firestore` arrastra Flutter. La hora llega ya convertida.
library;

import '../../../core/contratos/stock.dart';
import '../domain/movimiento_de_stock.dart';

/// Nunca lanza y nunca descarta: un documento de una forma rara se muestra
/// como un movimiento sin detalle, no desaparece de la lista (un movimiento
/// que se ve mal es un dato; uno que falta es un misterio).
MovimientoDeStock movimientoDesde(
  String id,
  Map<String, Object?> datos, {
  required DateTime? en,
  required String? miUid,
}) {
  final por = datos['por'];
  return MovimientoDeStock(
    id: id,
    en: en,
    antes: _entero(datos['antes']),
    despues: _entero(datos['despues']),
    operacion: _operacion(datos['operacion']),
    esMio: miUid != null && por == miUid,
  );
}

/// `NaN` e `Infinity` existen en Firestore y `toInt()` **lanza** con ellos: un
/// solo documento así ocultaría la lista entera.
int? _entero(Object? valor) =>
    valor is num && valor.isFinite ? valor.toInt() : null;

OperacionDeStock? _operacion(Object? valor) {
  if (valor is! Map) return null;
  switch (valor['tipo']) {
    case 'reponer':
      final cantidad = _entero(valor['cantidad']);
      return cantidad == null ? null : Reponer(cantidad);
    case 'corregir':
      final visto = _entero(valor['visto']);
      final nuevo = _entero(valor['valor']);
      final motivo = MotivoDeAjuste.desde(valor['motivo']);
      if (visto == null || nuevo == null || motivo == null) return null;
      return Corregir(visto: visto, valor: nuevo, motivo: motivo);
    default:
      return null;
  }
}
