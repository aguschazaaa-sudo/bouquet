import 'package:flutter/material.dart';

import '../../domain/borrador_de_vino.dart';
import 'botellas_por_unidad.dart';
import 'campo_de_precio.dart';

/// Como se vende: las botellas por unidad (HU-03.3), el volumen y el precio.
/// Van juntos porque el precio es **por unidad de venta**: en una caja de 3,
/// el de la caja entera (ADR 008 §1).
class SeccionDeLaVenta extends StatelessWidget {
  const SeccionDeLaVenta({
    super.key,
    required this.borrador,
    required this.revision,
    required this.problemaDe,
    required this.alCambiar,
  });

  final BorradorDeVino borrador;
  final Revision revision;
  final String? Function(CampoDelVino campo) problemaDe;
  final void Function(CampoDelVino? campo, BorradorDeVino nuevo) alCambiar;

  @override
  Widget build(BuildContext context) {
    final b = borrador;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BotellasPorUnidad(
          botellas: b.botellas,
          fijas: !b.esNuevo,
          problema: problemaDe(CampoDelVino.botellas),
          alCambiar: (n) => alCambiar(CampoDelVino.botellas, b.conBotellas(n)),
        ),
        const SizedBox(height: 20),
        TextFormField(
          initialValue: b.volumen,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Volumen de cada botella',
            suffixText: 'ml',
            errorText: problemaDe(CampoDelVino.volumen),
          ),
          onChanged: (v) => alCambiar(CampoDelVino.volumen, b.conVolumen(v)),
        ),
        const SizedBox(height: 20),
        CampoDePrecio(
          escrito: b.precio,
          leido: revision.precio,
          problema: problemaDe(CampoDelVino.precio),
          fijo: b.precioFijo,
          alCambiar: (v) => alCambiar(CampoDelVino.precio, b.conPrecio(v)),
        ),
        if (b.botellas > 1)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 12),
            child: Text(
              'Es el precio de la caja de ${b.botellas}, no de una botella.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}
