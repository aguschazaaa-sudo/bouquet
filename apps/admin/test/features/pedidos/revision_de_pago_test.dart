import 'package:admin/core/contratos/estado_entrega.dart';
import 'package:admin/core/contratos/estado_pago.dart';
import 'package:admin/core/contratos/pedido.dart';
import 'package:admin/features/pedidos/data/codigos_de_pedidos.dart';
import 'package:admin/features/pedidos/data/documento_de_la_orden.dart';
import 'package:admin/features/pedidos/domain/alerta_de_pago.dart';
import 'package:admin/features/pedidos/domain/fallo_de_pedidos.dart';
import 'package:admin/features/pedidos/domain/orden.dart';
import 'package:test/test.dart';

/// HU-08.1 y HU-08.3: lo que queda en la Orden de la ultima consulta a
/// Mercado Pago (`pago`), cuando tiene sentido volver a preguntar
/// (`sePuedeRevisarElPago`) y como se traducen los rechazos de `revisarPago`.

Orden _orden({
  Origen origen = Origen.vidriera,
  EstadoPago pago = EstadoPago.pendiente,
}) => Orden(
  id: 'pedido-de-prueba-0001',
  numero: 7,
  origen: origen,
  estadoPago: pago,
  estadoEntrega: EstadoEntrega.sin_preparar,
  items: const [
    ItemDeOrden(
      productoId: 'vino-a',
      nombre: 'Vino A',
      precioUnitario: 1990000,
      cantidad: 2,
      botellas: 1,
    ),
  ],
  subtotal: 3980000,
  total: 3980000,
  contacto: const ContactoDeOrden(nombre: 'Marta', telefonoE164: '+549351'),
  entrega: const EntregaDeOrden(
    calle: 'San Martin',
    numero: '120',
    codigoPostal: '5000',
    localidad: 'Cordoba',
    provincia: 'X',
  ),
);

void main() {
  group('lo que queda en la Orden', () {
    Map<String, Object?> documento(Map<String, Object?> cambios) => {
      'numero': 7,
      'origen': 'vidriera',
      'estadoPago': 'pagada',
      'estadoEntrega': 'sin_preparar',
      'items': [
        {
          'productoId': 'vino-a',
          'nombre': 'Vino A',
          'precioUnitario': 1990000,
          'cantidad': 2,
          'botellas': 1,
        },
      ],
      'total': 3980000,
      ...cambios,
    };
    final hora = DateTime(2026, 9, 28, 10);
    DateTime? horaDe(Object? v) => v == 'T' ? hora : null;

    test(
      'sin pago escrito, queda en null: el servidor todavia no consulto',
      () {
        final o = ordenDesde('x', documento({}));
        expect(o, isNotNull);
        expect(o!.pago, isNull);
      },
    );

    test('un pago sano se lee entero, con su hora', () {
      final o = ordenDesde(
        'x',
        documento({
          'pago': {
            'proveedor': 'mercadopago',
            'operacionId': '1318431457',
            'estadoDelProveedor': 'approved',
            'detalle': 'accredited',
            'monto': 3980000,
            'consultadoEn': 'T',
          },
        }),
        horaDe: horaDe,
      )!;
      expect(o.pago, isNotNull);
      expect(o.pago!.proveedor, 'mercadopago');
      expect(o.pago!.operacionId, '1318431457');
      expect(o.pago!.estadoDelProveedor, 'approved');
      expect(o.pago!.detalle, 'accredited');
      expect(o.pago!.monto, 3980000);
      expect(o.pago!.consultadoEn, hora);
    });

    test('sin detalle ni consultadoEn, se leen en null: se perdonan', () {
      final o = ordenDesde(
        'x',
        documento({
          'pago': {
            'proveedor': 'mercadopago',
            'operacionId': '1318431457',
            'estadoDelProveedor': 'in_process',
            'detalle': null,
            'monto': 3980000,
          },
        }),
      )!;
      expect(o.pago, isNotNull);
      expect(o.pago!.detalle, isNull);
      expect(o.pago!.consultadoEn, isNull);
    });

    test('un pago roto queda en null y el pedido se ve igual', () {
      final rotos = <String, Map<String, Object?>>{
        'sin operacionId': {
          'proveedor': 'mercadopago',
          'estadoDelProveedor': 'approved',
          'monto': 3980000,
        },
        'sin proveedor': {
          'operacionId': '1',
          'estadoDelProveedor': 'approved',
          'monto': 3980000,
        },
        'sin estadoDelProveedor': {
          'proveedor': 'mercadopago',
          'operacionId': '1',
          'monto': 3980000,
        },
        'sin monto': {
          'proveedor': 'mercadopago',
          'operacionId': '1',
          'estadoDelProveedor': 'approved',
        },
        'monto decimal': {
          'proveedor': 'mercadopago',
          'operacionId': '1',
          'estadoDelProveedor': 'approved',
          'monto': 39800.5,
        },
      };
      for (final entrada in rotos.entries) {
        final o = ordenDesde('x', documento({'pago': entrada.value}));
        expect(o, isNotNull, reason: 'un pedido que desaparece es peor');
        expect(o!.pago, isNull, reason: entrada.key);
      }
      // `pago` que no es ni siquiera un mapa: tampoco tumba el pedido.
      final o = ordenDesde('x', documento({'pago': 'nada'}));
      expect(o, isNotNull);
      expect(o!.pago, isNull);
    });
  });

  group('sePuedeRevisarElPago', () {
    test('solo un pedido de la vidriera con el pago sin cerrar', () {
      for (final origen in Origen.values) {
        for (final estadoPago in EstadoPago.values) {
          final esperado =
              origen == Origen.vidriera &&
              const {
                EstadoPago.pendiente,
                EstadoPago.en_proceso,
                EstadoPago.rechazada,
              }.contains(estadoPago);
          expect(
            _orden(origen: origen, pago: estadoPago).sePuedeRevisarElPago,
            esperado,
            reason: '${origen.name} + ${estadoPago.name}',
          );
        }
      }
    });

    test('control: un pedido de whatsapp pendiente NO se revisa', () {
      expect(
        _orden(
          origen: Origen.whatsapp,
          pago: EstadoPago.pendiente,
        ).sePuedeRevisarElPago,
        isFalse,
      );
    });

    test('control: uno de la vidriera pendiente SI se revisa', () {
      expect(
        _orden(
          origen: Origen.vidriera,
          pago: EstadoPago.pendiente,
        ).sePuedeRevisarElPago,
        isTrue,
      );
    });
  });

  group('los rechazos de revisarPago', () {
    test('sin sesion o sin el claim: sin permiso', () {
      expect(
        falloDeRevision('unauthenticated', null).error,
        ErrorDePedido.sinPermiso,
      );
      expect(
        falloDeRevision('permission-denied', null).error,
        ErrorDePedido.sinPermiso,
      );
    });

    test('un pedido con mala forma: datos invalidos', () {
      expect(
        falloDeRevision('invalid-argument', null).error,
        ErrorDePedido.datosInvalidos,
      );
    });

    test('not-found es el PEDIDO, con el codigo que manda revisar_pago.ts', () {
      expect(
        falloDeRevision('not-found', {'codigo': 'no-existe'}).error,
        ErrorDePedido.pedidoInexistente,
      );
      // Un not-found pelado es, otra vez, la callable que no existe.
      expect(
        falloDeRevision('not-found', null).error,
        ErrorDePedido.desconocido,
      );
    });

    test('el pedido es de WhatsApp: el cobro va por fuera', () {
      expect(
        falloDeRevision('failed-precondition', {'codigo': 'por-fuera'}).error,
        ErrorDePedido.pagoPorFuera,
      );
    });

    test('la orden tiene un dato roto: mismo caso que al cancelar', () {
      expect(
        falloDeRevision('failed-precondition', {'codigo': 'orden-rota'}).error,
        ErrorDePedido.pedidoRoto,
      );
    });

    test('failed-precondition sin detalles conocidos: desconocido', () {
      expect(
        falloDeRevision('failed-precondition', null).error,
        ErrorDePedido.desconocido,
      );
      expect(
        falloDeRevision('failed-precondition', {'codigo': 'otro'}).error,
        ErrorDePedido.desconocido,
      );
    });

    test('mercado pago no contesto: reintentar es seguro', () {
      expect(
        falloDeRevision('unavailable', {'codigo': 'proveedor-caido'}).error,
        ErrorDePedido.proveedorCaido,
      );
    });

    test(
      'control: unavailable SIN el codigo del proveedor es la red de ESTE panel',
      () {
        expect(
          falloDeRevision('unavailable', null).error,
          ErrorDePedido.sinConexion,
        );
      },
    );

    test('los demas codigos de red dicen "no llego"', () {
      for (final c in ['deadline-exceeded', 'cancelled', 'canceled']) {
        expect(
          falloDeRevision(c, null).error,
          ErrorDePedido.sinConexion,
          reason: c,
        );
      }
      // Control: uno que no es de red no lo es.
      expect(
        falloDeRevision('internal', null).error,
        ErrorDePedido.desconocido,
      );
    });
  });

  group('lo devuelto y la alerta (hallazgos de revisor-pagos)', () {
    Map<String, Object?> documento(Map<String, Object?> cambios) => {
      'numero': 7,
      'origen': 'vidriera',
      'estadoPago': 'pagada',
      'estadoEntrega': 'sin_preparar',
      'items': [
        {
          'productoId': 'vino-a',
          'nombre': 'Vino A',
          'precioUnitario': 1990000,
          'cantidad': 2,
          'botellas': 1,
        },
      ],
      'total': 3980000,
      ...cambios,
    };
    const pagoSano = {
      'proveedor': 'mercadopago',
      'operacionId': '1318431457',
      'estadoDelProveedor': 'approved',
      'monto': 3980000,
    };
    const alertaSana = {
      'motivo': 'pago-duplicado',
      'operacionId': '7000000002',
      'estadoDelProveedor': 'approved',
      'monto': 3980000,
    };

    test('lo devuelto se lee; ausente es 0', () {
      final conDevolucion = ordenDesde(
        'x',
        documento({
          'pago': {...pagoSano, 'reembolsado': 1990000},
        }),
      )!;
      expect(conDevolucion.pago!.reembolsado, 1990000);
      final sinDevolucion = ordenDesde('x', documento({'pago': pagoSano}))!;
      expect(sinDevolucion.pago!.reembolsado, 0);
    });

    test('sin alerta escrita, queda en null', () {
      expect(ordenDesde('x', documento({}))!.alertaDePago, isNull);
    });

    test('cada motivo del servidor se lee como el suyo', () {
      final motivos = {
        'pago-duplicado': MotivoDeAlerta.pagoDuplicado,
        'monto-distinto': MotivoDeAlerta.montoDistinto,
        'transicion-invalida': MotivoDeAlerta.transicionInvalida,
        'estado-sin-traduccion': MotivoDeAlerta.estadoSinTraduccion,
      };
      for (final MapEntry(key: crudo, value: motivo) in motivos.entries) {
        final o = ordenDesde(
          'x',
          documento({
            'alertaDePago': {...alertaSana, 'motivo': crudo},
          }),
        )!;
        expect(o.alertaDePago!.motivo, motivo, reason: crudo);
        expect(o.alertaDePago!.operacionId, '7000000002');
      }
    });

    test('un motivo que no se conoce NO esconde la alerta: es plata', () {
      final o = ordenDesde(
        'x',
        documento({
          'alertaDePago': {...alertaSana, 'motivo': 'uno-nuevo-del-servidor'},
        }),
      )!;
      expect(o.alertaDePago, isNotNull);
      expect(o.alertaDePago!.motivo, MotivoDeAlerta.otro);
    });

    test('una alerta rota queda en null y el pedido se ve igual', () {
      for (final falta in ['operacionId', 'estadoDelProveedor', 'monto']) {
        final rota = Map<String, Object?>.of(alertaSana)..remove(falta);
        final o = ordenDesde('x', documento({'alertaDePago': rota}));
        expect(o, isNotNull, reason: falta);
        expect(o!.alertaDePago, isNull, reason: falta);
      }
    });
  });
}
