import 'package:flutter/material.dart';

import '../../../theme/tokens.dart';
import 'textos_del_resumen.dart';

/// Un numero del dia, con lo que significa y a donde ir con el (HU-11.2).
///
/// Tres estados que se ven distinto, y el tercero es el que importa: contando
/// (un indicador), contado (el numero), y **no se pudo contar**, que NO se
/// pinta como un cero — *"no hay pedidos"* y *"no pude contarlos"* mandan a
/// hacer cosas opuestas.
class CifraDelDia extends StatelessWidget {
  const CifraDelDia({
    super.key,
    required this.titulo,
    required this.explicacion,
    required this.cifra,
    this.fallo = false,
    this.accion,
    this.alTocar,
  });

  final String titulo;
  final String explicacion;

  /// `null` mientras se cuenta.
  final String? cifra;

  /// El conteo fallo. Gana sobre [cifra].
  final bool fallo;

  /// El texto del boton, y lo que hace. Sin los dos, no hay boton.
  final String? accion;
  final VoidCallback? alTocar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final accion = this.accion;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      decoration: BoxDecoration(
        color: esquema.surface,
        border: Border.all(color: Tokens.regla),
        borderRadius: BorderRadius.circular(Medidas.radioSuperficie),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: tema.textTheme.titleSmall),
          const SizedBox(height: 6),
          SizedBox(
            height: 44,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _elNumero(tema),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            explicacion,
            style: tema.textTheme.bodySmall?.copyWith(color: Tokens.tinta3),
          ),
          if (accion != null && alTocar != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(onPressed: alTocar, child: Text(accion)),
            )
          else
            const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _elNumero(ThemeData tema) {
    if (fallo) {
      return Semantics(
        liveRegion: true,
        child: Text(
          textoNoSePudoContar,
          style: tema.textTheme.bodyMedium?.copyWith(
            color: tema.colorScheme.error,
          ),
        ),
      );
    }
    final cifra = this.cifra;
    if (cifra == null) {
      return const SizedBox.square(
        dimension: 22,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      );
    }
    return Text(
      cifra,
      style: tema.textTheme.headlineMedium?.copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
