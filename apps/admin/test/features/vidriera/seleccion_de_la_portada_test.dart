import 'dart:convert';
import 'dart:io';

import 'package:admin/core/contratos/producto.dart';
import 'package:admin/features/catalogo/domain/bodega.dart';
import 'package:admin/features/catalogo/domain/catalogo.dart';
import 'package:admin/features/catalogo/domain/ficha_del_vino.dart';
import 'package:admin/features/catalogo/domain/producto_del_panel.dart';
import 'package:admin/features/vidriera/domain/seleccion_de_la_portada.dart';
import 'package:test/test.dart';

/// HU-09.1, ADR 023: la seleccion de la portada. Cada escenario con su
/// control al lado. Dart puro: `flutter test` esta denegado en esta maquina.

final _norton = Bodega(id: 'norton', nombre: 'Bodega Norton', slug: 'norton');

ProductoDelPanel _vino(
  String id, {
  bool publicado = true,
  int botellas = 1,
  int? stock = 10,
}) => ProductoDelPanel(
  id: id,
  slug: id,
  nombre: 'Vino $id',
  precio: 1000000,
  publicado: publicado,
  ficha: const FichaDelVino(
    bodegaId: 'norton',
    varietales: ['Malbec'],
    color: ColorDelVino.tinto,
    region: 'Mendoza',
    volumenMl: 750,
  ),
  botellas: botellas,
  stock: stock,
  imagenes: const ['https://ejemplo.test/foto.webp'],
);

Catalogo _catalogo(List<ProductoDelPanel> productos) =>
    Catalogo.armar(productos: productos, bodegas: [_norton]);

void main() {
  test('el tope es el de contratos (generated/contratos.json)', () {
    final archivo = File('../../packages/contratos/generated/contratos.json');
    final contrato =
        json.decode(archivo.readAsStringSync()) as Map<String, dynamic>;
    final vidriera = contrato['vidriera'] as Map<String, dynamic>;
    expect(lugaresDeLaSeleccion, vidriera['lugaresDeLaSeleccion']);
  });

  group('desde el documento, como lo lee la tienda', () {
    test('sin documento, o sin la lista: nunca se eligio', () {
      expect(SeleccionDeLaPortada.desdeDocumento(null).elegida, isFalse);
      expect(
        SeleccionDeLaPortada.desdeDocumento({'ids': <String>[]}).elegida,
        isFalse,
      );
      // Control: la lista vacia SI es una eleccion.
      final vacia = SeleccionDeLaPortada.desdeDocumento({
        'productoIds': <String>[],
      });
      expect(vacia.elegida, isTrue);
      expect(vacia.productoIds, isEmpty);
    });

    test('descarta lo que no es un id, los repetidos y lo que pasa el tope', () {
      final s = SeleccionDeLaPortada.desdeDocumento({
        'productoIds': ['a', 7, '', 'b', 'a', 'c', 'd', 'e', 'f', 'g'],
      });
      expect(s.productoIds, ['a', 'b', 'c', 'd', 'e', 'f']);
    });
  });

  group('agregar, quitar y mover', () {
    test('agregar va al final; repetido o sin lugar, queda igual', () {
      final s = const SeleccionDeLaPortada(['a']).agregar('b');
      expect(s.productoIds, ['a', 'b']);
      expect(s.agregar('a').productoIds, ['a', 'b']);

      final llena = SeleccionDeLaPortada(
        List.generate(lugaresDeLaSeleccion, (i) => 'v$i'),
      );
      expect(llena.llena, isTrue);
      expect(llena.agregar('otro').productoIds, isNot(contains('otro')));
      // Control: con un lugar libre, entra.
      expect(llena.quitar('v0').agregar('otro').productoIds, contains('otro'));
    });

    test('quitar saca solo ese, y sigue siendo una eleccion aunque quede vacia', () {
      final s = const SeleccionDeLaPortada(['a', 'b']).quitar('a');
      expect(s.productoIds, ['b']);
      final vacia = s.quitar('b');
      expect(vacia.productoIds, isEmpty);
      expect(vacia.elegida, isTrue);
    });

    test('mover sube y baja, y en la punta queda igual', () {
      const s = SeleccionDeLaPortada(['a', 'b', 'c']);
      expect(s.mover('c', -1).productoIds, ['a', 'c', 'b']);
      expect(s.mover('a', 1).productoIds, ['b', 'a', 'c']);
      expect(s.mover('a', -1).productoIds, ['a', 'b', 'c']);
      expect(s.mover('c', 1).productoIds, ['a', 'b', 'c']);
      expect(s.mover('no-esta', 1).productoIds, ['a', 'b', 'c']);
    });
  });

  group('que se ve en la portada: lo mismo que decide la tienda', () {
    final catalogo = _catalogo([
      _vino('ok'),
      _vino('sin-publicar', publicado: false),
      _vino('caja', botellas: 2),
      _vino('agotado', stock: 0),
    ]);

    test('cada motivo, con el vino que se ve al lado', () {
      expect(fueraDeLaPortada(catalogo.vino('ok'), catalogo), isNull);
      expect(
        fueraDeLaPortada(catalogo.vino('sin-publicar'), catalogo),
        FueraDeLaPortada.noEstaEnLaTienda,
      );
      expect(
        fueraDeLaPortada(catalogo.vino('caja'), catalogo),
        FueraDeLaPortada.enCaja,
      );
      expect(
        fueraDeLaPortada(catalogo.vino('agotado'), catalogo),
        FueraDeLaPortada.agotado,
      );
      expect(fueraDeLaPortada(null, catalogo), FueraDeLaPortada.noExiste);
    });

    test('los lugares conservan el orden del dueño y dicen cual se ve', () {
      const s = SeleccionDeLaPortada(['agotado', 'borrado', 'ok']);
      final lugares = s.lugaresEn(catalogo);
      expect(lugares.map((l) => l.productoId), ['agotado', 'borrado', 'ok']);
      expect(lugares.map((l) => l.seVe), [false, false, true]);
      expect(lugares[1].producto, isNull);
    });

    test('usa la regla si nunca se eligio o si no queda ninguno visible', () {
      expect(
        const SeleccionDeLaPortada.sinElegir().usaLaReglaEn(catalogo),
        isTrue,
      );
      expect(
        const SeleccionDeLaPortada(['agotado', 'caja']).usaLaReglaEn(catalogo),
        isTrue,
      );
      expect(const SeleccionDeLaPortada([]).usaLaReglaEn(catalogo), isTrue);
      // Control: con uno visible, van los del dueño.
      expect(
        const SeleccionDeLaPortada(['agotado', 'ok']).usaLaReglaEn(catalogo),
        isFalse,
      );
    });
  });
}
