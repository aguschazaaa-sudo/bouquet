import 'dart:convert';
import 'dart:io';

import 'package:admin/core/contratos/producto.dart';
import 'package:admin/features/catalogo/domain/bodega.dart';
import 'package:admin/features/catalogo/domain/catalogo.dart';
import 'package:admin/features/catalogo/domain/ficha_del_vino.dart';
import 'package:admin/features/catalogo/domain/producto_del_panel.dart';
import 'package:admin/features/vidriera/data/codigos_de_las_cajas.dart';
import 'package:admin/features/vidriera/domain/borrador_de_caja.dart';
import 'package:admin/features/vidriera/domain/cajas_sugeridas.dart';
import 'package:admin/features/vidriera/domain/fallo_de_las_cajas.dart';
import 'package:test/test.dart';

/// HU-09.2 y HU-09.3, ADR 024: las cajas sugeridas del lado del panel. Cada
/// escenario con su control al lado. Dart puro.

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

const _seis = ['a', 'b', 'c', 'd', 'e', 'f'];

CajaSugerida _caja(String nombre, [List<String> ids = _seis]) =>
    CajaSugerida(slug: nombre.toLowerCase(), nombre: nombre, productoIds: ids);

void main() {
  test('los topes son los de contratos (generated/contratos.json)', () {
    final archivo = File('../../packages/contratos/generated/contratos.json');
    final contrato =
        json.decode(archivo.readAsStringSync()) as Map<String, dynamic>;
    final vidriera = contrato['vidriera'] as Map<String, dynamic>;
    expect(botellasPorCaja, vidriera['botellasPorCaja']);
    expect(topeDeCajas, vidriera['topeDeCajas']);
    expect(largoDelNombreDeCaja, vidriera['largoDelNombreDeCaja']);
  });

  group('el documento, como lo lee la tienda', () {
    test('sin documento o sin la lista: ninguna caja', () {
      expect(CajasSugeridas.desdeDocumento(null).cajas, isEmpty);
      expect(CajasSugeridas.desdeDocumento({'otra': 1}).cajas, isEmpty);
    });

    test('una caja sin la forma queda afuera; las buenas quedan', () {
      final c = CajasSugeridas.desdeDocumento({
        'cajas': [
          {'slug': 'buena', 'nombre': 'Buena', 'productoIds': _seis},
          {'slug': 'corta', 'nombre': 'Corta', 'productoIds': _seis.sublist(1)},
          {'slug': 'sin-nombre', 'nombre': ' ', 'productoIds': _seis},
          {'slug': 'rota', 'nombre': 'Rota', 'productoIds': [1, 2, 3, 4, 5, 6]},
          'basura',
        ],
      });
      expect(c.cajas.map((x) => x.nombre), ['Buena']);
    });
  });

  group('cambiar, ordenar y quitar (HU-09.3)', () {
    final tres = CajasSugeridas([_caja('A'), _caja('B'), _caja('C')]);

    test('con: reemplaza en su lugar, o suma al final', () {
      expect(tres.con(_caja('Z'), indice: 1).cajas.map((c) => c.nombre), [
        'A',
        'Z',
        'C',
      ]);
      expect(tres.con(_caja('Z')).cajas.map((c) => c.nombre), [
        'A',
        'B',
        'C',
        'Z',
      ]);
    });

    test('mover y sacar', () {
      expect(tres.mover(2, -1).cajas.map((c) => c.nombre), ['A', 'C', 'B']);
      expect(tres.mover(0, -1).cajas.map((c) => c.nombre), ['A', 'B', 'C']);
      expect(tres.sin(0).cajas.map((c) => c.nombre), ['B', 'C']);
    });

    test('el pedido lleva todas, en orden, sin slugs', () {
      final pedido = tres.pedido['cajas']! as List;
      expect(pedido.length, 3);
      expect((pedido.first as Map).keys, ['nombre', 'productoIds']);
    });
  });

  group('los lugares, como los llena la tienda', () {
    final catalogo = _catalogo([
      _vino('ok'),
      _vino('sin-publicar', publicado: false),
      _vino('caja', botellas: 2),
      _vino('agotado', stock: 0),
      _vino('uno-solo', stock: 1),
    ]);

    test('cada motivo, con el lugar que se llena al lado', () {
      final lugares = lugaresDeLaCaja(
        _caja('X', ['ok', 'sin-publicar', 'caja', 'agotado', 'no-esta', 'ok']),
        catalogo,
      );
      expect(lugares.map((l) => l.fuera), [
        null,
        FueraDeLaCaja.noEstaEnLaTienda,
        FueraDeLaCaja.enCaja,
        FueraDeLaCaja.agotado,
        FueraDeLaCaja.noExiste,
        null,
      ]);
    });

    test('la segunda copia de un vino con stock 1 no se llena, y no es agotado', () {
      final lugares = lugaresDeLaCaja(
        _caja('X', ['uno-solo', 'uno-solo', 'ok', 'ok', 'ok', 'ok']),
        catalogo,
      );
      expect(lugares[0].fuera, isNull);
      expect(lugares[1].fuera, FueraDeLaCaja.sinSuficiente);
      // Control: con stock de sobra, las cuatro copias de `ok` se llenan.
      expect(lugares.skip(2).every((l) => l.seLlena), isTrue);
    });

    test('al elegir un lugar nuevo, lo que no se llena no se ofrece', () {
      expect(fueraAlElegir(catalogo.vino('ok')!, catalogo), isNull);
      expect(
        fueraAlElegir(catalogo.vino('caja')!, catalogo),
        FueraDeLaCaja.enCaja,
      );
      expect(
        fueraAlElegir(catalogo.vino('agotado')!, catalogo),
        FueraDeLaCaja.agotado,
      );
    });
  });

  group('el borrador (HU-09.2)', () {
    test('una caja nueva tiene seis lugares vacios y dice cuantos faltan', () {
      final b = BorradorDeCaja.nueva().conNombre('Seis tintos');
      expect(b.faltan, botellasPorCaja);
      expect(b.problema(const []), ProblemaDeLaCaja.faltanVinos);
      final llena = [
        for (var i = 0; i < botellasPorCaja; i++) i,
      ].fold(b, (x, i) => x.conVino(i, 'ok'));
      expect(llena.faltan, 0);
      expect(llena.problema(const []), isNull);
      expect(llena.caja.slug, 'seis-tintos');
      expect(llena.sinVino(3).faltan, 1);
    });

    test('el nombre: vacio, sin letras, largo o repetido para la tienda', () {
      final lleno = BorradorDeCaja.desde(_caja('Seis tintos'));
      expect(lleno.conNombre('  ').problema(const []), ProblemaDeLaCaja.sinNombre);
      expect(lleno.conNombre('!!!').problema(const []), ProblemaDeLaCaja.nombreSinLetras);
      expect(
        lleno.conNombre('x' * (largoDelNombreDeCaja + 1)).problema(const []),
        ProblemaDeLaCaja.nombreLargo,
      );
      expect(
        lleno.conNombre('SEIS  Tintos!').problema([_caja('Seis tintos')]),
        ProblemaDeLaCaja.nombreRepetido,
      );
      // Control: el mismo nombre, sin otra caja que lo use, se guarda.
      expect(lleno.problema(const []), isNull);
    });
  });

  group('lo que dice la callable', () {
    test('cada codigo, y la caja que no cerro', () {
      final f = falloDeLasCajas('failed-precondition', {'caja': 'Seis tintos'});
      expect(f.error, ErrorDeLasCajas.noCierra);
      expect(f.caja, 'Seis tintos');
      expect(
        falloDeLasCajas('invalid-argument', null).error,
        ErrorDeLasCajas.noValida,
      );
      expect(
        falloDeLasCajas('permission-denied', null).error,
        ErrorDeLasCajas.sinPermiso,
      );
      expect(
        falloDeLasCajas('unavailable', null).error,
        ErrorDeLasCajas.sinConexion,
      );
      expect(falloDeLasCajas('internal', null).error, ErrorDeLasCajas.desconocido);
      // Control: sin detalles, no inventa una caja.
      expect(falloDeLasCajas('failed-precondition', 'x').caja, isNull);
    });
  });
}
