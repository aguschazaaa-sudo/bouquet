import 'package:flutter/material.dart';

import '../../../core/contratos/estado_entrega.dart';
import '../../../core/presentation/aviso.dart';
import '../../../core/presentation/lista_vacia.dart';
import '../domain/orden.dart';
import '../pedidos_providers.dart';
import 'fila_de_pedido.dart';
import 'textos_de_pedidos.dart';

/// Los pedidos ya cargados de un estado, con *"Ver mas"* si hay mas (HU-06.1).
///
/// **Una bandeja vacia dice que esta vacia** ([textoBandejaVacia]); y si hay
/// documentos que no se pudieron leer como pedido, **dice cuantos**
/// ([textoIncompletos]): un pedido que desaparece de la lista en silencio es
/// un pedido que nadie prepara.
class ListaDePedidos extends StatelessWidget {
  const ListaDePedidos({
    super.key,
    required this.estado,
    required this.bandeja,
    required this.ahora,
    required this.alAbrir,
    required this.alVerMas,
    required this.verMasFallo,
    required this.cargandoMas,
  });

  final EstadoEntrega estado;
  final Bandeja bandeja;
  final DateTime ahora;
  final ValueChanged<Orden> alAbrir;
  final VoidCallback alVerMas;

  /// El ultimo *"Ver mas"* fallo. Lo ya cargado se conserva y se avisa.
  final bool verMasFallo;
  final bool cargandoMas;

  @override
  Widget build(BuildContext context) {
    if (bandeja.estaVacia) {
      return ListaVacia(
        icono: Icons.receipt_long_outlined,
        texto: textoBandejaVacia(estado),
      );
    }
    return ListView(
      children: [
        if (bandeja.incompletos > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Aviso(
              texto: textoIncompletos(bandeja.incompletos),
              tono: TonoDelAviso.informacion,
            ),
          ),
        for (final orden in bandeja.ordenes)
          FilaDePedido(
            orden: orden,
            ahora: ahora,
            alAbrir: () => alAbrir(orden),
          ),
        if (verMasFallo)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Aviso(texto: textoNoSePudoVerMas, tono: TonoDelAviso.error),
          ),
        if (bandeja.hayMas)
          Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton(
              onPressed: cargandoMas ? null : alVerMas,
              child: Text(cargandoMas ? textoCargandoPedidos : textoVerMas),
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}
