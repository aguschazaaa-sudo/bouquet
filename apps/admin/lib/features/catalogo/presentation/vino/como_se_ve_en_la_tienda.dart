import 'package:flutter/material.dart';

import '../../../../core/contratos/catalogo_publico.dart';
import '../../../../core/presentation/aviso.dart';
import '../../domain/catalogo.dart';
import '../../domain/en_la_tienda.dart';
import '../../domain/producto_del_panel.dart';
import 'textos_del_vino.dart';

/// Cómo ve la tienda a este vino HOY (HU-03.7): si aparece, el balde en
/// palabras junto al número EXACTO de stock -que es un dato interno, la
/// tienda sólo muestra el balde-, el tope por pedido y el path de su ficha;
/// si no aparece, por qué.
///
/// Llama a `revisarParaLaTienda`, no a `revisarParaPublicar`: acá se muestra
/// el ESTADO REAL, no una simulación de "qué pasaría si publico ahora".
class ComoSeVeEnLaTienda extends StatelessWidget {
  const ComoSeVeEnLaTienda({
    super.key,
    required this.producto,
    required this.catalogo,
  });

  final ProductoDelPanel producto;
  final Catalogo catalogo;

  @override
  Widget build(BuildContext context) {
    final revision = revisarParaLaTienda(producto, catalogo);
    if (!revision.aparece) {
      return Aviso(
        texto: textoDelMotivoEnLaTienda(revision.motivo!),
        tono: TonoDelAviso.error,
      );
    }

    final stock = producto.stock ?? 0;
    final elBalde = balde(stock: stock, botellas: producto.botellas);
    final elTope = tope(stock: stock);
    final rotuloDelBalde = textoDelBalde(elBalde);
    final tema = Theme.of(context);
    final variante = tema.textTheme.bodySmall?.copyWith(
      color: tema.colorScheme.onSurfaceVariant,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Está en la tienda.',
          style: tema.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          rotuloDelBalde == null
              ? '$stock en stock · tope $elTope por pedido'
              : '$rotuloDelBalde · $stock en stock · tope $elTope por pedido',
          style: tema.textTheme.bodyMedium,
        ),
        if (revision.sinFoto) ...[
          const SizedBox(height: 6),
          const Aviso(texto: textoApareceSinFoto),
        ],
        const SizedBox(height: 6),
        // La vidriera todavía NO se desplegó (sin `apphosting.yaml`, sin
        // backend: ADR 014). El dominio final es un Open Question de
        // design.md ("¿a qué dominio apunta?"): hasta que exista, esto es
        // texto informativo con el path relativo, no un link tocable.
        Text('Su ficha: /vinos/${producto.slug}', style: variante),
        Text('Todavía no hay tienda publicada donde abrirlo.', style: variante),
      ],
    );
  }
}
