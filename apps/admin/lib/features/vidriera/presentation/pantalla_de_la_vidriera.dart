import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/presentation/cargando.dart';
import '../../../core/presentation/fallo_con_reintento.dart';
import '../../../theme/tokens.dart';
import '../../catalogo/catalogo_providers.dart';
import '../vidriera_providers.dart';
import 'seccion_de_cajas_sugeridas.dart';
import 'seccion_de_la_portada.dart';
import 'seccion_del_envio_sin_cargo.dart';
import 'textos_de_la_vidriera.dart';

/// La seccion Vidriera (EP-09): lo que la tienda **elige** mostrar, elegido
/// por el dueño y no por una regla. Arriba la portada (HU-09.1), abajo las
/// cajas sugeridas (HU-09.2, HU-09.3). Al final, desde que monto la entrega
/// sale sin cargo (HU-11.1, ADR 026): tambien es lo que la tienda ofrece.
///
/// Lee el catalogo que ya esta en memoria si se paso por Catalogo —mismos
/// providers, sin `autoDispose`— y tres documentos: la seleccion, las cajas y
/// `config/envios`.
/// Entrar aca primero paga la carga del catalogo una vez por sesion, igual
/// que entrar a Catalogo (ADR 012).
class PantallaDeLaVidriera extends ConsumerWidget {
  const PantallaDeLaVidriera({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogo = ref.watch(catalogoProvider);
    final seleccion = ref.watch(seleccionDeLaPortadaProvider);
    final cajas = ref.watch(cajasSugeridasProvider);
    final envio = ref.watch(envioSinCargoProvider);

    if (catalogo.hasError ||
        seleccion.hasError ||
        cajas.hasError ||
        envio.hasError) {
      return FalloConReintento(
        texto: textoNoSePudieronLeer,
        alReintentar: () {
          ref.invalidate(productosProvider);
          ref.invalidate(bodegasProvider);
          ref.invalidate(seleccionDeLaPortadaProvider);
          ref.invalidate(cajasSugeridasProvider);
          ref.invalidate(envioSinCargoProvider);
        },
      );
    }
    final cat = catalogo.valueOrNull;
    final sel = seleccion.valueOrNull;
    final caj = cajas.valueOrNull;
    final env = envio.valueOrNull;
    if (cat == null || sel == null || caj == null || env == null) {
      return const Cargando(que: 'Buscando tu vidriera…');
    }

    // Slivers y no un `ListView` con una columna adentro: la portada y las
    // cajas se ordenan arrastrando, y la pagina tiene que scrollear sola
    // cuando se arrastra hacia un borde. Una caja mide un tercio de telefono.
    const separador = SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Divider(),
      ),
    );
    return LayoutBuilder(
      builder: (context, limites) {
        // Centrado al ancho de escritorio: sin un `Center` que lo haga, el
        // margen se calcula.
        final lado = math.max(
          16.0,
          (limites.maxWidth - Medidas.anchoDeEscritorio) / 2,
        );
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(lado, 20, lado, 32),
              sliver: SliverMainAxisGroup(
                slivers: [
                  SeccionDeLaPortada(seleccion: sel, catalogo: cat),
                  separador,
                  SeccionDeCajasSugeridas(cajas: caj, catalogo: cat),
                  separador,
                  SliverToBoxAdapter(
                    child: SeccionDelEnvioSinCargo(envio: env),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
