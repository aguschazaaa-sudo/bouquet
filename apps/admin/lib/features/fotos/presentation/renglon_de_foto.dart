import 'package:flutter/material.dart';

import '../../../theme/tokens.dart';
import '../domain/foto_del_vino.dart';
import 'aviso_de_la_foto.dart';
import 'textos_de_fotos.dart';
import 'ventana_de_previsualizacion.dart';

/// Una foto ya subida: la previsualización, su aviso -- si corresponde -- y
/// el botón de quitar (spec "El operador quita una foto"). El renglón de la
/// libreta, mismo patrón que `RenglonDeProducto`: una fila por foto, con el
/// filete de abajo en vez de un `Divider` gris.
///
/// Miniatura de tamaño fijo (64×64): crece la lista con cada foto, no cada
/// renglón -- necesario para vivir adentro del `ListView` real de
/// `FormularioDelVino` sin pedir un alto propio.
class RenglonDeFoto extends StatelessWidget {
  const RenglonDeFoto({
    super.key,
    required this.url,
    this.recienSubida,
    required this.quitando,
    required this.alQuitar,
    this.esPrincipal = false,
    this.alUsarComoPrincipal,
    this.cambiandoPrincipal = false,
  });

  final String url;

  /// Lo que devolvió `procesarFoto` si esta foto se subió en esta sesión.
  /// `null` para una del catálogo, cargada antes de abrir esta página --
  /// el documento no persiste esa info, así que no hay aviso posible.
  final FotoDelVino? recienSubida;

  final bool quitando;
  final VoidCallback alQuitar;

  /// HU-04.2: la primera foto, la que dibuja la vidriera. Sólo la marca la
  /// sección cuando hay dos o más: con una sola no hay nada que elegir.
  final bool esPrincipal;

  /// `null` = sin botón (es la principal, o hay una sola foto).
  final VoidCallback? alUsarComoPrincipal;

  /// Un cambio de principal está en curso: el botón queda apagado.
  final bool cambiandoPrincipal;

  @override
  Widget build(BuildContext context) {
    final recienSubida = this.recienSubida;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Tokens.filetePapel)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(6)),
              child: VentanaDePrevisualizacion.url(url),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (esPrincipal)
                  Text(
                    textoPrincipal,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                if (alUsarComoPrincipal != null)
                  TextButton(
                    onPressed: cambiandoPrincipal ? null : alUsarComoPrincipal,
                    child: Text(
                      cambiandoPrincipal
                          ? textoCambiandoLaPrincipal
                          : textoUsarComoPrincipal,
                    ),
                  ),
                if (recienSubida != null) AvisoDeLaFoto(foto: recienSubida),
              ],
            ),
          ),
          const SizedBox(width: 4),
          _BotonDeQuitar(quitando: quitando, alQuitar: alQuitar),
        ],
      ),
    );
  }
}

class _BotonDeQuitar extends StatelessWidget {
  const _BotonDeQuitar({required this.quitando, required this.alQuitar});

  final bool quitando;
  final VoidCallback alQuitar;

  @override
  Widget build(BuildContext context) {
    final error = Theme.of(context).colorScheme.error;
    return IconButton(
      tooltip: textoQuitarFoto,
      onPressed: quitando ? null : alQuitar,
      icon: quitando
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: error),
            )
          : Icon(Icons.delete_outline, color: error),
    );
  }
}
