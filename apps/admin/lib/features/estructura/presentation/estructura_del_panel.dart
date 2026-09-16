import 'package:flutter/material.dart';

import '../../../theme/tokens.dart';
import 'banda_superior.dart';
import 'barra_inferior.dart';

/// Lo que rodea a toda seccion (HU-01.4, HU-01.5): la banda arriba y, en el
/// telefono, las secciones abajo. El corte es por ancho, no por plataforma:
/// una ventana angosta en la compu se usa como un telefono.
class EstructuraDelPanel extends StatelessWidget {
  const EstructuraDelPanel({
    super.key,
    required this.ubicacion,
    required this.child,
  });

  final String ubicacion;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, limites) {
        final ancha = limites.maxWidth >= Medidas.anchoDeEscritorio;
        return Scaffold(
          body: Column(
            children: [
              BandaSuperior(ubicacion: ubicacion, ancha: ancha),
              Expanded(child: child),
            ],
          ),
          bottomNavigationBar: ancha
              ? null
              : BarraInferior(ubicacion: ubicacion),
        );
      },
    );
  }
}
