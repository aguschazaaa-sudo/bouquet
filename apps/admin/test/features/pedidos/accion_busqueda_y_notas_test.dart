import 'package:admin/core/contratos/estado_entrega.dart';
import 'package:admin/core/contratos/estado_pago.dart';
import 'package:admin/core/contratos/estado_publico.dart';
import 'package:admin/features/pedidos/data/cambios_de_nota.dart';
import 'package:admin/features/pedidos/domain/nota_del_pedido.dart';
import 'package:admin/features/pedidos/domain/numero_buscado.dart';
import 'package:admin/features/pedidos/domain/para_hacer.dart';
import 'package:admin/features/pedidos/domain/vista_de_bandeja.dart';
import 'package:test/test.dart';

/// HU-06.4 y HU-07.7 (ADR 020), y las fichas de ADR 027: que la consulta de
/// *Para hacer* cubra exactamente los pares que tiene que cubrir, que el
/// buscador lea un número sin inventarlo, y lo que se escribe al anotar.

/// Los pares que la consulta trae, desarmando los tramos.
Set<String> _paresDe(List<TramoParaHacer> tramos) => {
  for (final t in tramos)
    for (final p in t.pagos ?? EstadoPago.values) '${p.name}|${t.entrega.name}',
};

void main() {
  group('ADR 027: los tramos de "Para hacer"', () {
    test('cubren EXACTAMENTE lo que no salió, lo que volvió y lo terminado que '
        'pide plata', () {
      final esperados = {
        for (final p in EstadoPago.values)
          for (final e in EstadoEntrega.values)
            if (entregasParaHacer.contains(e) ||
                estadosPublicosQueRequierenAccion.contains(
                  proyectarEstadoPublico(p, e),
                ))
              '${p.name}|${e.name}',
      };
      // Control positivo: el conjunto no puede estar vacío por un error de
      // lectura y confirmar cualquier cosa.
      expect(esperados, contains('por_fuera|sin_preparar'));
      expect(esperados, contains('pendiente|entregada'));
      expect(_paresDe(tramosParaHacer()), esperados);
    });

    test('un pedido de la tienda que espera el pago está: no queda en ninguna '
        'ficha', () {
      final pares = _paresDe(tramosParaHacer());
      expect(pares, contains('pendiente|sin_preparar'));
      expect(pares, contains('en_proceso|sin_preparar'));
      // Y lo que quedó en `preparando` antes de ADR 027, con cualquier pago.
      expect(pares, contains('por_fuera|preparando'));
    });

    test('lo que salió o terminó sin plata pendiente NO entra (control '
        'negativo)', () {
      final pares = _paresDe(tramosParaHacer());
      expect(pares, isNot(contains('por_fuera|despachada')));
      expect(pares, isNot(contains('pagada|despachada')));
      expect(pares, isNot(contains('por_fuera|entregada')));
      expect(pares, isNot(contains('por_fuera|cancelada')));
    });

    test('cinco tramos: los tres enteros sin filtrar por pago', () {
      final tramos = tramosParaHacer();
      expect(tramos.map((t) => t.entrega), [
        EstadoEntrega.sin_preparar,
        EstadoEntrega.preparando,
        EstadoEntrega.entregada,
        EstadoEntrega.fallida,
        EstadoEntrega.cancelada,
      ]);
      for (final e in entregasParaHacer) {
        expect(tramos.singleWhere((t) => t.entrega == e).pagos, isNull);
      }
    });

    test('entra en el tope de 30 disjuntos de Firestore', () {
      final total = tramosParaHacer().fold(0, (a, t) => a + t.disjuntos);
      expect(total, 8);
      expect(total, lessThanOrEqualTo(30));
    });
  });

  group('ADR 027: las fichas de la bandeja', () {
    test('tres, y "Para hacer" va primero', () {
      expect(VistaDeBandeja.values, [
        VistaDeBandeja.paraHacer,
        VistaDeBandeja.enCamino,
        VistaDeBandeja.terminados,
      ]);
    });

    test('igualdad por valor: es la clave de la familia del provider', () {
      expect(VistaDeBandeja.values[1], VistaDeBandeja.enCamino);
      expect(
        VistaDeBandeja.values[1].hashCode,
        VistaDeBandeja.enCamino.hashCode,
      );
      expect(VistaDeBandeja.paraHacer, isNot(VistaDeBandeja.terminados));
    });
  });

  group('HU-06.4: el número que se busca', () {
    test('lee lo que se copia de un chat', () {
      expect(numeroBuscado('123'), 123);
      expect(numeroBuscado(' 123 '), 123);
      expect(numeroBuscado('#123'), 123);
      expect(numeroBuscado('Pedido 123'), 123);
      expect(numeroBuscado('N.º 7'), 7);
    });

    test('no inventa un número', () {
      expect(numeroBuscado(''), isNull);
      expect(numeroBuscado('   '), isNull);
      expect(numeroBuscado('pedido'), isNull);
      expect(numeroBuscado('12 3'), isNull);
      expect(numeroBuscado('123abc'), isNull);
      expect(numeroBuscado('0'), isNull);
      expect(
        numeroBuscado('-4'),
        4,
        reason: 'el guion es un prefijo, no un signo',
      );
    });

    test('un teléfono pegado no se busca como pedido', () {
      expect(numeroBuscado('123456789'), 123456789);
      expect(numeroBuscado('3515551234'), isNull);
    });
  });

  group('HU-07.7: la nota', () {
    test('se guarda sin espacios de más, y vacía se borra', () {
      expect(notaAGuardar('  llamar antes \n'), 'llamar antes');
      expect(notaAGuardar(''), isNull);
      expect(notaAGuardar('  \n '), isNull);
    });

    test('el tope es el de las reglas, contado después de limpiar', () {
      expect(notaEntra('x' * largoMaximoDeNota), isTrue);
      expect(notaEntra('x' * (largoMaximoDeNota + 1)), isFalse);
      expect(notaEntra('  ${'x' * largoMaximoDeNota}  '), isTrue);
      expect(notaEntra(''), isTrue);
    });

    test('escribe SOLO las dos claves que acepta anota()', () {
      const hora = Object();
      const borrar = Object();
      final con = cambiosDeNota(
        'falta una',
        horaDelServidor: hora,
        borrar: borrar,
      );
      expect(con.keys.toSet(), {'notasOperador', 'actualizadaEn'});
      expect(con['notasOperador'], 'falta una');
      expect(con['actualizadaEn'], same(hora));

      final sin = cambiosDeNota(null, horaDelServidor: hora, borrar: borrar);
      expect(sin['notasOperador'], same(borrar));
      expect(sin.containsKey('estadoEntrega'), isFalse);
    });
  });
}
