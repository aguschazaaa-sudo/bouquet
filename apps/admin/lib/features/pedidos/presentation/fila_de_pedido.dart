import 'package:flutter/material.dart';

import '../../../core/contratos/estado_publico.dart';
import '../../../core/contratos/plata.dart';
import '../../../theme/tema.dart';
import '../../../theme/tokens.dart';
import '../domain/hace_cuanto.dart';
import '../domain/orden.dart';
import 'textos_de_pedidos.dart';

/// Un pedido en la bandeja (HU-06.1). El renglon de la libreta, como el del
/// catalogo: la linea de abajo es `filetePapel`.
///
/// Dice el **numero**, nunca el id del documento (glosario), y el rotulo sale
/// de la proyeccion. **Tocarlo abre el detalle**: es la unica puerta a
/// `/pedidos/<id>`.
///
/// Lo que espera algo del operador (`requiereAccion`) se distingue por el color
/// del rotulo **y por la palabra**, no solo por el color: no se le cree al
/// color.
class FilaDePedido extends StatelessWidget {
  const FilaDePedido({
    super.key,
    required this.orden,
    required this.ahora,
    required this.alAbrir,
  });

  final Orden orden;

  /// La hora contra la que se cuenta el *"hace cuanto"*. Viene de afuera para
  /// que un test la fije.
  final DateTime ahora;
  final VoidCallback alAbrir;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final rotulo = rotulosEstadoPublico[orden.estadoPublico]!.operador;
    final nombre = orden.contacto.nombre.isEmpty
        ? 'Sin nombre'
        : orden.contacto.nombre;
    final total = enPesos(orden.total);
    final hace = haceCuanto(orden.creadaEn, ahora);

    return Semantics(
      // Un solo nodo por renglon: sin esto el lector de pantalla lee cinco
      // fragmentos sueltos.
      container: true,
      button: true,
      label:
          '${textoDelNumero(orden.numero)}, $nombre, $rotulo, '
          '${textoBotellas(orden.botellasEnTotal)}, $hace, $total',
      hint: 'Ver el pedido',
      excludeSemantics: true,
      onTap: alAbrir,
      child: InkWell(
        onTap: alAbrir,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Tokens.filetePapel)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${textoDelNumero(orden.numero)} · $nombre',
                      style: estiloDeNombre(),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rotulo,
                      style: tema.textTheme.bodyMedium?.copyWith(
                        color: orden.requiereAccion
                            ? tema.colorScheme.primary
                            : tema.colorScheme.onSurfaceVariant,
                        fontWeight: orden.requiereAccion
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${textoDelOrigen(orden.origen)} · '
                      '${textoBotellas(orden.botellasEnTotal)} · $hace',
                      style: tema.textTheme.bodySmall?.copyWith(
                        color: tema.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Es el precio de LISTA: no se rotula "cobrado".
              Text(total, style: tema.textTheme.titleMedium),
            ],
          ),
        ),
      ),
    );
  }
}
