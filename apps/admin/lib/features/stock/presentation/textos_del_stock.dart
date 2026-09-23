import '../../../core/contratos/stock.dart';
import '../domain/fallo_de_stock.dart';

// Los textos de mover el stock, en la voz del panel: claros, sin jerga, para
// gente que no es tecnica (overview del panel). Son cadenas de una pantalla
// que ve el operador, no el comprador: no pasan por `voz`.
//
// Son funciones puras de Dart, sin Flutter, a proposito: se prueban con
// `dart test`, y "cuanto es 4 cajas de 6" no puede depender de un widget.

/// El stock dicho con su unidad. **La unidad de venta manda**: una botella
/// suelta se cuenta en botellas y una caja en cajas, y "sumar 6" a una caja
/// de 2 son doce botellas (glosario, EP-05 HU-05.1).
///
///   `10 botellas` · `1 botella` · `4 cajas de 6 · 24 botellas`
String describirElStock(int stock, {required int botellas}) {
  if (botellas <= 1) return _botellas(stock);
  final cajas = stock == 1 ? '1 caja' : '$stock cajas';
  return '$cajas de $botellas · ${_botellas(stock * botellas)}';
}

String _botellas(int n) => n == 1 ? '1 botella' : '$n botellas';

/// La unidad, para preguntar: "botellas" o "cajas de 6".
String unidadDeVenta(int botellas) =>
    botellas <= 1 ? 'botellas' : 'cajas de $botellas';

/// El maximo, con el punto de miles de es-AR.
final String _tope = _conMiles(topeDeStock);

String _conMiles(int n) {
  final digitos = n.toString();
  final sb = StringBuffer();
  for (var i = 0; i < digitos.length; i++) {
    if (i > 0 && (digitos.length - i) % 3 == 0) sb.write('.');
    sb.write(digitos[i]);
  }
  return sb.toString();
}

/// Lo que se ve si se sumaran [cantidad] unidades, o `null` si no se puede
/// contar (cantidad no valida, o pasa el maximo -- eso lo dice
/// [avisoDeReposicion]).
String? comoQuedaAlReponer(int stock, int? cantidad, {required int botellas}) {
  if (cantidad == null) return null;
  final r = aplicarOperacion(stock, Reponer(cantidad));
  if (!Reponer(cantidad).esValida || r is! Aplica) return null;
  return 'Va a quedar en ${describirElStock(r.despues, botellas: botellas)}.';
}

/// Por que no se puede reponer lo escrito, o `null` si se puede.
///
/// Escrito y vacio no es un problema todavia: la pantalla espera.
String? avisoDeReposicion(int stock, int? cantidad, {required String escrito}) {
  if (escrito.trim().isEmpty) return null;
  if (cantidad == null) return 'Escribí solo el número, sin comas ni letras.';
  if (cantidad < 1) return 'La cantidad tiene que ser mayor que cero.';
  if (cantidad > topeDeStock) {
    return 'El máximo por carga es $_tope.';
  }
  if (aplicarOperacion(stock, Reponer(cantidad)) is Rechaza) {
    return 'Con eso pasarías el máximo de $_tope. Hoy hay $stock.';
  }
  return null;
}

/// Lo que se ve si el stock pasa a [valor]: "Pasa de 10 a 7 (−3)."
String? comoQuedaAlCorregir(int visto, int? valor, {required int botellas}) {
  if (valor == null || valor == visto) return null;
  final diferencia = valor - visto;
  final signo = diferencia > 0 ? '+' : '−';
  return 'Pasa de ${describirElStock(visto, botellas: botellas)} a '
      '${describirElStock(valor, botellas: botellas)} '
      '($signo${diferencia.abs()}).';
}

/// Por que no se puede corregir a lo escrito, o `null` si se puede.
String? avisoDeCorreccion(int visto, int? valor, {required String escrito}) {
  if (escrito.trim().isEmpty) return null;
  if (valor == null) return 'Escribí solo el número, sin comas ni letras.';
  if (valor < 0) return 'No puede haber menos de cero.';
  if (valor > topeDeStock) return 'El máximo es $_tope.';
  if (valor == visto) return 'Ya figura ese número. No hay nada que corregir.';
  return null;
}

/// El motivo, en una palabra, para el selector de un toque.
String rotuloDelMotivo(MotivoDeAjuste motivo) => switch (motivo) {
  MotivoDeAjuste.conteo => 'Conteo',
  MotivoDeAjuste.rotura => 'Rotura',
  MotivoDeAjuste.otro => 'Otro',
};

/// El fallo, en palabras. Nunca el codigo crudo: eso va al log.
///
/// `sinConexion` **no dice "no se guardó"**, porque puede haberse guardado y
/// haberse perdido la respuesta. Decir lo contrario manda a reponer dos veces.
String textoDelFalloDeStock(FalloDeStock fallo) => switch (fallo.error) {
  ErrorDeStock.sinPermiso =>
    'Tu cuenta no tiene permiso para mover el stock. Si te lo dieron hace '
        'un rato, salí y volvé a entrar.',
  ErrorDeStock.sinConexion =>
    'No llegó la respuesta. Puede que ya se haya guardado: mirá el stock de '
        'arriba antes de volver a intentar.',
  ErrorDeStock.cambioElStock =>
    fallo.actual == null
        ? 'Mientras contabas, el stock cambió. Volvé a contar.'
        : 'Mientras contabas, el stock cambió: ahora figuran ${fallo.actual}. '
              'Volvé a contar.',
  ErrorDeStock.pasaElTope =>
    fallo.actual == null
        ? 'Con eso pasarías el máximo de $_tope.'
        : 'Con eso pasarías el máximo de $_tope. Hoy hay ${fallo.actual}.',
  ErrorDeStock.noSePuede =>
    'Este vino no lleva stock propio, o su stock está mal cargado. No se '
        'puede mover desde acá.',
  ErrorDeStock.noExiste => 'Ese vino ya no existe.',
  ErrorDeStock.yaEstaHecho =>
    'Ese movimiento ya se había registrado. Mirá el stock de arriba antes de '
        'volver a intentar.',
  ErrorDeStock.desconocido =>
    'No pudimos guardar el movimiento. Probá de nuevo; si sigue igual, '
        'avisale a quien arma el panel.',
};
