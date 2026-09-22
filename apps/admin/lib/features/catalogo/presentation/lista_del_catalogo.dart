import 'package:flutter/material.dart';

import '../../../core/presentation/lista_vacia.dart';
import '../domain/catalogo.dart';
import '../domain/en_la_tienda.dart';
import 'renglon_de_producto.dart';
import 'textos_del_catalogo.dart';

/// Los vinos que quedaron despues del filtro (HU-03.1).
///
/// Distingue **dos vacios** que se ven igual y no lo son: todavia no hay
/// ningun vino cargado, o no hay ninguno **para esta busqueda**. Decir el
/// segundo como el primero manda a alguien a cargar lo que ya existe.
class ListaDelCatalogo extends StatelessWidget {
  const ListaDelCatalogo({
    super.key,
    required this.renglones,
    required this.catalogo,
    required this.hayVinos,
    required this.alLimpiarLaBusqueda,
    required this.alAbrir,
  });

  /// Abrir la correccion de un vino (HU-03.4), por su id.
  final ValueChanged<String> alAbrir;

  final List<RenglonDelCatalogo> renglones;

  /// Para el motivo corto de HU-03.7: un vino publicado que la tienda igual
  /// descarta (`revisarParaLaTienda`).
  final Catalogo catalogo;

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
      itemBuilder: (_, i) {
        final p = renglones[i].producto;
        final revision = p.publicado ? revisarParaLaTienda(p, catalogo) : null;
        return RenglonDeProducto(
          renglon: renglones[i],
          alAbrir: () => alAbrir(p.id),
          motivoCorto: revision != null && !revision.aparece
              ? textoCortoDelMotivo(revision.motivo!)
              : null,
        );
      },
    );
  }
}
