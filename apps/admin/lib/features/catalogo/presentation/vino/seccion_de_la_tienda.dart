import 'package:flutter/material.dart';

import '../../domain/catalogo.dart';
import '../../domain/producto_del_panel.dart';
import 'como_se_ve_en_la_tienda.dart';
import 'hoja_de_precio.dart';
import 'interruptor_de_tienda.dart';
import 'revision_para_publicar.dart';
import 'textos_del_vino.dart';

/// Todo lo que en la página del vino toca la tienda: publicar/despublicar,
/// la revisión previa, cómo se ve hoy, y el cambio de precio. Aparte de la
/// ficha (`SeccionDelVino`) a propósito -- design.md Decision #3/#4: lo que
/// "es plata" no comparte el "Guardar" de lo que no lo es.
///
/// Sólo se compone acá, en `PaginaDelVino`, para un vino QUE YA EXISTE: un
/// alta nueva no tiene nada de esto todavía (HU-03.5/03.6/03.7 no aplican a
/// un vino que ni se guardó).
class SeccionDeLaTienda extends StatelessWidget {
  const SeccionDeLaTienda({
    super.key,
    required this.producto,
    required this.catalogo,
    this.alIrAFotos,
  });

  final ProductoDelPanel producto;
  final Catalogo catalogo;

  /// `null` cuando no hay a dónde llevar (no debería pasar acá: esta
  /// sección sólo se compone para un vino que ya existe, y ése siempre
  /// tiene una `SeccionDeFotos` más abajo, en el formulario). Se forwardea
  /// tal cual a `RevisionParaPublicar` -- panel-vino, "El aviso de sin foto
  /// que ya existe lleva a la solución".
  final VoidCallback? alIrAFotos;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text('La tienda', style: tema.textTheme.titleMedium),
        ),
        const SizedBox(height: 10),
        InterruptorDeTienda(producto: producto, catalogo: catalogo),
        const SizedBox(height: 8),
        RevisionParaPublicar(
          producto: producto,
          catalogo: catalogo,
          alIrAFotos: alIrAFotos,
        ),
        const SizedBox(height: 12),
        ComoSeVeEnLaTienda(producto: producto, catalogo: catalogo),
        if (producto.publicado) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _cambiarPrecio(context),
              icon: const Icon(Icons.sell_outlined),
              label: const Text('Cambiar el precio'),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _cambiarPrecio(BuildContext context) async {
    final precios = [
      for (final r in catalogo.renglones)
        if (r.producto.publicado) r.producto.precio,
    ];
    final guardo = await HojaDePrecio.mostrar(
      context,
      producto: producto,
      preciosPublicados: precios,
    );
    if (guardo == true && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(textoAvisoDeAtrasoDePrecio)));
    }
  }
}
