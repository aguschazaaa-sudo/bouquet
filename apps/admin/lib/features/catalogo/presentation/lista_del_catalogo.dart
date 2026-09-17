import 'package:flutter/material.dart';

import '../../../core/presentation/lista_vacia.dart';
import '../domain/catalogo.dart';
import 'renglon_de_producto.dart';

/// Los vinos que quedaron despues del filtro (HU-03.1).
///
/// Distingue **dos vacios** que se ven igual y no lo son: todavia no hay
/// ningun vino cargado, o no hay ninguno **para esta busqueda**. Decir el
/// segundo como el primero manda a alguien a cargar lo que ya existe.
class ListaDelCatalogo extends StatelessWidget {
  const ListaDelCatalogo({
    super.key,
    required this.renglones,
    required this.hayVinos,
    required this.alLimpiarLaBusqueda,
  });

  final List<RenglonDelCatalogo> renglones;

  /// Si el catalogo tiene vinos, aunque el filtro no deje ninguno.
  final bool hayVinos;

  final VoidCallback alLimpiarLaBusqueda;

  @override
  Widget build(BuildContext context) {
    if (renglones.isEmpty && !hayVinos) {
      return const ListaVacia(
        icono: Icons.wine_bar_outlined,
        texto:
            'Todavía no hay ningún vino cargado. Cuando cargues el primero, '
            'va a aparecer acá — publicado o no.',
      );
    }

    if (renglones.isEmpty) {
      return ListaVacia(
        icono: Icons.search_off,
        texto: 'Ningún vino coincide con lo que buscaste.',
        accion: OutlinedButton(
          onPressed: alLimpiarLaBusqueda,
          child: const Text('Ver todos'),
        ),
      );
    }

    return ListView.builder(
      // El padding de abajo deja ver el ultimo renglon por encima de la barra
      // de navegacion del telefono.
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: renglones.length,
      itemBuilder: (_, i) => RenglonDeProducto(renglon: renglones[i]),
    );
  }
}
