import 'package:flutter/material.dart';

import '../../../core/contratos/provincias.dart';
import '../domain/orden.dart';
import 'dato_del_pedido.dart';
import 'textos_de_pedidos.dart';

/// Quien recibe el pedido y a donde va (HU-06.2): lo que hace falta para
/// prepararlo y despacharlo sin preguntarle nada a nadie.
///
/// **Una fila que no tiene dato no se dibuja**: sin piso, sin referencia y sin
/// mail no hay filas vacias. Y el `ordenId` no aparece jamas (glosario).
class SeccionDeQuienYDonde extends StatelessWidget {
  const SeccionDeQuienYDonde({super.key, required this.orden});

  final Orden orden;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final c = orden.contacto;
    final e = orden.entrega;
    final provincia = nombreDeProvincia(e.provincia) ?? e.provincia;
    // "San Martín 120, piso 3B": el piso, si hay, va pegado a la calle.
    final calle = [
      '${e.calle} ${e.numero}'.trim(),
      if (e.piso != null) 'piso ${e.piso}',
    ].where((t) => t.isNotEmpty).join(', ');
    final lugar = [
      e.codigoPostal,
      e.localidad,
      provincia,
    ].where((t) => t.isNotEmpty).join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(textoQuienLoRecibe, style: tema.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (c.nombre.isNotEmpty)
          DatoDelPedido(etiqueta: 'Nombre', valor: c.nombre),
        if (c.telefonoE164.isNotEmpty)
          DatoDelPedido(etiqueta: 'Teléfono', valor: c.telefonoE164),
        if (c.email != null) DatoDelPedido(etiqueta: 'Mail', valor: c.email!),
        const SizedBox(height: 14),
        Text(textoADondeVa, style: tema.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (calle.isNotEmpty)
          DatoDelPedido(etiqueta: 'Dirección', valor: calle),
        if (lugar.isNotEmpty)
          DatoDelPedido(etiqueta: 'Localidad', valor: lugar),
        if (e.referencia != null)
          DatoDelPedido(etiqueta: 'Referencia', valor: e.referencia!),
      ],
    );
  }
}
