import 'package:flutter/material.dart';

import '../../domain/borrador_de_vino.dart';
import 'problema_del_campo.dart';

/// Cuantas botellas trae una unidad de venta (HU-03.3).
///
/// **Es el unico campo del alta sin vuelta atras** —junto con el tipo, que el
/// panel no ofrece—: una botella que pasa a caja es otro producto (ADR 009
/// §10). La pantalla lo dice **antes** de guardar, siempre; la confirmacion,
/// solo para una caja, esta en `confirmacion_de_caja.dart`.
///
/// Al corregir ([fijas]) se muestra lo que es y por que no cambia.
class BotellasPorUnidad extends StatelessWidget {
  const BotellasPorUnidad({
    super.key,
    required this.botellas,
    required this.fijas,
    required this.problema,
    required this.alCambiar,
  });

  final int botellas;
  final bool fijas;
  final String? problema;
  final ValueChanged<int> alCambiar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final gris = tema.textTheme.bodySmall?.copyWith(
      color: tema.colorScheme.onSurfaceVariant,
    );
    final esCaja = botellas > 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text('Cómo se vende', style: tema.textTheme.titleSmall),
        ),
        const SizedBox(height: 10),
        if (fijas)
          Text(
            esCaja ? 'En caja de $botellas botellas' : 'Botella suelta',
            style: tema.textTheme.bodyLarge,
          )
        else ...[
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Botella suelta')),
              ButtonSegment(value: true, label: Text('En su propia caja')),
            ],
            selected: {esCaja},
            showSelectedIcon: false,
            onSelectionChanged: (s) => alCambiar(s.first ? 2 : 1),
          ),
          if (esCaja) _Cuantas(botellas: botellas, alCambiar: alCambiar),
        ],
        const SizedBox(height: 8),
        Text(
          fijas
              ? 'No se cambia: una botella que pasa a caja es otro producto.'
              : 'Esto no se puede cambiar después de guardar.',
          style: gris,
        ),
        if (esCaja && !fijas)
          Text(
            'El stock se va a contar en cajas, la caja viaja sola en su propio '
            'bulto y no cuenta para armar la caja de seis.',
            style: gris,
          ),
        ProblemaDelCampo(texto: problema),
      ],
    );
  }
}

/// El menos, el numero y el mas.
class _Cuantas extends StatelessWidget {
  const _Cuantas({required this.botellas, required this.alCambiar});

  final int botellas;
  final ValueChanged<int> alCambiar;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          IconButton.outlined(
            onPressed: botellas > 2 ? () => alCambiar(botellas - 1) : null,
            icon: const Icon(Icons.remove),
            tooltip: 'Una botella menos',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Semantics(
              liveRegion: true,
              child: Text(
                'Caja de $botellas',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          IconButton.outlined(
            onPressed: botellas < botellasMaximas
                ? () => alCambiar(botellas + 1)
                : null,
            icon: const Icon(Icons.add),
            tooltip: 'Una botella más',
          ),
        ],
      ),
    );
  }
}
