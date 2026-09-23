/// Lo que se escribio en un campo de cantidad, como entero, o `null` si no es
/// una cantidad.
///
/// Solo digitos, con el punto de miles de es-AR permitido (`1.500`): quien lo
/// escribe asi no cometio un error. **No acepta** decimales, signos ni
/// espacios en el medio: `1,5` no es una cantidad de botellas, y adivinar que
/// quiso decir es exactamente lo que no se hace con el stock.
///
/// Vacio tambien devuelve `null`: la pantalla lo distingue de un texto malo
/// mirando el texto mismo (`avisoDeReposicion` y `avisoDeCorreccion` no
/// dicen nada mientras no haya nada escrito).
int? leerCantidad(String escrito) {
  final texto = escrito.trim();
  if (!_digitos.hasMatch(texto)) return null;
  final n = int.tryParse(texto.replaceAll('.', ''));
  return n;
}

/// `1234`, o `1.234` con el punto en su lugar. `1.23` y `12.345.6` no.
final _digitos = RegExp(r'^(\d{1,3}(?:\.\d{3})+|\d+)$');
