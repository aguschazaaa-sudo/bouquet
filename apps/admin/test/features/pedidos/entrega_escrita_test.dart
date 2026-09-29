import 'package:admin/core/contratos/pedido.dart';
import 'package:admin/features/pedidos/domain/entrega_escrita.dart';
import 'package:test/test.dart';

/// HU-10.1 y ADR 027: lo que el operador escribe de quien recibe y a donde va.
/// Espeja `validarEntregaDelPanel` de `packages/contratos`; los casos son los
/// mismos que prueba `packages/contratos/test/pedido.test.ts` del lado del
/// servidor.

const _valida = EntregaEscrita(
  nombre: 'Marta Gomez',
  telefono: '0351 15-555-1234',
  direccion: 'San Martin 120',
  localidad: 'Cordoba',
);

void main() {
  test('nombre, telefono, direccion y localidad alcanzan: sin el detalle', () {
    expect(_valida.primerProblema, isNull);
    expect(_valida.sePuedeMandar, isTrue);
    for (final c in CampoDeEntrega.values) {
      expect(_valida.esValido(c), isTrue, reason: c.name);
    }
  });

  test('son cuatro los obligatorios, en el orden del formulario (ADR 027)', () {
    expect(CampoDeEntrega.values, [
      CampoDeEntrega.nombre,
      CampoDeEntrega.telefono,
      CampoDeEntrega.direccion,
      CampoDeEntrega.localidad,
    ]);
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

    test('direccion: al menos 2 caracteres, con el numero adentro o no', () {
      expect(
        _valida.copiarCon(direccion: 'X').esValido(CampoDeEntrega.direccion),
        isFalse,
      );
      expect(
        _valida.copiarCon(direccion: '  ').esValido(CampoDeEntrega.direccion),
        isFalse,
      );
      expect(
        _valida
            .copiarCon(direccion: 'Ruta 38 km 12')
            .esValido(CampoDeEntrega.direccion),
        isTrue,
      );
    });

    test('localidad: no vacia', () {
      expect(
        _valida.copiarCon(localidad: ' ').esValido(CampoDeEntrega.localidad),
        isFalse,
      );
    });
  });

  group('cada texto libre tiene su tope de largo, como en el servidor', () {
    // El borde pasa y uno mas no. Sin el tope, una referencia de 900.000
    // caracteres deja la Orden cerca del MiB de Firestore.
    test('los obligatorios, en el campo que se marca', () {
      final casos = <CampoDeEntrega, (String, EntregaEscrita Function(String))>{
        CampoDeEntrega.nombre: ('nombre', (t) => _valida.copiarCon(nombre: t)),
        CampoDeEntrega.direccion: (
          'calle',
          (t) => _valida.copiarCon(direccion: t),
        ),
        CampoDeEntrega.localidad: (
          'localidad',
          (t) => _valida.copiarCon(localidad: t),
        ),
      };
      for (final MapEntry(key: campo, value: (clave, con)) in casos.entries) {
        final largo = largosDeEntrega[clave]!;
        expect(
          con('x' * largo).esValido(campo),
          isTrue,
          reason: '${campo.name} en el borde',
        );
        expect(
          con('x' * (largo + 1)).esValido(campo),
          isFalse,
          reason: '${campo.name} pasado',
        );
      }
    });

    test('el detalle bloquea el envio, sin ser un campo propio', () {
      final tope = largosDeEntrega['referencia']!;
      expect(_valida.copiarCon(detalle: 'x' * tope).sePuedeMandar, isTrue);
      expect(
        _valida.copiarCon(detalle: 'x' * (tope + 1)).sePuedeMandar,
        isFalse,
      );
      // No tiene un campo que marcar: `primerProblema` no lo ve.
      expect(
        _valida.copiarCon(detalle: 'x' * (tope + 1)).primerProblema,
        isNull,
      );
    });
  });

  test('el primer problema es el primero en el orden del formulario', () {
    final e = _valida.copiarCon(telefono: '1', localidad: '');
    expect(e.primerProblema, CampoDeEntrega.telefono);
    expect(_valida.copiarCon(nombre: '').primerProblema, CampoDeEntrega.nombre);
    expect(
      _valida.copiarCon(direccion: '', localidad: '').primerProblema,
      CampoDeEntrega.direccion,
    );
  });

  test('el telefono pegado del chat queda normalizado', () {
    expect(_valida.telefonoNormalizado, '+5493515551234');
    expect(_valida.copiarCon(telefono: 'abc').telefonoNormalizado, isNull);
  });

  test('aJson es la forma corta: recorta, y NO manda numero, codigo postal, '
      'provincia ni mail', () {
    final j = _valida
        .copiarCon(nombre: '  Marta  ', detalle: ' 3B, porton verde ')
        .aJson;
    expect(j, {
      'nombre': 'Marta',
      'telefono': '+5493515551234',
      'calle': 'San Martin 120',
      'referencia': '3B, porton verde',
      'destino': {'localidad': 'Cordoba'},
    });
    // Control: el servidor escribe null lo que no viaja; `propio` lo decide
    // el servidor.
    for (final clave in ['numero', 'piso', 'email', 'propio']) {
      expect(j.containsKey(clave), isFalse, reason: clave);
    }
  });
}
