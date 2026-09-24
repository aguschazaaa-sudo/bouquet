/// Cuantos pedidos abiertos se leen como maximo para contar las vendidas sin
/// despachar. Es el `limit` de la consulta, y coincide con lo que las reglas de
/// `ordenes` aceptan en un `list` (hasta 50).
const topeDePedidosAbiertos = 50;

/// Las unidades de un vino que estan en pedidos **que todavia no figuran como
/// despachados**: ya estan descontadas del stock, y **puede que sigan en la
/// estanteria** (ADR 018 §9).
///
/// Existe por el hallazgo 1 de `revisor-pagos`: sin este numero, contar el
/// deposito y corregir con lo contado **pisa lo vendido**. Con 10 en la base y en
/// la estanteria, se cargan 2 en un pedido: la base dice 8, el operador cuenta 10
/// y corrige a 10, y la proxima venta sobrevende dos botellas.
///
/// ⚠️ **Es un numero condicional**, y el aviso lo dice asi: mientras el panel no
/// pueda marcar un pedido como despachado (EP-07), un pedido cuyas botellas ya
/// salieron sigue figurando abierto. Solo el operador sabe si siguen en la
/// estanteria, asi que se le da el dato y no la orden de restar.
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

/// Lo que hay en los pedidos abiertos, **de todos los vinos a la vez**.
///
/// Se lee UNA vez y se consulta por vino. Leerlo por vino costaba hasta
/// [topeDePedidosAbiertos] lecturas cada vez que se abria la hoja de correccion:
/// un inventario de 200 vinos eran ~10.000 lecturas, el 20 % de la cuota
/// (`presupuesto-lecturas`, ADR 018 §9).
class PedidosAbiertos {
  const PedidosAbiertos({
    required this.unidadesPorVino,
    required this.completo,
  });

  /// `productoId` -> unidades de venta en pedidos abiertos.
  final Map<String, int> unidadesPorVino;

  /// `false` si se llego al tope de pedidos leidos.
  final bool completo;

  VentasSinDespachar de(String productoId) => VentasSinDespachar(
    unidades: unidadesPorVino[productoId] ?? 0,
    completo: completo,
  );
}

/// Los pedidos abiertos: los que todavia no figuran como despachados (HU-05.2,
/// ADR 018 §9).
///
/// **Lanza si no puede leer**: la hoja lo dice ("no pudimos ver si hay pedidos
/// sin despachar") y no dibuja un *"no hay"* que seria un falso tranquilizador.
abstract interface class RepositorioDeVentasSinDespachar {
  Future<PedidosAbiertos> abiertos();
}
