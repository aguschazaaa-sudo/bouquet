import 'dart:convert';
import 'dart:io';

import 'package:admin/core/contratos/catalogo_publico.dart';
import 'package:admin/core/contratos/producto.dart';
import 'package:admin/features/catalogo/domain/bodega.dart';
import 'package:admin/features/catalogo/domain/catalogo.dart';
import 'package:admin/features/catalogo/domain/en_la_tienda.dart';
import 'package:admin/features/catalogo/domain/ficha_del_vino.dart';
import 'package:admin/features/catalogo/domain/producto_del_panel.dart';
import 'package:test/test.dart';

/// HU-03.7, spec `panel-espejo-vidriera`: si la tienda muestra un vino y, si
/// no, por que. Los cinco escenarios del spec, cada uno con el caso que pasa
/// al lado del que falla, mas la comparacion contra
/// `generated/contratos.json` que 4.2 dejo pendiente.
///
/// Dart puro con `package:test`: corre en segundos, `flutter test` esta
/// denegado en esta maquina.

final _norton = Bodega(id: 'norton', nombre: 'Bodega Norton', slug: 'norton');

FichaDelVino _fichaValida({String bodegaId = 'norton'}) => FichaDelVino(
  bodegaId: bodegaId,
  varietales: const ['Malbec'],
  color: ColorDelVino.tinto,
  region: 'Mendoza',
  volumenMl: 750,
);

ProductoDelPanel _vino({
  required String id,
  String? slug,
  String nombre = 'Un vino',
  String bodegaId = 'norton',
  bool publicado = true,
  int precio = 1000000,
  List<String> imagenes = const ['https://ejemplo.test/foto.webp'],
  int? stock = 10,
}) => ProductoDelPanel(
  id: id,
  slug: slug ?? id,
  nombre: nombre,
  precio: precio,
  publicado: publicado,
  ficha: _fichaValida(bodegaId: bodegaId),
  botellas: 1,
  stock: stock,
  imagenes: imagenes,
);

/// El mapeo de un documento crudo (tal como lo guarda Firestore) a
/// [ProductoDelPanel], con el mismo criterio de
/// `RepositorioDeProductosFirestore._desdeElDocumento`: lo que falta o no es
/// del tipo esperado queda vacio o en `null`, nunca inventado. No importa
/// `campos.dart` porque sus funciones toman un `QueryDocumentSnapshot`, no
/// un `Map` suelto -- este helper es la misma logica sin Firebase adentro.
ProductoDelPanel _desdeDatos(String id, Map<String, dynamic> datos) {
  final presentacion =
      (datos['presentacion'] as Map?)?.cast<String, Object?>() ?? const {};
  final ficha =
      (datos['fichaVino'] as Map?)?.cast<String, Object?>() ?? const {};
  return ProductoDelPanel(
    id: id,
    slug: datos['slug'] as String? ?? '',
    nombre: datos['nombre'] as String? ?? '',
    precio: datos['precio'] as int? ?? 0,
    publicado: datos['publicado'] as bool? ?? false,
    ficha: FichaDelVino(
      bodegaId: ficha['bodegaId'] as String? ?? '',
      varietales: (ficha['varietales'] as List?)?.cast<String>() ?? const [],
      color: ColorDelVino.desde(ficha['color'] as String? ?? ''),
      organico: ficha['organico'] as bool? ?? false,
      anada: ficha['anada'] as int?,
      region: ficha['region'] as String? ?? '',
      volumenMl: ficha['volumenMl'] as int?,
      graduacion: ficha['graduacion'] as int?,
      descripcion: ficha['descripcion'] as String?,
    ),
    botellas: presentacion['botellas'] as int? ?? 1,
    stock: datos['stock'] as int?,
    muestra: datos['muestra'] as bool? ?? false,
    imagenes: (datos['imagenes'] as List?)?.cast<String>() ?? const [],
  );
}

void main() {
  group('Escenario: un vino publicado que si aparece', () {
    test('valida, publicado y con su bodega -> aparece, sin motivo', () {
      final v = _vino(id: 'a');
      final catalogo = Catalogo.armar(productos: [v], bodegas: [_norton]);
      final revision = revisarParaLaTienda(v, catalogo);
      expect(revision.aparece, isTrue);
      expect(revision.motivo, isNull);
    });
  });

  group('Escenario: publicado pero con la bodega borrada', () {
    test('bodegaId sin bodega en el catalogo -> bodegaInexistente', () {
      final v = _vino(id: 'a', bodegaId: 'fantasma');
      final catalogo = Catalogo.armar(productos: [v], bodegas: [_norton]);
      final revision = revisarParaLaTienda(v, catalogo);
      expect(revision.aparece, isFalse);
      expect(revision.motivo, equals(MotivoDeDescarte.bodegaInexistente));
    });

    test('al lado: con la bodega puesta, aparece', () {
      final v = _vino(id: 'a', bodegaId: 'norton');
      final catalogo = Catalogo.armar(productos: [v], bodegas: [_norton]);
      expect(revisarParaLaTienda(v, catalogo).aparece, isTrue);
    });
  });

  group('Escenario: publicado con un slug duplicado', () {
    test('dos vinos publicados con el mismo slug -> los dos slugDuplicado', () {
      final a = _vino(id: 'a', slug: 'compartido');
      final b = _vino(id: 'b', slug: 'compartido');
      final catalogo = Catalogo.armar(productos: [a, b], bodegas: [_norton]);
      expect(
        revisarParaLaTienda(a, catalogo).motivo,
        equals(MotivoDeDescarte.slugDuplicado),
      );
      expect(
        revisarParaLaTienda(b, catalogo).motivo,
        equals(MotivoDeDescarte.slugDuplicado),
      );
    });

    test('al lado: con slugs distintos, los dos aparecen', () {
      final a = _vino(id: 'a', slug: 'uno');
      final b = _vino(id: 'b', slug: 'dos');
      final catalogo = Catalogo.armar(productos: [a, b], bodegas: [_norton]);
      expect(revisarParaLaTienda(a, catalogo).aparece, isTrue);
      expect(revisarParaLaTienda(b, catalogo).aparece, isTrue);
    });

    test('un vino REAL choca con uno de MUESTRA: los dos slugDuplicado '
        '(ALTO 2 de revisor-pagos, ADR 014)', () {
      // `quienTiene(...).bloquea` es `false` para un choque contra uno de
      // muestra -- esa bandera contesta "¿se puede guardar el ALTA?"
      // (ADR 013 §1), no "¿lo muestra la tienda?". `armarCatalogo` cuenta
      // TODOS los documentos crudos con ese slug, de muestra o no, y
      // descarta a los dos: sin mirar `.bloquea`, `revisarParaLaTienda`
      // tiene que hacer lo mismo.
      final real = _vino(id: 'trumpeter-malbec', slug: 'trumpeter-malbec');
      final muestra = ProductoDelPanel(
        id: 'muestra-trumpeter-malbec',
        slug: 'trumpeter-malbec',
        nombre: 'Vino de muestra',
        precio: 1000000,
        publicado: true,
        ficha: _fichaValida(),
        botellas: 1,
        stock: 10,
        muestra: true,
      );
      final catalogo = Catalogo.armar(
        productos: [real, muestra],
        bodegas: [_norton],
      );
      expect(
        revisarParaLaTienda(real, catalogo).motivo,
        equals(MotivoDeDescarte.slugDuplicado),
        reason: 'el panel NO puede decir "está en la tienda" acá',
      );
      expect(
        revisarParaLaTienda(muestra, catalogo).motivo,
        equals(MotivoDeDescarte.slugDuplicado),
      );
    });

    test('al lado: el real con un slug propio, ninguno choca', () {
      final real = _vino(id: 'otro-vino', slug: 'otro-vino');
      final muestra = ProductoDelPanel(
        id: 'muestra-trumpeter-malbec',
        slug: 'trumpeter-malbec',
        nombre: 'Vino de muestra',
        precio: 1000000,
        publicado: true,
        ficha: _fichaValida(),
        botellas: 1,
        stock: 10,
        muestra: true,
      );
      final catalogo = Catalogo.armar(
        productos: [real, muestra],
        bodegas: [_norton],
      );
      expect(revisarParaLaTienda(real, catalogo).aparece, isTrue);
      expect(revisarParaLaTienda(muestra, catalogo).aparece, isTrue);
    });
  });

  group('Escenario: sin publicar', () {
    test('publicado en false -> noPublicado', () {
      final v = _vino(id: 'a', publicado: false);
      final catalogo = Catalogo.armar(productos: [v], bodegas: [_norton]);
      final revision = revisarParaLaTienda(v, catalogo);
      expect(revision.aparece, isFalse);
      expect(revision.motivo, equals(MotivoDeDescarte.noPublicado));
    });

    test('al lado: publicado, aparece', () {
      final v = _vino(id: 'a', publicado: true);
      final catalogo = Catalogo.armar(productos: [v], bodegas: [_norton]);
      expect(revisarParaLaTienda(v, catalogo).aparece, isTrue);
    });
  });

  group('Escenario: publicado y sin fotos', () {
    test('imagenes vacia -> aparece, pero sinFoto', () {
      final v = _vino(id: 'a', imagenes: const []);
      final catalogo = Catalogo.armar(productos: [v], bodegas: [_norton]);
      final revision = revisarParaLaTienda(v, catalogo);
      expect(revision.aparece, isTrue);
      expect(revision.sinFoto, isTrue);
    });

    test('al lado: con foto, aparece sin avisar', () {
      final v = _vino(id: 'a');
      final catalogo = Catalogo.armar(productos: [v], bodegas: [_norton]);
      final revision = revisarParaLaTienda(v, catalogo);
      expect(revision.aparece, isTrue);
      expect(revision.sinFoto, isFalse);
    });
  });

  group('revisarParaPublicar: como si publicado ya fuera true', () {
    test('un borrador con precio en cero -> noValida, NUNCA noPublicado', () {
      final v = _vino(id: 'a', publicado: false, precio: 0);
      final catalogo = Catalogo.armar(productos: [v], bodegas: [_norton]);
      final revision = revisarParaPublicar(v, catalogo);
      expect(revision.aparece, isFalse);
      expect(revision.motivo, equals(MotivoDeDescarte.noValida));
    });

    test('al lado: el mismo borrador con precio puesto, aparecería', () {
      final v = _vino(id: 'a', publicado: false, precio: 1000000);
      final catalogo = Catalogo.armar(productos: [v], bodegas: [_norton]);
      expect(revisarParaPublicar(v, catalogo).aparece, isTrue);
    });

    test('un borrador con la bodega borrada -> bodegaInexistente', () {
      final v = _vino(id: 'a', publicado: false, bodegaId: 'fantasma');
      final catalogo = Catalogo.armar(productos: [v], bodegas: [_norton]);
      expect(
        revisarParaPublicar(v, catalogo).motivo,
        equals(MotivoDeDescarte.bodegaInexistente),
      );
    });

    test('un borrador cuyo slug ya usa un vino publicado -> slugDuplicado', () {
      final publicado = _vino(id: 'a', slug: 'compartido');
      final borrador = _vino(id: 'b', slug: 'compartido', publicado: false);
      final catalogo = Catalogo.armar(
        productos: [publicado, borrador],
        bodegas: [_norton],
      );
      expect(
        revisarParaPublicar(borrador, catalogo).motivo,
        equals(MotivoDeDescarte.slugDuplicado),
      );
    });

    test('un borrador sin fotos -> aparecería, pero sinFoto', () {
      final v = _vino(id: 'a', publicado: false, imagenes: const []);
      final catalogo = Catalogo.armar(productos: [v], bodegas: [_norton]);
      final revision = revisarParaPublicar(v, catalogo);
      expect(revision.aparece, isTrue);
      expect(revision.sinFoto, isTrue);
    });

    test('un vino YA publicado: se revisa tal cual, sin simular nada', () {
      final v = _vino(id: 'a', publicado: true, precio: 0);
      final catalogo = Catalogo.armar(productos: [v], bodegas: [_norton]);
      // Un publicado con precio 0 no puede existir en la practica (las
      // reglas lo impiden), pero si existiera por un documento roto,
      // revisarParaPublicar no debe esconder el motivo detras de un
      // "aparece" falso: tiene que dar lo mismo que revisarParaLaTienda.
      expect(
        revisarParaPublicar(v, catalogo).motivo,
        equals(revisarParaLaTienda(v, catalogo).motivo),
      );
    });
  });

  group('contra generated/contratos.json -> catalogo.casosDeDescarte', () {
    late Map<String, dynamic> catalogoContrato;

    setUpAll(() {
      final archivo = File('../../packages/contratos/generated/contratos.json');
      final contrato =
          json.decode(archivo.readAsStringSync()) as Map<String, dynamic>;
      catalogoContrato = contrato['catalogo'] as Map<String, dynamic>;
    });

    test('cada caso se clasifica igual que armarCatalogo', () {
      // Las mismas bodegas de las fixtures: sin esto, "bodega inexistente"
      // no se puede reproducir del otro lado.
      final bodegas = [
        for (final b in catalogoContrato['bodegas'] as List)
          Bodega(
            id: (b as Map)['id'] as String,
            nombre: (b['datos'] as Map)['nombre'] as String,
            slug: (b['datos'] as Map)['slug'] as String,
          ),
      ];

      final casos = catalogoContrato['casosDeDescarte'] as List;
      // Un Catalogo con TODOS los documentos juntos, como
      // `fixturesDelCatalogo()` llama a `armarCatalogo` UNA vez sobre la
      // lista entera: el slug duplicado solo existe de a dos.
      final productos = [
        for (final caso in casos)
          _desdeDatos(
            (caso as Map<String, dynamic>)['id'] as String,
            (caso['documento'] as Map).cast<String, dynamic>(),
          ),
      ];
      final catalogo = Catalogo.armar(productos: productos, bodegas: bodegas);

      for (final caso in casos) {
        final c = caso as Map<String, dynamic>;
        final producto = productos.firstWhere((p) => p.id == c['id']);
        final revision = revisarParaLaTienda(producto, catalogo);
        final claseEsperada = c['clase'] as String;
        final porque = c['porque'] as String;

        if (claseEsperada == 'entra') {
          expect(revision.aparece, isTrue, reason: porque);
        } else {
          expect(revision.aparece, isFalse, reason: porque);
          expect(revision.motivo?.clave, equals(claseEsperada), reason: porque);
        }
      }
    });
  });
}
