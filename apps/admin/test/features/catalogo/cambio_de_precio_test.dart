import 'package:admin/features/catalogo/domain/cambio_de_precio.dart';
import 'package:test/test.dart';

/// HU-03.5: la baranda del cambio de precio. ARQUITECTURA §9.4 y design.md
/// de `panel-publicar-un-vino`, Decision #5.
void main() {
  group('con menos de 5 publicados: solo aplica la condicion relativa', () {
    test('mas del doble del anterior -> pide confirmacion', () {
      expect(
        pideConfirmarElCambio(
          precioNuevo: 3000000,
          precioAnterior: 1000000,
          preciosPublicados: [1000000, 1200000],
        ),
        isTrue,
      );
    });

    test('menos de la mitad del anterior -> pide confirmacion', () {
      expect(
        pideConfirmarElCambio(
          precioNuevo: 400000,
          precioAnterior: 1000000,
          preciosPublicados: [1000000, 1200000],
        ),
        isTrue,
      );
    });

    test('al lado: un cambio chico no pide confirmacion', () {
      expect(
        pideConfirmarElCambio(
          precioNuevo: 1100000,
          precioAnterior: 1000000,
          preciosPublicados: [1000000, 1200000],
        ),
        isFalse,
      );
    });

    test('un precio nuevo muy alejado de la mediana NO pide confirmacion '
        'con catalogo chico: la mediana no discrimina todavia', () {
      expect(
        pideConfirmarElCambio(
          precioNuevo: 1050000,
          precioAnterior: 1000000,
          // 20x la mediana de estos dos, pero son menos de 5.
          preciosPublicados: [10000, 20000],
        ),
        isFalse,
      );
    });

    test('el borde exacto: justo el doble no pide confirmacion', () {
      expect(
        pideConfirmarElCambio(
          precioNuevo: 2000000,
          precioAnterior: 1000000,
          preciosPublicados: [1000000],
        ),
        isFalse,
      );
    });

    test('arriba del borde: el doble mas uno si pide confirmacion', () {
      expect(
        pideConfirmarElCambio(
          precioNuevo: 2000001,
          precioAnterior: 1000000,
          preciosPublicados: [1000000],
        ),
        isTrue,
      );
    });
  });

  group('con 5 publicados o mas: la mediana entra a jugar', () {
    // Mediana de [900000, 950000, 1000000, 1050000, 1100000] = 1000000.
    const publicados = [900000, 950000, 1000000, 1050000, 1100000];

    test('10 veces la mediana -> pide confirmacion (el cero de mas)', () {
      expect(
        pideConfirmarElCambio(
          precioNuevo: 10000000,
          precioAnterior: 1000000,
          preciosPublicados: publicados,
        ),
        isTrue,
      );
    });

    test('un decimo de la mediana -> pide confirmacion (el cero de menos)', () {
      expect(
        pideConfirmarElCambio(
          precioNuevo: 100000,
          precioAnterior: 1000000,
          preciosPublicados: publicados,
        ),
        isTrue,
      );
    });

    test('se aparta de la mediana AUNQUE el precio anterior ya estuviera mal '
        '(design.md: "aunque el precio anterior ya estuviera mal")', () {
      expect(
        pideConfirmarElCambio(
          precioNuevo: 10000000,
          // El anterior tambien estaba lejos de la mediana, pero el
          // cambio en si (10x) no dispara la condicion relativa sola:
          // igual pide confirmacion, por la mediana.
          precioAnterior: 9000000,
          preciosPublicados: publicados,
        ),
        isTrue,
      );
    });

    test('al lado: un precio cerca de la mediana no pide confirmacion', () {
      expect(
        pideConfirmarElCambio(
          precioNuevo: 1020000,
          precioAnterior: 1000000,
          preciosPublicados: publicados,
        ),
        isFalse,
      );
    });

    test('el borde exacto de la mediana: 10x justo pide confirmacion', () {
      expect(
        pideConfirmarElCambio(
          precioNuevo: 10000000,
          precioAnterior: 10000000,
          preciosPublicados: publicados,
        ),
        isTrue,
      );
    });

    test('debajo del borde: 9,9x la mediana no pide por la mediana sola', () {
      // 9.900.000 no llega a 10x la mediana (1.000.000) y tampoco se aparta
      // del anterior (mismo valor): ninguna de las dos condiciones aplica.
      expect(
        pideConfirmarElCambio(
          precioNuevo: 9900000,
          precioAnterior: 9900000,
          preciosPublicados: publicados,
        ),
        isFalse,
      );
    });
  });
}
