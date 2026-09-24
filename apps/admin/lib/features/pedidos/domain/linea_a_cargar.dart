import 'dart:math' as math;

import '../../../core/contratos/stock.dart';
import '../../catalogo/domain/producto_del_panel.dart';

/// Por que un vino no se puede elegir para un pedido. La pantalla lo dice en el
/// renglon, deshabilitado: un vino que desaparece de la lista es un operador
/// preguntandose donde esta.
enum MotivoNoElegible {
  /// Datos de prueba del seed: su stock es inventado y la callable los rechaza.
  deMuestra,

  /// Un compuesto no tiene stock propio.
  compuesto,

  /// No hay stock. Se repone primero, en Stock: cargar un pedido no inventa
  /// unidades.
  sinStock,
}

/// `null` si el vino se puede elegir. Es la MISMA decision que toma la callable
/// (`armarOrden`): el panel la adelanta para no dejar cargar una linea que el
/// servidor va a rechazar, pero **quien decide es el servidor**.
MotivoNoElegible? motivoDeQueNoSeVende(ProductoDelPanel p) {
  if (p.muestra) return MotivoNoElegible.deMuestra;
  final stock = p.stock;
  if (stock == null) return MotivoNoElegible.compuesto;
  if (stock <= 0) return MotivoNoElegible.sinStock;
  return null;
}

/// Una linea del pedido que se esta cargando: un vino de la lista con su
/// cantidad. Guarda el **precio y el stock que el operador tenia en pantalla**:
/// el precio viaja como `precioUnitarioVisto` y la callable lo rechaza si
/// cambio.
class LineaACargar {
  const LineaACargar({
    required this.productoId,
    required this.nombre,
    required this.precioUnitario,
    required this.stock,
    required this.botellas,
    this.cantidad = 1,
  });

  /// Solo para un vino que se puede vender ([motivoDeQueNoSeVende] es `null`).
  factory LineaACargar.de(ProductoDelPanel p) {
    final stock = p.stock;
    if (stock == null) {
      throw ArgumentError('un compuesto no tiene stock propio: ${p.id}');
    }
    return LineaACargar(
      productoId: p.id,
      nombre: p.nombre,
      precioUnitario: p.precio,
      stock: stock,
      botellas: p.botellas,
    );
  }

  final String productoId;
  final String nombre;

  /// Centavos de la unidad de venta, **como se veia al elegir el vino**.
  final int precioUnitario;

  /// Unidades de venta que habia al elegirlo.
  final int stock;
  final int botellas;
  final int cantidad;

  /// Lo mas que se puede pedir: el stock que se ve, y nunca mas que el tope del
  /// contrato.
  int get maximo => math.min(stock, topeDeStock);

  /// La cantidad, siempre entre 1 y [maximo]. Pasarse no falla: se queda en el
  /// tope, y la pantalla lo dice.
  LineaACargar conCantidad(int n) => LineaACargar(
    productoId: productoId,
    nombre: nombre,
    precioUnitario: precioUnitario,
    stock: stock,
    botellas: botellas,
    cantidad: n.clamp(1, math.max(1, maximo)),
  );

  /// El precio de AHORA, tras un `cambio-el-precio` del servidor.
  LineaACargar conPrecio(int centavos) => LineaACargar(
    productoId: productoId,
    nombre: nombre,
    precioUnitario: centavos,
    stock: stock,
    botellas: botellas,
    cantidad: cantidad,
  );

  /// El stock de AHORA, tras un `sin-stock` del servidor. La cantidad se
  /// acomoda al nuevo tope.
  LineaACargar conStock(int unidades) => LineaACargar(
    productoId: productoId,
    nombre: nombre,
    precioUnitario: precioUnitario,
    stock: unidades,
    botellas: botellas,
    cantidad: cantidad,
  ).conCantidad(cantidad);

  int get subtotal => precioUnitario * cantidad;

  /// `true` si pedir [cantidad] no se puede: el vino se quedo sin stock.
  bool get sinStockSuficiente => stock < 1;
}
