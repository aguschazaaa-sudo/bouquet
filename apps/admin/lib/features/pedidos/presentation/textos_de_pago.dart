import '../../../core/contratos/estado_pago.dart';
import '../../../core/contratos/plata.dart';
import '../domain/alerta_de_pago.dart';
import '../domain/fallo_de_pedidos.dart';
import '../domain/repositorio_de_pedidos.dart';

// Los textos del cobro de un pedido de la vidriera (HU-08.1) y de volver a
// consultarlo a Mercado Pago (HU-08.3). Los lee la familia, no el comprador:
// no pasan por `voz`. Funciones puras, sin Flutter: se prueban con
// `dart test`.
//
// ⚠️ Ninguno muestra el estado CRUDO del proveedor (`approved`,
// `in_process`...): eso es `PagoDeLaOrden.estadoDelProveedor`, y no es lo que
// entiende alguien que no maneja Mercado Pago. Lo que se dice sale SIEMPRE de
// `EstadoPago` -- los mismos seis valores que ya sigue el resto del panel.

const textoTituloDelPago = 'El cobro';
const textoParaConciliar = 'Para conciliar';
const textoMontoInformado = 'Monto informado';
const textoConsultado = 'Consultado';
const textoSinPagoRegistrado =
    'Todavía no hay un pago de Mercado Pago para este pedido.';
const textoBotonRevisarPago = 'Volver a consultar a Mercado Pago';
const textoSinPagoEncontrado =
    'Mercado Pago todavía no tiene ningún pago para este pedido.';

/// Los seis `EstadoPago`, en palabras para quien no maneja Mercado Pago.
/// Nunca el estado crudo del proveedor.
String textoEstadoDelPago(EstadoPago e) => switch (e) {
  EstadoPago.pendiente => 'Pendiente',
  EstadoPago.en_proceso => 'En proceso',
  EstadoPago.pagada => 'Acreditado',
  EstadoPago.rechazada => 'Rechazado',
  EstadoPago.reembolsada => 'Reembolsado',
  EstadoPago.por_fuera => 'Por fuera del sistema',
};

/// `Mercado Pago · operación número 123456789`: lo que se copia para
/// conciliar contra el resumen del proveedor.
String textoOperacion(String operacionId) =>
    'Mercado Pago · operación número $operacionId';

/// El servidor no marca un pedido pagado por un monto distinto al de lista
/// (ADR 022): esto es para que el operador lo vea antes de que alguien le
/// pregunte por qué no cambió.
String textoMontoNoCoincide(int informado, int total) =>
    'Mercado Pago informa ${enPesos(informado)}, pero el total de lista es '
    '${enPesos(total)}. No se marca como pagado un monto distinto: revisalo '
    'antes de seguir.';

const textoDevuelto = 'Devuelto';

/// Lo que Mercado Pago dijo y el pedido NO refleja (ADR 022). Dice qué pasó
/// con la plata y qué hacer; el número de operación va siempre, porque es lo
/// que se busca en Mercado Pago.
String textoDeLaAlerta(AlertaDePago a) {
  final op = 'la operación número ${a.operacionId}';
  return switch (a.motivo) {
    MotivoDeAlerta.pagoDuplicado =>
      'Mercado Pago cobró este pedido dos veces: $op (${enPesos(a.monto)}) '
          'es un segundo cobro. Hay que devolverlo desde Mercado Pago.',
    MotivoDeAlerta.montoDistinto =>
      'Mercado Pago aprobó un pago de ${enPesos(a.monto)} ($op), que no es el '
          'total del pedido. No se marcó como pagado: revisalo en Mercado Pago.',
    MotivoDeAlerta.transicionInvalida =>
      'Mercado Pago aprobó un pago de ${enPesos(a.monto)} ($op) que este '
          'pedido ya no puede recibir. Revisalo en Mercado Pago: puede haber '
          'que devolverlo.',
    MotivoDeAlerta.estadoSinTraduccion =>
      'Mercado Pago informa un reclamo o un contracargo sobre $op. Revisalo '
          'en Mercado Pago.',
    MotivoDeAlerta.otro =>
      'Mercado Pago informó algo sobre $op que no se pudo aplicar al pedido. '
          'Revisalo en Mercado Pago.',
  };
}

/// HU-08.3, cuando volver a consultar movió el estado.
String textoPagoActualizado(EstadoPago nuevo) =>
    'El pago cambió: ${textoEstadoDelPago(nuevo)}.';

/// HU-08.3, cuando volver a consultar no movió nada.
String textoPagoSigueIgual(EstadoPago actual) =>
    'Sigue igual: ${textoEstadoDelPago(actual)}.';

/// El mensaje que corresponde a cada uno de los tres resultados posibles de
/// "Volver a consultar" (HU-08.3). `encontrados == 0` manda primero: sin
/// ningún pago que conciliar, decirlo es más útil que decir si el estado
/// cambió.
String textoDelResultadoDeRevision(ResultadoDeRevision r) {
  if (r.encontrados == 0) return textoSinPagoEncontrado;
  return r.cambio
      ? textoPagoActualizado(r.estadoPago)
      : textoPagoSigueIgual(r.estadoPago);
}

/// Por qué no se pudo volver a consultar el pago. Mismo estilo que
/// `textoDelFalloDeEntrega`: dice qué hacer, no sólo qué pasó.
String textoDelFalloDePago(FalloDePedidos f) => switch (f.error) {
  ErrorDePedido.proveedorCaido =>
    'Mercado Pago no contestó. Probá de nuevo en un rato.',
  _ => 'No pudimos consultar el pago. Probá de nuevo en un rato.',
};
