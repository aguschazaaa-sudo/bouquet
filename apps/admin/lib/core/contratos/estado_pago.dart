// ignore_for_file: constant_identifier_names
//
// El eje de PAGO de una Orden. Espejo de
// packages/contratos/src/orden.ts (ESTADOS_PAGO, NACE_PAGO,
// TRANSICIONES_PAGO, entroEnPagada, entroEnReembolsada).
//
// ADR 002: la Orden tiene DOS ejes independientes, nunca un string lineal.
// "Se cobró" avanza por plata; "se entregó" (ver estado_entrega.dart) avanza
// por logística — los dos hechos llegan por separado y a veces desordenados.
//
// Los nombres de los valores son snake_case A PROPÓSITO: son el mismo string
// que `packages/contratos` produce y que Firestore va a guardar en
// `estadoPago`. Traducirlos a camelCase acá sería una segunda
// implementación del mismo dato, y ADR 002 es explícito sobre qué pasa con
// eso: se desincroniza.
//
// scripts/ci/auditar_estados.mjs lee packages/contratos/generated/
// contratos.json y verifica que cada uno de estos strings aparezca en el
// código Dart de apps/admin/lib. Si agregás, renombrás o borrás un estado
// en orden.ts, correlo ANTES de tocar este archivo — te dice exactamente
// qué falta.

/// Ver ARQUITECTURA §4.2 para el significado de cada estado y desde dónde
/// se entra.
enum EstadoPago { pendiente, en_proceso, pagada, rechazada, reembolsada }

/// Estados en los que una Orden puede NACER en el eje de pago.
///
/// `pagada` está en la lista: carga manual desde el panel, link de pago
/// pre-aprobado, o cualquier otra ruta que agregue el dueño. Un trigger que
/// espere la transición `pendiente -> pagada` nunca se dispara para estas
/// órdenes — por eso los triggers usan `entroEnPagada`, no un chequeo de
/// transición (ADR 002, "Una Orden puede NACER en el estado final").
const Set<EstadoPago> naceEnPago = {EstadoPago.pendiente, EstadoPago.pagada};

/// A qué estados puede pasar cada estado. `rechazada` no es terminal: el
/// caso normal es que el cliente reintente con otro medio (ADR 002).
const Map<EstadoPago, Set<EstadoPago>> transicionesPago = {
  EstadoPago.pendiente: {
    EstadoPago.en_proceso,
    EstadoPago.pagada,
    EstadoPago.rechazada,
  },
  EstadoPago.en_proceso: {EstadoPago.pagada, EstadoPago.rechazada},
  EstadoPago.pagada: {EstadoPago.reembolsada},
  EstadoPago.rechazada: {EstadoPago.en_proceso, EstadoPago.pagada},
  EstadoPago.reembolsada: {},
};

/// Misma regla que `transicionPagoValida` en TS: `antes == null` es una
/// creación y se valida contra `naceEnPago`. Reescribir el mismo estado
/// siempre es válido — los webhooks son at-least-once y una notificación
/// repetida no es una transición inválida, es un reintento.
bool transicionPagoValida(EstadoPago? antes, EstadoPago despues) {
  if (antes == null) return naceEnPago.contains(despues);
  if (antes == despues) return true;
  return transicionesPago[antes]!.contains(despues);
}

/// "Entró en X" es el hecho observable, no "hubo una escritura". Es el
/// espejo exacto de `entroEnPagada`/`entroEnReembolsada` en
/// packages/contratos/src/orden.ts: `antes == null` en una creación también
/// cuenta, porque una Orden puede nacer pagada.
///
///   NO   reaccionar sólo cuando `antes == pendiente && despues == pagada`
///   SÍ   entroEnPagada(antes, despues)
bool entroEnPagada(EstadoPago? antes, EstadoPago? despues) =>
    despues == EstadoPago.pagada && antes != EstadoPago.pagada;

bool entroEnReembolsada(EstadoPago? antes, EstadoPago? despues) =>
    despues == EstadoPago.reembolsada && antes != EstadoPago.reembolsada;
