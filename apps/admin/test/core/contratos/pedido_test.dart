import 'dart:convert';
import 'dart:io';

import 'package:admin/core/contratos/estado_pago.dart';
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

  test('cada origen nace con el estado de pago del contrato', () {
    final inicial = pedido['estadoDePagoInicial'] as Map<String, dynamic>;
    for (final o in Origen.values) {
      expect(
        estadoDePagoInicial(o).name,
        equals(inicial[o.clave]),
        reason: 'origen ${o.clave}',
      );
    }
    // Si dieran lo mismo, la funcion no decidiria nada.
    expect(
      estadoDePagoInicial(Origen.whatsapp),
      isNot(estadoDePagoInicial(Origen.vidriera)),
    );
    expect(estadoDePagoInicial(Origen.whatsapp), EstadoPago.por_fuera);
  });

  test('los topes son los del contrato', () {
    expect(topeDeLineasDelPedido, pedido['topeDeLineas']);
    expect(topeDeStock, pedido['topeDeCantidad']);
    expect(precioMaximo, pedido['precioMaximo']);
  });

  test('el precio maximo nunca desborda un entero seguro en el peor pedido', () {
    // La razon de ser del tope: 30 lineas x cantidad maxima x precio maximo.
    // 2^53 - 1: en la web un entero es un double, y mas alla se pierde precision.
    const seguro = 9007199254740991;
    expect(
      precioMaximo * topeDeStock * topeDeLineasDelPedido,
      lessThanOrEqualTo(seguro),
    );
    // Y es el mayor: uno mas ya no entra.
    expect(
      (precioMaximo + 1) * topeDeStock * topeDeLineasDelPedido,
      greaterThan(seguro),
    );
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
