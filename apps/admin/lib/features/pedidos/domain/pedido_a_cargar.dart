import '../../../core/contratos/pedido.dart';
import 'entrega_escrita.dart';
import 'linea_a_cargar.dart';

/// El pedido de WhatsApp que se esta cargando (HU-10.1): los vinos y a quien y
/// a donde. Inmutable: cada cambio devuelve otro, asi el formulario tiene un
/// solo estado y no dos copias que se desincronizan.
class PedidoACargar {
  const PedidoACargar({
    required this.idPedido,
    this.lineas = const [],
    this.entrega = const EntregaEscrita(),
  });

  /// La clave de idempotencia, y el id de la Orden. **Nace al abrir el
  /// formulario y no se regenera nunca**, ni tras un error ni al cambiar las
  /// cantidades: un timeout con la transaccion ya commiteada, seguido de otro
  /// toque, tiene que ser el MISMO pedido (ADR 018 §4; la misma leccion que
  /// `moverStock`, hallazgo 2 de `revisor-pagos`).
  final String idPedido;
  final List<LineaACargar> lineas;
  final EntregaEscrita entrega;

  /// La suma de los precios de lista. **No es lo que se cobra**: el cobro va
  /// por fuera. La pantalla lo rotula *"Total de lista"*.
  int get totalDeLista => lineas.fold(0, (a, l) => a + l.subtotal);

  /// Botellas en total, para que el operador vea cuanto vino se lleva.
  int get botellasEnTotal =>
      lineas.fold(0, (a, l) => a + l.cantidad * l.botellas);

  bool tieneElVino(String productoId) =>
      lineas.any((l) => l.productoId == productoId);

  /// `true` si se puede sumar otro vino distinto: el tope de lineas es el del
  /// contrato.
  bool get admiteOtraLinea => lineas.length < topeDeLineasDelPedido;

  /// Elegir un vino que ya esta suma UNA unidad (hasta su maximo) en vez de
  /// repetir la linea: la callable rechaza un producto repetido.
  PedidoACargar conVino(LineaACargar nueva) {
    if (tieneElVino(nueva.productoId)) {
      return conLineas([
        for (final l in lineas)
          if (l.productoId == nueva.productoId)
            l.conCantidad(l.cantidad + 1)
          else
            l,
      ]);
    }
    if (!admiteOtraLinea) return this;
    return conLineas([...lineas, nueva]);
  }

  PedidoACargar conCantidad(String productoId, int cantidad) => conLineas([
    for (final l in lineas)
      if (l.productoId == productoId) l.conCantidad(cantidad) else l,
  ]);

  PedidoACargar sinVino(String productoId) => conLineas([
    for (final l in lineas)
      if (l.productoId != productoId) l,
  ]);

  PedidoACargar conPrecioDe(String productoId, int centavos) => conLineas([
    for (final l in lineas)
      if (l.productoId == productoId) l.conPrecio(centavos) else l,
  ]);

  PedidoACargar conStockDe(String productoId, int unidades) => conLineas([
    for (final l in lineas)
      if (l.productoId == productoId) l.conStock(unidades) else l,
  ]);

  PedidoACargar conEntrega(EntregaEscrita e) =>
      PedidoACargar(idPedido: idPedido, lineas: lineas, entrega: e);

  PedidoACargar conLineas(List<LineaACargar> l) =>
      PedidoACargar(idPedido: idPedido, lineas: l, entrega: entrega);

  /// Hay algo que mandar y no falta ningun dato. Un vino sin stock suficiente
  /// tambien lo frena: la callable lo rechazaria.
  bool get sePuedeConfirmar =>
      lineas.isNotEmpty &&
      lineas.length <= topeDeLineasDelPedido &&
      !lineas.any((l) => l.sinStockSuficiente) &&
      entrega.sePuedeMandar;

  /// Lo que viaja a `crearOrdenDelPanel`. **No lleva `origen` ni `estadoPago`**:
  /// el servidor los fija y rechaza un pedido que los traiga (ADR 018 §1).
  Map<String, Object?> get aJson => {
    'idPedido': idPedido,
    'lineas': [
      for (final l in lineas)
        {
          'productoId': l.productoId,
          'cantidad': l.cantidad,
          'precioUnitarioVisto': l.precioUnitario,
        },
    ],
    'entrega': entrega.aJson,
  };
}
