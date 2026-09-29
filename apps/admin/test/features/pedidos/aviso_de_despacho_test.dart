import 'package:admin/core/contratos/despacho.dart';
import 'package:admin/core/contratos/estado_entrega.dart';
import 'package:admin/core/contratos/estado_pago.dart';
import 'package:admin/core/contratos/pedido.dart';
import 'package:admin/core/contratos/telefono.dart';
import 'package:admin/features/pedidos/domain/aviso_de_despacho.dart';
import 'package:admin/features/pedidos/domain/despacho_de_orden.dart';
import 'package:admin/features/pedidos/domain/orden.dart';
import 'package:admin/features/pedidos/presentation/textos_del_aviso.dart';
import 'package:test/test.dart';

/// HU-07.3: qué mensaje le toca a cada estado, que el enlace `wa.me` lleve al
/// chat correcto con el texto entero —o vacío—, y los textos que lee el
/// comprador (curados por `voz`).

const _items = [
  ItemDeOrden(
    productoId: 'malbec-reserva',
    nombre: 'Malbec Reserva',
    precioUnitario: 1000000,
    cantidad: 2,
    botellas: 1,
  ),
  ItemDeOrden(
    productoId: 'torrontes',
    nombre: 'Torrontés',
    precioUnitario: 800000,
    cantidad: 1,
    botellas: 1,
  ),
];

Orden _orden({
  EstadoEntrega entrega = EstadoEntrega.despachada,
  DespachoDeOrden? despacho = const DespachoDeOrden(correo: Correo.andreani),
  EntregaFallida? entregaFallida,
  String nombre = 'Marta',
}) => Orden(
  id: 'pedido-de-prueba-0001',
  numero: 1184,
  origen: Origen.whatsapp,
  estadoPago: EstadoPago.por_fuera,
  estadoEntrega: entrega,
  items: _items,
  subtotal: 0,
  total: 0,
  contacto: ContactoDeOrden(nombre: nombre, telefonoE164: '+5493541234567'),
  entrega: const EntregaDeOrden(
    calle: 'San Martin',
    numero: '120',
    codigoPostal: '5152',
    localidad: 'Villa Carlos Paz',
    provincia: 'X',
  ),
  despacho: despacho,
  entregaFallida: entregaFallida,
);

void main() {
  group('mensajeSegun', () {
    test('un mensaje por estado, en los seis', () {
      final esperado = {
        EstadoEntrega.sin_preparar: isA<PedidoAnotado>(),
        EstadoEntrega.preparando: isA<PedidoAnotado>(),
        EstadoEntrega.despachada: isA<PedidoSalio>(),
        EstadoEntrega.fallida: isA<PedidoNoSeEntrego>(),
        EstadoEntrega.entregada: isA<PedidoLlego>(),
        EstadoEntrega.cancelada: isNull,
      };
      expect(esperado.keys, containsAll(EstadoEntrega.values));
      for (final e in EstadoEntrega.values) {
        expect(mensajeSegun(_orden(entrega: e)), esperado[e], reason: e.name);
      }
    });

    test('despachado sin el dato de por dónde salió: chat vacío', () {
      expect(mensajeSegun(_orden(despacho: null)), isNull);
    });

    test('la entrega fallida lleva su motivo, y sin motivo va null', () {
      final con = mensajeSegun(
        _orden(
          entrega: EstadoEntrega.fallida,
          entregaFallida: const EntregaFallida(motivo: MotivoDeFalla.nadie),
        ),
      );
      expect((con! as PedidoNoSeEntrego).motivo, MotivoDeFalla.nadie);
      final sin = mensajeSegun(_orden(entrega: EstadoEntrega.fallida));
      expect((sin! as PedidoNoSeEntrego).motivo, isNull);
    });
  });

  group('textoDelMensaje', () {
    test('anotado: los vinos, uno por renglón, y sin el total', () {
      final t = textoDelMensaje(
        const PedidoAnotado(),
        _orden(entrega: EstadoEntrega.sin_preparar),
      );
      expect(
        t,
        'Hola, Marta. Anotamos tu pedido #1184:\n\n'
        '2 × Malbec Reserva\n'
        '1 × Torrontés\n\n'
        'Te avisamos por acá cuando salga.',
      );
      expect(t, isNot(contains(r'$')));
    });

    test('anotado sin líneas no deja un renglón vacío', () {
      expect(
        textoDelAnotado(nombre: null, numero: 7, items: const []),
        'Hola. Anotamos tu pedido #7.\n\nTe avisamos por acá cuando salga.',
      );
    });

    test('salió: es el aviso de ADR 021, sin cambios', () {
      const d = DespachoDeOrden(correo: Correo.oca, seguimiento: 'X9');
      expect(
        textoDelMensaje(const PedidoSalio(d), _orden()),
        textoDelAviso(
          nombre: 'Marta',
          numero: 1184,
          correo: Correo.oca,
          seguimiento: 'X9',
        ),
      );
    });

    test('llegó', () {
      expect(
        textoDelMensaje(
          const PedidoLlego(),
          _orden(entrega: EstadoEntrega.entregada, nombre: 'Ana María'),
        ),
        'Hola, Ana. ¿Llegó todo bien con tu pedido #1184?\n\n'
        'Si necesitás algo, escribinos por acá.',
      );
    });
  });

  group('textoDeNoSeEntrego', () {
    String t(MotivoDeFalla? m) =>
        textoDeNoSeEntrego(nombre: 'Marta', numero: 5, motivo: m);
    const coordinamos =
        '\n\nCoordinamos otra entrega cuando quieras. El pedido está guardado.';

    test('sin un mayor de 18: el texto de voz.md §9.7', () {
      expect(
        t(MotivoDeFalla.sinMayor),
        'Hola, Marta. No pudimos entregarte el pedido #5: no había nadie mayor '
        'de 18 para recibirlo.$coordinamos',
      );
    });

    test('no había nadie', () {
      expect(
        t(MotivoDeFalla.nadie),
        'Hola, Marta. No pudimos entregarte el pedido #5: no había nadie para '
        'recibirlo.$coordinamos',
      );
    });

    test('la dirección: pide la dirección de nuevo', () {
      expect(
        t(MotivoDeFalla.direccion),
        'Hola, Marta. No pudimos entregarte el pedido #5: no dimos con la '
        'dirección.\n\nMandanos la dirección de nuevo y coordinamos otra '
        'entrega. El pedido está guardado.',
      );
    });

    test('un rechazo no dice "no pudimos": sin culpable', () {
      final r = t(MotivoDeFalla.rechazo);
      expect(r, 'Hola, Marta. Tu pedido #5 quedó sin entregar.$coordinamos');
      expect(r, isNot(contains('No pudimos')));
    });

    test('otro, y sin motivo: sin inventar uno', () {
      const sinMotivo =
          'Hola, Marta. No pudimos entregarte el pedido #5.$coordinamos';
      expect(t(MotivoDeFalla.otro), sinMotivo);
      expect(t(null), sinMotivo);
    });
  });

  test('ningún mensaje lleva exclamación, y todos dicen el número (voz.md)', () {
    final textos = [
      textoDelAnotado(nombre: 'Ana', numero: 1, items: _items),
      textoDeLlego(nombre: 'Ana', numero: 1),
      for (final m in [...MotivoDeFalla.values, null])
        textoDeNoSeEntrego(nombre: 'Ana', numero: 1, motivo: m),
    ];
    for (final t in textos) {
      expect(t, isNot(contains('!')), reason: t);
      expect(t, contains('#1'), reason: t);
      expect(t, startsWith('Hola, Ana. '), reason: t);
    }
  });

  group('enlaceDeWhatsapp', () {
    const texto = 'Hola, Marta. Tu pedido #1184 ya salió.\n\nSeguimiento: A&B';

    test('va al chat del comprador: los dígitos, sin el +', () {
      final u = enlaceDeWhatsapp('+5493541234567', texto)!;
      expect(u.scheme, 'https');
      expect(u.host, 'wa.me');
      expect(u.path, '/5493541234567');
    });

    test('el texto llega ENTERO: #, & y los saltos no lo cortan', () {
      final u = enlaceDeWhatsapp('+5493541234567', texto)!;
      expect(u.queryParameters.keys, ['text']);
      expect(u.queryParameters['text'], texto);
      expect(u.fragment, isEmpty);
    });

    test('el espacio va como %20, nunca como +', () {
      final crudo = enlaceDeWhatsapp('+5493541234567', 'a b')!.toString();
      expect(crudo, 'https://wa.me/5493541234567?text=a%20b');
    });

    test('sin texto, el chat vacío: ni ?text= ni un texto vacío', () {
      final u = enlaceDeWhatsapp('+5493541234567', null)!;
      expect(u.toString(), 'https://wa.me/5493541234567');
      expect(u.queryParameters, isEmpty);
    });

    test('sin texto, un teléfono que no es E.164 tampoco arma enlace', () {
      expect(enlaceDeWhatsapp('03541 15-123456', null), isNull);
    });

    test('lo que sale del normalizador arma enlace (control positivo)', () {
      final e164 = normalizarTelefonoAR('0351 15-555-1234')!;
      expect(enlaceDeWhatsapp(e164, 'x'), isNotNull);
    });

    test('un teléfono que no es E.164 no arma enlace', () {
      for (final malo in [
        '',
        '5493541234567',
        '03541 15-123456',
        '+0543541234567',
        '+54 9 3541 23-4567',
        '+5493541234567999999',
      ]) {
        expect(enlaceDeWhatsapp(malo, 'x'), isNull, reason: malo);
      }
    });
  });

  group('nombreDePila', () {
    test('la primera palabra, sin espacios', () {
      expect(nombreDePila('María José Pérez'), 'María');
      expect(nombreDePila('  Juan  '), 'Juan');
    });

    test('sin nombre, null: el saludo va sin nombre', () {
      expect(nombreDePila(''), isNull);
      expect(nombreDePila('   '), isNull);
    });
  });

  group('textoDelAviso', () {
    test('con correo, seguimiento y nombre', () {
      expect(
        textoDelAviso(
          nombre: 'Marta',
          numero: 1184,
          correo: Correo.andreani,
          seguimiento: 'AR123',
        ),
        'Hola, Marta. Tu pedido #1184 ya salió por Andreani.\n\n'
        'El número de seguimiento es AR123.\n\n'
        'Si necesitás algo, escribinos por acá.',
      );
    });

    test('en mano y sin nombre', () {
      expect(
        textoDelAviso(nombre: null, numero: 9, correo: Correo.enMano),
        'Hola. Tu pedido #9 ya salió: te lo llevamos nosotros.\n\n'
        'Si necesitás algo, escribinos por acá.',
      );
    });

    test('"otro" no nombra un correo', () {
      final t = textoDelAviso(nombre: 'Ana', numero: 9, correo: Correo.otro);
      expect(t, startsWith('Hola, Ana. Tu pedido #9 ya salió.\n\n'));
      expect(t, isNot(contains('Otro')));
    });

    test('ningún caso lleva exclamación, y todos dicen el número (voz.md §7.1)',
        () {
      for (final c in Correo.values) {
        for (final s in [null, 'X1']) {
          final t = textoDelAviso(
            nombre: 'Ana',
            numero: 1,
            correo: c,
            seguimiento: s,
          );
          expect(t, isNot(contains('!')), reason: '$c $s');
          expect(t, contains('#1 '), reason: '$c $s');
        }
      }
    });
  });
}
