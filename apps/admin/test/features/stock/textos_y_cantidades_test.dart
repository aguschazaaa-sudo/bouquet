import 'dart:math';

import 'package:admin/core/contratos/stock.dart';
import 'package:admin/features/stock/domain/cantidad_escrita.dart';
import 'package:admin/features/stock/domain/fallo_de_stock.dart';
import 'package:admin/features/stock/domain/id_de_movimiento.dart';
import 'package:admin/features/stock/presentation/textos_del_stock.dart';
import 'package:test/test.dart';

/// Lo que se lee, se cuenta y se dice en las hojas de stock. Dart puro.
void main() {
  group('leerCantidad', () {
    test('digitos, y el punto de miles de es-AR', () {
      expect(leerCantidad('6'), 6);
      expect(leerCantidad('  24 '), 24);
      expect(leerCantidad('0'), 0);
      expect(leerCantidad('1.500'), 1500);
      expect(leerCantidad('12.345'), 12345);
    });

    test('lo que NO es una cantidad da null, no un numero adivinado', () {
      for (final malo in [
        '',
        '  ',
        '-3',
        '1,5',
        '1.5',
        '12.34',
        'seis',
        '1 000',
        '1..000',
        '+4',
      ]) {
        expect(leerCantidad(malo), isNull, reason: "'$malo'");
      }
    });
  });

  group('nuevoIdDeMovimiento', () {
    test('32 hexadecimales: entra en lo que acepta el parser de contratos', () {
      final id = nuevoIdDeMovimiento();
      expect(id, matches(RegExp(r'^[0-9a-f]{32}$')));
      // La regla de contratos: [A-Za-z0-9_-]{16,64}.
      expect(id, matches(RegExp(r'^[A-Za-z0-9_-]{16,64}$')));
    });

    test('dos ids seguidos no coinciden', () {
      final ids = {for (var i = 0; i < 200; i++) nuevoIdDeMovimiento()};
      expect(ids, hasLength(200));
    });

    test('con el mismo azar da el mismo id: no hay estado escondido', () {
      expect(nuevoIdDeMovimiento(Random(7)), nuevoIdDeMovimiento(Random(7)));
      expect(
        nuevoIdDeMovimiento(Random(7)),
        isNot(nuevoIdDeMovimiento(Random(8))),
      );
    });
  });

  group('describirElStock: la unidad de venta manda', () {
    test('botellas sueltas', () {
      expect(describirElStock(10, botellas: 1), '10 botellas');
      expect(describirElStock(1, botellas: 1), '1 botella');
      expect(describirElStock(0, botellas: 1), '0 botellas');
    });

    test('una caja se cuenta en cajas, con las botellas al lado', () {
      expect(describirElStock(4, botellas: 6), '4 cajas de 6 · 24 botellas');
      expect(describirElStock(1, botellas: 6), '1 caja de 6 · 6 botellas');
      // "Sumar 6" a una caja de 2 son doce botellas.
      expect(describirElStock(6, botellas: 2), '6 cajas de 2 · 12 botellas');
    });

    test('unidadDeVenta', () {
      expect(unidadDeVenta(1), 'botellas');
      expect(unidadDeVenta(6), 'cajas de 6');
    });
  });

  group('reponer: lo que se dice antes de confirmar', () {
    test('cuenta el resultado', () {
      expect(
        comoQuedaAlReponer(4, 6, botellas: 1),
        'Va a quedar en 10 botellas.',
      );
      expect(
        comoQuedaAlReponer(1, 2, botellas: 6),
        'Va a quedar en 3 cajas de 6 · 18 botellas.',
      );
    });

    test(
      'no cuenta lo que no se puede: nada escrito, cero, o pasado el tope',
      () {
        expect(comoQuedaAlReponer(4, null, botellas: 1), isNull);
        expect(comoQuedaAlReponer(4, 0, botellas: 1), isNull);
        expect(comoQuedaAlReponer(4995, 6, botellas: 1), isNull);
      },
    );

    test('el aviso: vacio espera, y cada problema se dice', () {
      expect(avisoDeReposicion(4, null, escrito: ''), isNull);
      expect(avisoDeReposicion(4, 6, escrito: '6'), isNull);
      expect(
        avisoDeReposicion(4, null, escrito: 'abc'),
        contains('solo el número'),
      );
      expect(avisoDeReposicion(4, 0, escrito: '0'), contains('mayor que cero'));
      expect(avisoDeReposicion(4, 5001, escrito: '5001'), contains('5.000'));
      final pasa = avisoDeReposicion(4995, 6, escrito: '6');
      expect(pasa, contains('5.000'));
      expect(pasa, contains('4995'));
    });

    test('el borde exacto: hasta el tope si, una mas no', () {
      expect(avisoDeReposicion(4990, 10, escrito: '10'), isNull);
      expect(avisoDeReposicion(4990, 11, escrito: '11'), isNotNull);
    });
  });

  group('corregir: lo que se dice antes de guardar', () {
    test('la diferencia, con su signo', () {
      expect(
        comoQuedaAlCorregir(10, 7, botellas: 1),
        'Pasa de 10 botellas a 7 botellas (−3).',
      );
      expect(
        comoQuedaAlCorregir(3, 12, botellas: 1),
        'Pasa de 3 botellas a 12 botellas (+9).',
      );
    });

    test('no dice nada si no hay cambio o no hay numero', () {
      expect(comoQuedaAlCorregir(10, 10, botellas: 1), isNull);
      expect(comoQuedaAlCorregir(10, null, botellas: 1), isNull);
    });

    test('el aviso: mismo numero, negativo y pasado el tope', () {
      expect(avisoDeCorreccion(10, null, escrito: ''), isNull);
      expect(avisoDeCorreccion(10, 7, escrito: '7'), isNull);
      expect(avisoDeCorreccion(10, 0, escrito: '0'), isNull);
      expect(avisoDeCorreccion(10, 10, escrito: '10'), contains('Ya figura'));
      expect(avisoDeCorreccion(10, 5001, escrito: '5001'), contains('5.000'));
      expect(
        avisoDeCorreccion(10, null, escrito: 'x'),
        contains('solo el número'),
      );
    });

    test('lo que el aviso deja pasar, el espejo del contrato tambien', () {
      // El aviso y `Corregir.esValida` no pueden discrepar: un aviso que
      // calla sobre algo que el contrato rechaza deja un boton que no anda.
      for (final valor in [0, 1, 7, 9, 10, 11, 4999, 5000, 5001]) {
        final sinAviso =
            avisoDeCorreccion(10, valor, escrito: '$valor') == null;
        final valida = Corregir(
          visto: 10,
          valor: valor,
          motivo: MotivoDeAjuste.conteo,
        ).esValida;
        expect(sinAviso, valida, reason: 'valor $valor');
      }
    });

    test('lo mismo para reponer', () {
      for (final n in [0, 1, 6, 4990, 4995, 5000, 5001]) {
        final sinAviso = avisoDeReposicion(5, n, escrito: '$n') == null;
        final valida =
            Reponer(n).esValida && aplicarOperacion(5, Reponer(n)) is Aplica;
        expect(sinAviso, valida, reason: 'cantidad $n');
      }
    });
  });

  group('textoDelFalloDeStock', () {
    test(
      'cada error tiene su texto, ninguno vacio, ninguno con el codigo crudo',
      () {
        for (final e in ErrorDeStock.values) {
          final t = textoDelFalloDeStock(
            FalloDeStock(e, actual: 8, codigo: 'codigo-crudo'),
          );
          expect(t, isNotEmpty, reason: '$e');
          expect(t, isNot(contains('codigo-crudo')), reason: '$e');
        }
      },
    );

    test('cambio el stock: dice el numero de ahora', () {
      final t = textoDelFalloDeStock(
        const FalloDeStock(ErrorDeStock.cambioElStock, actual: 8),
      );
      expect(t, contains('8'));
      expect(t, contains('contar'));
    });

    test('sin conexion NO dice "no se guardo": puede haberse guardado', () {
      final t = textoDelFalloDeStock(
        const FalloDeStock(ErrorDeStock.sinConexion),
      );
      expect(t, isNot(contains('no se guardó')));
      expect(t, contains('Puede que ya se haya guardado'));
    });
  });
}
