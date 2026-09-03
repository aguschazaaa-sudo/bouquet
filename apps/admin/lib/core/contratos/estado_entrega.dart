// ignore_for_file: constant_identifier_names
//
// El eje de ENTREGA de una Orden. Espejo de packages/contratos/src/orden.ts
// (ESTADOS_ENTREGA, NACE_ENTREGA, TRANSICIONES_ENTREGA, entroEnDespachada,
// entroEnEntregada, entroEnCancelada).
//
// Ver el comentario de cabecera de estado_pago.dart: mismo trato, mismo
// motivo. Los nombres son snake_case porque son el string que Firestore
// guarda en `estadoEntrega`, y scripts/ci/auditar_estados.mjs los busca
// literalmente en este código.

/// Ver ARQUITECTURA §4.2 para el significado de cada estado y desde dónde
/// se entra.
enum EstadoEntrega {
  sin_preparar,
  preparando,
  despachada,
  entregada,
  fallida,
  cancelada,
}

/// En el eje de entrega la Orden sólo puede nacer `sin_preparar`: el
/// carrito vive en `localStorage` y la Orden nace confirmada, nunca en
/// borrador (ARQUITECTURA §4.4).
const Set<EstadoEntrega> naceEnEntrega = {EstadoEntrega.sin_preparar};

/// `despachada` NO puede cancelarse: una vez que el vino salió, el estado
/// honesto es `fallida`, no `cancelada` — el reparto ya costó. Y `fallida`
/// vuelve a `despachada`: no había nadie el martes, se vuelve el jueves
/// (ADR 002).
const Map<EstadoEntrega, Set<EstadoEntrega>> transicionesEntrega = {
  EstadoEntrega.sin_preparar: {
    EstadoEntrega.preparando,
    EstadoEntrega.cancelada,
  },
  EstadoEntrega.preparando: {EstadoEntrega.despachada, EstadoEntrega.cancelada},
  EstadoEntrega.despachada: {EstadoEntrega.entregada, EstadoEntrega.fallida},
  EstadoEntrega.entregada: {},
  EstadoEntrega.fallida: {EstadoEntrega.despachada},
  EstadoEntrega.cancelada: {},
};

bool transicionEntregaValida(EstadoEntrega? antes, EstadoEntrega despues) {
  if (antes == null) return naceEnEntrega.contains(despues);
  if (antes == despues) return true;
  return transicionesEntrega[antes]!.contains(despues);
}

bool entroEnDespachada(EstadoEntrega? antes, EstadoEntrega? despues) =>
    despues == EstadoEntrega.despachada && antes != EstadoEntrega.despachada;

bool entroEnEntregada(EstadoEntrega? antes, EstadoEntrega? despues) =>
    despues == EstadoEntrega.entregada && antes != EstadoEntrega.entregada;

bool entroEnCancelada(EstadoEntrega? antes, EstadoEntrega? despues) =>
    despues == EstadoEntrega.cancelada && antes != EstadoEntrega.cancelada;
