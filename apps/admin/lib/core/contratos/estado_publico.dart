// ignore_for_file: constant_identifier_names
//
// La proyección pública de una Orden: los 5 x 6 = 30 pares de (EstadoPago,
// EstadoEntrega) reducidos a UN rótulo por par. Espejo de
// `proyectarEstadoPublico` en packages/contratos/src/orden.ts (y del bloque
// "publico" de generated/contratos.json).
//
// ADR 002 es tajante con esto: "La UI nunca arma un rótulo a partir de los
// dos campos: llama a la proyección. Dos implementaciones del mismo rótulo
// se desincronizan." Este archivo es esa única fuente del lado Dart —
// nadie en `presentation/` calcula un rótulo mirando estadoPago +
// estadoEntrega por separado; llaman a `proyectarEstadoPublico`.

import 'estado_entrega.dart';
import 'estado_pago.dart';

enum EstadoPublico {
  recibida,
  confirmando,
  pago_rechazado,
  pagada,
  en_preparacion,
  en_camino,
  entregada,
  entregada_impaga,
  no_entregada,
  cancelada,
  cancelada_con_pago,
  reembolsada,
}

/// Estados públicos donde el operador tiene algo que resolver: cobrar,
/// entregar de nuevo, o devolver. `entregada_impaga` es la trampa —
/// entregado y visualmente "listo", pero sin cobrar.
const Set<EstadoPublico> estadosPublicosQueRequierenAccion = {
  EstadoPublico.pagada,
  EstadoPublico.entregada_impaga,
  EstadoPublico.no_entregada,
  EstadoPublico.cancelada_con_pago,
};

/// El texto que ve cada lado. `cliente` es el copy de la vidriera y del
/// panel cuando muestra "cómo lo ve el cliente"; `operador` es lo que ve
/// quien administra. Mismo dato, dos audiencias — nunca dos cálculos.
class RotuloEstado {
  const RotuloEstado({required this.cliente, required this.operador});
  final String cliente;
  final String operador;
}

const Map<EstadoPublico, RotuloEstado> rotulosEstadoPublico = {
  EstadoPublico.recibida: RotuloEstado(
    cliente: 'Pedido recibido',
    operador: 'Recibida - falta cobrar',
  ),
  EstadoPublico.confirmando: RotuloEstado(
    cliente: 'Confirmando...',
    operador: 'Pago en proceso',
  ),
  EstadoPublico.pago_rechazado: RotuloEstado(
    cliente: 'No pudimos cobrar el pago',
    operador: 'Pago rechazado',
  ),
  EstadoPublico.pagada: RotuloEstado(
    cliente: 'Pago acreditado',
    operador: 'Pagada - falta preparar',
  ),
  EstadoPublico.en_preparacion: RotuloEstado(
    cliente: 'Preparando tu pedido',
    operador: 'En preparacion',
  ),
  EstadoPublico.en_camino: RotuloEstado(
    cliente: 'En camino',
    operador: 'Despachada',
  ),
  EstadoPublico.entregada: RotuloEstado(
    cliente: 'Entregado',
    operador: 'Entregada',
  ),
  EstadoPublico.entregada_impaga: RotuloEstado(
    cliente: 'Entregado',
    operador: 'ENTREGADA SIN COBRAR',
  ),
  EstadoPublico.no_entregada: RotuloEstado(
    cliente: 'No pudimos entregarlo',
    operador: 'Entrega fallida - reprogramar',
  ),
  EstadoPublico.cancelada: RotuloEstado(
    cliente: 'Pedido cancelado',
    operador: 'Cancelada',
  ),
  EstadoPublico.cancelada_con_pago: RotuloEstado(
    cliente: 'Pedido cancelado',
    operador: 'CANCELADA CON PAGO - devolver',
  ),
  EstadoPublico.reembolsada: RotuloEstado(
    cliente: 'Pedido cancelado y reintegrado',
    operador: 'Reembolsada',
  ),
};

/// Clave = `'${estadoPago.name}|${estadoEntrega.name}'`. Es la misma forma
/// de clave que usa `generated/contratos.json` en `publico.proyeccion`, así
/// que el test que compara este archivo contra el JSON puede iterar el uno
/// contra el otro sin traducir nada.
const Map<String, EstadoPublico> proyeccion = {
  'pendiente|sin_preparar': EstadoPublico.recibida,
  'pendiente|preparando': EstadoPublico.en_preparacion,
  'pendiente|despachada': EstadoPublico.en_camino,
  'pendiente|entregada': EstadoPublico.entregada_impaga,
  'pendiente|fallida': EstadoPublico.no_entregada,
  'pendiente|cancelada': EstadoPublico.cancelada,
  'en_proceso|sin_preparar': EstadoPublico.confirmando,
  'en_proceso|preparando': EstadoPublico.confirmando,
  'en_proceso|despachada': EstadoPublico.confirmando,
  'en_proceso|entregada': EstadoPublico.entregada_impaga,
  'en_proceso|fallida': EstadoPublico.no_entregada,
  'en_proceso|cancelada': EstadoPublico.cancelada,
  'pagada|sin_preparar': EstadoPublico.pagada,
  'pagada|preparando': EstadoPublico.en_preparacion,
  'pagada|despachada': EstadoPublico.en_camino,
  'pagada|entregada': EstadoPublico.entregada,
  'pagada|fallida': EstadoPublico.no_entregada,
  'pagada|cancelada': EstadoPublico.cancelada_con_pago,
  'rechazada|sin_preparar': EstadoPublico.pago_rechazado,
  'rechazada|preparando': EstadoPublico.pago_rechazado,
  'rechazada|despachada': EstadoPublico.pago_rechazado,
  'rechazada|entregada': EstadoPublico.entregada_impaga,
  'rechazada|fallida': EstadoPublico.no_entregada,
  'rechazada|cancelada': EstadoPublico.cancelada,
  'reembolsada|sin_preparar': EstadoPublico.reembolsada,
  'reembolsada|preparando': EstadoPublico.reembolsada,
  'reembolsada|despachada': EstadoPublico.reembolsada,
  'reembolsada|entregada': EstadoPublico.entregada_impaga,
  'reembolsada|fallida': EstadoPublico.no_entregada,
  'reembolsada|cancelada': EstadoPublico.reembolsada,
};

/// La única función que arma el rótulo público. `domain/orden.dart` la usa
/// para exponer `Orden.estadoPublico`; nada más en el panel recalcula esto.
EstadoPublico proyectarEstadoPublico(EstadoPago pago, EstadoEntrega entrega) {
  final clave = '${pago.name}|${entrega.name}';
  final resultado = proyeccion[clave];
  if (resultado == null) {
    throw StateError(
      'sin proyección pública para el par "$clave" — ver ADR 002',
    );
  }
  return resultado;
}
