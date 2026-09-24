import 'package:admin/core/contratos/stock.dart';
import 'package:admin/features/stock/data/documento_del_movimiento.dart';
import 'package:admin/features/stock/domain/movimiento_de_stock.dart';
import 'package:admin/features/stock/presentation/textos_de_movimientos.dart';
import 'package:test/test.dart';

/// HU-05.4: leer un movimiento y decirlo. Dart puro.
void main() {
  final hora = DateTime(2026, 9, 23, 21, 4);

  group('movimientoDesde', () {
    test('el movimiento REAL de producción: reponer 32, de 0 a 32', () {
      // Es el de vino-de-prueba del 2026-09-24 00:04 UTC, tal como está en
      // Firestore: operacion {tipo, cantidad}, antes, despues, por.
      final m = movimientoDesde(
        '8d285f36c640',
        {
          'operacion': {'tipo': 'reponer', 'cantidad': 32},
          'antes': 0,
          'despues': 32,
          'por': 'uid-del-dueno',
        },
        en: hora,
        miUid: 'uid-del-dueno',
      );
      expect(m.operacion, isA<Reponer>());
      expect((m.operacion! as Reponer).cantidad, 32);
      expect((m.antes, m.despues), (0, 32));
      expect(m.esMio, isTrue);
      expect(m.en, hora);
    });

    test('una corrección lleva visto, valor y motivo', () {
      final m = movimientoDesde(
        'x',
        {
          'operacion': {
            'tipo': 'corregir',
            'visto': 8,
            'valor': 10,
            'motivo': 'conteo',
          },
          'antes': 8,
          'despues': 10,
          'por': 'otro',
        },
        en: hora,
        miUid: 'yo',
      );
      final op = m.operacion! as Corregir;
      expect((op.visto, op.valor, op.motivo), (8, 10, MotivoDeAjuste.conteo));
      expect(m.esMio, isFalse);
    });

    test('un tipo que este panel no conoce se muestra, no desaparece', () {
      final m = movimientoDesde(
        'x',
        {
          'operacion': {'tipo': 'venta', 'cantidad': 2},
          'antes': 5,
          'despues': 3,
          'por': 'a',
        },
        en: hora,
        miUid: 'a',
      );
      expect(m.operacion, isNull);
      expect((m.antes, m.despues), (5, 3));
    });

    test('un documento roto no lanza: sale sin detalle', () {
      final m = movimientoDesde(
        'x',
        {'operacion': 'basura', 'antes': 'cuatro'},
        en: null,
        miUid: null,
      );
      expect((m.operacion, m.antes, m.despues, m.en), (null, null, null, null));
      expect(m.esMio, isFalse);
    });

    test('NaN e Infinity no lanzan: un documento así no oculta la lista', () {
      final m = movimientoDesde(
        'x',
        {'antes': double.nan, 'despues': double.infinity},
        en: hora,
        miUid: null,
      );
      expect((m.antes, m.despues), (null, null));
      final r = movimientoDesde(
        'x',
        {
          'operacion': {'tipo': 'reponer', 'cantidad': double.nan},
        },
        en: hora,
        miUid: null,
      );
      expect(r.operacion, isNull);
    });

    test('sin usuario actual, nunca es "mío"', () {
      final m = movimientoDesde('x', {'por': 'a'}, en: hora, miUid: null);
      expect(m.esMio, isFalse);
    });

    test('un corregir con motivo inventado no se inventa uno', () {
      final m = movimientoDesde(
        'x',
        {
          'operacion': {
            'tipo': 'corregir',
            'visto': 1,
            'valor': 2,
            'motivo': 'zzz',
          },
        },
        en: hora,
        miUid: null,
      );
      expect(m.operacion, isNull);
    });
  });

  group('los textos', () {
    MovimientoDeStock mov(OperacionDeStock? op, {int? antes, int? despues}) =>
        MovimientoDeStock(
          id: 'x',
          en: hora,
          antes: antes,
          despues: despues,
          operacion: op,
          esMio: true,
        );

    test('cargar en botellas y en cajas', () {
      expect(
        queSeHizo(mov(const Reponer(32)), botellas: 1),
        'Cargó 32 botellas',
      );
      expect(queSeHizo(mov(const Reponer(1)), botellas: 1), 'Cargó 1 botella');
      expect(
        queSeHizo(mov(const Reponer(2)), botellas: 6),
        'Cargó 2 cajas de 6',
      );
      expect(
        queSeHizo(mov(const Reponer(1)), botellas: 6),
        'Cargó 1 caja de 6',
      );
    });

    test('corregir dice el motivo en minúscula', () {
      final op = Corregir(visto: 8, valor: 10, motivo: MotivoDeAjuste.rotura);
      expect(queSeHizo(mov(op), botellas: 1), 'Corrigió el stock (rotura)');
    });

    test('sin operación conocida', () {
      expect(queSeHizo(mov(null), botellas: 1), 'Movimiento de stock');
    });

    test('de cuánto a cuánto, y nada si falta un número', () {
      final m = mov(null, antes: 0, despues: 32);
      expect(deCuantoACuanto(m, botellas: 1), 'de 0 a 32 botellas');
      expect(deCuantoACuanto(mov(null, antes: 0), botellas: 1), isNull);
      expect(deCuantoACuanto(mov(null, despues: 3), botellas: 1), isNull);
    });

    test(
      'de cuánto a cuánto dice CAJAS en un vino de caja (no 60 botellas)',
      () {
        final m = mov(null, antes: 8, despues: 10);
        expect(deCuantoACuanto(m, botellas: 6), 'de 8 a 10 cajas');
        expect(
          deCuantoACuanto(mov(null, antes: 0, despues: 1), botellas: 6),
          'de 0 a 1 caja',
        );
        expect(
          deCuantoACuanto(mov(null, antes: 3, despues: 1), botellas: 1),
          'de 3 a 1 botella',
        );
      },
    );

    test('quién: vos u otra persona', () {
      expect(quien(mov(null)), 'Vos');
      expect(
        quien(
          const MovimientoDeStock(
            id: 'x',
            en: null,
            antes: null,
            despues: null,
            operacion: null,
            esMio: false,
          ),
        ),
        'Otra persona',
      );
    });

    test('cuándo: hoy, ayer, esta fecha, otro año, sin fecha', () {
      final ahora = DateTime(2026, 9, 24, 10, 0);
      expect(cuando(DateTime(2026, 9, 24, 8, 5), ahora: ahora), 'hoy 08:05');
      expect(cuando(DateTime(2026, 9, 23, 21, 4), ahora: ahora), 'ayer 21:04');
      expect(cuando(DateTime(2026, 9, 1, 9, 0), ahora: ahora), '01/09 09:00');
      expect(
        cuando(DateTime(2025, 12, 31, 23, 59), ahora: ahora),
        '31/12/2025 23:59',
      );
      expect(cuando(null, ahora: ahora), 'sin fecha');
    });

    test('ayer cruza el fin de mes', () {
      final ahora = DateTime(2026, 10, 1, 0, 30);
      expect(cuando(DateTime(2026, 9, 30, 23, 0), ahora: ahora), 'ayer 23:00');
    });
  });
}
