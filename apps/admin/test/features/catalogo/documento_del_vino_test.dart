import 'dart:io';

import 'package:admin/core/contratos/producto.dart';
import 'package:admin/features/catalogo/data/documento_del_vino.dart';
import 'package:admin/features/catalogo/domain/escrituras_del_vino.dart';
import 'package:admin/features/catalogo/domain/ficha_del_vino.dart';
import 'package:test/test.dart';

/// Lo que se escribe en `productos`, contra **`firestore.rules`**: la unidad
/// externa. Las reglas cierran el documento con `hasAll` y `hasOnly`, tambien
/// adentro de `fichaVino`, y un campo de mas o de menos es un
/// `permission-denied` que en el panel se lee como "no tenes permiso".
/// Comparar contra una lista escrita aca seria comparar el codigo consigo
/// mismo.

/// La lista de `<que>.keys().<metodo>([...])` de las reglas.
Set<String> listaDeLasReglas(String reglas, String que, String metodo) {
  final m = RegExp(
    '${RegExp.escape(que)}\\.keys\\(\\)\\.$metodo\\(\\[([^\\]]*)\\]\\)',
  ).firstMatch(reglas);
  if (m == null) fail('las reglas no tienen $que.keys().$metodo([...])');
  return {for (final c in RegExp("'([^']+)'").allMatches(m[1]!)) c[1]!};
}

AltaDeVino alta({
  int? anada,
  int? graduacion,
  String? descripcion,
  int botellas = 1,
  List<String> imagenes = const [],
  bool publicar = false,
}) => AltaDeVino(
  slug: 'norton-malbec',
  nombre: 'Norton Malbec',
  ficha: FichaDelVino(
    bodegaId: 'norton',
    varietales: const ['Malbec', 'Syrah'],
    color: ColorDelVino.tinto,
    region: 'Luján de Cuyo, Mendoza',
    volumenMl: 750,
    anada: anada,
    graduacion: graduacion,
    descripcion: descripcion,
  ),
  precio: 1250000,
  botellas: botellas,
  imagenes: imagenes,
  publicar: publicar,
);

void main() {
  final reglas = File('../../firestore.rules').readAsStringSync();

  group('documentoNuevo, la unica factory', () {
    test('nace sin publicar, sin stock, simple y sin fotos', () {
      final d = documentoNuevo(alta());
      expect(d['publicado'], isFalse);
      expect(d['stock'], 0);
      expect(d['tipo'], 'simple');
      expect(d['imagenes'], isEmpty);
      expect(d['slug'], 'norton-malbec');
      expect(d['precio'], 1250000);
      expect(d['presentacion'], {'botellas': 1});
    });

    test('las claves del documento son las que aceptan las reglas', () {
      final d = documentoNuevo(alta(anada: 2022, graduacion: 135));
      final obligatorias = listaDeLasReglas(reglas, 'd', 'hasAll');
      final permitidas = listaDeLasReglas(reglas, 'd', 'hasOnly');
      // Control: si la lectura de las reglas diera vacio, todo "cumpliria".
      expect(obligatorias, contains('publicado'));
      expect(d.keys.toSet().containsAll(obligatorias), isTrue);
      expect(permitidas.containsAll(d.keys), isTrue, reason: '${d.keys}');
      expect(d.containsKey('muestra'), isFalse, reason: 'es del servidor');
    });

    test('las claves de fichaVino, tambien', () {
      final ficha =
          documentoNuevo(alta(anada: 2022, graduacion: 135))['fichaVino']!
              as Map<String, Object?>;
      final obligatorias = listaDeLasReglas(reglas, 'f', 'hasAll');
      final permitidas = listaDeLasReglas(reglas, 'f', 'hasOnly');
      expect(permitidas, contains('graduacion'), reason: 'ADR 013');
      expect(permitidas, contains('descripcion'), reason: 'ADR 014');
      expect(ficha.keys.toSet().containsAll(obligatorias), isTrue);
      expect(
        permitidas.containsAll(ficha.keys),
        isTrue,
        reason: '${ficha.keys}',
      );
      expect(ficha['color'], 'tinto', reason: 'el name del enum');
      expect(ficha['graduacion'], 135);
    });

    test('la descripcion viaja, y vacia no se escribe', () {
      final con =
          documentoNuevo(
                alta(descripcion: 'Un Malbec de altura.'),
              )['fichaVino']!
              as Map<String, Object?>;
      expect(con['descripcion'], 'Un Malbec de altura.');

      // Ausente, no `''`: las reglas rechazan la cadena en blanco.
      final sin = documentoNuevo(alta())['fichaVino']! as Map<String, Object?>;
      expect(sin.containsKey('descripcion'), isFalse);
    });

    test('la añada y la graduacion vacias no se escriben', () {
      final ficha =
          documentoNuevo(alta())['fichaVino']! as Map<String, Object?>;
      expect(ficha.containsKey('anada'), isFalse);
      expect(ficha.containsKey('graduacion'), isFalse);
    });

    test('una caja de 3 guarda sus botellas', () {
      expect(documentoNuevo(alta(botellas: 3))['presentacion'], {
        'botellas': 3,
      });
    });

    // ADR 015 §5: revierte la exclusion original de imagenes/publicado --
    // stock y tipo siguen fijos, estos dos ahora salen del alta.
    test('las fotos subidas durante el alta y "publicar" SI salen de ahi', () {
      final d = documentoNuevo(
        alta(imagenes: const ['https://ejemplo.test/a.webp'], publicar: true),
      );
      expect(d['imagenes'], ['https://ejemplo.test/a.webp']);
      expect(d['publicado'], isTrue);
      expect(d['stock'], 0, reason: 'stock sigue sin salir del alta');
      expect(d['tipo'], 'simple', reason: 'tipo sigue sin salir del alta');
    });
  });

  group('camposQueCambiaron', () {
    test('solo lo que cambio, con rutas con punto adentro de la ficha', () {
      expect(camposQueCambiaron(const CambiosDeVino(region: 'Gualtallary')), {
        'fichaVino.region': 'Gualtallary',
      });
      expect(
        camposQueCambiaron(
          const CambiosDeVino(
            nombre: 'Otro',
            precio: 1300000,
            color: ColorDelVino.rosado,
          ),
        ),
        {'nombre': 'Otro', 'precio': 1300000, 'fichaVino.color': 'rosado'},
      );
    });

    test('vaciar la añada escribe null; no tocarla no escribe nada', () {
      expect(camposQueCambiaron(const CambiosDeVino(anada: Cambio(null))), {
        'fichaVino.anada': null,
      });
      expect(camposQueCambiaron(const CambiosDeVino()), isEmpty);
    });

    test('los varietales no van aca: van con arrayUnion/arrayRemove', () {
      final m = camposQueCambiaron(
        const CambiosDeVino(
          varietalesAgregados: ['Merlot'],
          varietalesQuitados: ['Syrah'],
        ),
      );
      expect(m, isEmpty);
      expect(campoDeLosVarietales, 'fichaVino.varietales');
    });

    test('cada ruta de la ficha es una clave que aceptan las reglas', () {
      final permitidas = listaDeLasReglas(reglas, 'f', 'hasOnly');
      final todo = camposQueCambiaron(
        const CambiosDeVino(
          bodegaId: 'b',
          color: ColorDelVino.blanco,
          organico: true,
          region: 'r',
          volumenMl: 750,
          anada: Cambio(2020),
          graduacion: Cambio(130),
          descripcion: Cambio('Nueva.'),
        ),
      );
      for (final ruta in [...todo.keys, campoDeLosVarietales]) {
        expect(ruta, startsWith('fichaVino.'));
        expect(permitidas, contains(ruta.substring('fichaVino.'.length)));
      }
    });
  });
}
