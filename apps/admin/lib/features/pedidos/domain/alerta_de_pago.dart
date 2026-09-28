/// Por que un hecho de Mercado Pago que movio plata NO se aplico a la Orden.
/// Espeja los motivos de `resolverConsulta` que dejan alerta
/// (`requiereAtencion`, `packages/contratos/src/pago.ts`).
///
/// [otro] es el que no se reconoce: un motivo que el servidor agregue manana
/// se muestra igual, con un texto generico, en vez de esconder la alerta.
enum MotivoDeAlerta {
  /// Un SEGUNDO cobro aprobado, con otro numero de operacion: al comprador le
  /// cobraron dos veces y hay que devolver uno.
  pagoDuplicado,

  /// Un cobro aprobado por un monto que no es el total del pedido.
  montoDistinto,

  /// Un cobro aprobado que el pedido ya no puede recibir (uno ya devuelto).
  transicionInvalida,

  /// Un estado que no mueve el eje: un contracargo o una disputa.
  estadoSinTraduccion,

  otro,
}

/// Lo que Mercado Pago dijo y la Orden NO refleja (ADR 022): la ultima
/// alerta, en `ordenes/{id}.alertaDePago`. La escribe **solo** el servidor, en
/// la misma transaccion que el marcador del hecho.
class AlertaDePago {
  const AlertaDePago({
    required this.motivo,
    required this.operacionId,
    required this.estadoDelProveedor,
    required this.monto,
    this.en,
  });

  final MotivoDeAlerta motivo;

  /// La operacion de Mercado Pago a revisar (o a devolver).
  final String operacionId;

  /// El estado crudo (`approved`, `charged_back`...). No se muestra como
  /// titulo: sirve para buscarlo en Mercado Pago.
  final String estadoDelProveedor;

  /// Centavos.
  final int monto;

  /// La hora del servidor. `null` si el documento no la trae.
  final DateTime? en;
}
