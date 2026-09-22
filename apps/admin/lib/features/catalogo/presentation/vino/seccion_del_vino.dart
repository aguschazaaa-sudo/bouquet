import 'package:flutter/material.dart';

import '../../../../core/contratos/producto.dart' show descripcionMaxima;
import '../../domain/borrador_de_vino.dart';
import '../../domain/catalogo.dart';
import 'campo_de_bodega.dart';
import 'campo_de_graduacion.dart';
import 'campo_de_region.dart';
import 'direccion_del_vino.dart';
import 'eleccion_de_color.dart';
import 'eleccion_de_varietales.dart';

/// La ficha: que vino es. Nombre y direccion, bodega, uvas, color, organico,
/// region, añada y graduacion. Lo de la venta va en `SeccionDeLaVenta`.
///
/// No guarda nada: cada cambio sube como un borrador nuevo, y [problemaDe] ya
/// decide que se muestra (lo tocado en un alta, todo en una correccion).
class SeccionDelVino extends StatelessWidget {
  const SeccionDelVino({
    super.key,
    required this.borrador,
    required this.revision,
    required this.catalogo,
    required this.problemaDe,
    required this.alCambiar,
  });

  final BorradorDeVino borrador;
  final Revision revision;
  final Catalogo catalogo;
  final String? Function(CampoDelVino campo) problemaDe;

  /// [campo] es el que queda tocado; `null` para uno sin problema posible.
  final void Function(CampoDelVino? campo, BorradorDeVino nuevo) alCambiar;

  @override
  Widget build(BuildContext context) {
    final b = borrador;
    const aire = SizedBox(height: 20);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          initialValue: b.nombre,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Nombre del vino',
            helperText: 'Como está en la etiqueta: Trumpeter Malbec',
            errorText: problemaDe(CampoDelVino.nombre),
            errorMaxLines: 3,
          ),
          onChanged: (v) => alCambiar(CampoDelVino.nombre, b.conNombre(v)),
        ),
        const SizedBox(height: 8),
        DireccionDelVino(
          slug: revision.slug,
          esNuevo: b.esNuevo,
          choque: revision.choque,
        ),
        aire,
        CampoDeBodega(
          bodegas: catalogo.bodegas,
          elegida: b.bodegaId,
          problema: problemaDe(CampoDelVino.bodega),
          alElegir: (id) => alCambiar(CampoDelVino.bodega, b.conBodega(id)),
        ),
        aire,
        EleccionDeVarietales(
          elegidos: b.varietales,
          problema: problemaDe(CampoDelVino.varietales),
          alCambiar: (uva, elegida) => alCambiar(
            CampoDelVino.varietales,
            b.conVarietal(uva, elegida: elegida),
          ),
        ),
        aire,
        EleccionDeColor(
          elegido: b.color,
          problema: problemaDe(CampoDelVino.color),
          alElegir: (c) => alCambiar(CampoDelVino.color, b.conColor(c)),
        ),
        const SizedBox(height: 8),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Orgánico'),
          value: b.organico,
          // Sin problema posible: no hay un campo que marcar como tocado.
          onChanged: (v) => alCambiar(null, b.conOrganico(v)),
        ),
        aire,
        CampoDeRegion(
          escrita: b.region,
          sugerenciasPara: catalogo.regionesCon,
          problema: problemaDe(CampoDelVino.region),
          alCambiar: (v) => alCambiar(CampoDelVino.region, b.conRegion(v)),
        ),
        aire,
        TextFormField(
          initialValue: b.anada,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Añada (opcional)',
            helperText:
                'El año de cosecha. Vacía si no tiene, como un espumante',
            errorText: problemaDe(CampoDelVino.anada),
          ),
          onChanged: (v) => alCambiar(CampoDelVino.anada, b.conAnada(v)),
        ),
        aire,
        CampoDeGraduacion(
          escrito: b.graduacion,
          problema: problemaDe(CampoDelVino.graduacion),
          alCambiar: (v) =>
              alCambiar(CampoDelVino.graduacion, b.conGraduacion(v)),
        ),
        aire,
        // Sin la puerta de `precioFijo`, a proposito: no es plata, se edita
        // igual en un vino publicado (`BorradorDeVino.conDescripcion`).
        TextFormField(
          initialValue: b.descripcion,
          minLines: 3,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: 'Descripción (opcional)',
            helperText:
                'Lo que un comprador lee en la ficha del vino, en la tienda.',
            helperMaxLines: 2,
            errorText: problemaDe(CampoDelVino.descripcion),
            errorMaxLines: 3,
            counterText:
                '${descripcionMaxima - b.descripcion.trim().length} '
                'caracteres disponibles',
          ),
          onChanged: (v) =>
              alCambiar(CampoDelVino.descripcion, b.conDescripcion(v)),
        ),
      ],
    );
  }
}
