import '../domain/fallo_de_pedidos.dart';
import 'textos_de_entrega.dart';

// Las notas internas de un pedido (HU-07.7). Las lee la familia, nunca el
// comprador: no pasan por `voz`. Funciones puras, sin Flutter: se prueban con
// `dart test`.

const textoNotas = 'Notas internas';
const textoNotasSoloFamilia = 'Solo las ven ustedes: el cliente nunca.';
const textoSinNotas = 'Sin notas.';
const textoEscribirNota = 'Escribir una nota';
const textoEditarNota = 'Cambiar la nota';
const textoGuardarNota = 'Guardar la nota';
const textoEjemploDeNota =
    'Por ejemplo: llamar antes de ir, falta una botella…';

/// El titulo de la hoja: dice de que pedido es.
String textoTituloDeLaNota(int numero) => 'Nota del pedido $numero';

String textoNotaLarga(int largo) => 'La nota tiene hasta $largo caracteres.';

/// Lo que dice el `SnackBar` al guardar.
String textoNotaGuardada(int numero, {required bool borrada}) => borrada
    ? 'Se borró la nota del pedido $numero.'
    : 'Se guardó la nota del pedido $numero.';

/// Un error al anotar. Los de mover el pedido ya dicen lo que pasa con la
/// conexion y el permiso; el de *"otra persona lo movio"* no aplica igual -- la
/// nota no toca el estado --, asi que se dice aparte.
String textoDelFalloDeNota(FalloDePedidos f) => switch (f.error) {
  ErrorDePedido.cambioElPedido =>
    'No se guardó la nota. Ya volvimos a leer el pedido: probá de nuevo.',
  _ => textoDelFalloDeEntrega(f),
};
