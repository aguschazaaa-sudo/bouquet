import 'package:flutter/material.dart';

import '../../../core/presentation/aviso.dart';
import '../domain/bodega.dart';

/// El aviso de HU-02.2: las bodegas que se parecen a la que se esta
/// escribiendo, **antes** de guardar.
///
/// **No impide guardar.** Puede haber dos bodegas con nombres parecidos de
/// verdad; lo que no puede pasar es que nadie lo haya visto. El criterio del
/// panel es *"un paso mas tiene que evitar una perdida concreta"* — y
/// bloquear un alta legitima no evita ninguna.
///
/// **Cero lecturas de Firestore:** las bodegas ya estan en memoria.
class BodegasParecidas extends StatelessWidget {
  const BodegasParecidas({
    super.key,
    required this.laMisma,
    required this.parecidas,
  });

  /// La que se llama exactamente igual, escrita como sea. Se avisa con otras
  /// palabras que una parecida: no es "fijate", es "ya está".
  final Bodega? laMisma;

  final List<Bodega> parecidas;

  @override
  Widget build(BuildContext context) {
    if (laMisma case final misma?) {
      return Aviso(
        texto: 'Ya tenés una bodega que se llama "${misma.nombre}".',
        tono: TonoDelAviso.error,
      );
    }
    if (parecidas.isEmpty) return const SizedBox.shrink();

    final nombres = parecidas.map((b) => '"${b.nombre}"').join(', ');
    return Aviso(
      texto: parecidas.length == 1
          ? 'Ya tenés una parecida: $nombres. Fijate que no sea la misma.'
          : 'Ya tenés estas parecidas: $nombres. Fijate que no sean la misma.',
    );
  }
}
