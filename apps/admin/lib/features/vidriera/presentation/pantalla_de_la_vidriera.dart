import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/cargando.dart';
import '../../../core/presentation/fallo_con_reintento.dart';
import '../../../theme/tokens.dart';
import '../../catalogo/catalogo_providers.dart';
import '../vidriera_providers.dart';
import 'seccion_de_cajas_sugeridas.dart';
import 'seccion_de_la_portada.dart';
import 'textos_de_la_vidriera.dart';

/// La seccion Vidriera (EP-09): lo que la tienda **elige** mostrar, elegido
/// por el dueño y no por una regla. Arriba la portada (HU-09.1), abajo las
/// cajas sugeridas (HU-09.2, HU-09.3).
///
/// Lee el catalogo que ya esta en memoria si se paso por Catalogo —mismos
/// providers, sin `autoDispose`— y dos documentos: la seleccion y las cajas.
/// Entrar aca primero paga la carga del catalogo una vez por sesion, igual
/// que entrar a Catalogo (ADR 012).
class PantallaDeLaVidriera extends ConsumerWidget {
  const PantallaDeLaVidriera({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogo = ref.watch(catalogoProvider);
    final seleccion = ref.watch(seleccionDeLaPortadaProvider);
    final cajas = ref.watch(cajasSugeridasProvider);

    if (catalogo.hasError || seleccion.hasError || cajas.hasError) {
      return FalloConReintento(
        texto: textoNoSePudieronLeer,
        alReintentar: () {
          ref.invalidate(productosProvider);
          ref.invalidate(bodegasProvider);
          ref.invalidate(seleccionDeLaPortadaProvider);
          ref.invalidate(cajasSugeridasProvider);
        },
      );
    }
    final cat = catalogo.valueOrNull;
    final sel = seleccion.valueOrNull;
    final caj = cajas.valueOrNull;
    if (cat == null || sel == null || caj == null) {
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SeccionDeLaPortada(seleccion: sel, catalogo: cat),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Divider(),
                ),
                SeccionDeCajasSugeridas(cajas: caj, catalogo: cat),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
