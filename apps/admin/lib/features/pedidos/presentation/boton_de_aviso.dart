import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/presentation/aviso.dart';
import '../../acceso/acceso_providers.dart';
import '../domain/aviso_de_despacho.dart';
import '../domain/orden.dart';
import 'textos_del_aviso.dart';

/// Avisarle al comprador que su pedido salio, con un toque (HU-07.3): abre
/// WhatsApp en su chat con el texto escrito, y la persona aprieta enviar.
///
/// **Sólo lo ve quien tiene la marca `avisaPorWhatsApp`**
/// ([avisaPorWhatsappProvider]): el aviso sale del WhatsApp del telefono que
/// toca el boton, y el comprador no tiene que recibir mensajes de numeros
/// distintos. Y sólo en un pedido
/// despachado ([sePuedeAvisar]).
///
/// Un telefono que no es E.164 **no arma el enlace**: `wa.me` abriria el chat de
/// otra persona sin fallar. Se dice, y se avisa a mano.
class BotonDeAviso extends ConsumerWidget {
  const BotonDeAviso({super.key, required this.orden});

  final Orden orden;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final despacho = orden.despacho;
    if (!ref.watch(avisaPorWhatsappProvider) ||
        !sePuedeAvisar(orden) ||
        despacho == null) {
      return const SizedBox.shrink();
    }

    final enlace = enlaceDeWhatsapp(
      orden.contacto.telefonoE164,
      textoDelAviso(
        nombre: nombreDePila(orden.contacto.nombre),
        numero: orden.numero,
        correo: despacho.correo,
        seguimiento: despacho.seguimiento,
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: enlace == null
          ? const Aviso(texto: textoTelefonoSinWhatsapp)
          : Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => _abrir(context, enlace),
                icon: const Icon(Icons.chat_outlined),
                label: const Text(textoBotonAvisar),
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
