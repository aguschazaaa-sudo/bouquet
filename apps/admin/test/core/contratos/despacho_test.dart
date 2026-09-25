import 'dart:convert';
import 'dart:io';

import 'package:admin/core/contratos/despacho.dart';
import 'package:admin/core/contratos/estado_entrega.dart';
import 'package:admin/core/contratos/estado_pago.dart';
import 'package:admin/core/contratos/pedido.dart';
import 'package:test/test.dart';

/// El espejo de `packages/contratos/src/despacho.ts`. Compara CONTRA
/// `generated/contratos.json`: las dos reglas viajan CALCULADAS por el
/// TypeScript de hoy, asi que este test no compara el archivo contra si mismo.
///
/// Usa package:test y NO flutter_test A PROPOSITO: `flutter test` esta
/// DENEGADO en esta maquina.
void main() {
  late Map<String, dynamic> despacho;

  setUpAll(() {
    final archivo = File('../../packages/contratos/generated/contratos.json');
    final contrato =
        json.decode(archivo.readAsStringSync()) as Map<String, dynamic>;
    despacho = contrato['despacho'] as Map<String, dynamic>;
  });

  List<String> lista(String clave) =>
      List<String>.from(despacho[clave] as List);

  test('las listas coinciden con el contrato, en el mismo orden', () {
    expect(Correo.values.map((c) => c.clave).toList(), lista('correos'));
    expect(
      MotivoDeFalla.values.map((m) => m.clave).toList(),
      lista('motivosDeFalla'),
    );
    expect(
      MotivoDeCancelacion.values.map((m) => m.clave).toList(),
      lista('motivosDeCancelacion'),
    );
    expect(
      MotivoSinReponer.values.map((m) => m.clave).toList(),
      lista('motivosSinReponer'),
    );
    expect(largoDelSeguimiento, despacho['largoDelSeguimiento']);
    expect(
      soloLoEscribeElServidor.map((e) => e.name).toList(),
      lista('soloLoEscribeElServidor'),
    );
  });

  test('laEscribeElPanel coincide con el contrato en los 36 pares', () {
    final delContrato = despacho['laEscribeElPanel'] as Map<String, dynamic>;
    var aceptados = 0;
    for (final antes in EstadoEntrega.values) {
      final esperados = Set<String>.from(delContrato[antes.name] as List);
      for (final despues in EstadoEntrega.values) {
        final propio = laEscribeElPanel(antes, despues);
        expect(
          propio,
          esperados.contains(despues.name),
          reason: '${antes.name} -> ${despues.name}',
        );
        if (propio) aceptados += 1;
      }
    }
    // Control: un contrato vacio daria todo `false` y pasaria igual.
    expect(aceptados, 5);
  });

  test('sePuedeDespachar coincide con el contrato para cada origen y pago', () {
    final delContrato = despacho['sePuedeDespachar'] as Map<String, dynamic>;
    for (final origen in Origen.values) {
      final esperados = Set<String>.from(delContrato[origen.clave] as List);
      for (final pago in EstadoPago.values) {
        expect(
          sePuedeDespachar(origen, pago),
          esperados.contains(pago.name),
          reason: '${origen.clave}/${pago.name}',
        );
      }
    }
  });

  test('desde lo que no es una clave del contrato, null', () {
    expect(Correo.desde('paloma'), isNull);
    expect(MotivoDeFalla.desde(null), isNull);
    expect(MotivoDeCancelacion.desde(3), isNull);
    expect(MotivoSinReponer.desde(''), isNull);
    // Control positivo.
    expect(Correo.desde('correo_argentino'), Correo.correoArgentino);
  });
}
