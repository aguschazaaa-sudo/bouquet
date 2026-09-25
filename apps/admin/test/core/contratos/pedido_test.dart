import 'dart:convert';
import 'dart:io';

import 'package:admin/core/contratos/pedido.dart';
import 'package:admin/core/contratos/provincias.dart';
import 'package:admin/core/contratos/stock.dart';
import 'package:test/test.dart';

/// El origen y los topes del pedido del panel, contra lo que calculo el
/// TypeScript (`generated/contratos.json`, seccion `pedido`). ADR 018.
void main() {
  late Map<String, dynamic> pedido;

  setUpAll(() {
    final archivo = File('../../packages/contratos/generated/contratos.json');
    final contrato =
        json.decode(archivo.readAsStringSync()) as Map<String, dynamic>;
    pedido = contrato['pedido'] as Map<String, dynamic>;
  });

  test('los origenes son los del contrato', () {
    final delContrato = Set<String>.from(pedido['origenes'] as List);
    expect(Origen.values.map((o) => o.clave).toSet(), equals(delContrato));
  });

  test('los topes son los del contrato', () {
    expect(topeDeLineasDelPedido, pedido['topeDeLineas']);
    expect(topeDeStock, pedido['topeDeCantidad']);
  });

  test('los largos de la entrega son los del contrato', () {
    final delContrato = (pedido['largosDeEntrega'] as Map<String, dynamic>)
        .cast<String, int>();
    expect(largosDeEntrega, equals(delContrato));
    expect(largosDeEntrega, isNotEmpty);
  });

  test('las provincias son las del contrato, con codigo y nombre', () {
    final delContrato = (pedido['provincias'] as List)
        .cast<Map<String, dynamic>>();
    expect(provincias, hasLength(delContrato.length));
    expect(provincias, hasLength(24));
    for (var i = 0; i < delContrato.length; i++) {
      expect(provincias[i].iso, delContrato[i]['iso'], reason: 'posicion $i');
      expect(
        provincias[i].nombre,
        delContrato[i]['nombre'],
        reason: delContrato[i]['iso'] as String,
      );
    }
    // Control: un codigo que no existe no es provincia, y el que existe si.
    expect(esProvinciaIso('X'), isTrue);
    expect(esProvinciaIso('ZZ'), isFalse);
    expect(esProvinciaIso('x'), isFalse, reason: 'el codigo es en mayuscula');
    expect(nombreDeProvincia('X'), 'Córdoba');
    expect(nombreDeProvincia('ZZ'), isNull);
  });

  test('Origen.desde reconoce las dos claves y nada mas', () {
    expect(Origen.desde('whatsapp'), Origen.whatsapp);
    expect(Origen.desde('vidriera'), Origen.vidriera);
    expect(Origen.desde('telefono'), isNull);
    expect(Origen.desde(null), isNull);
  });
}
