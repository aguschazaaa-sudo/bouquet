import 'package:admin/features/fotos/domain/foto_principal.dart';
import 'package:test/test.dart';

/// La regla de "usar como principal" (HU-04.2): la elegida al frente, el resto
/// en su orden relativo. Dart puro.
void main() {
  group('conPrincipal', () {
    test('la segunda pasa al frente y las demás se corren', () {
      expect(conPrincipal(['A', 'B', 'C'], 'B'), ['B', 'A', 'C']);
    });

    test('la última pasa al frente sin reordenar las otras', () {
      expect(conPrincipal(['A', 'B', 'C'], 'C'), ['C', 'A', 'B']);
    });

    test('la que ya es principal devuelve la misma lista', () {
      expect(conPrincipal(['A', 'B', 'C'], 'A'), ['A', 'B', 'C']);
    });

    test('deshacer: elegir B y después A vuelve al orden original', () {
      final conB = conPrincipal(['A', 'B', 'C'], 'B')!;
      expect(conPrincipal(conB, 'A'), ['A', 'B', 'C']);
    });

    test('una url que no está da null', () {
      expect(conPrincipal(['A', 'B'], 'Z'), isNull);
    });

    test('una lista vacía da null', () {
      expect(conPrincipal(const [], 'A'), isNull);
    });

    test('una sola foto, la misma', () {
      expect(conPrincipal(['A'], 'A'), ['A']);
    });

    test('repetidas: mueve la primera aparición y conserva el resto', () {
      expect(conPrincipal(['A', 'B', 'A'], 'A'), ['A', 'B', 'A']);
      expect(conPrincipal(['B', 'A', 'C', 'A'], 'A'), ['A', 'B', 'C', 'A']);
    });

    test('es una permutación: no pierde ni agrega fotos', () {
      final original = ['A', 'B', 'C', 'D'];
      final nueva = conPrincipal(original, 'C')!;
      expect(nueva.length, original.length);
      expect([...nueva]..sort(), [...original]..sort());
    });

    test('no muta la lista que recibe', () {
      final original = ['A', 'B', 'C'];
      conPrincipal(original, 'C');
      expect(original, ['A', 'B', 'C']);
    });
  });
}
