import 'package:flutter/material.dart';

import '../../../app/rutas.dart';
import '../../../theme/tokens.dart';

/// El camino a Bodegas desde Catalogo.
///
/// **Bodegas no es una seccion de la navegacion** —no esta en
/// `secciones.dart`— y por eso este widget no es decoracion: es la UNICA
/// puerta a `/catalogo/bodegas`. Sin el, la pantalla existe y nadie la puede
/// abrir, que es la pagina huerfana que `cazador-de-puertas` busca.
class AccesoABodegas extends StatelessWidget {
  const AccesoABodegas({super.key, required this.cuantas, required this.alIr});

  final int cuantas;

  /// Recibe la ruta a la que ir, para no importar go_router desde acá.
  final void Function(String ruta) alIr;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);

    return Material(
      color: tema.colorScheme.surface,
      borderRadius: BorderRadius.circular(Medidas.radio),
      child: InkWell(
        borderRadius: BorderRadius.circular(Medidas.radio),
        onTap: () => alIr(Rutas.bodegas),
        child: Container(
          constraints: const BoxConstraints(minHeight: Medidas.tactil),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Medidas.radio),
            border: Border.all(color: tema.colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(
                Icons.store_outlined,
                size: 20,
                color: tema.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  cuantas == 0
                      ? 'Bodegas — todavía no cargaste ninguna'
                      : 'Bodegas — $cuantas cargadas',
                  style: tema.textTheme.bodyMedium,
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: tema.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
