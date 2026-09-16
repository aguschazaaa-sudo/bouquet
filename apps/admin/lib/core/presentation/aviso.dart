import 'package:flutter/material.dart';

import '../../theme/tokens.dart';

enum TonoDelAviso { informacion, error }

/// Un mensaje en la pantalla, en palabras.
///
/// Existe por HU-04.4: en PadelPunilla la subida de fotos fallo meses sin un
/// solo reporte porque el error se perdia. Aca un error siempre llega a la
/// pantalla, y el lector de pantalla lo anuncia (`liveRegion`).
class Aviso extends StatelessWidget {
  const Aviso({
    super.key,
    required this.texto,
    this.tono = TonoDelAviso.informacion,
  });

  final String texto;
  final TonoDelAviso tono;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final esError = tono == TonoDelAviso.error;
    final color = esError ? esquema.error : esquema.onSurface;

    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: esError ? esquema.surface : esquema.surfaceContainerHighest,
          border: esError ? Border.all(color: esquema.error) : null,
          borderRadius: BorderRadius.circular(Medidas.radio),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              esError ? Icons.error_outline : Icons.mark_email_read_outlined,
              size: 20,
              color: color,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                texto,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: color, height: 1.45),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
