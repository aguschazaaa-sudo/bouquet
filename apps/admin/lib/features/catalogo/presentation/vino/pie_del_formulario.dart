import 'package:flutter/material.dart';

import '../../../../core/presentation/aviso.dart';
import '../../domain/borrador_de_vino.dart';
import 'textos_del_vino.dart';

/// Lo que falta, lo que fallo y el boton.
///
/// **El boton apagado dice por que.** En un alta los problemas se muestran al
/// lado de cada campo recien cuando se toco —un formulario vacio no arranca
/// con seis errores en rojo—, asi que esta linea es la que explica un boton
/// que no se deja apretar.
class PieDelFormulario extends StatelessWidget {
  const PieDelFormulario({
    super.key,
    required this.revision,
    required this.esNuevo,
    required this.guardando,
    required this.fallo,
    required this.alGuardar,
  });

  final Revision revision;
  final bool esNuevo;
  final bool guardando;
  final String? fallo;
  final VoidCallback alGuardar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final problemas = revision.problemas.keys.map(nombreDelCampo);
    final String? falta = problemas.isNotEmpty
        ? 'Para guardar falta revisar ${enumerar(problemas)}.'
        : !revision.sePuedeGuardar && !esNuevo
        ? 'No cambiaste nada todavía.'
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (falta != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Semantics(
              liveRegion: true,
              child: Text(
                falta,
                style: tema.textTheme.bodyMedium?.copyWith(
                  color: tema.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        if (fallo case final fallo?)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Aviso(texto: fallo, tono: TonoDelAviso.error),
          ),
        FilledButton(
          onPressed: revision.sePuedeGuardar && !guardando ? alGuardar : null,
          child: Text(
            guardando
                ? 'Guardando…'
                : esNuevo
                ? 'Cargar el vino'
                : 'Guardar los cambios',
          ),
        ),
        if (esNuevo)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              'Se carga sin publicar y sin stock: todavía no aparece en la '
              'tienda.',
              textAlign: TextAlign.center,
              style: tema.textTheme.bodySmall?.copyWith(
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}
