import 'dart:math';

import 'package:admin/core/contratos/pedido.dart';
import 'package:admin/core/contratos/stock.dart';
import 'package:admin/features/catalogo/domain/ficha_del_vino.dart';
import 'package:admin/features/catalogo/domain/producto_del_panel.dart';
import 'package:admin/features/pedidos/domain/entrega_escrita.dart';
import 'package:admin/features/pedidos/domain/id_de_pedido.dart';
import 'package:admin/features/pedidos/domain/linea_a_cargar.dart';
import 'package:admin/features/pedidos/domain/pedido_a_cargar.dart';
import 'package:test/test.dart';

/// HU-10.1, specs `cargar-pedido-de-whatsapp` y `crear-orden-del-panel`: el
/// borrador del pedido, sus lineas y lo que viaja a la callable.
///
/// Dart puro con `package:test`: corre en segundos, `flutter test` esta
/// denegado en esta maquina.

ProductoDelPanel _vino(
  String id, {
  int? stock = 10,
  int precio = 1990000,
  int botellas = 1,
  bool muestra = false,
}) => ProductoDelPanel(
  id: id,
  slug: id,
  nombre: 'Vino $id',
  precio: precio,
  publicado: true,
  ficha: const FichaDelVino(bodegaId: 'b'),
  botellas: botellas,
  stock: stock,
  muestra: muestra,
);

LineaACargar _linea(String id, {int? stock = 10, int precio = 1990000}) =>
    LineaACargar.de(_vino(id, stock: stock, precio: precio));

const _entregaValida = EntregaEscrita(
  nombre: 'Marta Gomez',
  telefono: '0351 15-555-1234',
  calle: 'San Martin',
  numero: '120',
  codigoPostal: '5000',
  localidad: 'Cordoba',
  provincia: 'X',
);

PedidoACargar _pedido({List<LineaACargar>? lineas}) => PedidoACargar(
  idPedido: 'pedido-de-prueba-0001',
  lineas: lineas ?? [_linea('a')],
  entrega: _entregaValida,
);

void main() {
  group('que vinos se pueden elegir', () {
    test('uno con stock, no de muestra, si', () {
      expect(motivoDeQueNoSeVende(_vino('a')), isNull);
    });

    test('uno de muestra no: su stock es inventado', () {
      expect(
        motivoDeQueNoSeVende(_vino('a', muestra: true)),
        MotivoNoElegible.deMuestra,
      );
    });

    test('uno sin stock no, y se dice que se repone primero', () {
      expect(
        motivoDeQueNoSeVende(_vino('a', stock: 0)),
        MotivoNoElegible.sinStock,
      );
    });

    test('un compuesto no tiene stock propio', () {
      expect(
        motivoDeQueNoSeVende(_vino('a', stock: null)),
        MotivoNoElegible.compuesto,
      );
    });

    test('uno NO publicado si: el operador sabe lo que vende', () {
      // El panel no mira `publicado`: ADR 018 §5.
      expect(motivoDeQueNoSeVende(_vino('a')), isNull);
    });

    test('armar una linea de un compuesto es un error de programacion', () {
      expect(
        () => LineaACargar.de(_vino('a', stock: null)),
        throwsArgumentError,
      );
    });
  });

  group('la cantidad de una linea', () {
    test('no pasa del stock que se ve', () {
      final l = _linea('a', stock: 10).conCantidad(11);
      expect(l.cantidad, 10);
      // Control positivo: el borde exacto pasa.
      expect(_linea('a', stock: 10).conCantidad(10).cantidad, 10);
    });

    test('no baja de 1', () {
      expect(_linea('a').conCantidad(0).cantidad, 1);
      expect(_linea('a').conCantidad(-3).cantidad, 1);
    });

    test('nunca pasa del tope del contrato aunque haya mas stock', () {
      final l = _linea('a', stock: 999999);
      expect(l.maximo, topeDeStock);
      expect(l.conCantidad(999999).cantidad, topeDeStock);
    });

    test('el stock de ahora acomoda la cantidad al nuevo tope', () {
      final l = _linea('a', stock: 10).conCantidad(8).conStock(3);
      expect(l.stock, 3);
      expect(l.cantidad, 3);
    });

    test('el precio de ahora se guarda, y la cantidad no cambia', () {
      final l = _linea('a').conCantidad(4).conPrecio(2100000);
      expect(l.precioUnitario, 2100000);
      expect(l.cantidad, 4);
    });
  });

  group('el pedido', () {
    test('elegir un vino que ya esta suma una unidad, no repite la linea', () {
      // La callable rechaza un producto repetido.
      final p = _pedido().conVino(_linea('a'));
      expect(p.lineas, hasLength(1));
      expect(p.lineas.single.cantidad, 2);
    });

    test('elegir el mismo vino no pasa de su maximo', () {
      var p = _pedido(lineas: [_linea('a', stock: 2)]);
      p = p.conVino(_linea('a', stock: 2)).conVino(_linea('a', stock: 2));
      expect(p.lineas.single.cantidad, 2);
    });

    test('un vino distinto agrega una linea', () {
      final p = _pedido().conVino(_linea('b'));
      expect(p.lineas.map((l) => l.productoId), ['a', 'b']);
    });

    test('no admite mas lineas que el tope del contrato', () {
      var p = _pedido(lineas: []);
      for (var i = 0; i < topeDeLineasDelPedido; i++) {
        p = p.conVino(_linea('vino-$i'));
      }
      expect(p.lineas, hasLength(topeDeLineasDelPedido));
      expect(p.admiteOtraLinea, isFalse);
      // Otro vino distinto ya no entra.
      expect(
        p.conVino(_linea('uno-mas')).lineas,
        hasLength(topeDeLineasDelPedido),
      );
    });

    test('sacar un vino lo saca', () {
      final p = _pedido().conVino(_linea('b')).sinVino('a');
      expect(p.lineas.map((l) => l.productoId), ['b']);
    });

    test('el total de lista suma precio por cantidad, en centavos enteros', () {
      final p = _pedido(
        lineas: [
          _linea('a', precio: 1990000).conCantidad(2),
          _linea('b', precio: 2500000).conCantidad(3),
        ],
      );
      expect(p.totalDeLista, 2 * 1990000 + 3 * 2500000);
    });

    test('cuenta las botellas, no las unidades de venta', () {
      final caja = LineaACargar.de(_vino('caja', botellas: 2)).conCantidad(3);
      expect(_pedido(lineas: [caja]).botellasEnTotal, 6);
    });
  });

  group('cuando se puede confirmar', () {
    test('con vinos y todos los datos, si', () {
      expect(_pedido().sePuedeConfirmar, isTrue);
    });

    test('sin vinos no', () {
      expect(_pedido(lineas: []).sePuedeConfirmar, isFalse);
    });

    test('con un dato de entrega malo no', () {
      final p = _pedido().conEntrega(_entregaValida.copiarCon(telefono: '123'));
      expect(p.sePuedeConfirmar, isFalse);
    });

    test('con un vino que se quedo sin stock no', () {
      final p = _pedido().conStockDe('a', 0);
      expect(p.sePuedeConfirmar, isFalse);
    });
  });

  group('lo que viaja a la callable', () {
    test('la forma exacta: idPedido, lineas y entrega', () {
      final j = _pedido(lineas: [_linea('a').conCantidad(2)]).aJson;
      expect(j.keys.toSet(), {'idPedido', 'lineas', 'entrega'});
      expect(j['idPedido'], 'pedido-de-prueba-0001');
      expect(j['lineas'], [
        {'productoId': 'a', 'cantidad': 2, 'precioUnitarioVisto': 1990000},
      ]);
    });

    test('NO lleva origen ni estadoPago: los fija el servidor', () {
      final j = _pedido().aJson;
      expect(j.containsKey('origen'), isFalse);
      expect(j.containsKey('estadoPago'), isFalse);
    });

    test(
      'el telefono va normalizado, lo que el operador vio antes de confirmar',
      () {
        final entrega = _pedido().aJson['entrega'] as Map;
        expect(entrega['telefono'], '+5493515551234');
      },
    );

    test('el idPedido no cambia al cambiar cantidades, lineas ni datos', () {
      // El bug de `moverStock` (hallazgo 2 de revisor-pagos): un id nuevo tras
      // un error ambiguo suma dos veces.
      final inicial = _pedido();
      final despues = inicial
          .conVino(_linea('b'))
          .conCantidad('a', 5)
          .conPrecioDe('a', 2100000)
          .conEntrega(_entregaValida.copiarCon(calle: 'Belgrano'))
          .sinVino('b');
      expect(despues.idPedido, inicial.idPedido);
    });
  });

  group('el id del pedido', () {
    test('son 32 hexadecimales, dentro de lo que acepta el servidor', () {
      final id = nuevoIdDePedido();
      expect(id, matches(RegExp(r'^[0-9a-f]{32}$')));
      expect(id, matches(RegExp(r'^[A-Za-z0-9_-]{16,64}$')));
    });

    test('dos ids no se repiten', () {
      expect(nuevoIdDePedido(), isNot(nuevoIdDePedido()));
    });

    test('con el mismo azar da el mismo id (es determinista de verdad)', () {
      expect(nuevoIdDePedido(Random(1)), nuevoIdDePedido(Random(1)));
    });
  });
}
