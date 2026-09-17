import 'package:flutter/material.dart';

import '../../../theme/tokens.dart';
import 'banda_superior.dart';
import 'barra_inferior.dart';

/// Lo que rodea a toda seccion (HU-01.4, HU-01.5): la banda arriba y, en el
/// telefono, las secciones abajo. El corte es por ancho, no por plataforma:
/// una ventana angosta en la compu se usa como un telefono.
///
/// ⚠️ La banda va en el slot `appBar`, NO como primer hijo de un `Column`.
/// El `ShellRoute` mete un `Navigator`, y la barrera modal de su ruta lleva un
/// `BlockSemantics` que borra la semantica de todo lo pintado ANTES que ella.
/// Medido el 2026-09-17 sobre el canal de preview: con la banda en el `Column`,
/// el arbol de accesibilidad no tenia ni `bouquet`, ni las pestanas, ni el
/// mail, ni "Salir" —siete nodos, todos de la seccion—, mientras la barra
/// inferior de 390 px SI aparecia. Esa es la diferencia: el `Scaffold` agrega
/// sus slots despues del body, asi que se pintan despues de la barrera.
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
        // La banda se hace cargo de la muesca con su propio SafeArea, asi que
        // la altura del slot la incluye.
        final alturaDeLaBanda =
            Medidas.banda + MediaQuery.paddingOf(context).top;
        return Scaffold(
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(alturaDeLaBanda),
            child: BandaSuperior(ubicacion: ubicacion, ancha: ancha),
          ),
          body: child,
          bottomNavigationBar: ancha
              ? null
              : BarraInferior(ubicacion: ubicacion),
        );
      },
    );
  }
}
