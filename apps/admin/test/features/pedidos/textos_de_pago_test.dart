import 'package:admin/core/contratos/estado_pago.dart';
import 'package:admin/core/contratos/plata.dart';
import 'package:admin/features/pedidos/domain/alerta_de_pago.dart';
import 'package:admin/features/pedidos/domain/fallo_de_pedidos.dart';
import 'package:admin/features/pedidos/domain/repositorio_de_pedidos.dart';
import 'package:admin/features/pedidos/presentation/textos_de_pago.dart';
import 'package:test/test.dart';

/// Spec `detalle-del-pedido`: lo que dice la sección del cobro de un pedido de
/// la vidriera (HU-08.1) y el botón "Volver a consultar a Mercado Pago"
/// (HU-08.3).
///
/// Dart puro con `package:test`: corre en segundos, `flutter test` está
/// denegado en esta máquina.

void main() {
  group('el estado del pago, en palabras', () {
    test('los seis EstadoPago tienen un texto, y son todos distintos', () {
      final textos = EstadoPago.values.map(textoEstadoDelPago).toSet();
      expect(textos, hasLength(EstadoPago.values.length));
      for (final t in textos) {
        expect(t, isNotEmpty);
      }
    });

    test('ninguno muestra el estado crudo del proveedor', () {
      // Los que Mercado Pago manda de verdad (ADR 022): si alguno se
      // colara tal cual, no lo entendería quien no maneja Mercado Pago.
      const crudos = [
        'approved',
        'pending',
        'in_process',
        'rejected',
        'refunded',
        'cancelled',
      ];
      for (final e in EstadoPago.values) {
        final t = textoEstadoDelPago(e).toLowerCase();
        for (final crudo in crudos) {
          expect(t, isNot(contains(crudo)), reason: '$e -> $t');
        }
      }
      // Control positivo: el detector SI ve la palabra, si estuviera.
      expect('approved'.contains('approved'), isTrue);
    });
  });

  group('la operación para conciliar', () {
    test('dice el proveedor y el número, tal cual', () {
      final t = textoOperacion('123456789');
      expect(t, contains('Mercado Pago'));
      expect(t, contains('123456789'));
    });

    test('dos operaciones distintas dan textos distintos', () {
      expect(textoOperacion('1'), isNot(textoOperacion('2')));
    });
  });

  group('el monto que informó Mercado Pago no coincide con el total', () {
    test('dice los dos montos, formateados como en el resto del panel', () {
      final t = textoMontoNoCoincide(2100000, 2500000);
      expect(t, contains('21.000'));
      expect(t, contains('25.000'));
    });

    test('dice que un monto distinto no se marca pagado', () {
      final t = textoMontoNoCoincide(1000, 2000);
      expect(t.toLowerCase(), contains('no se marca'));
    });
  });

  group('los tres resultados de "volver a consultar"', () {
    test('sin ningún pago para conciliar', () {
      const r = ResultadoDeRevision(
        estadoPago: EstadoPago.pendiente,
        cambio: false,
        encontrados: 0,
      );
      expect(textoDelResultadoDeRevision(r), textoSinPagoEncontrado);
    });

    test('la revisión movió el estado: avisa cuál es el nuevo', () {
      const r = ResultadoDeRevision(
        estadoPago: EstadoPago.pagada,
        cambio: true,
        encontrados: 1,
      );
      final t = textoDelResultadoDeRevision(r);
      expect(t, contains(textoEstadoDelPago(EstadoPago.pagada)));
      expect(t, isNot(textoSinPagoEncontrado));
    });

    test('la revisión no movió nada: dice que sigue igual', () {
      const r = ResultadoDeRevision(
        estadoPago: EstadoPago.rechazada,
        cambio: false,
        encontrados: 1,
      );
      final t = textoDelResultadoDeRevision(r);
      expect(t, contains('Sigue igual'));
      expect(t, contains(textoEstadoDelPago(EstadoPago.rechazada)));
    });

    test('0 encontrados manda primero, aunque cambio venga en true', () {
      const r = ResultadoDeRevision(
        estadoPago: EstadoPago.pendiente,
        cambio: true,
        encontrados: 0,
      );
      expect(textoDelResultadoDeRevision(r), textoSinPagoEncontrado);
    });
  });

  group('cuando no se pudo volver a consultar', () {
    test('el proveedor caído tiene su propio mensaje', () {
      final t = textoDelFalloDePago(
        const FalloDePedidos(ErrorDePedido.proveedorCaido),
      );
      expect(t, contains('Mercado Pago'));
      expect(t.toLowerCase(), contains('no contestó'));
    });

    test('sin conexión usa el mensaje genérico, no el del proveedor caído', () {
      final t = textoDelFalloDePago(
        const FalloDePedidos(ErrorDePedido.sinConexion),
      );
      expect(t.toLowerCase(), isNot(contains('no contestó')));
      expect(t, isNotEmpty);
    });

    test('un error desconocido también usa el mensaje genérico', () {
      final conocido = textoDelFalloDePago(
        const FalloDePedidos(ErrorDePedido.sinConexion),
      );
      final desconocido = textoDelFalloDePago(
        const FalloDePedidos(ErrorDePedido.desconocido),
      );
      expect(desconocido, conocido);
    });

    test('ningun texto de fallo muestra un codigo crudo del servidor', () {
      for (final e in ErrorDePedido.values) {
        final t = textoDelFalloDePago(FalloDePedidos(e, codigo: 'internal'));
        expect(t, isNot(contains('internal')), reason: '$e');
        expect(t, isNot(contains('HttpsError')), reason: '$e');
      }
    });
  });

  group('la alerta: plata que el pedido no refleja', () {
    AlertaDePago alerta(MotivoDeAlerta m) => AlertaDePago(
      motivo: m,
      operacionId: '7000000002',
      estadoDelProveedor: 'charged_back',
      monto: 3980000,
    );

    test('cada motivo tiene su texto, y todos dicen la operación', () {
      final textos = MotivoDeAlerta.values.map((m) => textoDeLaAlerta(alerta(m)));
      expect(textos.toSet().length, MotivoDeAlerta.values.length);
      for (final t in textos) {
        expect(t, contains('7000000002'));
        expect(t, contains('Mercado Pago'));
      }
    });

    test('el segundo cobro dice que hay que devolverlo, con el monto', () {
      final t = textoDeLaAlerta(alerta(MotivoDeAlerta.pagoDuplicado));
      expect(t, contains('dos veces'));
      expect(t, contains('devolver'));
      expect(t, contains(enPesos(3980000)));
    });

    test('ninguna alerta muestra el estado crudo del proveedor', () {
      for (final m in MotivoDeAlerta.values) {
        expect(textoDeLaAlerta(alerta(m)), isNot(contains('charged_back')), reason: '$m');
      }
      // Control positivo: el crudo SI esta en la alerta, para buscarlo en Mercado Pago.
      expect(alerta(MotivoDeAlerta.otro).estadoDelProveedor, 'charged_back');
    });
  });
}
