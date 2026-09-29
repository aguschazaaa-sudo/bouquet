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

/// HU-07.3: cuándo el chat se abre con el aviso, que el enlace `wa.me` lleve al
/// chat correcto con el texto entero —o vacío—, y el texto que lee el comprador.

Orden _orden({
  EstadoEntrega entrega = EstadoEntrega.despachada,
  DespachoDeOrden? despacho = const DespachoDeOrden(correo: Correo.andreani),
}) => Orden(
  id: 'pedido-de-prueba-0001',
  numero: 1184,
  origen: Origen.whatsapp,
  estadoPago: EstadoPago.por_fuera,
  estadoEntrega: entrega,
  items: const [],
  subtotal: 0,
  total: 0,
  contacto: const ContactoDeOrden(
    nombre: 'Marta',
    telefonoE164: '+5493541234567',
  ),
  entrega: const EntregaDeOrden(
    calle: 'San Martin',
    numero: '120',
    codigoPostal: '5152',
    localidad: 'Villa Carlos Paz',
    provincia: 'X',
  ),
  despacho: despacho,
);

void main() {
  group('sePuedeAvisar', () {
    test('sólo un pedido despachado, en los seis estados', () {
      for (final e in EstadoEntrega.values) {
        expect(
          sePuedeAvisar(_orden(entrega: e)),
          e == EstadoEntrega.despachada,
          reason: e.name,
        );
      }
    });

    test('despachado sin el dato de por dónde salió, no', () {
      expect(sePuedeAvisar(_orden(despacho: null)), isFalse);
    });
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
