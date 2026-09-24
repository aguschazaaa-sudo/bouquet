import 'dart:convert';
import 'dart:io';

import 'package:admin/core/contratos/estado_pago.dart';
import 'package:admin/core/contratos/pedido.dart';
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
  });

  test('Origen.desde reconoce las dos claves y nada mas', () {
    expect(Origen.desde('whatsapp'), Origen.whatsapp);
    expect(Origen.desde('vidriera'), Origen.vidriera);
    expect(Origen.desde('telefono'), isNull);
    expect(Origen.desde(null), isNull);
  });
}
