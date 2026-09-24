import '../../../core/contratos/stock.dart';
import '../domain/movimiento_de_stock.dart';
import 'textos_del_stock.dart';

// Los textos de la lista de movimientos (HU-05.4). Los lee la familia, no el
// comprador: no pasan por `voz`. Funciones puras, sin Flutter: se prueban con
// `dart test`.

const textoTituloDeMovimientos = 'Movimientos';
const textoVerMovimientos = 'Ver los últimos movimientos';
const textoSinMovimientos =
    'Todavía no hay movimientos: el stock no se cargó ni se corrigió desde el '
    'panel.';
const textoNoSePudieronLeer =
    'No pudimos leer los movimientos. Puede ser la conexión, o que tu cuenta '
    'no tenga permiso.';

/// Qué se hizo, en una frase. La unidad es la de venta del vino.
///
///   `Cargó 32 botellas` · `Cargó 2 cajas de 6` · `Corrigió el stock (conteo)`
String queSeHizo(MovimientoDeStock m, {required int botellas}) {
  // Una venta no es una operacion que el operador pida: se dice aparte.
  final venta = m.venta;
  if (venta != null) {
    final numero = venta.numero == null ? '' : ' (pedido ${venta.numero})';
    return 'Se vendió ${_unidades(venta.cantidad, botellas)}$numero';
  }
  final operacion = m.operacion;
  return switch (operacion) {
    Reponer(:final cantidad) => 'Cargó ${_unidades(cantidad, botellas)}',
    Corregir(:final motivo) =>
      'Corrigió el stock (${rotuloDelMotivo(motivo).toLowerCase()})',
    null => 'Movimiento de stock',
  };
}

/// De cuánto a cuánto, **con la unidad**: `de 0 a 32 botellas`, `de 8 a 10
/// cajas`. Sin ella, "de 8 a 10" en un vino de caja de 6 se lee como 10
/// botellas cuando son 60. `null` si el documento no trae los dos números.
String? deCuantoACuanto(MovimientoDeStock m, {required int botellas}) {
  final antes = m.antes;
  final despues = m.despues;
  if (antes == null || despues == null) return null;
  final unidad = botellas <= 1
      ? (despues == 1 ? 'botella' : 'botellas')
      : (despues == 1 ? 'caja' : 'cajas');
  return 'de $antes a $despues $unidad';
}

String _unidades(int n, int botellas) {
  if (botellas <= 1) return n == 1 ? '1 botella' : '$n botellas';
  return '${n == 1 ? '1 caja' : '$n cajas'} de $botellas';
}

/// Quién: `Vos` o `Otra persona`. El movimiento guarda un uid, no un nombre.
String quien(MovimientoDeStock m) => m.esMio ? 'Vos' : 'Otra persona';

/// Cuándo, en hora de quien mira: `hoy 21:04`, `ayer 21:04`, `24/09 21:04`
/// (con el año si no es el actual). [en] y [ahora] tienen que venir en la
/// misma zona.
String cuando(DateTime? en, {required DateTime ahora}) {
  if (en == null) return 'sin fecha';
  final hora = '${_dos(en.hour)}:${_dos(en.minute)}';
  final dia = DateTime(en.year, en.month, en.day);
  final hoy = DateTime(ahora.year, ahora.month, ahora.day);
  final diferencia = hoy.difference(dia).inDays;
  if (diferencia == 0) return 'hoy $hora';
  if (diferencia == 1) return 'ayer $hora';
  final fecha = '${_dos(en.day)}/${_dos(en.month)}';
  return en.year == ahora.year ? '$fecha $hora' : '$fecha/${en.year} $hora';
}

String _dos(int n) => n.toString().padLeft(2, '0');
