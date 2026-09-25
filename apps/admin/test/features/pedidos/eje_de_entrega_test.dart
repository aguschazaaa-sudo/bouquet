import 'package:admin/core/contratos/despacho.dart';
import 'package:admin/core/contratos/estado_entrega.dart';
import 'package:admin/core/contratos/estado_pago.dart';
import 'package:admin/core/contratos/pedido.dart';
import 'package:admin/features/pedidos/data/cambios_de_entrega.dart';
import 'package:admin/features/pedidos/data/codigos_de_pedidos.dart';
import 'package:admin/features/pedidos/data/documento_de_la_orden.dart';
import 'package:admin/features/pedidos/domain/fallo_de_pedidos.dart';
import 'package:admin/features/pedidos/domain/orden.dart';
import 'package:admin/features/pedidos/domain/paso_de_entrega.dart';
import 'package:admin/features/pedidos/presentation/textos_de_entrega.dart';
import 'package:test/test.dart';

/// EP-07, ADR 019: que se ofrece desde cada estado, que se escribe por cada
/// paso, como se traducen los rechazos y como se lee lo que quedo en la Orden.
///
/// Las listas y las dos reglas del contrato se comparan contra el JSON en
/// `test/core/contratos/despacho_test.dart`; aca se prueba lo que el panel
/// arma ENCIMA de eso.

Orden _orden({
  EstadoEntrega entrega = EstadoEntrega.sin_preparar,
  Origen origen = Origen.whatsapp,
  EstadoPago pago = EstadoPago.por_fuera,
}) => Orden(
  id: 'pedido-de-prueba-0001',
  numero: 7,
  origen: origen,
  estadoPago: pago,
  estadoEntrega: entrega,
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
  group('lo que se ofrece desde cada estado', () {
    test('un pedido de WhatsApp recorre la tabla entera', () {
      final esperado = {
        EstadoEntrega.sin_preparar: [
          AccionDelPedido.preparar,
          AccionDelPedido.cancelar,
        ],
        EstadoEntrega.preparando: [
          AccionDelPedido.despachar,
          AccionDelPedido.cancelar,
        ],
        EstadoEntrega.despachada: [
          AccionDelPedido.entregar,
          AccionDelPedido.noSeEntrego,
        ],
        EstadoEntrega.fallida: [AccionDelPedido.despachar],
        EstadoEntrega.entregada: <AccionDelPedido>[],
        EstadoEntrega.cancelada: <AccionDelPedido>[],
      };
      for (final MapEntry(key: estado, value: acciones) in esperado.entries) {
        expect(
          accionesDe(_orden(entrega: estado)),
          acciones,
          reason: estado.name,
        );
      }
    });

    test('un despachado NO se cancela: el envio ya costo', () {
      for (final estado in [
        EstadoEntrega.despachada,
        EstadoEntrega.entregada,
        EstadoEntrega.fallida,
      ]) {
        expect(
          accionesDe(_orden(entrega: estado)),
          isNot(contains(AccionDelPedido.cancelar)),
        );
      }
    });

    test('uno de la tienda impago no se despacha, y se dice por que', () {
      final impago = _orden(
        entrega: EstadoEntrega.preparando,
        origen: Origen.vidriera,
        pago: EstadoPago.pendiente,
      );
      expect(accionesDe(impago), [AccionDelPedido.cancelar]);
      expect(despachoEsperaElPago(impago), isTrue);

      final pagado = _orden(
        entrega: EstadoEntrega.preparando,
        origen: Origen.vidriera,
        pago: EstadoPago.pagada,
      );
      expect(accionesDe(pagado), contains(AccionDelPedido.despachar));
      expect(despachoEsperaElPago(pagado), isFalse);
    });

    test('uno de WhatsApp nunca espera el pago', () {
      for (final e in EstadoEntrega.values) {
        expect(
          despachoEsperaElPago(_orden(entrega: e)),
          isFalse,
          reason: e.name,
        );
      }
    });
  });

  group('el seguimiento', () {
    test('se guarda sin espacios, y vacio es null', () {
      expect(seguimientoDe('  AND-123  '), 'AND-123');
      expect(seguimientoDe('   '), isNull);
      expect(seguimientoDe(''), isNull);
    });

    test('hasta el largo del contrato', () {
      final justo = 'x' * largoDelSeguimiento;
      expect(seguimientoEsValido(justo), isTrue);
      expect(seguimientoDe(justo), justo);
      expect(seguimientoEsValido('${justo}x'), isFalse);
      // Los espacios de las puntas no cuentan.
      expect(seguimientoEsValido('  $justo  '), isTrue);
    });
  });

  group('lo que se escribe por cada paso: el estado, la hora y SU campo', () {
    const hora = 'HORA-DEL-SERVIDOR';

    test('preparar y entregar: solo el estado y la hora', () {
      expect(cambiosDe(const Preparar(), horaDelServidor: hora), {
        'estadoEntrega': 'preparando',
        'actualizadaEn': hora,
      });
      expect(cambiosDe(const Entregar(), horaDelServidor: hora), {
        'estadoEntrega': 'entregada',
        'actualizadaEn': hora,
      });
    });

    test('despachar: el despacho con las TRES claves que piden las reglas', () {
      expect(
        cambiosDe(
          const Despachar(correo: Correo.correoArgentino, seguimiento: 'CA1'),
          horaDelServidor: hora,
        ),
        {
          'estadoEntrega': 'despachada',
          'actualizadaEn': hora,
          'despacho': {
            'correo': 'correo_argentino',
            'seguimiento': 'CA1',
            'en': hora,
          },
        },
      );
      // Sin seguimiento la clave va igual, en null: las reglas la exigen.
      final sin = cambiosDe(
        const Despachar(correo: Correo.enMano),
        horaDelServidor: hora,
      );
      final despacho = sin['despacho'] as Map;
      expect(despacho.containsKey('seguimiento'), isTrue);
      expect(despacho['seguimiento'], isNull);
    });

    test('no se entrego: el motivo y la hora', () {
      expect(
        cambiosDe(
          const NoSeEntrego(MotivoDeFalla.sinMayor),
          horaDelServidor: hora,
        ),
        {
          'estadoEntrega': 'fallida',
          'actualizadaEn': hora,
          'entregaFallida': {'motivo': 'sin_mayor', 'en': hora},
        },
      );
    });

    test('ningun paso escribe cancelada: eso es de la callable', () {
      for (final paso in const <PasoDeEntrega>[
        Preparar(),
        Despachar(correo: Correo.oca),
        Entregar(),
        NoSeEntrego(MotivoDeFalla.nadie),
      ]) {
        expect(
          soloLoEscribeElServidor,
          isNot(contains(paso.destino)),
          reason: '$paso',
        );
      }
    });
  });

  group('los rechazos', () {
    test(
      'cancelar: los codigos que lanza functions/src/pedidos/cancelar.ts',
      () {
        expect(
          falloDeCancelar('failed-precondition', {
            'codigo': 'ya-salio',
            'estado': 'despachada',
          }).error,
          ErrorDePedido.yaSalio,
        );
        expect(
          falloDeCancelar('failed-precondition', {
            'codigo': 'orden-rota',
          }).error,
          ErrorDePedido.pedidoRoto,
        );
        // Aca un not-found es el PEDIDO, no un vino como en crearOrdenDelPanel.
        expect(
          falloDeCancelar('not-found', {'codigo': 'no-existe'}).error,
          ErrorDePedido.pedidoInexistente,
        );
        // Un not-found SIN el codigo es la callable que no existe (un panel
        // publicado antes que la funcion): no es "el pedido ya no existe".
        expect(
          falloDeCancelar('not-found', null).error,
          ErrorDePedido.desconocido,
        );
        expect(
          falloDeCancelar('permission-denied', null).error,
          ErrorDePedido.sinPermiso,
        );
        expect(
          falloDeCancelar('unavailable', null).error,
          ErrorDePedido.sinConexion,
        );
        expect(
          falloDeCancelar('failed-precondition', null).error,
          ErrorDePedido.desconocido,
        );
      },
    );

    test('una escritura rechazada por las reglas es un pedido que cambio', () {
      expect(
        falloDeEscritura('permission-denied').error,
        ErrorDePedido.cambioElPedido,
      );
      expect(
        falloDeEscritura('not-found').error,
        ErrorDePedido.pedidoInexistente,
      );
      expect(falloDeEscritura('unavailable').error, ErrorDePedido.sinConexion);
      expect(falloDeEscritura('internal').error, ErrorDePedido.desconocido);
    });

    test('los que dicen que lo que se ve ya no es lo que hay, releen', () {
      expect(
        hayQueReleer(const FalloDePedidos(ErrorDePedido.cambioElPedido)),
        isTrue,
      );
      expect(hayQueReleer(const FalloDePedidos(ErrorDePedido.yaSalio)), isTrue);
      // Sin conexion NO: el pedido que se ve sigue siendo el ultimo que se sabe,
      // y el error queda escrito para reintentar.
      expect(
        hayQueReleer(const FalloDePedidos(ErrorDePedido.sinConexion)),
        isFalse,
      );
    });
  });

  group('lo que queda en la Orden', () {
    Map<String, Object?> documento(Map<String, Object?> cambios) => {
      'numero': 7,
      'origen': 'whatsapp',
      'estadoPago': 'por_fuera',
      'estadoEntrega': 'despachada',
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
    final hora = DateTime(2026, 9, 25, 10);
    DateTime? horaDe(Object? v) => v == 'T' ? hora : null;

    test('el despacho, con su correo, su seguimiento y su hora', () {
      final o = ordenDesde(
        'x',
        documento({
          'despacho': {'correo': 'oca', 'seguimiento': 'OCA-1', 'en': 'T'},
        }),
        horaDe: horaDe,
      )!;
      expect(o.despacho?.correo, Correo.oca);
      expect(o.despacho?.seguimiento, 'OCA-1');
      expect(o.despacho?.en, hora);
    });

    test('un despacho raro queda en null y el pedido se ve igual', () {
      final o = ordenDesde(
        'x',
        documento({
          'despacho': {'correo': 'paloma'},
          'entregaFallida': 'nadie',
          'cancelacion': 3,
        }),
      );
      expect(o, isNotNull, reason: 'un pedido que desaparece es peor');
      expect(o!.despacho, isNull);
      expect(o.entregaFallida, isNull);
      expect(o.cancelacion, isNull);
    });

    test('la entrega fallida, con su motivo', () {
      final o = ordenDesde(
        'x',
        documento({
          'estadoEntrega': 'fallida',
          'entregaFallida': {'motivo': 'sin_mayor', 'en': 'T'},
        }),
        horaDe: horaDe,
      )!;
      expect(o.entregaFallida?.motivo, MotivoDeFalla.sinMayor);
      expect(o.entregaFallida?.en, hora);
    });

    test('la cancelacion con lo que NO volvio, aunque el motivo sea nuevo', () {
      final o = ordenDesde(
        'x',
        documento({
          'estadoEntrega': 'cancelada',
          'cancelacion': {
            'motivo': 'uno-que-no-conozco',
            'sinReponer': [
              {
                'productoId': 'vino-a',
                'nombre': 'Vino A',
                'cantidad': 2,
                'motivo': 'no_existe',
              },
            ],
          },
        }),
      )!;
      expect(o.cancelacion, isNotNull);
      expect(o.cancelacion!.motivo, isNull);
      expect(
        o.cancelacion!.sinReponer.single.motivo,
        MotivoSinReponer.noExiste,
      );
      expect(o.cancelacion!.sinReponer.single.cantidad, 2);
    });

    test('lo que devuelve la callable en la web: un entero como double', () {
      final lineas = lineasSinReponerDesde([
        {
          'productoId': 'a',
          'nombre': 'A',
          'cantidad': 2.0,
          'motivo': 'compuesto',
        },
        {'productoId': 'b', 'cantidad': 1.5},
        {'cantidad': 1},
      ]);
      expect(
        lineas.length,
        1,
        reason: 'la fraccion y la sin id no se inventan',
      );
      expect(lineas.single.cantidad, 2);
      expect(lineas.single.motivo, MotivoSinReponer.compuesto);
    });
  });

  group('los textos', () {
    test('cada accion, correo y motivo tiene su texto', () {
      for (final a in AccionDelPedido.values) {
        expect(textoDeLaAccion(a), isNotEmpty);
      }
      for (final c in Correo.values) {
        expect(textoRotuloDelCorreo(c), isNotEmpty);
      }
      for (final m in MotivoDeFalla.values) {
        expect(textoDelMotivoDeFalla(m), isNotEmpty);
      }
      for (final m in MotivoDeCancelacion.values) {
        expect(textoDelMotivoDeCancelacion(m), isNotEmpty);
      }
    });

    test('la confirmacion de entrega dice la condicion legal', () {
      expect(textoConfirmarEntrega, contains('mayor de 18'));
      expect(textoCondicionDeEntrega, contains('mayor de 18'));
    });

    test('ningun texto de EP-07 dice "cobrado" ni "pagado"', () {
      final textos = [
        textoCondicionDeEntrega,
        textoDespuesDeLaFalla,
        textoCancelarNoSeDeshace,
        textoNoVolvieron,
        textoEsperaElPago,
        for (final e in ErrorDePedido.values)
          textoDelFalloDeEntrega(FalloDePedidos(e)),
        textoCancelado(7, repetido: false, sinReponer: 0),
        textoCancelado(7, repetido: false, sinReponer: 1),
        textoCancelado(7, repetido: true, sinReponer: 0),
      ];
      for (final t in textos) {
        expect(t.toLowerCase(), isNot(contains('cobrado')), reason: t);
        expect(t.toLowerCase(), isNot(contains('pagado')), reason: t);
      }
    });

    test('cancelar con lineas sin reponer manda a mirar el detalle', () {
      expect(
        textoCancelado(7, repetido: false, sinReponer: 1),
        contains('no volvieron'),
      );
      expect(
        textoCancelado(7, repetido: false, sinReponer: 0),
        contains('su stock volvió'),
      );
    });
  });
}
