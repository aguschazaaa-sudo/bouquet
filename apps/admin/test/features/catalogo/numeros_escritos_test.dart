import 'package:admin/core/contratos/plata.dart';
import 'package:admin/features/catalogo/domain/numeros_escritos.dart';
import 'package:test/test.dart';

/// El precio y la graduacion escritos a mano. ADR 013 §3.
///
/// Es la tabla de `design.md §3` entera: cada fila es un caso. Un precio mal
/// leido es cobrar mil veces de mas o de menos, y en esta maquina el panel no
/// compila — esto es lo unico que lo prueba antes de CI.
void main() {
  group('leerPesos', () {
    void lee(String escrito, int centavos) =>
        test('"$escrito" son $centavos', () {
          final l = leerPesos(escrito);
          expect(l.problema, isNull);
          expect(l.valor, centavos);
        });

    void rechaza(String escrito, Matcher motivo) =>
        test('"$escrito" se rechaza', () {
          final l = leerPesos(escrito);
          expect(l.valor, isNull);
          expect(l.problema, motivo);
        });

    // Control positivo: sin estos, un parser que rechaza todo pasaria cada
    // rechazo de abajo.
    lee('12500', 1250000);
    lee('12.500', 1250000);
    lee(r'$ 12.500', 1250000);
    lee('12.500,50', 1250050);
    lee('12500,5', 1250050);
    lee('1.250.000', 125000000);
    lee('  990 ', 99000);
    lee('0', 0);
    lee('0,99', 99);

    test('pegar el precio tal como lo muestra la vidriera', () {
      // `enPesos` pone U+00A0 entre el signo y la cifra. `trim` lo saca.
      expect(leerPesos(enPesos(1250050)).valor, 1250050);
    });

    rechaza('12.50', contains('¿12,50 o 12.500?'));
    rechaza('12.5', contains('¿12,50 o 12.500?'));
    rechaza('12,505', contains('Hasta dos decimales'));
    rechaza('1.2.3', contains('No parece un precio'));
    rechaza('12,5,0', contains('No parece un precio'));
    rechaza('12.5000', contains('No parece un precio'));
    rechaza('1.25.000', contains('No parece un precio'));
    rechaza('doce mil', contains('No parece un precio'));
    rechaza('12 500', contains('No parece un precio'));
    rechaza('-500', contains('negativo'));
    rechaza('1.000.000.000', contains('demasiado alto'));

    test('vacio no es un problema del parser: lo decide quien pregunta', () {
      expect(leerPesos('').estaVacia, isTrue);
      expect(leerPesos(r'  $ ').estaVacia, isTrue);
    });

    test('la vuelta: lo que el formulario escribe, se lee al mismo numero', () {
      for (final c in [0, 99, 100, 1250000, 1250050, 1250005, 999999999]) {
        expect(leerPesos(pesosParaEscribir(c)).valor, c, reason: '$c');
      }
      expect(pesosParaEscribir(1250000), '12.500');
      expect(pesosParaEscribir(1250050), '12.500,50');
      expect(pesosParaEscribir(1250005), '12.500,05');
    });
  });

  group('leerGraduacion', () {
    test('en grados, con coma o punto, a decimas', () {
      expect(leerGraduacion('13,5').valor, 135);
      expect(leerGraduacion('13.5').valor, 135);
      expect(leerGraduacion('14').valor, 140);
      expect(leerGraduacion('14 %').valor, 140);
      expect(leerGraduacion('5').valor, 50, reason: 'el piso entra');
      expect(leerGraduacion('25').valor, 250, reason: 'el techo entra');
    });

    test('la unidad equivocada rebota con el mensaje del rango', () {
      // "135" pensando en decimas: 1350 decimas, fuera de rango.
      expect(leerGraduacion('135').problema, contains('entre 5 y 25'));
      expect(leerGraduacion('4,9').problema, contains('entre 5 y 25'));
      expect(leerGraduacion('25,1').problema, contains('entre 5 y 25'));
    });

    test('dos decimales o algo que no es un numero: rechazado', () {
      expect(leerGraduacion('13,55').problema, contains('un decimal'));
      expect(leerGraduacion('trece').problema, contains('No parece'));
      expect(leerGraduacion('1350').problema, contains('No parece'));
    });

    test('vacia es vacia', () {
      expect(leerGraduacion('').estaVacia, isTrue);
      expect(leerGraduacion(' % ').estaVacia, isTrue);
    });

    test('la vuelta', () {
      for (final d in [50, 135, 140, 250]) {
        expect(leerGraduacion(graduacionParaEscribir(d)).valor, d);
      }
      expect(graduacionParaEscribir(135), '13,5');
      expect(graduacionParaEscribir(140), '14');
    });
  });
}
