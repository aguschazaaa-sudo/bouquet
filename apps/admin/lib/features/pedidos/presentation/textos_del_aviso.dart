import '../../../core/contratos/despacho.dart';
import 'textos_de_entrega.dart';

// Los textos del aviso de despacho (HU-07.3). El primero NO es del panel: lo lee
// el COMPRADOR en su WhatsApp, y por eso pasa por `voz` (voz.md §4, mostrador:
// corto, con el dato, sin exclamaciones ni emoji). No firma con un nombre: lo
// manda una persona desde su WhatsApp y puede sumarlo antes de enviar, y el
// nombre con el que firma la tienda lo decide el dueño (voz.md §12).

/// El mensaje que queda escrito en el chat del comprador.
String textoDelAviso({
  required String? nombre,
  required int numero,
  required Correo correo,
  String? seguimiento,
}) {
  final saludo = nombre == null ? 'Hola.' : 'Hola, $nombre.';
  final salio = switch (correo) {
    Correo.enMano => 'Tu pedido #$numero ya salió: te lo llevamos nosotros.',
    Correo.otro => 'Tu pedido #$numero ya salió.',
    _ => 'Tu pedido #$numero ya salió por ${textoRotuloDelCorreo(correo)}.',
  };
  final conSeguimiento = seguimiento == null
      ? ''
      : '\n\nEl número de seguimiento es $seguimiento.';
  return '$saludo $salio$conSeguimiento\n\n'
      'Si necesitás algo, escribinos por acá.';
}

// De acá para abajo, el panel: los lee quien avisa.

const textoBotonAvisar = 'Avisarle por WhatsApp que salió';

const textoTelefonoSinWhatsapp =
    'El teléfono de este pedido no sirve para WhatsApp, así que el aviso no se '
    'puede armar. Avisale a mano.';

const textoNoSeAbrioWhatsapp =
    'No se pudo abrir WhatsApp. Si el navegador bloqueó la ventana, permitila y '
    'probá de nuevo.';
