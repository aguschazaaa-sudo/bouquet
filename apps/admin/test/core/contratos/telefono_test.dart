import 'dart:convert';
import 'dart:io';

import 'package:admin/core/contratos/telefono.dart';
import 'package:test/test.dart';

/// El panel le muestra al operador como quedo el numero que pego del chat, y
/// el servidor guarda el que sale de `normalizarTelefonoAR` en TypeScript. **Este
/// test es lo que hace que el espejo no sea una segunda implementacion**: corre
/// las fixtures que calculo el TypeScript.
///
/// Es teatro si el JSON esta viejo: `scripts/ci/auditar_estados.mjs` verifica
/// que `contratos.json` sea lo que produce hoy `envio.ts`, y que estas
/// fixtures tengan los dos lados (uno que se normaliza y uno que no).
void main() {
  late List<dynamic> casos;

  setUpAll(() {
    final archivo = File('../../packages/contratos/generated/contratos.json');
    final contrato =
        json.decode(archivo.readAsStringSync()) as Map<String, dynamic>;
    casos = (contrato['pedido'] as Map<String, dynamic>)['telefonos'] as List;
  });

  test('el contrato trae fixtures de telefono, de los dos lados', () {
    // Control de la MEDICION: una lista vacia haria pasar el test de abajo sin
    // comparar nada, y sin un `null` una implementacion que acepta todo pasa.
    expect(casos, isNotEmpty);
    expect(casos.any((c) => (c as Map)['e164'] != null), isTrue);
    expect(casos.any((c) => (c as Map)['e164'] == null), isTrue);
  });

  test('normalizarTelefonoAR da lo mismo que el TypeScript', () {
    for (final caso in casos) {
      final c = caso as Map<String, dynamic>;
      expect(
        normalizarTelefonoAR(c['entrada'] as String),
        equals(c['e164']),
        reason: 'entrada: "${c['entrada']}"',
      );
    }
  });

  test('un numero pegado del chat con el 15 queda normalizado', () {
    expect(normalizarTelefonoAR('0351 15-555-1234'), '+5493515551234');
    expect(normalizarTelefonoAR('351 15 555 1234'), '+5493515551234');
  });

  test('uno incompleto no se normaliza', () {
    expect(normalizarTelefonoAR('12345678'), isNull);
    expect(normalizarTelefonoAR(''), isNull);
  });
}
