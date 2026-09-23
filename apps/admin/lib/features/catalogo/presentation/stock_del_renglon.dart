import 'package:flutter/material.dart';

import '../../../core/contratos/catalogo_publico.dart';
import '../../stock/presentation/textos_del_stock.dart';

/// El stock de un vino en la lista del catalogo (HU-05.3): el numero exacto,
/// en su unidad, y en rojo cuando hay que reponer.
///
/// El operador barre la lista buscando lo que falta: por eso un agotado dice
/// solo "Se agotó" —el "0 botellas" de al lado no agrega nada— y un vino con
/// stock de sobra va en el color de las notas, sin llamar la atencion. **Lo
/// normal no se anuncia con color**, igual que la etiqueta de la tienda.
///
/// Un compuesto no tiene stock propio y no dibuja nada.
class StockDelRenglon extends StatelessWidget {
  const StockDelRenglon({
    super.key,
    required this.stock,
    required this.botellas,
  });

  final int? stock;
  final int botellas;

  /// El mismo texto para quien no ve la pantalla: la lista lo lee entero.
  static String? paraLeer(int? stock, int botellas) {
    if (stock == null) return null;
    return switch (balde(stock: stock, botellas: botellas)) {
      Balde.agotado => 'se agotó',
      Balde.quedanPocas =>
        'quedan pocas, ${describirElStock(stock, botellas: botellas)}',
      Balde.disponible =>
        'stock ${describirElStock(stock, botellas: botellas)}',
    };
  }

  @override
  Widget build(BuildContext context) {
    final actual = stock;
    if (actual == null) return const SizedBox.shrink();

    final tema = Theme.of(context);
    final elBalde = balde(stock: actual, botellas: botellas);
    final hayQueReponer = elBalde != Balde.disponible;

    final texto = switch (elBalde) {
      Balde.agotado => 'Se agotó',
      Balde.quedanPocas =>
        'Quedan pocas · ${describirElStock(actual, botellas: botellas)}',
      Balde.disponible => describirElStock(actual, botellas: botellas),
    };

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        texto,
        style: tema.textTheme.bodySmall?.copyWith(
          color: hayQueReponer
              ? tema.colorScheme.error
              : tema.colorScheme.onSurfaceVariant,
          fontWeight: hayQueReponer ? FontWeight.w600 : null,
        ),
      ),
    );
  }
}
