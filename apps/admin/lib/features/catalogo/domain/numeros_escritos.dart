/// Leer un numero **escrito por una persona**: el precio en pesos y la
/// graduacion en grados. ADR 013 §3.
///
/// **Se lee como texto, nunca con `double.parse(x) * 100`:** `1.005 * 100`
/// da `100.49999999999999`, y redondear eso pierde un centavo en silencio
/// para siempre (lo documenta `packages/contratos/src/dinero.ts`).
///
/// **No es `desdePesos` de `contratos`, a proposito.** Aquel acepta `19.99`
/// como diecinueve con noventa y nueve —el punto decimal de un archivo o de
/// un script—, y un operador argentino escribe `12.500` para doce mil
/// quinientos. Nadie mas que el panel lee un precio tipeado por una persona,
/// asi que esto no es una segunda implementacion de nada.
library;

import '../../../core/contratos/producto.dart';

/// Lo que salio de leer un texto: un entero, nada escrito, o el motivo por el
/// que no se pudo leer — dicho para quien lo escribio, no para un log.
final class Lectura {
  const Lectura.valor(int this.valor) : problema = null;
  const Lectura.problema(String this.problema) : valor = null;
  const Lectura.vacia() : valor = null, problema = null;

  final int? valor;
  final String? problema;

  bool get estaVacia => valor == null && problema == null;

  @override
  String toString() => estaVacia
      ? 'Lectura.vacia'
      : valor != null
      ? 'Lectura.valor($valor)'
      : 'Lectura.problema($problema)';
}

/// Hasta 999.999.999 pesos. Mas que eso no es el precio de un vino: es un
/// dedo apoyado en una tecla, y en centavos se acerca al borde de lo que un
/// `number` de JavaScript representa exacto.
const _digitosMaximosDePesos = 9;

/// Puntos de miles en grupos de tres, o ninguno; la coma, y hasta dos
/// decimales despues.
final _pesos = RegExp(r'^(\d{1,3}(?:\.\d{3})+|\d+)(?:,(\d{1,2}))?$');

/// Un punto con uno o dos digitos al final: `12.50`, `12.5`.
final _puntoDecimal = RegExp(r'^\d+\.\d{1,2}$');

final _masDeDosDecimales = RegExp(r'^[\d.]+,\d{3,}$');

/// El precio, en **centavos**. Acepta `12500`, `12.500`, `12.500,50`,
/// `12500,5` y lo mismo con `$` adelante —el formato que muestra la vidriera,
/// espacio duro incluido, para que pegar un precio de la tienda funcione—.
///
/// ⚠️ **`12.50` no se adivina.** Puede ser doce con cincuenta escrito con
/// punto, o doce mil quinientos con un cero que se perdio. Elegir una de las
/// dos es arriesgar un precio mil veces mas alto o mas bajo; se pregunta.
///
/// Cero se lee como cero: que el precio tenga que ser mayor que cero lo
/// decide quien pregunta, no el parser.
Lectura leerPesos(String escrito) {
  var t = escrito.trim();
  if (t.startsWith(r'$')) t = t.substring(1).trim();
  if (t.isEmpty) return const Lectura.vacia();

  if (t.startsWith('-')) {
    return const Lectura.problema('El precio no puede ser negativo.');
  }
  if (_puntoDecimal.hasMatch(t)) {
    final (enteros, decimales) = _partir(t, '.');
    return Lectura.problema(
      '¿$enteros,${decimales.padRight(2, '0')} o '
      '${_conMiles(enteros + decimales.padRight(3, '0'))}? '
      'Los centavos van después de una coma.',
    );
  }
  if (_masDeDosDecimales.hasMatch(t)) {
    return const Lectura.problema(
      'Hasta dos decimales, después de la coma: 12.500,50.',
    );
  }

  final m = _pesos.firstMatch(t);
  if (m == null) {
    return const Lectura.problema(
      'No parece un precio. Escribilo así: 12.500 o 12.500,50.',
    );
  }
  final enteros = m.group(1)!.replaceAll('.', '');
  final decimales = (m.group(2) ?? '').padRight(2, '0');
  final sinCeros = enteros.replaceFirst(RegExp(r'^0+(?=\d)'), '');
  if (sinCeros.length > _digitosMaximosDePesos) {
    return const Lectura.problema('Es un precio demasiado alto.');
  }
  return Lectura.valor(int.parse(sinCeros) * 100 + int.parse(decimales));
}

/// Hasta tres digitos antes del decimal, para que `135` —el que se confundio
/// de unidad— llegue al chequeo de rango y reciba ESE mensaje, y no "no es
/// una graduacion".
final _grados = RegExp(r'^(\d{1,3})(?:[.,](\d))?$');
final _gradosConDosDecimales = RegExp(r'^\d{1,3}[.,]\d{2,}$');

/// La graduacion, en **decimas** de grado: `13,5` da `135`. Acepta coma o
/// punto —aca no hay miles que confundir— y un `%` al final.
///
/// Fuera de `graduacionMinima`..`graduacionMaxima` se rechaza: el piso no
/// describe a los vinos, atrapa la unidad equivocada (`core/contratos/producto.dart`).
Lectura leerGraduacion(String escrito) {
  var t = escrito.trim();
  if (t.endsWith('%')) t = t.substring(0, t.length - 1).trim();
  if (t.isEmpty) return const Lectura.vacia();

  if (_gradosConDosDecimales.hasMatch(t)) {
    return const Lectura.problema(
      'Con un decimal alcanza: la etiqueta dice 13,5 y no 13,55.',
    );
  }
  final m = _grados.firstMatch(t);
  if (m == null) {
    return const Lectura.problema(
      'No parece una graduación. Escribila así: 13,5.',
    );
  }
  final decimas = int.parse(m.group(1)!) * 10 + int.parse(m.group(2) ?? '0');
  if (decimas < graduacionMinima || decimas > graduacionMaxima) {
    return Lectura.problema(
      'Va en grados, entre ${graduacionMinima ~/ 10} y '
      '${graduacionMaxima ~/ 10}: por ejemplo 13,5.',
    );
  }
  return Lectura.valor(decimas);
}

/// El texto con que el formulario muestra un precio guardado: `1250000` da
/// `12.500` y `1250050` da `12.500,50`. Lo que devuelve, [leerPesos] lo lee
/// de vuelta al mismo numero — y eso tiene test.
String pesosParaEscribir(int centavos) {
  final enteros = _conMiles('${centavos ~/ 100}');
  final resto = centavos % 100;
  return resto == 0 ? enteros : '$enteros,${resto.toString().padLeft(2, '0')}';
}

/// `135` da `13,5`; `140` da `14`. La vuelta de [leerGraduacion].
String graduacionParaEscribir(int decimas) {
  final resto = decimas % 10;
  return resto == 0 ? '${decimas ~/ 10}' : '${decimas ~/ 10},$resto';
}

(String, String) _partir(String t, String separador) {
  final i = t.indexOf(separador);
  return (t.substring(0, i), t.substring(i + 1));
}

String _conMiles(String digitos) {
  final salida = StringBuffer();
  for (var i = 0; i < digitos.length; i++) {
    if (i > 0 && (digitos.length - i) % 3 == 0) salida.write('.');
    salida.write(digitos[i]);
  }
  return salida.toString();
}
