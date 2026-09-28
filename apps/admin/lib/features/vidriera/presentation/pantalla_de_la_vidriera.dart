import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/cargando.dart';
import '../../../core/presentation/fallo_con_reintento.dart';
import '../../../theme/tokens.dart';
import '../../catalogo/catalogo_providers.dart';
import '../vidriera_providers.dart';
import 'seccion_de_la_portada.dart';
import 'textos_de_la_vidriera.dart';

/// La seccion Vidriera (EP-09): lo que la tienda **elige** mostrar, elegido
/// por el dueño y no por una regla.
///
/// Lee el catalogo que ya esta en memoria si se paso por Catalogo —mismos
/// providers, sin `autoDispose`— y un documento: la seleccion. Entrar aca
/// primero paga la carga del catalogo una vez por sesion, igual que entrar a
/// Catalogo (ADR 012).
class PantallaDeLaVidriera extends ConsumerWidget {
  const PantallaDeLaVidriera({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogo = ref.watch(catalogoProvider);
    final seleccion = ref.watch(seleccionDeLaPortadaProvider);

    if (catalogo.hasError || seleccion.hasError) {
      return FalloConReintento(
        texto: textoNoSePudieronLeer,
        alReintentar: () {
          ref.invalidate(productosProvider);
          ref.invalidate(bodegasProvider);
          ref.invalidate(seleccionDeLaPortadaProvider);
        },
      );
    }
    final cat = catalogo.valueOrNull;
    final sel = seleccion.valueOrNull;
    if (cat == null || sel == null) {
      return const Cargando(que: 'Buscando tu vidriera…');
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: Medidas.anchoDeEscritorio,
            ),
            child: SeccionDeLaPortada(seleccion: sel, catalogo: cat),
          ),
        ),
      ],
    );
  }
}
