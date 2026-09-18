import 'package:flutter/material.dart';

import '../../../../core/presentation/aviso.dart';
import '../../domain/catalogo.dart';

/// La direccion del vino en la tienda, a la vista mientras se escribe el
/// nombre (ADR 013 §1).
///
/// **Queda fija desde el alta**, no desde la publicacion: el slug es el id del
/// documento. Por eso se muestra antes de guardar — es la unica forma de ver
/// un error de tipeo a tiempo. Al corregir se muestra fija, y decirlo es el
/// punto.
///
/// El choque que frena ya lo dice el campo del nombre. Aca va solo el que no
/// frena: uno de muestra.
class DireccionDelVino extends StatelessWidget {
  const DireccionDelVino({
    super.key,
    required this.slug,
    required this.esNuevo,
    required this.choque,
  });

  final String slug;
  final bool esNuevo;
  final ChoqueDeDireccion? choque;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final texto = slug.isEmpty
        ? 'Escribí el nombre para ver su dirección en la tienda'
        : esNuevo
        ? 'Su dirección en la tienda: /vinos/$slug — no se cambia después'
        : 'Su dirección en la tienda no cambia: /vinos/$slug';
    final deMuestra = choque != null && !choque!.bloquea ? choque : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Text(
            texto,
            style: tema.textTheme.bodySmall?.copyWith(
              color: tema.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        if (deMuestra != null) ...[
          const SizedBox(height: 10),
          Aviso(
            texto:
                'Hay un vino de muestra con esta dirección: '
                '«${deMuestra.vino.nombre}». No molesta mientras no estén los '
                'dos en la tienda; los de muestra se borran antes de abrirla.',
          ),
        ],
      ],
    );
  }
}
