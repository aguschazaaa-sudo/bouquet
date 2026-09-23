import 'package:admin/core/contratos/producto.dart';
import 'package:admin/features/catalogo/domain/borrador_de_vino.dart';
import 'package:admin/features/catalogo/domain/bodega.dart';
import 'package:admin/features/catalogo/domain/catalogo.dart';
import 'package:admin/features/catalogo/domain/escrituras_del_vino.dart';
import 'package:admin/features/catalogo/domain/ficha_del_vino.dart';
import 'package:admin/features/catalogo/domain/producto_del_panel.dart';
import 'package:test/test.dart';

/// El formulario de HU-03.2, HU-03.3 y HU-03.4, sin widgets. ADR 013 §4.
///
/// El widget no decide nada: lee la `Revision`. Asi que esto es lo que prueba
/// el formulario, y corre en segundos en una maquina donde el panel no
/// compila.

const anio = 2026;

final norton = Bodega(id: 'norton', nombre: 'Bodega Norton', slug: 'norton');

ProductoDelPanel vino(
  String id, {
  String? slug,
  String nombre = 'Malbec Reserva',
  bool publicado = false,
  bool muestra = false,
  List<String> varietales = const ['Malbec'],
  String region = 'Luján de Cuyo, Mendoza',
  int? anada = 2022,
  int? graduacion,
  String? descripcion,
  int precio = 1250000,
  int botellas = 1,
}) => ProductoDelPanel(
  id: id,
  slug: slug ?? id,
  nombre: nombre,
  precio: precio,
  publicado: publicado,
  ficha: FichaDelVino(
    bodegaId: 'norton',
    varietales: varietales,
    color: ColorDelVino.tinto,
    region: region,
    anada: anada,
    volumenMl: 750,
    graduacion: graduacion,
    descripcion: descripcion,
  ),
  botellas: botellas,
  stock: 0,
  muestra: muestra,
);

Catalogo catalogo([List<ProductoDelPanel> vinos = const []]) =>
    Catalogo.armar(productos: vinos, bodegas: [norton]);

/// Un alta completa: el control positivo de cada caso que rompe una cosa.
BorradorDeVino completo() => const BorradorDeVino()
    .conNombre('Norton Malbec Reserva')
    .conBodega('norton')
    .conVarietal('Malbec', elegida: true)
    .conColor(ColorDelVino.tinto)
    .conRegion('Luján de Cuyo, Mendoza')
    .conPrecio('12.500');

void main() {
  group('alta (HU-03.2)', () {
    test('completa: se puede guardar, y el alta lleva lo leido', () {
      final r = completo().revisar(catalogo(), anioActual: anio);
      expect(r.problemas, isEmpty);
      expect(r.sePuedeGuardar, isTrue);
      final alta = r.alta!;
      expect(alta.slug, 'norton-malbec-reserva');
      expect(alta.nombre, 'Norton Malbec Reserva');
      expect(alta.precio, 1250000);
      expect(alta.botellas, 1);
      expect(alta.ficha.volumenMl, 750, reason: '750 por omision');
      expect(alta.ficha.anada, isNull, reason: 'la añada puede faltar');
      expect(alta.ficha.graduacion, isNull);
      expect(r.cambios, isNull);
    });

    // ADR 015 §5: cargar el vino, sumarle una foto y publicarlo eran tres
    // viajes separados; ahora las dos ultimas son parte del mismo alta.
    test('las fotos subidas como borrador y el tilde de activar viajan '
        'en el alta', () {
      final r = completo()
          .conImagenes(const ['https://ejemplo.test/a.webp'])
          .conActivar(false)
          .revisar(catalogo(), anioActual: anio);
      expect(r.alta!.imagenes, ['https://ejemplo.test/a.webp']);
      expect(r.alta!.publicar, isFalse);
    });

    test('por omision, un alta nueva ya viene con activar en true', () {
      final r = completo().revisar(catalogo(), anioActual: anio);
      expect(r.alta!.publicar, isTrue);
      expect(r.alta!.imagenes, isEmpty);
    });

    test('conImagenes y conActivar no hacen nada en una correccion', () {
      final b = BorradorDeVino.desde(
        vino('norton-malbec-reserva'),
      ).conImagenes(const ['https://ejemplo.test/a.webp']).conActivar(true);
      expect(
        b.imagenes,
        isEmpty,
        reason: 'una correccion no tiene borrador de fotos',
      );
      expect(b.activar, isFalse, reason: 'el original no estaba publicado');
    });

    test('un borrador vacio dice que falta, campo por campo', () {
      final r = const BorradorDeVino().revisar(catalogo(), anioActual: anio);
      expect(r.sePuedeGuardar, isFalse);
      expect(r.alta, isNull);
      expect(r.problemas.keys, {
        CampoDelVino.nombre,
        CampoDelVino.bodega,
        CampoDelVino.varietales,
        CampoDelVino.color,
        CampoDelVino.region,
        CampoDelVino.precio,
      });
      expect(r.problemaDe(CampoDelVino.precio), 'Falta el precio.');
    });

    test('un nombre sin letras ni numeros no tiene direccion posible', () {
      final r = completo()
          .conNombre('---')
          .revisar(catalogo(), anioActual: anio);
      expect(r.problemaDe(CampoDelVino.nombre), contains('letras o números'));
      expect(r.slug, isEmpty);
    });

    test('precio cero, ambiguo o mal escrito: no se guarda', () {
      String? problema(String p) => completo()
          .conPrecio(p)
          .revisar(catalogo(), anioActual: anio)
          .problemaDe(CampoDelVino.precio);
      expect(problema('0'), contains('mayor que cero'));
      expect(problema('12.50'), contains('¿12,50 o 12.500?'));
      expect(problema('doce'), contains('No parece un precio'));
    });

    test('la vista previa del precio sale aunque falte otra cosa', () {
      final r = const BorradorDeVino()
          .conPrecio('12.500,50')
          .revisar(catalogo(), anioActual: anio);
      expect(r.sePuedeGuardar, isFalse);
      expect(r.precio, 1250050);
    });

    test('añada: vacia se guarda sin añada; un año futuro o un texto, no', () {
      String? problema(String a) => completo()
          .conAnada(a)
          .revisar(catalogo(), anioActual: anio)
          .problemaDe(CampoDelVino.anada);
      expect(problema(''), isNull);
      expect(problema('2021'), isNull);
      expect(problema('$anio'), isNull);
      expect(problema('${anio + 1}'), contains('todavía no llegó'));
      expect(problema('21'), contains('año de cosecha'));
      expect(problema('1800'), contains('año de cosecha'));
    });

    test('graduacion y volumen: se leen, y lo mal escrito se dice', () {
      final bien = completo()
          .conGraduacion('13,5')
          .conVolumen('1500')
          .revisar(catalogo(), anioActual: anio);
      expect(bien.alta!.ficha.graduacion, 135);
      expect(bien.alta!.ficha.volumenMl, 1500);

      final mal = completo()
          .conGraduacion('135')
          .conVolumen('750ml')
          .revisar(catalogo(), anioActual: anio);
      expect(mal.problemaDe(CampoDelVino.graduacion), contains('entre 5 y 25'));
      expect(mal.problemaDe(CampoDelVino.volumen), contains('mililitros'));
    });

    test('los varietales se guardan en el orden de la lista cerrada', () {
      final r = completo()
          .conVarietal('Malbec', elegida: false)
          .conVarietal('Syrah', elegida: true)
          .conVarietal('Cabernet Franc', elegida: true)
          .revisar(catalogo(), anioActual: anio);
      expect(r.alta!.ficha.varietales, ['Cabernet Franc', 'Syrah']);
    });

    test('una bodega que no esta en el catalogo no se puede elegir', () {
      final r = completo()
          .conBodega('fantasma')
          .revisar(catalogo(), anioActual: anio);
      expect(r.problemaDe(CampoDelVino.bodega), contains('ya no existe'));
    });
  });

  group('la direccion (ADR 013 §1)', () {
    test('ya la tiene un vino real: frena, y dice cual', () {
      final r = completo().revisar(
        catalogo([vino('norton-malbec-reserva', nombre: 'Norton Malbec')]),
        anioActual: anio,
      );
      expect(r.sePuedeGuardar, isFalse);
      expect(r.choque!.bloquea, isTrue);
      expect(r.problemaDe(CampoDelVino.nombre), contains('«Norton Malbec»'));
    });

    test('la tiene uno de muestra: avisa y deja guardar', () {
      final deMuestra = vino(
        'muestra-norton-malbec-reserva',
        slug: 'norton-malbec-reserva',
        muestra: true,
      );
      final r = completo().revisar(catalogo([deMuestra]), anioActual: anio);
      expect(r.choque!.vino, same(deMuestra));
      expect(r.choque!.bloquea, isFalse);
      expect(r.problemas, isEmpty);
      expect(r.sePuedeGuardar, isTrue);
    });

    test('un id igual al slug nuevo frena aunque sea de muestra', () {
      // La base rechazaria el alta: el documento ya existe.
      final c = catalogo([
        vino('norton-malbec-reserva', slug: 'otro', muestra: true),
      ]);
      expect(c.quienTiene('norton-malbec-reserva')!.bloquea, isTrue);
    });

    test('libre: sin choque. Y el control: un slug inventado da null', () {
      final c = catalogo([vino('trumpeter-malbec')]);
      expect(c.quienTiene('ruta-inventada-2026'), isNull);
      expect(c.quienTiene('trumpeter-malbec'), isNotNull);
      expect(c.quienTiene(''), isNull);
    });
  });

  group('la caja (HU-03.3)', () {
    test('una botella suelta no pide confirmar; una caja de 3 si', () {
      final suelta = completo().revisar(catalogo(), anioActual: anio);
      expect(suelta.pideConfirmarLaCaja, isFalse);

      final caja = completo()
          .conBotellas(3)
          .revisar(catalogo(), anioActual: anio);
      expect(caja.alta!.botellas, 3);
      expect(caja.pideConfirmarLaCaja, isTrue);
    });

    test('fuera de 1 a 12 botellas: no se guarda', () {
      for (final n in [0, 13]) {
        final r = completo()
            .conBotellas(n)
            .revisar(catalogo(), anioActual: anio);
        expect(r.problemaDe(CampoDelVino.botellas), isNotNull, reason: '$n');
      }
    });
  });

  group('correccion (HU-03.4)', () {
    final original = vino(
      'norton-malbec',
      nombre: 'Norton Malbec',
      varietales: ['Malbec', 'Syrah'],
      graduacion: 140,
    );

    test('abrir y no tocar nada: no hay nada que guardar', () {
      final r = BorradorDeVino.desde(
        original,
      ).revisar(catalogo([original]), anioActual: anio);
      expect(r.problemas, isEmpty);
      expect(r.cambios!.hayAlgo, isFalse);
      expect(r.sePuedeGuardar, isFalse);
    });

    test('cambiar solo la region manda solo la region', () {
      final r = BorradorDeVino.desde(original)
          .conRegion('Gualtallary, Mendoza')
          .revisar(catalogo([original]), anioActual: anio);
      final c = r.cambios!;
      expect(c.region, 'Gualtallary, Mendoza');
      expect([
        c.nombre,
        c.bodegaId,
        c.color,
        c.organico,
        c.volumenMl,
        c.precio,
      ], everyElement(isNull));
      expect([c.anada, c.graduacion], everyElement(isNull));
      expect(c.varietalesAgregados, isEmpty);
      expect(c.varietalesQuitados, isEmpty);
      expect(r.sePuedeGuardar, isTrue);
    });

    test('cambiar el nombre no mueve la direccion', () {
      final r = BorradorDeVino.desde(original)
          .conNombre('Norton Malbec Clásico')
          .revisar(catalogo([original]), anioActual: anio);
      expect(r.slug, 'norton-malbec');
      expect(r.cambios!.nombre, 'Norton Malbec Clásico');
      expect(r.choque, isNull, reason: 'su propia direccion no es un choque');
    });

    test('varietales: agregados y quitados, nunca la lista entera', () {
      final r = BorradorDeVino.desde(original)
          .conVarietal('Syrah', elegida: false)
          .conVarietal('Merlot', elegida: true)
          .revisar(catalogo([original]), anioActual: anio);
      expect(r.cambios!.varietalesAgregados, ['Merlot']);
      expect(r.cambios!.varietalesQuitados, ['Syrah']);
    });

    test('vaciar la graduacion es un cambio a null, no "sin cambios"', () {
      final r = BorradorDeVino.desde(
        original,
      ).conGraduacion('').revisar(catalogo([original]), anioActual: anio);
      expect(r.cambios!.graduacion, isNotNull);
      expect(r.cambios!.graduacion!.valor, isNull);
    });

    test('el precio de un vino sin publicar se corrige', () {
      final r = BorradorDeVino.desde(
        original,
      ).conPrecio('13.000').revisar(catalogo([original]), anioActual: anio);
      expect(r.cambios!.precio, 1300000);
    });

    test('el precio de un vino en la tienda no se toca (ADR 013 §9)', () {
      final enLaTienda = vino('norton-malbec', publicado: true);
      final b = BorradorDeVino.desde(enLaTienda).conPrecio('1');
      expect(b.precioFijo, isTrue);
      expect(b.precio, '12.500', reason: 'conPrecio no hace nada');
      final r = b.revisar(catalogo([enLaTienda]), anioActual: anio);
      expect(r.problemaDe(CampoDelVino.precio), isNull);
      expect(r.cambios!.precio, isNull);
    });

    test('conOriginalActualizado: publicar CON el formulario abierto '
        'congela el precio (ALTO 1 de revisor-pagos, ADR 014)', () {
      final antesDePublicar = vino('trumpeter', publicado: false);
      var b = BorradorDeVino.desde(antesDePublicar).conPrecio('1.990');
      expect(b.precioFijo, isFalse, reason: 'todavia no esta publicado');

      // Sin conOriginalActualizado esto NO pasaba: el interruptor de la
      // tienda (arriba, en la misma pagina) publica el vino mientras el
      // formulario sigue abierto con el precio a medio escribir.
      final yaPublicado = vino(
        'trumpeter',
        publicado: true,
        precio: antesDePublicar.precio,
      );
      b = b.conOriginalActualizado(yaPublicado);

      expect(b.precioFijo, isTrue, reason: 'el original ya esta publicado');
      expect(b.precio, '1.990', reason: 'lo tecleado no se pierde');
      final r = b.revisar(catalogo([yaPublicado]), anioActual: anio);
      expect(
        r.cambios!.precio,
        isNull,
        reason: 'el precio NO puede viajar sin la baranda de HU-03.5',
      );
    });

    test('conOriginalActualizado no pisa nada de lo tecleado', () {
      final b = BorradorDeVino.desde(original)
          .conNombre('Nombre a medio escribir')
          .conRegion('Otra region')
          .conOriginalActualizado(
            vino('norton-malbec', nombre: original.nombre),
          );
      expect(b.nombre, 'Nombre a medio escribir');
      expect(b.region, 'Otra region');
    });

    test('las botellas no se cambian despues del alta', () {
      final b = BorradorDeVino.desde(original).conBotellas(6);
      expect(b.botellas, 1);
    });

    test('un vino guardado roto hay que arreglarlo para guardar', () {
      // El Admin SDK no pasa por las reglas. Las reglas validan el documento
      // ENTERO en cada update, asi que guardar sin arreglarlo rebotaria.
      final roto = vino('roto', region: '', varietales: ['Cab. Sauv.']);
      final r = BorradorDeVino.desde(
        roto,
      ).conNombre('Otro nombre').revisar(catalogo([roto]), anioActual: anio);
      expect(r.problemaDe(CampoDelVino.region), 'Falta la región.');
      expect(r.problemaDe(CampoDelVino.varietales), contains('«Cab. Sauv.»'));
      expect(r.sePuedeGuardar, isFalse);
    });
  });

  group('lo que el formulario le pregunta al catalogo (cero lecturas)', () {
    test('el vino por id, y un id inventado da null', () {
      final c = catalogo([vino('a')]);
      expect(c.vino('a'), isNotNull);
      expect(c.vino('ruta-inventada-2026'), isNull);
    });

    test('las regiones, una por clave, filtradas por lo escrito', () {
      final c = catalogo([
        vino('a', region: 'Valle de Uco, Mendoza'),
        vino('b', region: 'valle de uco, mendoza'),
        vino('c', region: 'Cafayate, Salta'),
        vino('d', region: '  '),
      ]);
      expect(c.regionesCon(''), ['Cafayate, Salta', 'Valle de Uco, Mendoza']);
      expect(c.regionesCon('mendo'), ['Valle de Uco, Mendoza']);
    });
  });

  group('la descripcion', () {
    test('vacia se guarda como null, no como cadena en blanco', () {
      // Control positivo: el mismo borrador CON texto si la lleva, asi que el
      // null de abajo es por estar vacia y no porque el campo no viaje.
      final con = completo()
          .conDescripcion('Un Malbec de altura.')
          .revisar(catalogo(), anioActual: anio);
      expect(con.alta!.ficha.descripcion, 'Un Malbec de altura.');

      final saltos = String.fromCharCodes([10, 10]);
      for (final vacia in ['', '   ', saltos]) {
        final r = completo()
            .conDescripcion(vacia)
            .revisar(catalogo(), anioActual: anio);
        expect(r.sePuedeGuardar, isTrue, reason: 'sin descripcion se guarda');
        expect(r.alta!.ficha.descripcion, isNull, reason: vacia);
      }
    });

    test('se guarda recortada', () {
      final r = completo()
          .conDescripcion('  con espacios al borde  ')
          .revisar(catalogo(), anioActual: anio);
      expect(r.alta!.ficha.descripcion, 'con espacios al borde');
    });

    test('el tope: 600 entra, 601 dice cuantos sobran', () {
      // El numero va escrito y no leido de la constante: un test que arma el
      // caso con `descripcionMaxima` se mide contra si mismo.
      expect(descripcionMaxima, 600);

      final justo = completo()
          .conDescripcion('a' * 600)
          .revisar(catalogo(), anioActual: anio);
      expect(justo.sePuedeGuardar, isTrue);
      expect(justo.alta!.ficha.descripcion!.length, 600);

      final pasado = completo()
          .conDescripcion('a' * 603)
          .revisar(catalogo(), anioActual: anio);
      expect(pasado.sePuedeGuardar, isFalse);
      expect(pasado.problemas[CampoDelVino.descripcion], contains('3'));
      expect(pasado.problemas[CampoDelVino.descripcion], contains('600'));
    });

    test('el tope se mide sobre lo recortado, no sobre lo tecleado', () {
      // 600 letras entre espacios: lo que se ESCRIBE son 600, asi que entra.
      // Medirlo sobre lo tecleado rebotaria un texto que cabe.
      final r = completo()
          .conDescripcion('   ${'a' * 600}   ')
          .revisar(catalogo(), anioActual: anio);
      expect(r.sePuedeGuardar, isTrue);
      expect(r.alta!.ficha.descripcion!.length, 600);
    });

    test('se corrige en un vino PUBLICADO, a diferencia del precio', () {
      final publicado = vino('v', publicado: true, descripcion: 'Vieja.');
      final b = BorradorDeVino.desde(publicado);
      expect(b.descripcion, 'Vieja.');
      expect(b.precioFijo, isTrue, reason: 'el precio si esta fijo');

      // El precio no se mueve...
      expect(b.conPrecio('999').precio, b.precio);
      // ...y la descripcion si.
      final r = b
          .conDescripcion('Nueva.')
          .revisar(catalogo([publicado]), anioActual: anio);
      expect(r.sePuedeGuardar, isTrue);
      expect(r.cambios!.descripcion!.valor, 'Nueva.');
      expect(r.cambios!.precio, isNull, reason: 'el precio no viaja');
    });

    test('borrarla es un cambio, y no tocarla no lo es', () {
      final publicado = vino('v', descripcion: 'Habia una.');
      final borrada = BorradorDeVino.desde(
        publicado,
      ).conDescripcion('').revisar(catalogo([publicado]), anioActual: anio);
      expect(borrada.cambios!.descripcion, isNotNull);
      expect(borrada.cambios!.descripcion!.valor, isNull);

      final igual = BorradorDeVino.desde(
        publicado,
      ).revisar(catalogo([publicado]), anioActual: anio);
      expect(igual.cambios!.descripcion, isNull, reason: 'no cambio');
      expect(igual.cambios!.hayAlgo, isFalse);
    });
  });

  test('CambiosDeVino vacio no tiene nada', () {
    expect(const CambiosDeVino().hayAlgo, isFalse);
    expect(const CambiosDeVino(anada: Cambio(null)).hayAlgo, isTrue);
  });
}
