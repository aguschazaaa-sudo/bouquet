import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/rutas.dart';
import '../../../core/presentation/cargando.dart';
import '../../../core/presentation/fallo_con_reintento.dart';
import '../domain/vista_de_bandeja.dart';
import '../pedidos_providers.dart';
import 'buscador_de_pedido.dart';
import 'lista_de_pedidos.dart';
import 'selector_de_vista.dart';
import 'textos_de_pedidos.dart';

/// `/pedidos` — los pedidos por lo que hay que hacer con ellos (HU-06.1,
/// HU-06.3), el buscador por numero (HU-06.4) y la puerta a cargar uno de
/// WhatsApp (HU-10.1).
///
/// **Una lectura por apertura, y otra por *"Actualizar"* o *"Ver mas"***: la
/// bandeja no escucha cambios en vivo, y por eso el boton existe
/// (ARQUITECTURA §6.3: el riesgo de cuota es un stream sin `limit`).
///
/// La vista elegida vive aca y no en un provider global: al salir de la
/// pantalla se olvida, y volver empieza en *"Requieren acción"* (HU-06.3), que
/// es lo que pregunta quien entra: *"¿que espera algo de mi?"*. Antes empezaba
/// en *"Por preparar"*, que deja afuera una entrega fallida.
class PantallaDePedidos extends ConsumerStatefulWidget {
  const PantallaDePedidos({super.key});

  @override
  ConsumerState<PantallaDePedidos> createState() => _PantallaDePedidosState();
}

class _PantallaDePedidosState extends ConsumerState<PantallaDePedidos> {
  VistaDeBandeja _vista = const RequierenAccion();
  bool _cargandoMas = false;
  bool _verMasFallo = false;

  Future<void> _verMas() async {
    setState(() {
      _cargandoMas = true;
      _verMasFallo = false;
    });
    try {
      await ref.read(bandejaProvider(_vista).notifier).verMas();
    } catch (_) {
      // Lo ya cargado se conserva; se avisa. Un error que se pierde es un
      // boton que "no hace nada" (HU-04.4).
      if (mounted) setState(() => _verMasFallo = true);
    } finally {
      if (mounted) setState(() => _cargandoMas = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bandeja = ref.watch(bandejaProvider(_vista));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      textoTituloDePedidos,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: textoActualizar,
                    onPressed: () => ref.invalidate(bandejaProvider(_vista)),
                    icon: const Icon(Icons.refresh),
                  ),
                  const SizedBox(width: 4),
                  // La unica puerta a `/pedidos/nuevo` (HU-10.1).
                  FilledButton.icon(
                    onPressed: () => context.go(Rutas.nuevoPedido),
                    icon: const Icon(Icons.add),
                    label: const Text(textoCargarUnPedido),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const BuscadorDePedido(),
              const SizedBox(height: 12),
              SelectorDeVista(
                elegida: _vista,
                alElegir: (v) => setState(() {
                  _vista = v;
                  _verMasFallo = false;
                }),
              ),
            ],
          ),
        ),
        Expanded(
          child: switch (bandeja) {
            // El error va PRIMERO: una lectura que fallo y se pinta como una
            // bandeja vacia manda a cargar de nuevo lo que ya existe.
            AsyncError() => FalloConReintento(
              texto: textoNoSePudieronLeerLosPedidos,
              alReintentar: () => ref.invalidate(bandejaProvider(_vista)),
            ),
            AsyncData(:final value) => ListaDePedidos(
              vista: _vista,
              bandeja: value,
              ahora: DateTime.now(),
              alAbrir: (orden) =>
                  context.go(Rutas.pedido(orden.id), extra: orden),
              alVerMas: _verMas,
              verMasFallo: _verMasFallo,
              cargandoMas: _cargandoMas,
            ),
            _ => const Cargando(que: textoCargandoPedidos),
          },
        ),
      ],
    );
  }
}
