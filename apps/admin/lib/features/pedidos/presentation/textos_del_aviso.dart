import '../../../core/contratos/despacho.dart';
import '../domain/aviso_de_despacho.dart';
import '../domain/orden.dart';
import 'textos_de_entrega.dart';

// Los mensajes que el panel deja escritos en el WhatsApp del comprador (HU-07.3),
// uno por estado del pedido. NO son del panel: los lee el COMPRADOR, y por eso
// pasan por `voz` (voz.md §4, mostrador: corto, con el dato, sin exclamaciones
// ni emoji; curados el 2026-09-28 el de *salio* y el 2026-09-29 los demas). No
// firman con un nombre: los manda una persona desde su WhatsApp y puede sumarlo
// antes de enviar, y el nombre con el que firma la tienda lo decide el dueño
// (voz.md §12). Ninguno dice el total: es el de lista, y el que se arreglo por
// chat puede ser otro (ADR 018 §6).

/// Lo que queda escrito en el chat del comprador para [m].
String textoDelMensaje(MensajeAlComprador m, Orden orden) {
  final nombre = nombreDePila(orden.contacto.nombre);
  final numero = orden.numero;
  return switch (m) {
    PedidoAnotado() => textoDelAnotado(
      nombre: nombre,
      numero: numero,
      items: orden.items,
    ),
    PedidoSalio(:final despacho) => textoDelAviso(
      nombre: nombre,
      numero: numero,
      correo: despacho.correo,
      seguimiento: despacho.seguimiento,
    ),
    PedidoNoSeEntrego(:final motivo) => textoDeNoSeEntrego(
      nombre: nombre,
      numero: numero,
      motivo: motivo,
    ),
    PedidoLlego() => textoDeLlego(nombre: nombre, numero: numero),
  };
}

/// voz.md §4.2: *"Nombre, o nada"*.
String _saludo(String? nombre) => nombre == null ? 'Hola.' : 'Hola, $nombre.';

/// Por preparar: que lo anotamos y que lleva, un vino por renglon.
String textoDelAnotado({
  required String? nombre,
  required int numero,
  required List<ItemDeOrden> items,
}) {
  final renglones = [for (final i in items) '${i.cantidad} × ${i.nombre}'];
  // Un pedido siempre tiene lineas; si no, no se deja un renglon vacio.
  final queLleva = renglones.isEmpty
      ? 'Anotamos tu pedido #$numero.'
      : 'Anotamos tu pedido #$numero:\n\n${renglones.join('\n')}';
  return '${_saludo(nombre)} $queLleva\n\n'
      'Te avisamos por acá cuando salga.';
}

/// Despachado: por donde salio y, si hay, el seguimiento.
String textoDelAviso({
  required String? nombre,
  required int numero,
  required Correo correo,
  String? seguimiento,
}) {
  final salio = switch (correo) {
    Correo.enMano => 'Tu pedido #$numero ya salió: te lo llevamos nosotros.',
    Correo.otro => 'Tu pedido #$numero ya salió.',
    _ => 'Tu pedido #$numero ya salió por ${textoRotuloDelCorreo(correo)}.',
  };
  final conSeguimiento = seguimiento == null
      ? ''
      : '\n\nEl número de seguimiento es $seguimiento.';
  return '${_saludo(nombre)} $salio$conSeguimiento\n\n'
      'Si necesitás algo, escribinos por acá.';
}

/// La entrega fallo. El motivo se dice sin reproche (voz.md §9.7): con
/// *rechazo* el comprador pudo haberlo rechazado, asi que no dice "no pudimos".
String textoDeNoSeEntrego({
  required String? nombre,
  required int numero,
  required MotivoDeFalla? motivo,
}) {
  final saludo = _saludo(nombre);
  const coordinamos =
      'Coordinamos otra entrega cuando quieras. El pedido está guardado.';
  final noPudimos = '$saludo No pudimos entregarte el pedido #$numero';
  return switch (motivo) {
    MotivoDeFalla.sinMayor =>
      '$noPudimos: no había nadie mayor de 18 para recibirlo.\n\n$coordinamos',
    MotivoDeFalla.nadie =>
      '$noPudimos: no había nadie para recibirlo.\n\n$coordinamos',
    MotivoDeFalla.direccion =>
      '$noPudimos: no dimos con la dirección.\n\n'
          'Mandanos la dirección de nuevo y coordinamos otra entrega. El pedido '
          'está guardado.',
    MotivoDeFalla.rechazo =>
      '$saludo Tu pedido #$numero quedó sin entregar.\n\n$coordinamos',
    MotivoDeFalla.otro || null => '$noPudimos.\n\n$coordinamos',
  };
}

/// Entregado: si llego todo bien.
String textoDeLlego({required String? nombre, required int numero}) =>
    '${_saludo(nombre)} ¿Llegó todo bien con tu pedido #$numero?\n\n'
    'Si necesitás algo, escribinos por acá.';

// De acá para abajo, el panel: los lee quien escribe.

/// En un pedido despachado: abre el chat con el aviso de que salió.
const textoBotonAvisar = 'Avisarle por WhatsApp que salió';

/// En cualquier otro estado: abre el chat con el mensaje de su estado, o vacío
/// si está cancelado.
const textoBotonEscribir = 'Escribirle por WhatsApp';

const textoTelefonoSinWhatsapp =
    'El teléfono de este pedido no sirve para WhatsApp, así que no podemos '
    'abrir el chat. Buscalo a mano en tu WhatsApp.';

const textoNoSeAbrioWhatsapp =
    'No se pudo abrir WhatsApp. Si el navegador bloqueó la ventana, permitila y '
    'probá de nuevo.';
