import 'package:admin/features/catalogo/domain/bodega.dart';
import 'package:admin/features/catalogo/domain/catalogo.dart';
import 'package:admin/features/catalogo/domain/producto_del_panel.dart';
import 'package:test/test.dart';

/// El cruce productos x bodegas, el filtro de HU-03.1 y el conteo que decide
/// si HU-02.4 frena un borrado.
///
/// Es Dart puro con `package:test`, no `flutter_test`: corre en segundos en
/// esta maquina, donde `flutter test` esta denegado. O sea que **se ejecuta**
/// en vez de existir.

Bodega bodega(String id, String nombre) =>
    Bodega(id: id, nombre: nombre, slug: id);

ProductoDelPanel vino(
  String id,
  String nombre, {
  String bodegaId = 'norton',
  bool publicado = true,
  int precio = 1000000,
  int botellas = 1,
  int? stock = 10,
}) => ProductoDelPanel(
  id: id,
  slug: id,
  nombre: nombre,
  precio: precio,
  publicado: publicado,
  bodegaId: bodegaId,
  botellas: botellas,
  stock: stock,
);

void main() {
  final norton = bodega('norton', 'Bodega Norton');
  final catena = bodega('catena-zapata', 'Catena Zapata');
  final nandu = bodega('nandu', 'Bodega Ñandú');

  group('armar', () {
    test('cruza cada producto con su bodega', () {
      final c = Catalogo.armar(
        productos: [vino('a', 'Malbec', bodegaId: 'norton')],
        bodegas: [norton],
      );
      expect(c.renglones.single.bodega, equals(norton));
    });

    test('un producto de una bodega que no existe queda con bodega null', () {
      // No se descarta: `armarCatalogo` ya lo descarta en la vidriera SIN
      // avisar, y el panel existe para decirlo.
      final c = Catalogo.armar(
        productos: [vino('a', 'Malbec', bodegaId: 'fantasma')],
        bodegas: [norton],
      );
      expect(c.renglones, hasLength(1));
      expect(c.renglones.single.bodega, isNull);
    });

    test('ordena por nombre normalizado, no por bytes', () {
      // Con un compareTo crudo, "Ñandú" cae despues de "Zuccardi".
      final c = Catalogo.armar(
        productos: [
          vino('z', 'Zuccardi Serie A'),
          vino('n', 'Ñandú Malbec'),
          vino('a', 'Altos del Plata'),
        ],
        bodegas: [norton],
      );
      expect(c.renglones.map((r) => r.producto.id), equals(['a', 'n', 'z']));
    });

    test('el catalogo vacio no tiene renglones ni bodegas', () {
      expect(Catalogo.vacio.renglones, isEmpty);
      expect(Catalogo.vacio.bodegas, isEmpty);
    });
  });

  group('filtrar (HU-03.1)', () {
    final c = Catalogo.armar(
      productos: [
        vino('t', 'Torrontés Reserva', bodegaId: 'nandu'),
        vino('m', 'Malbec Clásico', bodegaId: 'norton'),
        vino('c', 'Cabernet', bodegaId: 'catena-zapata'),
      ],
      bodegas: [norton, catena, nandu],
    );

    test('una consulta vacia devuelve todo', () {
      expect(c.filtrar(''), hasLength(3));
      expect(c.filtrar('   '), hasLength(3));
    });

    test('encuentra sin acentos y sin mayusculas', () {
      expect(c.filtrar('torrontes').map((r) => r.producto.id), equals(['t']));
      expect(c.filtrar('TORRONTÉS').map((r) => r.producto.id), equals(['t']));
    });

    test('encuentra por el nombre de la bodega', () {
      expect(c.filtrar('catena').map((r) => r.producto.id), equals(['c']));
    });

    test('una consulta que no coincide con nada devuelve vacio', () {
      // Control negativo: sin esto, un filtro que devuelve todo siempre
      // pasaria los tres tests de arriba.
      expect(c.filtrar('zzzzz-no-existe'), isEmpty);
    });

    test('un producto sin bodega se encuentra igual por su nombre', () {
      final huerfano = Catalogo.armar(
        productos: [vino('h', 'Huérfano', bodegaId: 'fantasma')],
        bodegas: [norton],
      );
      expect(huerfano.filtrar('huerfano'), hasLength(1));
    });
  });

  group('vinosDe (HU-02.4)', () {
    final c = Catalogo.armar(
      productos: [
        vino('a', 'Uno', bodegaId: 'norton'),
        vino('b', 'Dos', bodegaId: 'norton', publicado: false),
        vino('c', 'Tres', bodegaId: 'catena-zapata'),
      ],
      bodegas: [norton, catena, nandu],
    );

    test('cuenta los vinos de cada bodega', () {
      expect(c.vinosDe('norton'), equals(2));
      expect(c.vinosDe('catena-zapata'), equals(1));
    });

    test('cuenta tambien los NO publicados', () {
      // Borrar la bodega de un vino no publicado tampoco puede pasar: el dia
      // que se publique, ya no tendria bodega.
      expect(c.vinosDe('norton'), equals(2));
    });

    test('una bodega sin vinos da cero', () {
      expect(c.vinosDe('nandu'), equals(0));
    });

    test('una bodega que no existe da cero', () {
      expect(c.vinosDe('inventada'), equals(0));
    });
  });

  group('parecidas (HU-02.2)', () {
    final c = Catalogo.armar(
      productos: const [],
      bodegas: [norton, catena, nandu],
    );

    test('avisa de la que contiene al nombre nuevo', () {
      expect(c.parecidasA('Catena'), equals([catena]));
    });

    test('no avisa de bodegas que no tienen nada que ver', () {
      expect(c.parecidasA('Zuccardi'), isEmpty);
    });

    test('la que se llama igual NO sale como parecida', () {
      // Sale por `conElMismoNombre`, con otras palabras. Decir las dos cosas
      // del mismo caso es ruido.
      expect(c.parecidasA('catena zapata'), isEmpty);
      expect(c.conElMismoNombre('catena zapata'), equals(catena));
    });

    test('un nombre sin clave no se parece a nada', () {
      // Sin el corte de `seParecen`, la clave vacia esta contenida en todas y
      // toda bodega nueva pareceria un duplicado de todo.
      expect(c.parecidasA('···'), isEmpty);
      expect(c.conElMismoNombre('···'), isNull);
    });

    test('editando, una bodega no se avisa a si misma', () {
      expect(c.conElMismoNombre('Bodega Norton', exceptoId: 'norton'), isNull);
      expect(c.parecidasA('Bodega Norton', exceptoId: 'norton'), isEmpty);
    });

    test('editando, sigue avisando de las OTRAS', () {
      // Control positivo de `exceptoId`: si filtrara de mas, este caso
      // quedaria vacio y el aviso no serviria para nada al editar.
      expect(
        c.conElMismoNombre('Catena Zapata', exceptoId: 'norton'),
        equals(catena),
      );
    });

    test('el mismo nombre escrito distinto se detecta igual', () {
      expect(c.conElMismoNombre('CATENA  ZAPATA'), equals(catena));
      expect(c.conElMismoNombre('catena-zapata'), equals(catena));
    });
  });
}
