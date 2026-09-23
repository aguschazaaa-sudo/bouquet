import 'dart:convert';
import 'dart:io';

import 'package:admin/core/contratos/stock.dart';
import 'package:test/test.dart';

/// El espejo de `packages/contratos/src/stock.ts`. Compara CONTRA
/// `generated/contratos.json`, no contra si mismo: los casos y sus salidas los
/// CALCULO el TypeScript de hoy.
///
/// Usa package:test y NO flutter_test A PROPOSITO: `flutter test` esta
/// DENEGADO en esta maquina.
void main() {
  late Map<String, dynamic> stock;

  setUpAll(() {
    final archivo = File('../../packages/contratos/generated/contratos.json');
    final contrato =
        json.decode(archivo.readAsStringSync()) as Map<String, dynamic>;
    stock = contrato['stock'] as Map<String, dynamic>;
  });

  test('topeDeStock coincide con el contrato', () {
    expect(topeDeStock, equals(stock['topeDeStock']));
  });

  test('MotivoDeAjuste cubre exactamente los motivos del contrato', () {
    expect(
      MotivoDeAjuste.values.map((m) => m.clave).toList(),
      equals(List<String>.from(stock['motivosDeAjuste'] as List)),
    );
  });

  test('CodigoDeRechazo cubre exactamente los codigos del contrato', () {
    expect(
      CodigoDeRechazo.values.map((c) => c.clave).toList(),
      equals(List<String>.from(stock['codigosDeRechazo'] as List)),
    );
  });

  test(
    'MotivoDeAjuste.desde: una clave desconocida da null, no una por defecto',
    () {
      expect(MotivoDeAjuste.desde('conteo'), MotivoDeAjuste.conteo);
      expect(MotivoDeAjuste.desde('porque-si'), isNull);
      expect(MotivoDeAjuste.desde(null), isNull);
      expect(MotivoDeAjuste.desde(3), isNull);
    },
  );

  group('las fixtures del contrato', () {
    late List casos;

    setUpAll(() {
      casos = stock['casos'] as List;
    });

    test('el contrato trae fixtures', () {
      // Una lista vacia haria pasar el resto sin comparar nada.
      expect(casos, isNotEmpty);
    });

    test('las fixtures tienen las cuatro salidas: aplica, las dos de rechazo y '
        'la invalida', () {
      final salidas = <String>{};
      for (final c in casos.cast<Map<String, dynamic>>()) {
        if (c['valido'] != true) {
          salidas.add('invalido');
        } else {
          final r = c['resultado'] as Map<String, dynamic>;
          salidas.add(r['ok'] == true ? 'aplica' : r['codigo'] as String);
        }
      }
      expect(
        salidas,
        equals({'aplica', 'cambio-el-stock', 'pasa-el-tope', 'invalido'}),
      );
    });

    test('cada caso: la validez y la cuenta dan lo que dijo TypeScript', () {
      var comparados = 0;
      var invalidosPorTipo = 0;

      for (final c in casos.cast<Map<String, dynamic>>()) {
        final porque = c['porque'] as String;
        final operacion = _aDart(c['operacion']);

        // Lo que Dart ni siquiera puede escribir -un texto donde va un
        // numero, una fraccion, un motivo que no existe- es invalido en
        // TypeScript tambien. Es el tipo quien lo frena aca.
        if (operacion == null) {
          expect(c['valido'], isFalse, reason: porque);
          invalidosPorTipo++;
          continue;
        }

        comparados++;
        expect(operacion.esValida, equals(c['valido']), reason: porque);
        if (c['valido'] != true) continue;

        final esperado = c['resultado'] as Map<String, dynamic>;
        final obtenido = aplicarOperacion(c['stock'] as int, operacion);
        if (esperado['ok'] == true) {
          expect(obtenido, isA<Aplica>(), reason: porque);
          expect(
            (obtenido as Aplica).despues,
            esperado['despues'],
            reason: porque,
          );
        } else {
          expect(obtenido, isA<Rechaza>(), reason: porque);
          expect(
            (obtenido as Rechaza).codigo.clave,
            esperado['codigo'],
            reason: porque,
          );
        }
      }

      // Si `_aDart` devolviera null para todo, el bucle "pasaria" sin
      // comparar nada: los dos numeros tienen que ser distintos de cero.
      expect(comparados, greaterThan(8));
      expect(invalidosPorTipo, greaterThan(2));
    });
  });

  group('aJson: lo que viaja a la callable', () {
    test('reponer lleva {tipo, cantidad} y nada mas', () {
      expect(
        const Reponer(6).aJson,
        equals({'tipo': 'reponer', 'cantidad': 6}),
      );
    });

    test('corregir lleva {tipo, visto, valor, motivo} y nada mas', () {
      expect(
        const Corregir(
          visto: 10,
          valor: 7,
          motivo: MotivoDeAjuste.rotura,
        ).aJson,
        equals({
          'tipo': 'corregir',
          'visto': 10,
          'valor': 7,
          'motivo': 'rotura',
        }),
      );
    });
  });
}

/// De lo que trae el JSON a lo que Dart puede escribir, o `null` si el tipo
/// mismo lo impide.
OperacionDeStock? _aDart(Object? json) {
  if (json is! Map) return null;
  final tipo = json['tipo'];
  if (tipo == 'reponer') {
    final cantidad = json['cantidad'];
    return cantidad is int ? Reponer(cantidad) : null;
  }
  if (tipo == 'corregir') {
    final visto = json['visto'];
    final valor = json['valor'];
    final motivo = MotivoDeAjuste.desde(json['motivo']);
    if (visto is int && valor is int && motivo != null) {
      return Corregir(visto: visto, valor: valor, motivo: motivo);
    }
  }
  return null;
}
