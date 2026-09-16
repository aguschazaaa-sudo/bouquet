// A donde manda el panel a cada sesion. specs/panel-estructura y
// specs/panel-acceso de openspec/changes/panel-entrar.
//
// Dart puro: corre con `dart test` (en CI, alcance tests o panel).

import 'package:admin/app/destino.dart';
import 'package:admin/app/rutas.dart';
import 'package:admin/features/acceso/domain/sesion.dart';
import 'package:test/test.dart';

String? ir(Sesion sesion, String url) => destinoPara(sesion, Uri.parse(url));

void main() {
  const operador = Operador('familia@gmail.com');
  const sinPermiso = SinPermiso('otro@gmail.com');

  group('sin sesion', () {
    test('una seccion manda a entrar y recuerda cual era', () {
      final destino = Uri.parse(ir(const SinSesion(), '/pedidos')!);
      expect(destino.path, Rutas.entrar);
      expect(destino.queryParameters['desde'], Rutas.pedidos);
    });

    test('en /entrar se queda (control: no hay bucle)', () {
      expect(ir(const SinSesion(), '/entrar?desde=%2Fpedidos'), isNull);
    });

    test('la raiz manda a entrar sin desde', () {
      expect(ir(const SinSesion(), '/'), Rutas.entrar);
    });

    test('desde /espera conserva a donde iba', () {
      final destino = Uri.parse(
        ir(const SinSesion(), '/espera?desde=%2Fpedidos')!,
      );
      expect(destino.path, Rutas.entrar);
      expect(destino.queryParameters['desde'], Rutas.pedidos);
    });
  });

  group('resolviendo', () {
    test('recargar en /pedidos espera y recuerda /pedidos', () {
      final destino = Uri.parse(ir(const Resolviendo(), '/pedidos')!);
      expect(destino.path, Rutas.espera);
      expect(destino.queryParameters['desde'], Rutas.pedidos);
    });

    test('en /espera se queda', () {
      expect(ir(const Resolviendo(), '/espera?desde=%2Fpedidos'), isNull);
    });
  });

  group('sin permiso', () {
    test('una seccion por URL vuelve a /sin-acceso', () {
      expect(ir(sinPermiso, '/catalogo'), Rutas.sinAcceso);
    });

    test('/entrar tambien', () {
      expect(ir(sinPermiso, '/entrar'), Rutas.sinAcceso);
    });

    test('en /sin-acceso se queda', () {
      expect(ir(sinPermiso, '/sin-acceso'), isNull);
    });

    test('un token ilegible va al mismo lugar', () {
      expect(ir(const Inaccesible('x@gmail.com'), '/pedidos'), Rutas.sinAcceso);
    });
  });

  group('operador', () {
    test('se queda en una seccion (control positivo)', () {
      expect(ir(operador, '/pedidos'), isNull);
    });

    test('al entrar vuelve a desde', () {
      expect(ir(operador, '/entrar?desde=%2Fpedidos'), Rutas.pedidos);
    });

    test('al entrar sin desde va a Catalogo', () {
      expect(ir(operador, '/entrar'), Rutas.catalogo);
    });

    test('desde /sin-acceso, con el permiso recien dado, va a Catalogo', () {
      expect(ir(operador, '/sin-acceso'), Rutas.catalogo);
    });

    test('la raiz va a Catalogo', () {
      expect(ir(operador, '/'), Rutas.catalogo);
    });

    test('una ruta inventada se deja pasar a la pagina no encontrada', () {
      expect(ir(operador, '/ruta-que-no-existe'), isNull);
    });

    test('recargar una ruta inventada la conserva hasta resolverse', () {
      final espera = ir(const Resolviendo(), '/ruta-que-no-existe')!;
      expect(ir(operador, espera), '/ruta-que-no-existe');
    });
  });

  group('desde no es una redireccion abierta', () {
    for (final malo in [
      'https://otro.com/catalogo',
      '//otro.com/catalogo',
      'catalogo',
      '/entrar',
      '/',
    ]) {
      test('desde=$malo cae en Catalogo', () {
        final url = Uri(
          path: Rutas.entrar,
          queryParameters: {'desde': malo},
        ).toString();
        expect(ir(operador, url), Rutas.catalogo);
      });
    }
  });
}
