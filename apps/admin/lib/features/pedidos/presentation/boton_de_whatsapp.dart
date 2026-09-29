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
/// al panel (ADR 021, *Revision*). Si el pedido esta despachado
/// ([sePuedeAvisar]) el chat se abre con el aviso de que salio ya escrito
/// (HU-07.3); si no, vacio. Uno y no dos: dos botones parecidos obligan a
/// elegir, y el texto igual se puede cambiar antes de enviar.
///
/// Un telefono que no es E.164 **no arma el enlace**: `wa.me` abriria el chat de
/// otra persona sin fallar. Se dice, y se escribe a mano.
class BotonDeWhatsapp extends StatelessWidget {
  const BotonDeWhatsapp({super.key, required this.orden});

  final Orden orden;

  @override
  Widget build(BuildContext context) {
    final despacho = sePuedeAvisar(orden) ? orden.despacho : null;
    final aviso = despacho == null
        ? null
        : textoDelAviso(
            nombre: nombreDePila(orden.contacto.nombre),
            numero: orden.numero,
            correo: despacho.correo,
            seguimiento: despacho.seguimiento,
          );

    final enlace = enlaceDeWhatsapp(orden.contacto.telefonoE164, aviso);
    if (enlace == null) return const Aviso(texto: textoTelefonoSinWhatsapp);
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: () => _abrir(context, enlace),
        icon: const Icon(Icons.chat_outlined),
        label: Text(aviso == null ? textoBotonEscribir : textoBotonAvisar),
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
