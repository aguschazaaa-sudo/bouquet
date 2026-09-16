// El permiso sale del claim `rol`, y los codigos de Firebase se traducen a
// lo que dice la pantalla. specs/panel-acceso.

import 'package:admin/features/acceso/data/codigos_de_auth.dart';
import 'package:admin/features/acceso/domain/repositorio_de_sesion.dart';
import 'package:admin/features/acceso/domain/sesion.dart';
import 'package:test/test.dart';

void main() {
  group('sesionDesde', () {
    test('rol admin es operador (control positivo)', () {
      final sesion = sesionDesde(
        mail: 'familia@gmail.com',
        claims: {'rol': 'admin', 'otro': 1},
      );
      expect(sesion, isA<Operador>());
      expect((sesion as Operador).mail, 'familia@gmail.com');
    });

    test('sin claims no tiene permiso', () {
      final sesion = sesionDesde(mail: 'x@gmail.com', claims: null);
      expect(sesion, isA<SinPermiso>());
      expect((sesion as SinPermiso).mail, 'x@gmail.com');
    });

    test('otro rol no tiene permiso', () {
      expect(
        sesionDesde(mail: 'x@gmail.com', claims: {'rol': 'repartidor'}),
        isA<SinPermiso>(),
      );
    });

    test('el valor tiene que ser exacto', () {
      expect(
        sesionDesde(mail: 'x@gmail.com', claims: {'rol': 'Admin'}),
        isA<SinPermiso>(),
      );
      expect(
        sesionDesde(mail: 'x@gmail.com', claims: {'admin': true}),
        isA<SinPermiso>(),
      );
    });

    test('una cuenta sin mail no rompe', () {
      final sesion = sesionDesde(mail: null, claims: {'rol': 'admin'});
      expect((sesion as Operador).mail, '');
    });

    test('el rol es el mismo string que miran las reglas', () {
      expect(rolDelPanel, 'admin');
    });
  });

  group('errorDeEntradaPara', () {
    test('mail o contrasena equivocados es un solo mensaje', () {
      for (final codigo in [
        'invalid-credential',
        'invalid-login-credentials',
        'wrong-password',
        'user-not-found',
      ]) {
        expect(
          errorDeEntradaPara(codigo),
          ErrorDeEntrada.credencialesInvalidas,
          reason: codigo,
        );
      }
    });

    test('cerrar la ventana de Google no es un error', () {
      expect(errorDeEntradaPara('popup-closed-by-user'), isNull);
      expect(errorDeEntradaPara('cancelled-popup-request'), isNull);
    });

    test('demasiados intentos no dice que la contrasena esta mal', () {
      expect(
        errorDeEntradaPara('too-many-requests'),
        ErrorDeEntrada.demasiadosIntentos,
      );
    });

    test('un dominio no autorizado se nombra', () {
      expect(
        errorDeEntradaPara('unauthorized-domain'),
        ErrorDeEntrada.sitioNoHabilitado,
      );
    });

    test('un codigo desconocido no se traga (control negativo)', () {
      expect(
        errorDeEntradaPara('codigo-inventado-de-control'),
        ErrorDeEntrada.desconocido,
      );
    });
  });
}
