import 'package:admin/features/stock/data/documento_de_ventas.dart';
import 'package:admin/features/stock/data/documento_del_movimiento.dart';
import 'package:admin/features/stock/domain/ventas_sin_despachar.dart';
import 'package:admin/features/stock/presentation/textos_de_movimientos.dart';
import 'package:admin/features/stock/presentation/textos_de_ventas_sin_despachar.dart';
import 'package:test/test.dart';

/// HU-05.2 y HU-05.4, spec `stock-vendido-sin-despachar`: el aviso de lo vendido
/// y sin despachar, y la venta en el historial del vino. ADR 018 §8 y §9,
/// hallazgos 1 y 2 de `revisor-pagos`.
///
/// Dart puro con `package:test`: corre en segundos, `flutter test` esta
/// denegado en esta maquina.

Map<String, Object?> _pedido(List<(String, Object?)> items) => {
  'items': [
    for (final (id, cantidad) in items)
      {'productoId': id, 'cantidad': cantidad},
  ],
};

void main() {
  group('cuanto de un vino esta vendido y sin despachar', () {
    test('suma las unidades de ese vino en todos los pedidos abiertos', () {
      final v = ventasSinDespacharDe('vino-a', [
        _pedido([('vino-a', 2), ('vino-b', 9)]),
        _pedido([('vino-a', 3)]),
      ]);
      expect(v.unidades, 5);
      expect(v.completo, isTrue);
      expect(v.hayQueAvisar, isTrue);
    });

    test(
      'otro vino no cuenta: sin pedidos de este, no hay nada que avisar',
      () {
        final v = ventasSinDespacharDe('vino-a', [
          _pedido([('vino-b', 4)]),
          _pedido([('vino-c', 1)]),
        ]);
        expect(v.unidades, 0);
        expect(v.hayQueAvisar, isFalse);
        // Control positivo: el mismo conjunto, mirando el vino que si esta.
        expect(
          ventasSinDespacharDe('vino-b', [
            _pedido([('vino-b', 4)]),
            _pedido([('vino-c', 1)]),
          ]).unidades,
          4,
        );
      },
    );

    test('sin pedidos abiertos no hay nada que avisar', () {
      final v = ventasSinDespacharDe('vino-a', []);
      expect(v.unidades, 0);
      expect(v.completo, isTrue);
      expect(v.hayQueAvisar, isFalse);
    });

    test(
      'al llegar al tope de pedidos leidos el numero es un piso, y se avisa',
      () {
        final pedidos = List.generate(
          topeDePedidosAbiertos,
          (_) => _pedido([('vino-b', 1)]),
        );
        final v = ventasSinDespacharDe('vino-a', pedidos);
        expect(v.unidades, 0);
        expect(v.completo, isFalse, reason: 'pudo haber mas pedidos sin leer');
        expect(v.hayQueAvisar, isTrue, reason: 'la duda tambien es un aviso');
        // Un pedido menos que el tope: completo.
        expect(
          ventasSinDespacharDe(
            'vino-a',
            pedidos.take(topeDePedidosAbiertos - 1).toList(),
          ).completo,
          isTrue,
        );
      },
    );

    test('un pedido de forma rara no esconde el aviso ni lanza', () {
      final v = ventasSinDespacharDe('vino-a', [
        {'items': 'nada'},
        {'sin': 'items'},
        {
          'items': [
            'un texto',
            {'productoId': 'vino-a'},
            {'productoId': 'vino-a', 'cantidad': 'dos'},
            {'productoId': 'vino-a', 'cantidad': 0},
            {'productoId': 'vino-a', 'cantidad': -3},
            {'productoId': 'vino-a', 'cantidad': 2.5},
            {'productoId': 'vino-a', 'cantidad': 4},
          ],
        },
      ]);
      expect(v.unidades, 4, reason: 'solo la linea sana suma');
    });
  });

  group('lo que dice el aviso', () {
    test('dice que ya estan descontadas Y que siguen en la estanteria', () {
      final t = textoDeVentasSinDespachar(
        const VentasSinDespachar(unidades: 2, completo: true),
        botellas: 1,
      );
      expect(t, contains('2 botellas vendidas'));
      expect(t, contains('descontadas'));
      expect(t, contains('estantería'));
      expect(t, contains('restale esas 2'));
      expect(t, isNot(contains('muchos pedidos')));
    });

    test('una sola se dice en singular', () {
      final t = textoDeVentasSinDespachar(
        const VentasSinDespachar(unidades: 1, completo: true),
        botellas: 1,
      );
      expect(t, contains('1 botella vendida'));
      expect(t, contains('restale esa.'));
    });

    test('un vino de caja lo dice en cajas, no en botellas sueltas', () {
      final t = textoDeVentasSinDespachar(
        const VentasSinDespachar(unidades: 2, completo: true),
        botellas: 6,
      );
      expect(t, contains('2 cajas de 6'));
    });

    test('si no llego a leer todos los pedidos, lo dice', () {
      final conNumero = textoDeVentasSinDespachar(
        const VentasSinDespachar(unidades: 3, completo: false),
        botellas: 1,
      );
      expect(conNumero, contains('puede haber más'));
      final soloDuda = textoDeVentasSinDespachar(
        const VentasSinDespachar(unidades: 0, completo: false),
        botellas: 1,
      );
      expect(soloDuda, contains('no llegamos a leerlos todos'));
    });

    test('no dice "no hay" cuando no pudo leer', () {
      expect(textoNoSePudoVerLoVendido, contains('No pudimos ver'));
      expect(
        textoNoSePudoVerLoVendido.toLowerCase(),
        isNot(contains('no hay pedidos')),
      );
    });
  });

  group('la venta en el historial del vino', () {
    Map<String, Object?> venta([Map<String, Object?> cambios = const {}]) => {
      'operacion': {
        'tipo': 'venta',
        'cantidad': 2,
        'idPedido': 'pedido-de-prueba-0001',
        'numero': 7,
        ...cambios,
      },
      'antes': 10,
      'despues': 8,
      'por': 'operador',
    };

    test('se lee como una venta, con su cantidad y el numero del pedido', () {
      final m = movimientoDesde(
        'venta-x',
        venta(),
        en: null,
        miUid: 'operador',
      );
      expect(m.venta, isNotNull);
      expect(m.venta!.cantidad, 2);
      expect(m.venta!.numero, 7);
      expect(m.operacion, isNull, reason: 'no es algo que el operador pidio');
      expect(m.esMio, isTrue);
    });

    test('se dice "Se vendio", no "Movimiento de stock"', () {
      final m = movimientoDesde('venta-x', venta(), en: null, miUid: 'otro');
      expect(queSeHizo(m, botellas: 1), 'Se vendió 2 botellas (pedido 7)');
      expect(deCuantoACuanto(m, botellas: 1), 'de 10 a 8 botellas');
      expect(quien(m), 'Otra persona');
    });

    test('un vino de caja lo dice en cajas', () {
      final m = movimientoDesde('venta-x', venta(), en: null, miUid: null);
      expect(queSeHizo(m, botellas: 6), 'Se vendió 2 cajas de 6 (pedido 7)');
    });

    test('sin numero de pedido se dice igual, sin numero', () {
      final m = movimientoDesde(
        'venta-x',
        venta({'numero': null}),
        en: null,
        miUid: null,
      );
      expect(queSeHizo(m, botellas: 1), 'Se vendió 2 botellas');
    });

    test(
      'una venta sin cantidad no se inventa: queda como un movimiento sin detalle',
      () {
        final m = movimientoDesde(
          'venta-x',
          venta({'cantidad': null}),
          en: null,
          miUid: null,
        );
        expect(m.venta, isNull);
        expect(queSeHizo(m, botellas: 1), 'Movimiento de stock');
      },
    );

    test('lo que NO es una venta sigue igual: una reposicion no la toca', () {
      final m = movimientoDesde(
        'mov-1',
        {
          'operacion': {'tipo': 'reponer', 'cantidad': 6},
          'antes': 4,
          'despues': 10,
          'por': 'operador',
        },
        en: null,
        miUid: 'operador',
      );
      expect(m.venta, isNull);
      expect(queSeHizo(m, botellas: 1), 'Cargó 6 botellas');
    });
  });
}
