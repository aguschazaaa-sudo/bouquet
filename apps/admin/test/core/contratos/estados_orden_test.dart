import 'dart:convert';
import 'dart:io';

import 'package:admin/core/contratos/estado_entrega.dart';
import 'package:admin/core/contratos/estado_pago.dart';
import 'package:admin/core/contratos/estado_publico.dart';
import 'package:test/test.dart';

/// ADR 002: "apps/admin espeja el enum en Dart, con un test que compara
/// contra contratos/generated/contratos.json." Este es ese test.
///
/// Es teatro si el JSON está viejo — por eso NO alcanza con que este test
/// esté verde: `scripts/ci/auditar_estados.mjs` corre en CI y verifica que
/// `contratos.json` sea exactamente lo que produce hoy
/// `packages/contratos/src/orden.ts`. Sin esa pieza, este test compara
/// contra un contrato que ya no existe y pasa igual.
///
/// La ruta al JSON es relativa a la raíz de ESTE paquete (`apps/admin/`),
/// que es el directorio de trabajo cuando corre `dart test`.
///
/// Usa package:test y NO flutter_test A PROPOSITO: no hay un solo widget acá,
/// y `flutter test` esta DENEGADO en esta maquina (un archivo de test no
/// completo en 7 minutos). Con package:test corre local en segundos — o sea
/// que este test se EJECUTA en vez de existir.
void main() {
  late Map<String, dynamic> contrato;

  setUpAll(() {
    final archivo = File('../../packages/contratos/generated/contratos.json');
    contrato = json.decode(archivo.readAsStringSync()) as Map<String, dynamic>;
  });

  group('EstadoPago', () {
    test('cubre exactamente los estados del contrato', () {
      final delContrato = Set<String>.from(contrato['pago']['estados'] as List);
      final delEnum = EstadoPago.values.map((e) => e.name).toSet();
      expect(delEnum, equals(delContrato));
    });

    test('naceEnPago coincide con el contrato', () {
      final delContrato = Set<String>.from(contrato['pago']['naceEn'] as List);
      final propio = naceEnPago.map((e) => e.name).toSet();
      expect(propio, equals(delContrato));
    });

    test('las transiciones coinciden con el contrato', () {
      final transiciones =
          contrato['pago']['transiciones'] as Map<String, dynamic>;
      for (final entrada in transiciones.entries) {
        final desde = EstadoPago.values.byName(entrada.key);
        final haciaContrato = Set<String>.from(entrada.value as List);
        final haciaPropio = transicionesPago[desde]!.map((e) => e.name).toSet();
        expect(
          haciaPropio,
          equals(haciaContrato),
          reason: 'transición desde "${entrada.key}"',
        );
      }
    });
  });

  group('EstadoEntrega', () {
    test('cubre exactamente los estados del contrato', () {
      final delContrato = Set<String>.from(
        contrato['entrega']['estados'] as List,
      );
      final delEnum = EstadoEntrega.values.map((e) => e.name).toSet();
      expect(delEnum, equals(delContrato));
    });

    test('naceEnEntrega coincide con el contrato', () {
      final delContrato = Set<String>.from(
        contrato['entrega']['naceEn'] as List,
      );
      final propio = naceEnEntrega.map((e) => e.name).toSet();
      expect(propio, equals(delContrato));
    });

    test('las transiciones coinciden con el contrato', () {
      final transiciones =
          contrato['entrega']['transiciones'] as Map<String, dynamic>;
      for (final entrada in transiciones.entries) {
        final desde = EstadoEntrega.values.byName(entrada.key);
        final haciaContrato = Set<String>.from(entrada.value as List);
        final haciaPropio = transicionesEntrega[desde]!
            .map((e) => e.name)
            .toSet();
        expect(
          haciaPropio,
          equals(haciaContrato),
          reason: 'transición desde "${entrada.key}"',
        );
      }
    });
  });

  group('EstadoPublico', () {
    test('cubre exactamente los estados del contrato', () {
      final delContrato = Set<String>.from(
        contrato['publico']['estados'] as List,
      );
      final delEnum = EstadoPublico.values.map((e) => e.name).toSet();
      expect(delEnum, equals(delContrato));
    });

    test('la proyección cubre los mismos 30 pares, con el mismo resultado', () {
      final proyeccionContrato =
          contrato['publico']['proyeccion'] as Map<String, dynamic>;
      expect(proyeccion.length, equals(proyeccionContrato.length));

      for (final entrada in proyeccionContrato.entries) {
        final partes = entrada.key.split('|');
        final pago = EstadoPago.values.byName(partes[0]);
        final entrega = EstadoEntrega.values.byName(partes[1]);
        final publico = proyectarEstadoPublico(pago, entrega);
        expect(
          publico.name,
          equals(entrada.value),
          reason: 'par "${entrada.key}"',
        );
      }
    });

    test('cada estado público tiene rótulo para cliente y operador', () {
      for (final estado in EstadoPublico.values) {
        expect(
          rotulosEstadoPublico.containsKey(estado),
          isTrue,
          reason: '$estado sin rótulo',
        );
      }
    });
  });
}
