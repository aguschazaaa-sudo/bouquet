import 'package:admin/core/contratos/estado_entrega.dart';
import 'package:admin/core/contratos/estado_pago.dart';
import 'package:admin/core/contratos/estado_publico.dart';
import 'package:admin/core/contratos/pedido.dart';
import 'package:admin/features/pedidos/data/documento_de_la_orden.dart';
import 'package:test/test.dart';

/// HU-06.1 y HU-06.2, specs `bandeja-de-pedidos` y `detalle-del-pedido`: como se
/// lee el documento de una Orden, y sobre todo como se lee uno ROTO.
///
/// El documento de ejemplo es el que deja `crearOrdenDelPanel`
/// (`functions/src/pedidos/armar.ts`).

Map<String, Object?> _documento([Map<String, Object?> cambios = const {}]) => {
  'numero': 7,
  'origen': 'whatsapp',
  'estadoPago': 'por_fuera',
  'estadoEntrega': 'sin_preparar',
  'items': [
    {
      'productoId': 'vino-a',
      'nombre': 'Vino A',
      'precioUnitario': 1990000,
      'cantidad': 2,
      'botellas': 1,
    },
    {
      'productoId': 'caja',
      'nombre': 'Caja de dos',
      'precioUnitario': 3980000,
      'cantidad': 1,
      'botellas': 2,
    },
  ],
  'subtotal': 7960000,
  'envio': null,
  'total': 7960000,
  'contacto': {
    'nombre': 'Marta Gomez',
    'telefonoE164': '+5493515551234',
    'email': null,
  },
  'entrega': {
    'calle': 'San Martin',
    'numero': '120',
    'piso': null,
    'referencia': null,
    'destino': {
      'codigoPostal': '5000',
      'localidad': 'Cordoba',
      'provincia': 'X',
      'propio': false,
    },
  },
  'creadaPor': 'operador',
  ...cambios,
};

void main() {
  group('un documento sano', () {
    test('se lee entero', () {
      final o = ordenDesde(
        'id-1',
        _documento(),
        creadaEn: DateTime(2026, 9, 24),
      );
      expect(o, isNotNull);
      o!;
      expect(o.id, 'id-1');
      expect(o.numero, 7);
      expect(o.origen, Origen.whatsapp);
      expect(o.estadoPago, EstadoPago.por_fuera);
      expect(o.estadoEntrega, EstadoEntrega.sin_preparar);
      expect(o.total, 7960000);
      expect(o.creadaEn, DateTime(2026, 9, 24));
      expect(o.contacto.nombre, 'Marta Gomez');
      expect(o.contacto.telefonoE164, '+5493515551234');
      expect(o.contacto.email, isNull);
      expect(o.entrega.calle, 'San Martin');
      expect(o.entrega.provincia, 'X');
      expect(o.entrega.piso, isNull);
    });

    test('los items salen del snapshot, con sus botellas', () {
      final o = ordenDesde('id-1', _documento())!;
      expect(o.items, hasLength(2));
      expect(o.items[0].precioUnitario, 1990000);
      expect(o.items[0].subtotal, 3980000);
      expect(o.items[1].botellas, 2);
      // 2 x 1 botella + 1 caja de 2 = 4 botellas.
      expect(o.botellasEnTotal, 4);
    });

    test(
      'el rotulo sale de la proyeccion, y es el de un pedido por preparar',
      () {
        final o = ordenDesde('id-1', _documento())!;
        expect(o.estadoPublico, EstadoPublico.por_preparar);
        expect(o.requiereAccion, isTrue);
        expect(o.cobroPorFuera, isTrue);
        expect(
          rotulosEstadoPublico[o.estadoPublico]!.operador,
          'Cobro por fuera - falta preparar',
        );
      },
    );

    test('un pedido entregado de WhatsApp NO queda como entregada impaga', () {
      final o = ordenDesde('id-1', _documento({'estadoEntrega': 'entregada'}))!;
      expect(o.estadoPublico, EstadoPublico.entregada);
      expect(o.requiereAccion, isFalse);
    });

    test('las notas del operador y los opcionales se leen si estan', () {
      final o = ordenDesde(
        'id-1',
        _documento({
          'notasOperador': 'llamar antes',
          'contacto': {
            'nombre': 'Marta',
            'telefonoE164': '+5493515551234',
            'email': 'marta@ejemplo.com',
          },
        }),
      )!;
      expect(o.notasOperador, 'llamar antes');
      expect(o.contacto.email, 'marta@ejemplo.com');
    });

    test('sin subtotal escrito, es el total', () {
      final d = _documento()..remove('subtotal');
      expect(ordenDesde('id-1', d)!.subtotal, 7960000);
    });
  });

  group('un documento roto NO tira la lista: devuelve null para contarlo', () {
    final rotos = <String, Map<String, Object?> Function()>{
      'sin numero': () => _documento()..remove('numero'),
      'numero que no es entero': () => _documento({'numero': 7.5}),
      'sin total': () => _documento()..remove('total'),
      'sin estado de entrega': () => _documento()..remove('estadoEntrega'),
      'estado de entrega desconocido': () =>
          _documento({'estadoEntrega': 'teletransportada'}),
      'estado de pago desconocido': () =>
          _documento({'estadoPago': 'regalada'}),
      'origen desconocido': () => _documento({'origen': 'telefono'}),
      'sin items': () => _documento()..remove('items'),
      'items vacio': () => _documento({'items': <Object?>[]}),
      'items que no es lista': () => _documento({'items': 'nada'}),
      'un item sin cantidad': () => _documento({
        'items': [
          {
            'productoId': 'a',
            'nombre': 'A',
            'precioUnitario': 1,
            'botellas': 1,
          },
        ],
      }),
      'un item con cantidad 0': () => _documento({
        'items': [
          {
            'productoId': 'a',
            'nombre': 'A',
            'precioUnitario': 1,
            'cantidad': 0,
            'botellas': 1,
          },
        ],
      }),
      'un item con precio decimal': () => _documento({
        'items': [
          {
            'productoId': 'a',
            'nombre': 'A',
            'precioUnitario': 19.9,
            'cantidad': 1,
            'botellas': 1,
          },
        ],
      }),
      'un item que no es un mapa': () => _documento({
        'items': ['cualquier cosa'],
      }),
    };

    for (final entrada in rotos.entries) {
      test(entrada.key, () {
        // Control positivo, en cada caso: el documento sano SI se lee. Sin esto,
        // un mapeo que devuelve null para todo pasaria todos los casos.
        expect(ordenDesde('id', _documento()), isNotNull);
        expect(ordenDesde('id', entrada.value()), isNull);
      });
    }

    test('un total que es NaN no lo tumba: no es entero', () {
      expect(ordenDesde('id', _documento({'total': double.nan})), isNull);
    });
  });

  group('lo que se perdona', () {
    test('sin contacto ni entrega se lee igual, con textos vacios', () {
      final d = _documento()
        ..remove('contacto')
        ..remove('entrega');
      final o = ordenDesde('id', d);
      expect(o, isNotNull, reason: 'con el numero y los items alcanza');
      expect(o!.contacto.nombre, '');
      expect(o.entrega.calle, '');
    });

    test('un piso en blanco es lo mismo que sin piso', () {
      final d = _documento({
        'entrega': {
          'calle': 'San Martin',
          'numero': '1',
          'piso': '   ',
          'destino': {
            'codigoPostal': '5000',
            'localidad': 'x',
            'provincia': 'X',
          },
        },
      });
      expect(ordenDesde('id', d)!.entrega.piso, isNull);
    });

    test('una creadaEn que no llega queda en null', () {
      expect(ordenDesde('id', _documento())!.creadaEn, isNull);
    });
  });
}
