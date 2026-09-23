import 'dart:io';

import 'package:admin/features/stock/data/codigos_de_stock.dart';
import 'package:admin/features/stock/domain/fallo_de_stock.dart';
import 'package:test/test.dart';

/// La traduccion de los `HttpsError` de `moverStock` a lo que la pantalla
/// sabe decir. Dart puro con `package:test`: el adaptador que sabe del SDK
/// (`fallos_de_stock.dart`) no se puede cargar sin Flutter, y por eso lo unico
/// con logica vive en `codigos_de_stock.dart`.
void main() {
  group('falloDesdeLaCallable', () {
    test('sin sesion y sin el claim: sinPermiso', () {
      expect(
        falloDesdeLaCallable('unauthenticated', null).error,
        ErrorDeStock.sinPermiso,
      );
      expect(
        falloDesdeLaCallable('permission-denied', null).error,
        ErrorDeStock.sinPermiso,
      );
    });

    test('el vino no existe y el id ya usado tienen su propio error', () {
      expect(
        falloDesdeLaCallable('not-found', null).error,
        ErrorDeStock.noExiste,
      );
      expect(
        falloDesdeLaCallable('already-exists', null).error,
        ErrorDeStock.yaEstaHecho,
      );
    });

    test('cambio el stock: trae el numero de AHORA', () {
      final f = falloDesdeLaCallable('failed-precondition', {
        'codigo': 'cambio-el-stock',
        'actual': 8,
      });
      expect(f.error, ErrorDeStock.cambioElStock);
      expect(f.actual, 8);
    });

    test(
      'pasa el tope: trae el stock actual, aunque en la web llegue double',
      () {
        final f = falloDesdeLaCallable('failed-precondition', {
          'codigo': 'pasa-el-tope',
          'actual': 4995.0,
        });
        expect(f.error, ErrorDeStock.pasaElTope);
        expect(f.actual, 4995);
      },
    );

    test('un rechazo sin numero no se cae: actual queda en null', () {
      final f = falloDesdeLaCallable('failed-precondition', {
        'codigo': 'cambio-el-stock',
      });
      expect(f.error, ErrorDeStock.cambioElStock);
      expect(f.actual, isNull);
    });

    test('failed-precondition sin detalles reconocibles: noSePuede', () {
      // Un compuesto, o un stock roto: la callable no manda `details`.
      for (final detalles in [
        null,
        'texto',
        3,
        <String, Object?>{},
        {'codigo': 'otro'},
      ]) {
        expect(
          falloDesdeLaCallable('failed-precondition', detalles).error,
          ErrorDeStock.noSePuede,
          reason: '$detalles',
        );
      }
    });

    test('sin red: sinConexion, y nunca dice "no se guardo"', () {
      for (final codigo in ['unavailable', 'deadline-exceeded', 'cancelled']) {
        expect(
          falloDesdeLaCallable(codigo, null).error,
          ErrorDeStock.sinConexion,
        );
      }
    });

    test('lo que no se conoce es desconocido, no un error de otro tipo', () {
      for (final codigo in ['internal', 'invalid-argument', 'algo-nuevo']) {
        expect(
          falloDesdeLaCallable(codigo, null).error,
          ErrorDeStock.desconocido,
        );
      }
    });

    test('guarda el codigo crudo para el log', () {
      expect(falloDesdeLaCallable('internal', null).codigo, 'internal');
    });
  });

  group('contra los codigos que la callable lanza de verdad', () {
    // Lo que el panel sabe traducir no puede quedar viejo respecto del
    // servidor: si `moverStock` empieza a lanzar un codigo nuevo, este test
    // avisa antes de que la pantalla diga "no pudimos guardar" sin motivo.
    test(
      'cada codigo de mover.ts, mover_stock.ts y auth.ts esta contemplado',
      () {
        final fuentes = [
          '../../functions/src/stock/mover.ts',
          '../../functions/src/stock/mover_stock.ts',
          '../../functions/src/auth.ts',
        ].map((r) => File(r).readAsStringSync()).join('\n');

        final codigos = RegExp(
          r"new HttpsError\(\s*'([a-z-]+)'",
        ).allMatches(fuentes).map((m) => m.group(1)!).toSet();

        // Control positivo: si el regex no encontrara nada, el bucle de abajo
        // no compararia nada y el test pasaria vacio.
        expect(codigos, containsAll(['not-found', 'failed-precondition']));
        expect(codigos.length, greaterThanOrEqualTo(5));

        // `invalid-argument` lo dispara un pedido mal formado: el panel valida
        // antes de mandar, asi que solo llegaria con una deriva de versiones, y
        // "desconocido" es la respuesta honesta. Todo lo demas tiene su error.
        const sinTraduccionPropia = {'invalid-argument'};
        for (final c in codigos) {
          final f = falloDesdeLaCallable(c, null);
          if (sinTraduccionPropia.contains(c)) {
            expect(f.error, ErrorDeStock.desconocido, reason: c);
          } else {
            expect(f.error, isNot(ErrorDeStock.desconocido), reason: c);
          }
        }
      },
    );
  });
}
