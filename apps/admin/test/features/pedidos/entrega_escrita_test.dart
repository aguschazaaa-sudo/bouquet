import 'package:admin/core/contratos/pedido.dart';
import 'package:admin/features/pedidos/domain/entrega_escrita.dart';
import 'package:test/test.dart';

/// HU-10.1: lo que el operador escribe de quien recibe y a donde va. Espeja
/// `validarDatosDeEntrega` de `packages/contratos`; los casos son los mismos que
/// prueba `packages/contratos/test/pedido.test.ts` del lado del servidor.

const _valida = EntregaEscrita(
  nombre: 'Marta Gomez',
  telefono: '0351 15-555-1234',
  calle: 'San Martin',
  numero: '120',
  codigoPostal: '5000',
  localidad: 'Cordoba',
  provincia: 'X',
);

void main() {
  test('una entrega completa no tiene problemas', () {
    expect(_valida.primerProblema, isNull);
    for (final c in CampoDeEntrega.values) {
      expect(_valida.esValido(c), isTrue, reason: c.name);
    }
  });

  group('cada campo, con el que pasa y el que no', () {
    test('nombre: de 2 a 120 caracteres', () {
      expect(
        _valida.copiarCon(nombre: 'Ma').esValido(CampoDeEntrega.nombre),
        isTrue,
      );
      expect(
        _valida.copiarCon(nombre: 'M').esValido(CampoDeEntrega.nombre),
        isFalse,
      );
      expect(
        _valida.copiarCon(nombre: '   ').esValido(CampoDeEntrega.nombre),
        isFalse,
      );
      expect(
        _valida.copiarCon(nombre: 'x' * 120).esValido(CampoDeEntrega.nombre),
        isTrue,
      );
      expect(
        _valida.copiarCon(nombre: 'x' * 121).esValido(CampoDeEntrega.nombre),
        isFalse,
      );
    });

    test('telefono: el que se puede normalizar', () {
      expect(_valida.esValido(CampoDeEntrega.telefono), isTrue);
      expect(
        _valida
            .copiarCon(telefono: '12345678')
            .esValido(CampoDeEntrega.telefono),
        isFalse,
      );
      expect(
        _valida.copiarCon(telefono: '').esValido(CampoDeEntrega.telefono),
        isFalse,
      );
    });

    test('email: puede faltar, pero escrito tiene que tener forma', () {
      expect(
        _valida.esValido(CampoDeEntrega.email),
        isTrue,
        reason: 'en blanco',
      );
      expect(
        _valida
            .copiarCon(email: 'marta@ejemplo.com')
            .esValido(CampoDeEntrega.email),
        isTrue,
      );
      expect(
        _valida.copiarCon(email: 'marta@').esValido(CampoDeEntrega.email),
        isFalse,
      );
      expect(
        _valida
            .copiarCon(email: 'sin arroba.com')
            .esValido(CampoDeEntrega.email),
        isFalse,
      );
    });

    test('calle: al menos 2 caracteres; numero: no vacio', () {
      expect(
        _valida.copiarCon(calle: 'X').esValido(CampoDeEntrega.calle),
        isFalse,
      );
      expect(
        _valida.copiarCon(numero: '').esValido(CampoDeEntrega.numero),
        isFalse,
      );
      expect(
        _valida.copiarCon(numero: 's/n').esValido(CampoDeEntrega.numero),
        isTrue,
      );
    });

    test('codigo postal: cuatro digitos', () {
      for (final malo in ['50', '50000', 'X500', '5 00', '']) {
        expect(
          _valida
              .copiarCon(codigoPostal: malo)
              .esValido(CampoDeEntrega.codigoPostal),
          isFalse,
          reason: '"$malo"',
        );
      }
      expect(
        _valida
            .copiarCon(codigoPostal: ' 5000 ')
            .esValido(CampoDeEntrega.codigoPostal),
        isTrue,
        reason: 'los espacios de los costados no cuentan',
      );
    });

    test('localidad no vacia; provincia, uno de los 24 codigos ISO', () {
      expect(
        _valida.copiarCon(localidad: ' ').esValido(CampoDeEntrega.localidad),
        isFalse,
      );
      expect(
        _valida.copiarCon(provincia: '').esValido(CampoDeEntrega.provincia),
        isFalse,
      );
      expect(
        _valida.copiarCon(provincia: 'ZZ').esValido(CampoDeEntrega.provincia),
        isFalse,
      );
      // El codigo, no el nombre: es lo que el correo espera.
      expect(
        _valida
            .copiarCon(provincia: 'Cordoba')
            .esValido(CampoDeEntrega.provincia),
        isFalse,
      );
    });
  });

  group('cada texto libre tiene su tope de largo, como en el servidor', () {
    // El borde pasa y uno mas no. Sin el tope, una referencia de 900.000
    // caracteres deja la Orden cerca del MiB de Firestore.
    test('los obligatorios, en el campo que se marca', () {
      final casos = <CampoDeEntrega, EntregaEscrita Function(String)>{
        CampoDeEntrega.nombre: (t) => _valida.copiarCon(nombre: t),
        CampoDeEntrega.calle: (t) => _valida.copiarCon(calle: t),
        CampoDeEntrega.numero: (t) => _valida.copiarCon(numero: t),
        CampoDeEntrega.localidad: (t) => _valida.copiarCon(localidad: t),
      };
      final claves = {
        CampoDeEntrega.nombre: 'nombre',
        CampoDeEntrega.calle: 'calle',
        CampoDeEntrega.numero: 'numero',
        CampoDeEntrega.localidad: 'localidad',
      };
      for (final entrada in casos.entries) {
        final largo = largosDeEntrega[claves[entrada.key]]!;
        expect(
          entrada.value('x' * largo).esValido(entrada.key),
          isTrue,
          reason: '${entrada.key.name} en el borde',
        );
        expect(
          entrada.value('x' * (largo + 1)).esValido(entrada.key),
          isFalse,
          reason: '${entrada.key.name} pasado',
        );
      }
    });

    test('el mail: la forma y el largo', () {
      String mail(int n) => '${'a' * (n - '@e.co'.length)}@e.co';
      final largo = largosDeEntrega['email']!;
      expect(
        _valida.copiarCon(email: mail(largo)).esValido(CampoDeEntrega.email),
        isTrue,
      );
      expect(
        _valida
            .copiarCon(email: mail(largo + 1))
            .esValido(CampoDeEntrega.email),
        isFalse,
      );
    });

    test(
      'el piso y la referencia bloquean el envio, sin ser un campo propio',
      () {
        expect(_valida.sePuedeMandar, isTrue);
        final piso = largosDeEntrega['piso']!;
        final referencia = largosDeEntrega['referencia']!;
        expect(_valida.copiarCon(piso: 'x' * piso).sePuedeMandar, isTrue);
        expect(
          _valida.copiarCon(piso: 'x' * (piso + 1)).sePuedeMandar,
          isFalse,
        );
        expect(
          _valida.copiarCon(referencia: 'x' * referencia).sePuedeMandar,
          isTrue,
        );
        expect(
          _valida.copiarCon(referencia: 'x' * (referencia + 1)).sePuedeMandar,
          isFalse,
        );
        // No tienen un campo que marcar: `primerProblema` no los ve.
        expect(
          _valida.copiarCon(piso: 'x' * (piso + 1)).primerProblema,
          isNull,
        );
      },
    );
  });

  test('el primer problema es el primero en el orden del formulario', () {
    final e = _valida.copiarCon(telefono: '1', localidad: '');
    expect(e.primerProblema, CampoDeEntrega.telefono);
    expect(_valida.copiarCon(nombre: '').primerProblema, CampoDeEntrega.nombre);
  });

  test('el telefono pegado del chat queda normalizado', () {
    expect(_valida.telefonoNormalizado, '+5493515551234');
    expect(_valida.copiarCon(telefono: 'abc').telefonoNormalizado, isNull);
  });

  test('aJson recorta los espacios y manda el codigo de provincia', () {
    final j = _valida
        .copiarCon(nombre: '  Marta  ', piso: ' 3B ', codigoPostal: ' 5000 ')
        .aJson;
    expect(j['nombre'], 'Marta');
    expect(j['piso'], '3B');
    final destino = j['destino'] as Map;
    expect(destino['codigoPostal'], '5000');
    expect(destino['provincia'], 'X');
    expect(j.containsKey('propio'), isFalse);
    expect(
      destino.containsKey('propio'),
      isFalse,
      reason: 'lo decide el servidor',
    );
  });
}
