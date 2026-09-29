import 'package:flutter/material.dart';

import '../../../theme/tokens.dart';

/// De donde se toma un renglon para cambiarlo de lugar, en la portada y en las
/// cajas sugeridas.
///
/// **El arrastre empieza solo desde aca**, apenas se apoya el dedo; el resto
/// del renglon sigue scrolleando la pagina. Por eso antes eran botones de
/// subir y bajar —*"arrastrar en un telefono se confunde con scrollear"*—: con
/// una manija no hay nada que confundir, y las flechas ocupaban la mitad del
/// renglon (lo mostro el dueño el 2026-09-29).
///
/// Quien no puede arrastrar no pierde el gesto: la lista le agrega a cada
/// renglon las acciones de accesibilidad de mover —arriba, abajo, al principio,
/// al final—, traducidas por `WidgetsLocalizations`.
class ManijaParaArrastrar extends StatelessWidget {
  const ManijaParaArrastrar({
    super.key,
    required this.indice,
    required this.habilitada,
  });

  /// La posicion en la lista, desde 0.
  final int indice;

  /// `false` mientras se guarda el cambio anterior.
  final bool habilitada;

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    return ReorderableDragStartListener(
      index: indice,
      enabled: habilitada,
      child: MouseRegion(
        cursor: habilitada ? SystemMouseCursors.grab : MouseCursor.defer,
        child: SizedBox.square(
          dimension: Medidas.tactil,
          // Las acciones de mover ya las dice la lista: la manija, leida,
          // seria un "boton" que no hace nada al tocarlo.
          child: ExcludeSemantics(
            child: Icon(
              Icons.drag_indicator,
              // Esperando, la regla y no un gris a media tinta: la diferencia
              // con la habilitada se tiene que ver sin comparar dos grises.
              color: habilitada
                  ? esquema.onSurfaceVariant
                  : esquema.outlineVariant,
            ),
          ),
        ),
      ),
    );
  }
}
