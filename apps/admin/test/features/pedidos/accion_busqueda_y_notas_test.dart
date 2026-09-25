import 'package:admin/core/contratos/estado_entrega.dart';
import 'package:admin/core/contratos/estado_pago.dart';
import 'package:admin/core/contratos/estado_publico.dart';
import 'package:admin/features/pedidos/data/cambios_de_nota.dart';
import 'package:admin/features/pedidos/domain/lo_que_requiere_accion.dart';
import 'package:admin/features/pedidos/domain/nota_del_pedido.dart';
import 'package:admin/features/pedidos/domain/numero_buscado.dart';
import 'package:admin/features/pedidos/domain/vista_de_bandeja.dart';
import 'package:test/test.dart';

/// HU-06.3, HU-06.4 y HU-07.7 (ADR 020): que la consulta de *"Requieren acción"*
/// cubra exactamente los pares de la proyección, que el buscador lea un número
/// sin inventarlo, y lo que se escribe al anotar.

/// Los pares que la consulta trae, desarmando los tramos.
Set<String> _paresDe(List<TramoQueRequiereAccion> tramos) => {
  for (final t in tramos)
    for (final p in t.pagos ?? EstadoPago.values) '${p.name}|${t.entrega.name}',
};

void main() {
  group('HU-06.3: los tramos de la consulta', () {
    test('cubren EXACTAMENTE los pares que la proyección marca con acción', () {
      final esperados = {
        for (final p in EstadoPago.values)
          for (final e in EstadoEntrega.values)
            if (estadosPublicosQueRequierenAccion.contains(
              proyectarEstadoPublico(p, e),
            ))
              '${p.name}|${e.name}',
      };
      // Control positivo: el conjunto no puede estar vacío por un error de
      // lectura y confirmar cualquier cosa.
      expect(esperados, contains('por_fuera|sin_preparar'));
      expect(esperados, contains('pendiente|entregada'));
      expect(_paresDe(tramosQueRequierenAccion()), esperados);
    });

    test('los que NO requieren acción no entran (control negativo)', () {
      final pares = _paresDe(tramosQueRequierenAccion());
      expect(pares, isNot(contains('por_fuera|entregada')));
      expect(pares, isNot(contains('por_fuera|cancelada')));
      expect(pares, isNot(contains('pendiente|sin_preparar')));
      expect(pares, isNot(contains('pagada|despachada')));
    });

    test('hoy son cuatro tramos, y fallida no filtra por pago', () {
      final tramos = tramosQueRequierenAccion();
      expect(tramos.map((t) => t.entrega), [
        EstadoEntrega.sin_preparar,
        EstadoEntrega.entregada,
        EstadoEntrega.fallida,
        EstadoEntrega.cancelada,
      ]);
      expect(
        tramos.singleWhere((t) => t.entrega == EstadoEntrega.fallida).pagos,
        isNull,
      );
      expect(
        tramos
            .singleWhere((t) => t.entrega == EstadoEntrega.sin_preparar)
            .pagos,
        [EstadoPago.pagada, EstadoPago.por_fuera],
      );
    });

    test('entra en el tope de 30 disjuntos de Firestore', () {
      final total = tramosQueRequierenAccion().fold(
        0,
        (a, t) => a + t.disjuntos,
      );
      expect(total, 8);
      expect(total, lessThanOrEqualTo(30));
    });
  });

  group('HU-06.3: las fichas de la bandeja', () {
    test('"Requieren acción" va primero, y después los seis estados', () {
      expect(VistaDeBandeja.todas.first, const RequierenAccion());
      expect(VistaDeBandeja.todas.skip(1), [
        for (final e in EstadoEntrega.values) DeUnEstado(e),
      ]);
    });

    test('igualdad por valor: es la clave de la familia del provider', () {
      expect(
        const DeUnEstado(EstadoEntrega.fallida),
        DeUnEstado(EstadoEntrega.values[4]),
      );
      expect(
        const DeUnEstado(EstadoEntrega.fallida).hashCode,
        DeUnEstado(EstadoEntrega.values[4]).hashCode,
      );
      expect(
        const DeUnEstado(EstadoEntrega.fallida),
        isNot(const DeUnEstado(EstadoEntrega.cancelada)),
      );
      expect(const RequierenAccion(), isNot(VistaDeBandeja.todas[1]));
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
