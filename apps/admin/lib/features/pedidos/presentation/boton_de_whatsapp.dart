import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/presentation/aviso.dart';
import '../domain/aviso_de_despacho.dart';
import '../domain/orden.dart';
import 'textos_del_aviso.dart';

/// Escribirle al comprador por WhatsApp, con un toque: abre su chat y la
/// persona aprieta enviar desde su WhatsApp.
///
/// **Un solo boton, en cualquier estado del pedido**, y lo ve todo el que entra
/// al panel (ADR 021, *Revision*). El chat se abre con el mensaje que le toca al
/// estado ya escrito ([mensajeSegun]): que lo anotamos, que salio (HU-07.3), que
/// no se pudo entregar, o si llego bien; vacio si esta cancelado. Uno y no dos:
/// dos botones parecidos obligan a elegir, y el texto igual se puede cambiar
/// antes de enviar.
///
/// Un telefono que no es E.164 **no arma el enlace**: `wa.me` abriria el chat de
/// otra persona sin fallar. Se dice, y se escribe a mano.
class BotonDeWhatsapp extends StatelessWidget {
  const BotonDeWhatsapp({super.key, required this.orden});

  final Orden orden;

  @override
  Widget build(BuildContext context) {
    final mensaje = mensajeSegun(orden);
    final texto = mensaje == null ? null : textoDelMensaje(mensaje, orden);

    final enlace = enlaceDeWhatsapp(orden.contacto.telefonoE164, texto);
    if (enlace == null) return const Aviso(texto: textoTelefonoSinWhatsapp);
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: () => _abrir(context, enlace),
        icon: const Icon(Icons.chat_outlined),
        label: Text(
          mensaje is PedidoSalio ? textoBotonAvisar : textoBotonEscribir,
        ),
      ),
    );
  }

  /// En la web abre una pestana nueva; si el navegador la bloquea,
  /// `launchUrl` devuelve `false` o tira, y se dice en vez de no hacer nada.
  Future<void> _abrir(BuildContext context, Uri enlace) async {
    final avisos = ScaffoldMessenger.of(context);
    var abrio = false;
    try {
      abrio = await launchUrl(enlace, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('No se pudo abrir $enlace: $e');
    }
    if (!abrio) {
      avisos.showSnackBar(const SnackBar(content: Text(textoNoSeAbrioWhatsapp)));
    }
  }
}
