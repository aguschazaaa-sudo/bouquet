/// Cuantas pedidos abiertos se leen como maximo para contar las vendidas sin
/// despachar. Es el `limit` de la consulta, y coincide con lo que las reglas de
/// `ordenes` aceptan en un `list` (hasta 50).
const topeDePedidosAbiertos = 50;

/// Las unidades de un vino que ya se **vendieron y todavia no se despacharon**:
/// estan descontadas del stock pero **siguen en la estanteria** (ADR 018 §9).
///
/// Existe por el hallazgo 1 de `revisor-pagos`: sin este numero, contar el
/// deposito y corregir con lo contado **pisa lo vendido**. Con 10 en la base y en
/// la estanteria, se cargan 2 en un pedido: la base dice 8, el operador cuenta 10
/// y corrige a 10, y la proxima venta sobrevende dos botellas.
class VentasSinDespachar {
  const VentasSinDespachar({required this.unidades, required this.completo});

  /// Unidades de venta de ese vino en pedidos `sin_preparar` o `preparando`.
  final int unidades;

  /// `false` si se llego al tope de pedidos leidos: puede haber mas que las
  /// [unidades] contadas, y el aviso lo dice en vez de afirmar un numero corto.
  final bool completo;

  /// Hay algo que decirle al operador: unidades, o la duda de que las haya.
  bool get hayQueAvisar => unidades > 0 || !completo;
}

/// Cuanto de un vino esta vendido y sin despachar (HU-05.2, ADR 018 §9).
///
/// **Lanza si no puede leer**: la hoja lo dice ("no pudimos ver si hay pedidos
/// sin despachar") y no dibuja un *"no hay"* que seria un falso tranquilizador.
abstract interface class RepositorioDeVentasSinDespachar {
  Future<VentasSinDespachar> de(String productoId);
}
