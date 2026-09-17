/// El espejo en Dart de `formatearARS` de `packages/contratos/src/dinero.ts`.
///
/// **Por que se escribe y no se usa `intl`:** el contrato no es "algun formato
/// de moneda argentino", es **exactamente** lo que muestra la vidriera. Con
/// `NumberFormat` eso depende de los datos de locale que traiga la version de
/// `intl` que resuelva pub ese dia, y una diferencia ahi no se ve al mirar:
/// se ve cuando alguien compara el precio del panel con el de la tienda.
/// Escrito aca, `test/core/contratos/plata_test.dart` lo compara contra las
/// fixtures que calculo el TypeScript, y eso es una unidad externa.
///
/// ⚠️ **El espacio entre el signo y la cifra es U+00A0, no la barra
/// espaciadora.** Es lo que emite `Intl.NumberFormat('es-AR')`, se midió
/// —`24 a0 31 32 ...`— y una implementacion escrita a ojo pone el otro.
library;

/// El espacio duro que va entre `$` y la cifra en es-AR.
const espacioDeLaCifra = ' ';

/// Centavos enteros a lo que ve el comprador: `1250000` da `$ 12.500,00`.
///
/// Negativo lleva el signo **antes** del `$`, igual que la vidriera. Todavia
/// no hay ningun monto negativo en el panel; lo va a haber con el primer
/// reembolso, y el formato ya esta decidido en vez de improvisarse ese dia.
String enPesos(int centavos) {
  final abs = centavos.abs();
  final enteros = _conSeparadorDeMiles(abs ~/ 100);
  final decimales = (abs % 100).toString().padLeft(2, '0');
  final signo = centavos < 0 ? '-' : '';
  return '$signo\$$espacioDeLaCifra$enteros,$decimales';
}

/// Punto cada tres digitos, de derecha a izquierda.
String _conSeparadorDeMiles(int entero) {
  final digitos = entero.toString();
  final salida = StringBuffer();
  for (var i = 0; i < digitos.length; i++) {
    if (i > 0 && (digitos.length - i) % 3 == 0) salida.write('.');
    salida.write(digitos[i]);
  }
  return salida.toString();
}
