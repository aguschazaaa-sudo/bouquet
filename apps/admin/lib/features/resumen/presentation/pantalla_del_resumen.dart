import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/cargando.dart';
import '../../../core/presentation/fallo_con_reintento.dart';
import '../../../theme/tokens.dart';
import '../../catalogo/catalogo_providers.dart';
import 'seccion_del_dia.dart';
import 'seccion_lo_que_mas_se_vende.dart';
import 'textos_del_resumen.dart';

/// La seccion Resumen (EP-11), y **a donde se entra** (HU-11.2: *"al
/// entrar"*). Arriba, el dia; abajo, lo que mas se vende.
///
/// Lee el catalogo con los mismos providers de Catalogo —sin `autoDispose`—:
/// entrar aca paga su carga una vez por sesion, que es lo que antes pagaba
/// entrar a Catalogo, que era la primera seccion (ADR 012, ADR 025). Encima,
/// tres lecturas por apertura: dos conteos y un documento.
class PantallaDelResumen extends ConsumerWidget {
  const PantallaDelResumen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogo = ref.watch(catalogoProvider);

    if (catalogo.hasError) {
      return FalloConReintento(
        texto: textoNoSeLeyoElCatalogo,
        alReintentar: () {
          ref.invalidate(productosProvider);
          ref.invalidate(bodegasProvider);
        },
      );
    }
    final cat = catalogo.valueOrNull;
    if (cat == null) return const Cargando(que: textoArmandoElResumen);

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
                SeccionDelDia(catalogo: cat),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Divider(),
                ),
                SeccionLoQueMasSeVende(catalogo: cat),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
