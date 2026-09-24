import 'package:admin/features/pedidos/data/codigos_de_pedidos.dart';
import 'package:admin/features/pedidos/domain/fallo_de_pedidos.dart';
import 'package:test/test.dart';

/// La traduccion de los codigos que `functions/src/pedidos/crear.ts` lanza de
/// verdad, a lo que la pantalla sabe decir. Los `details` son los MISMOS que
/// asserta `functions/test/pedidos/crear.emulador.mjs`.

void main() {
  test('sin sesion o sin el claim: sin permiso', () {
    expect(
      falloDesdeLaCallable('unauthenticated', null).error,
      ErrorDePedido.sinPermiso,
    );
    expect(
      falloDesdeLaCallable('permission-denied', null).error,
      ErrorDePedido.sinPermiso,
    );
  });

  test('sin stock: trae el vino y cuantas quedan', () {
    final f = falloDesdeLaCallable('failed-precondition', {
      'codigo': 'sin-stock',
      'productoId': 'vino-b',
      'actual': 5,
    });
    expect(f.error, ErrorDePedido.sinStock);
    expect(f.productoId, 'vino-b');
    expect(f.actual, 5);
  });

  test('cambio el precio: trae el de ahora', () {
    final f = falloDesdeLaCallable('failed-precondition', {
      'codigo': 'cambio-el-precio',
      'productoId': 'vino-a',
      'actual': 2100000,
    });
    expect(f.error, ErrorDePedido.cambioElPrecio);
    expect(f.actual, 2100000);
  });

  test('en la web un entero puede llegar como double', () {
    final f = falloDesdeLaCallable('failed-precondition', {
      'codigo': 'sin-stock',
      'productoId': 'vino-b',
      'actual': 5.0,
    });
    expect(f.actual, 5);
  });

  test('los demas rechazos de un vino', () {
    for (final (codigo, esperado) in [
      ('de-muestra', ErrorDePedido.deMuestra),
      ('compuesto', ErrorDePedido.compuesto),
      ('sin-precio', ErrorDePedido.sinPrecio),
      ('producto-roto', ErrorDePedido.productoRoto),
      ('no-existe', ErrorDePedido.noExiste),
    ]) {
      final f = falloDesdeLaCallable('failed-precondition', {
        'codigo': codigo,
        'productoId': 'vino-a',
      });
      expect(f.error, esperado, reason: codigo);
      expect(f.productoId, 'vino-a');
    }
  });

  test('not-found trae el producto que no existe', () {
    final f = falloDesdeLaCallable('not-found', {
      'codigo': 'no-existe',
      'productoId': 'fantasma',
    });
    expect(f.error, ErrorDePedido.noExiste);
    expect(f.productoId, 'fantasma');
  });

  test(
    'el mismo id con otro pedido: ya esta hecho, con el numero que existe',
    () {
      final f = falloDesdeLaCallable('already-exists', {
        'codigo': 'otro-pedido',
        'numero': 7,
      });
      expect(f.error, ErrorDePedido.yaEstaHecho);
      expect(f.numero, 7);
      // Sin detalles sigue siendo "ya esta hecho": solo falta el numero.
      final sin = falloDesdeLaCallable('already-exists', null);
      expect(sin.error, ErrorDePedido.yaEstaHecho);
      expect(sin.numero, isNull);
    },
  );

  test('un pedido con mala forma: datos invalidos', () {
    expect(
      falloDesdeLaCallable('invalid-argument', null).error,
      ErrorDePedido.datosInvalidos,
    );
  });

  test('un failed-precondition sin detalles no se inventa: desconocido', () {
    expect(
      falloDesdeLaCallable('failed-precondition', null).error,
      ErrorDePedido.desconocido,
    );
    expect(
      falloDesdeLaCallable('failed-precondition', {'codigo': 'otro'}).error,
      ErrorDePedido.desconocido,
    );
  });

  test('los codigos de red dicen "no llego", no "me dijeron que no"', () {
    for (final c in [
      'unavailable',
      'deadline-exceeded',
      'cancelled',
      'canceled',
      'retry-limit-exceeded',
    ]) {
      expect(
        falloDesdeLaCallable(c, null).error,
        ErrorDePedido.sinConexion,
        reason: c,
      );
    }
    // Control: un codigo que no es de red no lo es.
    expect(
      falloDesdeLaCallable('internal', null).error,
      ErrorDePedido.desconocido,
    );
  });
}
