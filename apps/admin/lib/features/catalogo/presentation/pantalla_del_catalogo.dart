import 'package:flutter/material.dart';

import '../../../core/presentation/seccion_vacia.dart';

/// `/catalogo`. Vacia en este cambio: las bodegas y los vinos llegan con
/// EP-02 y EP-03, sobre la busqueda y los renglones de la mezcla C.
class PantallaDelCatalogo extends StatelessWidget {
  const PantallaDelCatalogo({super.key});

  @override
  Widget build(BuildContext context) {
    return const SeccionVacia(
      titulo: 'Catálogo',
      icono: Icons.wine_bar_outlined,
      explicacion:
          'Acá vas a ver y cargar tus vinos y sus bodegas: el precio, el '
          'stock, las fotos y si están a la venta en la tienda. Esta parte '
          'todavía se está construyendo.',
    );
  }
}
