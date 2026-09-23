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
    required this.activar,
    required this.alCambiarActivar,
    required this.alGuardar,
  });

  final Revision revision;
  final bool esNuevo;
  final bool guardando;
  final String? fallo;

  /// El tilde "Publicar apenas se cargue" (ADR 015 §5). Sin efecto fuera de
  /// un alta -- `esNuevo` es quien decide si este widget lo muestra.
  final bool activar;
  final ValueChanged<bool> alCambiarActivar;
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
        if (esNuevo)
          CheckboxListTile(
            value: activar,
            onChanged: guardando ? null : (v) => alCambiarActivar(v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: const Text('Publicar apenas se cargue'),
            subtitle: Text(
              activar
                  ? 'Va a aparecer en la tienda al toque -- "agotado" hasta '
                        'la próxima reposición de stock.'
                  : 'Se carga sin publicar: todavía no va a aparecer en la '
                        'tienda.',
            ),
          ),
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
                ? (activar ? 'Cargar y publicar' : 'Cargar el vino')
                : 'Guardar los cambios',
          ),
        ),
      ],
    );
  }
}
