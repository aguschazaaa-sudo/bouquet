import 'package:admin/core/contratos/estado_entrega.dart';
import 'package:admin/core/contratos/estado_pago.dart';
import 'package:admin/core/contratos/estado_publico.dart';
import 'package:admin/core/contratos/pedido.dart';
import 'package:admin/features/pedidos/domain/entrega_escrita.dart';
import 'package:admin/features/pedidos/domain/fallo_de_pedidos.dart';
import 'package:admin/features/pedidos/domain/hace_cuanto.dart';
import 'package:admin/features/pedidos/domain/linea_a_cargar.dart';
import 'package:admin/features/pedidos/presentation/textos_de_carga.dart';
import 'package:admin/features/pedidos/presentation/textos_de_pedidos.dart';
import 'package:test/test.dart';

/// Specs `detalle-del-pedido`, `bandeja-de-pedidos` y `cargar-pedido-de-whatsapp`:
/// lo que dicen las pantallas, y hace cuanto se creo un pedido.
///
/// Dart puro con `package:test`: corre en segundos, `flutter test` esta
/// denegado en esta maquina.

/// Todos los textos que estas pantallas pueden mostrar, juntos.
List<String> _todosLosTextos() => [
  textoTituloDePedidos,
  textoCargarUnPedido,
  textoActualizar,
  textoVerMas,
  textoCargandoPedidos,
  textoTotalDeLista,
  textoNoSePudieronLeerLosPedidos,
  textoNoSePudoVerMas,
  for (final e in EstadoEntrega.values) ...[
    textoDelEstado(e),
    textoBandejaVacia(e),
  ],
  textoIncompletos(1),
  textoIncompletos(3),
  textoDelNumero(7),
  for (final o in Origen.values) textoDelOrigen(o),
  textoQueLleva,
  textoQuienLoRecibe,
  textoADondeVa,
  textoElCobroVaPorFuera,
  textoPedidoInexistente,
  textoPedidoIncompleto,
  textoNoSePudoLeerElPedido,
  textoTituloDeCargar,
  textoQueSeLlevan,
  textoSinVinosTodavia,
  textoQuienYDonde,
  textoCargarElPedido,
  textoFaltaAlgo,
  textoTelefonoAyuda,
  textoVaAQuedarComo('+5493515551234'),
  for (final c in CampoDeEntrega.values) textoDelProblema(c),
  for (final m in MotivoNoElegible.values) textoDeMotivoNoElegible(m),
  for (final e in ErrorDePedido.values)
    textoDelFalloDePedidos(
      FalloDePedidos(e, actual: 5, numero: 7, productoId: 'x'),
      nombre: 'Malbec',
    ),
  // Los rotulos que ve el operador en la bandeja y el detalle.
  for (final r in rotulosEstadoPublico.values) r.operador,
];

void main() {
  group('el total es de lista', () {
    test('ningun texto dice "cobrado" ni "pagado"', () {
      // El cobro de un pedido de WhatsApp va por fuera y el panel no lo sigue:
      // decir "cobrado" seria afirmar algo que nadie comprobo (ADR 018 §6).
      // Los rotulos de los estados de plata de la vidriera (`pagada`, `Pago en
      // proceso`) son otra cosa: se acotan a los textos de estas pantallas.
      final pantallas = _todosLosTextos().sublist(
        0,
        _todosLosTextos().length - rotulosEstadoPublico.length,
      );
      for (final t in pantallas) {
        expect(t.toLowerCase(), isNot(contains('cobrado')), reason: t);
        expect(t.toLowerCase(), isNot(contains('pagado')), reason: t);
      }
      // Control positivo: el detector SI ve la palabra, si estuviera.
      expect('Total cobrado'.toLowerCase(), contains('cobrado'));
    });

    test(
      'el rotulo de un pedido de WhatsApp por preparar no afirma un cobro',
      () {
        final r =
            rotulosEstadoPublico[proyectarEstadoPublico(
              EstadoPago.por_fuera,
              EstadoEntrega.sin_preparar,
            )]!;
        expect(r.operador, 'Cobro por fuera - falta preparar');
        expect(r.operador.toLowerCase(), isNot(contains('acreditad')));
        expect(r.cliente.toLowerCase(), isNot(contains('cobrar')));
      },
    );
  });

  group('cada texto de la bandeja', () {
    test('los seis estados tienen su nombre y su bandeja vacia, distintos', () {
      final nombres = EstadoEntrega.values.map(textoDelEstado).toSet();
      final vacias = EstadoEntrega.values.map(textoBandejaVacia).toSet();
      expect(nombres, hasLength(EstadoEntrega.values.length));
      expect(vacias, hasLength(EstadoEntrega.values.length));
      for (final v in vacias) {
        expect(v, isNotEmpty);
      }
    });

    test(
      'los pedidos que no se pudieron leer se cuentan, en singular y plural',
      () {
        expect(textoIncompletos(1), contains('1 pedido'));
        expect(textoIncompletos(3), contains('3 pedidos'));
      },
    );

    test('las botellas, en singular y plural', () {
      expect(textoBotellas(1), '1 botella');
      expect(textoBotellas(4), '4 botellas');
    });
  });

  group('cada rechazo dice que hacer', () {
    test('un stock que cambio dice cuantas quedan y el vino', () {
      final t = textoDelFalloDePedidos(
        const FalloDePedidos(ErrorDePedido.sinStock, actual: 3),
        nombre: 'Malbec',
      );
      expect(t, contains('Malbec'));
      expect(t, contains('quedan 3'));
    });

    test('un precio que cambio dice el de ahora, en pesos', () {
      final t = textoDelFalloDePedidos(
        const FalloDePedidos(ErrorDePedido.cambioElPrecio, actual: 2100000),
        nombre: 'Malbec',
      );
      expect(t, contains('Malbec'));
      expect(t, contains('21.000'));
    });

    test(
      'ya esta hecho manda a abrir el pedido, con su numero, y no a cargar otro',
      () {
        final t = textoDelFalloDePedidos(
          const FalloDePedidos(ErrorDePedido.yaEstaHecho, numero: 7),
        );
        expect(t, contains('pedido 7'));
        expect(t, contains('No lo cargues de nuevo'));
      },
    );

    test(
      'un error de conexion dice que no se sabe si llego, y que reintentar no duplica',
      () {
        final t = textoDelFalloDePedidos(
          const FalloDePedidos(ErrorDePedido.sinConexion),
        );
        expect(t, contains('no sabemos si el pedido llegó'));
        expect(t, contains('no se duplica'));
      },
    );

    test('ningun texto muestra un id ni un codigo crudo del servidor', () {
      for (final e in ErrorDePedido.values) {
        final t = textoDelFalloDePedidos(
          FalloDePedidos(
            e,
            productoId: 'vino-id-interno-9',
            codigo: 'failed-precondition',
          ),
        );
        expect(t, isNot(contains('vino-id-interno-9')), reason: '$e');
        expect(t, isNot(contains('failed-precondition')), reason: '$e');
        expect(t, isNot(contains('HttpsError')), reason: '$e');
      }
    });

    test('el nombre del vino se usa cuando se conoce, y "Ese vino" si no', () {
      const f = FalloDePedidos(ErrorDePedido.deMuestra);
      expect(textoDelFalloDePedidos(f, nombre: 'Malbec'), startsWith('Malbec'));
      expect(textoDelFalloDePedidos(f), startsWith('Ese vino'));
    });
  });

  group('como va a quedar el telefono', () {
    test('lo dice con el 9 separado, antes de confirmar', () {
      expect(
        textoVaAQuedarComo('+5493515551234'),
        'Va a quedar como +54 9 3515551234',
      );
    });
  });

  group('hace cuanto se creo un pedido', () {
    final ahora = DateTime(2026, 9, 24, 15, 30);

    test('sin fecha no inventa una', () {
      expect(haceCuanto(null, ahora), 'sin fecha');
    });

    test('menos de un minuto es "recien", y un reloj adelantado tambien', () {
      expect(
        haceCuanto(ahora.subtract(const Duration(seconds: 20)), ahora),
        'recién',
      );
      expect(
        haceCuanto(ahora.add(const Duration(minutes: 3)), ahora),
        'recién',
      );
    });

    test('minutos, horas y ayer', () {
      expect(
        haceCuanto(ahora.subtract(const Duration(minutes: 5)), ahora),
        'hace 5 min',
      );
      expect(
        haceCuanto(ahora.subtract(const Duration(minutes: 59)), ahora),
        'hace 59 min',
      );
      expect(
        haceCuanto(ahora.subtract(const Duration(hours: 3)), ahora),
        'hace 3 h',
      );
      expect(haceCuanto(DateTime(2026, 9, 23, 9), ahora), 'ayer');
    });

    test('mas viejo, la fecha; con el anio si no es el actual', () {
      expect(haceCuanto(DateTime(2026, 9, 10, 9), ahora), '10/09');
      expect(haceCuanto(DateTime(2025, 12, 31, 9), ahora), '31/12/2025');
    });

    test(
      'cruza el fin de mes: el 1 de octubre, el 30 de septiembre es ayer',
      () {
        // 38 horas: ya no es "hace N h", y "ayer" tiene que ser el 30, no el 0.
        expect(
          haceCuanto(DateTime(2026, 9, 30, 6), DateTime(2026, 10, 1, 20)),
          'ayer',
        );
        // Control: 12 horas antes NO es "ayer" aunque cruce la medianoche.
        expect(
          haceCuanto(DateTime(2026, 9, 30, 20), DateTime(2026, 10, 1, 8)),
          'hace 12 h',
        );
      },
    );
  });
}
