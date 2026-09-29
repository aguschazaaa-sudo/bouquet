import 'dart:convert';
import 'dart:io';

import 'package:admin/core/contratos/estado_entrega.dart';
import 'package:admin/core/contratos/estado_pago.dart';
import 'package:admin/core/contratos/producto.dart';
import 'package:admin/features/catalogo/domain/bodega.dart';
import 'package:admin/features/catalogo/domain/catalogo.dart';
import 'package:admin/features/catalogo/domain/ficha_del_vino.dart';
import 'package:admin/features/catalogo/domain/producto_del_panel.dart';
import 'package:admin/features/resumen/domain/lo_del_dia.dart';
import 'package:admin/features/resumen/domain/lo_que_mas_se_vende.dart';
import 'package:admin/features/resumen/presentation/textos_del_resumen.dart';
import 'package:test/test.dart';

/// EP-11, ADR 025: el resumen del dia (HU-11.2) y lo que mas se vende
/// (HU-11.3). Cada regla con su control al lado. Dart puro: `flutter test`
/// esta denegado en esta maquina.

final _norton = Bodega(id: 'norton', nombre: 'Bodega Norton', slug: 'norton');

ProductoDelPanel _vino(
  String id, {
  bool publicado = true,
  int botellas = 1,
  int? stock = 10,
}) => ProductoDelPanel(
  id: id,
  slug: id,
  nombre: 'Vino $id',
  precio: 1000000,
  publicado: publicado,
  ficha: const FichaDelVino(
    bodegaId: 'norton',
    varietales: ['Malbec'],
    color: ColorDelVino.tinto,
    region: 'Mendoza',
    volumenMl: 750,
  ),
  botellas: botellas,
  stock: stock,
);

Catalogo _catalogo(List<ProductoDelPanel> productos) =>
    Catalogo.armar(productos: productos, bodegas: [_norton]);

Map<String, dynamic> _contrato() =>
    json.decode(
          File(
            '../../packages/contratos/generated/contratos.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;

void main() {
  group('para despachar sale de la proyeccion (HU-11.2, ADR 027)', () {
    test('los pares son EXACTAMENTE los de "pagada" y "por_preparar"', () {
      final publico = _contrato()['publico'] as Map<String, dynamic>;
      final proyeccion = publico['proyeccion'] as Map<String, dynamic>;
      final esperados = [
        for (final MapEntry(:key, :value) in proyeccion.entries)
          if (value == 'pagada' || value == 'por_preparar') key,
      ]..sort();

      final pares = [
        for (final t in tramosPorPreparar())
          for (final p in t.pagos) '${p.name}|${t.entrega.name}',
      ]..sort();

      expect(pares, esperados);
      // Control: la lista no es vacia por error, y no se colo nada que ya
      // salio ni un pedido de la tienda que espera el pago -tampoco desde
      // `preparando`, que la proyeccion da con cualquier pago-.
      expect(pares, ['pagada|sin_preparar', 'por_fuera|sin_preparar']);
      expect(pares, isNot(contains('pendiente|preparando')));
      expect(pares, isNot(contains('pendiente|sin_preparar')));
    });

    test('hoy es un tramo solo: sin_preparar, con pagada y por_fuera', () {
      final tramos = tramosPorPreparar();
      expect(tramos, hasLength(1));
      expect(tramos.single.entrega, EstadoEntrega.sin_preparar);
      expect(tramos.single.pagos, [EstadoPago.pagada, EstadoPago.por_fuera]);
    });
  });

  group('un conteo en el tope no es exacto', () {
    test('debajo del tope dice el numero', () {
      expect(textoDelConteo(const Conteo(0)), '0');
      expect(textoDelConteo(const Conteo(49)), '49');
      expect(const Conteo(49).llegoAlTope, isFalse);
    });

    test('en el tope dice "50 o más", que es lo que el limit deja saber', () {
      expect(topeDelConteo, 50);
      expect(const Conteo(50).llegoAlTope, isTrue);
      expect(textoDelConteo(const Conteo(50)), '50 o más');
    });
  });

  group('agotados en la tienda (HU-11.2)', () {
    test('solo los publicados sin stock, en el orden del catalogo', () {
      final c = _catalogo([
        _vino('b-agotado', stock: 0),
        _vino('a-agotado', stock: 0),
        _vino('negativo', stock: -2),
        _vino('con-stock', stock: 30),
        _vino('pocas', stock: 3),
        _vino('oculto', publicado: false, stock: 0),
        _vino('compuesto', stock: null),
      ]);
      expect(
        [for (final p in agotadosEnLaTienda(c)) p.id],
        ['a-agotado', 'b-agotado', 'negativo'],
      );
    });

    test('un catalogo sano no tiene agotados', () {
      expect(agotadosEnLaTienda(_catalogo([_vino('a'), _vino('b')])), isEmpty);
    });

    test('los nombres: singular, plural y el "y N más"', () {
      expect(textoSeAgotaron(['A']), 'Se agotó: A.');
      expect(textoSeAgotaron(['A', 'B']), 'Se agotaron: A, B.');
      expect(
        textoSeAgotaron(['A', 'B', 'C', 'D', 'E', 'F', 'G']),
        'Se agotaron: A, B, C, D, E y 2 más.',
      );
    });
  });

  group('lo que mas se vende (HU-11.3)', () {
    final hora = DateTime.utc(2026, 9, 29, 8);
    Map<String, Object?> medido(Map<String, Object?> unidades) => {
      'simulada': false,
      'ventanaDias': 90,
      'ventas': 4,
      'unidades': unidades,
    };

    test('sin documento, o el simulado del seed: no hay ranking', () {
      expect(LoQueMasSeVende.desde(null, calculadaEn: null), isA<SinMedir>());
      expect(
        LoQueMasSeVende.desde({
          'simulada': true,
          'unidades': {'a': 9},
        }, calculadaEn: hora),
        isA<SinMedir>(),
      );
      // Uno que no dice nada no afirma que midio.
      expect(
        LoQueMasSeVende.desde({
          'unidades': {'a': 9},
        }, calculadaEn: hora),
        isA<SinMedir>(),
      );
    });

    test('medido: mas vendido primero, empate por id, sin ceros', () {
      final lo = LoQueMasSeVende.desde(
        medido({'c': 2, 'b': 5, 'a': 2, 'cero': 0, 'roto': 'x', 'd': 7}),
        calculadaEn: hora,
      );
      expect(lo, isA<Medido>());
      final m = lo as Medido;
      expect([for (final p in m.puestos) p.productoId], ['d', 'b', 'a', 'c']);
      expect(m.puestos.first.unidades, 7);
      expect(m.ventanaDias, 90);
      expect(m.ventas, 4);
      expect(m.calculadaEn, hora);
    });

    test('muestra hasta $puestosQueSeMuestran puestos', () {
      final muchos = {for (var i = 1; i <= 25; i++) 'v$i': i};
      final m = LoQueMasSeVende.desde(medido(muchos), calculadaEn: hora) as Medido;
      expect(m.puestos, hasLength(puestosQueSeMuestran));
      expect(m.puestos.first.productoId, 'v25');
    });

    test('medido y vacio es real: no hubo ventas en la ventana', () {
      final m = LoQueMasSeVende.desde(medido({}), calculadaEn: hora);
      expect(m, isA<Medido>());
      expect((m as Medido).puestos, isEmpty);
    });

    test('dice que midio y no se puede leer: ilegible, no "sin ventas"', () {
      expect(
        LoQueMasSeVende.desde(medido({'a': 1}), calculadaEn: null),
        isA<Ilegible>(),
      );
      expect(
        LoQueMasSeVende.desde({
          ...medido({'a': 1}),
          'unidades': 'roto',
        }, calculadaEn: hora),
        isA<Ilegible>(),
      );
      expect(
        LoQueMasSeVende.desde({
          ...medido({'a': 1}),
          'ventanaDias': 0,
        }, calculadaEn: hora),
        isA<Ilegible>(),
      );
    });
  });
}
