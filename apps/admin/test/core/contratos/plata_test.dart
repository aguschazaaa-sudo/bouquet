import 'dart:convert';
import 'dart:io';

import 'package:admin/core/contratos/plata.dart';
import 'package:test/test.dart';

/// El formato del precio del panel tiene que ser EL MISMO que el de la
/// vidriera. No es cosmetica: "$12,500.00" y "$ 12.500,00" son dos numeros
/// distintos para quien los lee.
void main() {
  late List casos;

  setUpAll(() {
    final archivo = File('../../packages/contratos/generated/contratos.json');
    final contrato =
        json.decode(archivo.readAsStringSync()) as Map<String, dynamic>;
    casos = (contrato['plata'] as Map<String, dynamic>)['casos'] as List;
  });

  test('el contrato trae fixtures de plata', () {
    // Una lista vacia haria pasar el test de abajo sin comparar nada.
    expect(casos, isNotEmpty);
  });

  test('enPesos da lo mismo que formatearARS', () {
    for (final caso in casos) {
      final c = caso as Map<String, dynamic>;
      expect(
        enPesos(c['centavos'] as int),
        equals(c['ars']),
        reason: 'centavos: ${c['centavos']}',
      );
    }
  });

  test('las fixtures cubren miles, decimales y negativo', () {
    // Sin un monto de mas de mil, una implementacion sin separador de miles
    // pasaria. Sin uno negativo, una que ignora el signo tambien.
    final centavos = casos.map((c) => (c as Map)['centavos'] as int).toList();
    expect(
      centavos.any((c) => c >= 100000),
      isTrue,
      reason: 'falta un monto con miles',
    );
    expect(
      centavos.any((c) => c < 0),
      isTrue,
      reason: 'falta un monto negativo',
    );
  });

  test('el espacio de la cifra es U+00A0 y no la barra espaciadora', () {
    // El caso que una implementacion escrita a ojo se come.
    expect(enPesos(1250000).codeUnitAt(1), equals(0x00A0));
  });
}
