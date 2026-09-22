import 'dart:convert';
import 'dart:io';

import 'package:admin/core/contratos/catalogo_publico.dart';
import 'package:test/test.dart';

/// El espejo de `balde`, `tope` y las clases de descarte de
/// `packages/contratos/src/producto.ts`. Compara CONTRA
/// `generated/contratos.json`, no contra si mismo: "la unidad externa es el
/// JSON, no el Dart" (design.md de `panel-publicar-un-vino`, Decision #2).
///
/// La comparacion de los MOTIVOS de descarte, documento por documento —o sea
/// que la clasificacion de `domain/en_la_tienda.dart` coincide con lo que
/// `armarCatalogo` hizo de verdad— esta en
/// `test/features/catalogo/en_la_tienda_test.dart`. Aca solo se verifica
/// `balde()`, `tope()` y que la LISTA de clases sea exactamente la misma:
/// ese test no puede llamar a `armarCatalogo`, que no existe en Dart.
///
/// Usa package:test y NO flutter_test A PROPOSITO: `flutter test` esta
/// DENEGADO en esta maquina.
void main() {
  late Map<String, dynamic> catalogo;

  setUpAll(() {
    final archivo = File('../../packages/contratos/generated/contratos.json');
    final contrato =
        json.decode(archivo.readAsStringSync()) as Map<String, dynamic>;
    catalogo = contrato['catalogo'] as Map<String, dynamic>;
  });

  test('umbralQuedanPocas y topePorPedido coinciden con el contrato', () {
    expect(umbralQuedanPocas, equals(catalogo['umbralQuedanPocas']));
    expect(topePorPedido, equals(catalogo['topePorPedido']));
  });

  test('Balde cubre exactamente los baldes del contrato', () {
    final delContrato = Set<String>.from(catalogo['baldes'] as List);
    final delEnum = Balde.values.map((b) => b.clave).toSet();
    expect(delEnum, equals(delContrato));
  });

  test('MotivoDeDescarte cubre exactamente las clases que no son "entra"', () {
    final delContrato = Set<String>.from(catalogo['clasesDeDescarte'] as List)
      ..remove('entra');
    final delEnum = MotivoDeDescarte.values.map((m) => m.clave).toSet();
    expect(delEnum, equals(delContrato));
  });

  group('balde() y tope()', () {
    late List casos;

    setUpAll(() {
      casos = catalogo['casosDeBalde'] as List;
    });

    test('el contrato trae fixtures de balde', () {
      // Una lista vacia haria pasar el resto sin comparar nada.
      expect(casos, isNotEmpty);
    });

    test('balde() da lo mismo que el contrato, caso por caso', () {
      for (final caso in casos) {
        final c = caso as Map<String, dynamic>;
        final resultado = balde(
          stock: c['stock'] as int,
          botellas: c['botellas'] as int,
        );
        expect(
          resultado.clave,
          equals(c['balde']),
          reason: c['porque'] as String,
        );
      }
    });

    test('tope() da lo mismo que el contrato, caso por caso', () {
      for (final caso in casos) {
        final c = caso as Map<String, dynamic>;
        expect(
          tope(stock: c['stock'] as int),
          equals(c['tope']),
          reason: c['porque'] as String,
        );
      }
    });

    test('las fixtures cubren los tres baldes', () {
      // Con solo "disponible", un espejo que devuelve siempre lo mismo
      // pasaria las dos pruebas de arriba.
      final baldes = casos.map((c) => (c as Map)['balde'] as String).toSet();
      expect(baldes, equals({'disponible', 'quedan-pocas', 'agotado'}));
    });
  });

  test('el contrato trae fixtures de descarte, con las cinco clases', () {
    final casos = catalogo['casosDeDescarte'] as List;
    expect(casos, isNotEmpty);
    final clases = casos.map((c) => (c as Map)['clase'] as String).toSet();
    // Control positivo: al menos un caso que SI entra a la vidriera. Sin
    // esto, un espejo que descarta todo pasaria todas las comparaciones.
    expect(clases.contains('entra'), isTrue);
    // Control negativo: al menos uno de cada clase que NO entra.
    for (final motivo in MotivoDeDescarte.values) {
      expect(
        clases.contains(motivo.clave),
        isTrue,
        reason: 'falta un caso de "${motivo.clave}"',
      );
    }
  });
}
