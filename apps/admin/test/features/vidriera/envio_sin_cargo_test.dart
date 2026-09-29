import 'dart:convert';
import 'dart:io';

import 'package:admin/features/vidriera/data/codigos_del_envio.dart';
import 'package:admin/features/vidriera/domain/envio_sin_cargo.dart';
import 'package:admin/features/vidriera/presentation/textos_del_envio.dart';
import 'package:test/test.dart';

/// HU-11.1, ADR 026: el umbral de la entrega sin cargo, del lado del panel.
/// Toca plata: cada regla con el lado que aplica y el que no. Dart puro:
/// `flutter test` esta denegado en esta maquina.

void main() {
  group('los topes son los de contratos (generated/contratos.json)', () {
    test('minimo y maximo', () {
      final contrato =
          json.decode(
                File(
                  '../../packages/contratos/generated/contratos.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>;
      final vidriera = contrato['vidriera'] as Map<String, dynamic>;
      expect(umbralMinimo, vidriera['sinCargoMinimo']);
      expect(umbralMaximo, vidriera['sinCargoMaximo']);
    });
  });

  group('leer config/envios: espejo de leerConfigDeEnvios', () {
    test('sin documento, o null, es apagado y no roto', () {
      for (final datos in [
        null,
        <String, Object?>{'sinCargoDesde': null},
      ]) {
        final e = EnvioSinCargo.desdeDocumento(datos);
        expect(e.desde, isNull);
        expect(e.roto, isFalse);
      }
    });

    test('un umbral sano se lee', () {
      final e = EnvioSinCargo.desdeDocumento({
        'sinCargoDesde': 15000000,
        'actualizadoPor': 'x',
      });
      expect(e.desde, 15000000);
      expect(e.roto, isFalse);
    });

    test('ROTO se lee como APAGADO, nunca como sin cargo desde 0', () {
      for (final malo in <Object?>[
        0,
        -100,
        150.5,
        15000050,
        '150000',
        umbralMaximo + 100,
        true,
        <String, Object?>{},
      ]) {
        final e = EnvioSinCargo.desdeDocumento({'sinCargoDesde': malo});
        expect(e.desde, isNull, reason: '$malo');
        expect(e.roto, isTrue, reason: '$malo');
      }
      // Un documento sin el campo tambien esta roto: contratos dice lo mismo.
      expect(EnvioSinCargo.desdeDocumento({}).roto, isTrue);
    });
  });

  group('lo que escribe el dueño', () {
    test('pesos enteros, con o sin puntos de miles y con el signo', () {
      expect(leerUmbral('150000').valor, 15000000);
      expect(leerUmbral('150.000').valor, 15000000);
      expect(leerUmbral(r'$ 150.000').valor, 15000000);
    });

    test('sin centavos, y mayor que cero', () {
      expect(leerUmbral('150.000,50').problema, isNotNull);
      expect(leerUmbral('0').problema, isNotNull);
      expect(leerUmbral('-5').problema, isNotNull);
      expect(leerUmbral('mucho').problema, isNotNull);
      expect(leerUmbral('').estaVacia, isTrue);
    });
  });

  group('la respuesta de fijarEnvioSinCargo', () {
    test('guardado, con monto o apagado', () {
      final fijado = ResultadoDeFijar.desde({
        'guardado': true,
        'sinCargoDesde': 15000000,
      });
      expect(fijado, isA<Fijado>());
      expect((fijado as Fijado).desde, 15000000);

      final apagado = ResultadoDeFijar.desde({
        'guardado': true,
        'sinCargoDesde': null,
      });
      expect((apagado as Fijado).desde, isNull);
    });

    test('pide confirmar, con el monto que lo explica', () {
      final caja = ResultadoDeFijar.desde({
        'guardado': false,
        'motivo': 'debajo-de-una-caja',
        'cajaTipica': 18000000,
      });
      expect(caja, isA<PideConfirmar>());
      expect((caja as PideConfirmar).motivo, MotivoParaConfirmar.debajoDeUnaCaja);
      expect(caja.referencia, 18000000);

      final mitad = ResultadoDeFijar.desde({
        'guardado': false,
        'motivo': 'menos-de-la-mitad',
        'anterior': 20000000,
      });
      expect((mitad as PideConfirmar).motivo, MotivoParaConfirmar.menosDeLaMitad);
      expect(mitad.referencia, 20000000);
    });

    test('una forma desconocida es null, no un "guardado" inventado', () {
      for (final raro in <Object?>[
        null,
        'ok',
        <String, Object?>{},
        {'guardado': 'si'},
        {'guardado': false, 'motivo': 'otro'},
        {'guardado': false, 'motivo': 'debajo-de-una-caja'},
        {'guardado': true, 'sinCargoDesde': 'x'},
      ]) {
        expect(ResultadoDeFijar.desde(raro), isNull, reason: '$raro');
      }
    });
  });

  group('los codigos de la callable', () {
    test('cada codigo que lanza fijar.ts tiene su fallo', () {
      expect(falloDelEnvio('invalid-argument').error, ErrorDelEnvio.noValido);
      expect(falloDelEnvio('permission-denied').error, ErrorDelEnvio.sinPermiso);
      expect(falloDelEnvio('unauthenticated').error, ErrorDelEnvio.sinPermiso);
      expect(falloDelEnvio('unavailable').error, ErrorDelEnvio.sinConexion);
      expect(falloDelEnvio('internal').error, ErrorDelEnvio.desconocido);
    });
  });

  group('la pregunta dice los dos montos', () {
    test('debajo de una caja', () {
      final t = textoDeLaPregunta(
        1500000,
        const PideConfirmar(
          MotivoParaConfirmar.debajoDeUnaCaja,
          referencia: 18000000,
        ),
      );
      expect(t, contains('15.000'));
      expect(t, contains('180.000'));
    });

    test('menos de la mitad', () {
      final t = textoDeLaPregunta(
        9000000,
        const PideConfirmar(
          MotivoParaConfirmar.menosDeLaMitad,
          referencia: 20000000,
        ),
      );
      expect(t, contains('90.000'));
      expect(t, contains('200.000'));
    });
  });
}
