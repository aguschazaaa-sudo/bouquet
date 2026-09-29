import 'package:flutter/material.dart';

import '../../../theme/tema.dart';
import '../domain/seleccion_de_la_portada.dart';
import 'manija_para_arrastrar.dart';
import 'textos_de_la_vidriera.dart';

/// Un lugar de la portada: la manija para cambiarlo de lugar, el numero, el
/// vino, si se ve, y sacarlo.
///
/// La manija a la izquierda y sacar a la derecha, lejos: sacar no pide
/// confirmacion —tiene vuelta atras en un toque, volver a agregarlo, y la regla
/// del panel es confirmar solo lo que no la tiene—, asi que no puede estar al
/// lado de lo que se toca para arrastrar.
class RenglonDeLaPortada extends StatelessWidget {
  const RenglonDeLaPortada({
    super.key,
    required this.lugar,
    required this.indice,
    required this.habilitado,
    required this.alSacar,
  });

  final LugarDeLaPortada lugar;

  /// La posicion en la lista, desde 0. En pantalla se cuenta desde 1, como lo
  /// cuenta una persona.
  final int indice;

  /// `false` mientras se guarda el cambio anterior: dos gestos seguidos
  /// guardarian dos listas armadas sobre la misma de antes.
  final bool habilitado;

  final VoidCallback alSacar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final esquema = tema.colorScheme;
    final fuera = lugar.fuera;
    final nombre = lugar.producto?.nombre ?? textoVinoQueYaNoExiste;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Row(
        children: [
          ManijaParaArrastrar(indice: indice, habilitada: habilitado),
          CircleAvatar(
            radius: 12,
            backgroundColor: esquema.surfaceContainerHighest,
            foregroundColor: esquema.onSurface,
            child: Text('${indice + 1}', style: tema.textTheme.labelMedium),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(nombre, style: estiloDeNombre()),
                  if (fuera != null)
                    Text(
                      textoFueraDeLaPortada(fuera),
                      style: tema.textTheme.bodySmall?.copyWith(
                        color: esquema.error,
                      ),
                    ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: textoSacar,
            iconSize: 20,
            // Deshabilitado con la regla, no con el gris a media tinta de
            // Material: al lado de uno habilitado, no se distinguian.
            style: IconButton.styleFrom(
              foregroundColor: esquema.onSurfaceVariant,
              disabledForegroundColor: esquema.outlineVariant,
            ),
            icon: const Icon(Icons.close),
            onPressed: habilitado ? alSacar : null,
          ),
        ],
      ),
    );
  }
}
