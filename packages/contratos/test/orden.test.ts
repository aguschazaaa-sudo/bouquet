import { test } from 'node:test';
import assert from 'node:assert/strict';

import {
  entroEn,
  entroEnDespachada,
  entroEnEntregada,
  entroEnReembolsada,
  ESTADOS_ENTREGA,
  ESTADOS_PAGO,
  NACE_PAGO,
  entroEnCancelada,
  entroEnPagada,
  transicionEntregaValida,
  transicionPagoValida,
  type EstadoEntrega,
  type EstadoPago,
} from '../src/orden.ts';

// ===========================================================================
// LA leccion: una Orden puede NACER en su estado final.
// ===========================================================================

test('entroEnPagada se dispara cuando la Orden NACE pagada', () => {
  // antes === undefined es un create. Es el caso que un onDocumentUpdated se
  // pierde en silencio - no falla, simplemente no corre.
  assert.equal(entroEnPagada(undefined, 'pagada'), true);
});

test('entroEnPagada se dispara en la transicion normal', () => {
  assert.equal(entroEnPagada('pendiente', 'pagada'), true);
  assert.equal(entroEnPagada('en_proceso', 'pagada'), true);
});

test('entroEnPagada NO se dispara si ya estaba pagada', () => {
  // Los webhooks son at-least-once: la re-entrega reescribe el mismo estado.
  // El efecto no se puede repetir, y esta es la primera de las dos barreras
  // (la otra es el marcador de idempotencia, en la misma transaccion).
  assert.equal(entroEnPagada('pagada', 'pagada'), false);
});

test('entroEnPagada NO se dispara cuando el estado se va de pagada', () => {
  assert.equal(entroEnPagada('pagada', 'reembolsada'), false);
});

test('los otros entroEn* se comportan igual: nacimiento cuenta, repeticion no', () => {
  // Estos tres los encontro call-site-guard: estaban exportados y sin un solo
  // test. Un export sin consumidor ni test es codigo que nadie ejercito, y
  // "un componente que nunca ejecuto no tiene evidencia de funcionar".
  assert.equal(entroEnDespachada('preparando', 'despachada'), true);
  assert.equal(entroEnDespachada('despachada', 'despachada'), false);
  assert.equal(entroEnDespachada('fallida', 'despachada'), true, 'reprogramar despacha de nuevo');

  assert.equal(entroEnEntregada('despachada', 'entregada'), true);
  assert.equal(entroEnEntregada(undefined, 'entregada'), true, 'el helper no juzga nacimientos');

  assert.equal(entroEnReembolsada('pagada', 'reembolsada'), true);
  assert.equal(entroEnReembolsada('reembolsada', 'reembolsada'), false);
});

test('entroEn generico: undefined -> undefined no es entrar en nada', () => {
  assert.equal(entroEn('pagada', undefined, undefined), false);
  assert.equal(entroEn('pagada', 'pendiente', undefined), false, 'borrar no es entrar');
  assert.equal(entroEn('pagada', undefined, 'pagada'), true);
});

test('una Orden puede nacer cancelada? no: cancelar es una transicion', () => {
  assert.equal(entroEnCancelada(undefined, 'cancelada'), true); // el helper es honesto...
  assert.equal(transicionEntregaValida(undefined, 'cancelada'), false); // ...la tabla no lo permite
});

test('los nacimientos validos del eje de pago son pendiente y pagada', () => {
  for (const e of ESTADOS_PAGO) {
    assert.equal(
      transicionPagoValida(undefined, e),
      NACE_PAGO.includes(e),
      `nacer en ${e} deberia ser ${NACE_PAGO.includes(e)}`,
    );
  }
});

// ===========================================================================
// Transiciones
// ===========================================================================

test('transiciones de pago validas', () => {
  assert.equal(transicionPagoValida('pendiente', 'en_proceso'), true);
  assert.equal(transicionPagoValida('en_proceso', 'pagada'), true);
  assert.equal(transicionPagoValida('pagada', 'reembolsada'), true);
  assert.equal(transicionPagoValida('rechazada', 'pagada'), true); // reintento
});

test('transiciones de pago invalidas', () => {
  assert.equal(transicionPagoValida('reembolsada', 'pagada'), false);
  assert.equal(transicionPagoValida('pendiente', 'reembolsada'), false);
  assert.equal(transicionPagoValida('pagada', 'pendiente'), false);
});

test('reescribir el mismo estado siempre es valido', () => {
  for (const e of ESTADOS_PAGO) assert.equal(transicionPagoValida(e, e), true);
  for (const e of ESTADOS_ENTREGA) assert.equal(transicionEntregaValida(e, e), true);
});

test('transiciones de entrega', () => {
  assert.equal(transicionEntregaValida('sin_preparar', 'preparando'), true);
  assert.equal(transicionEntregaValida('preparando', 'cancelada'), true);
  assert.equal(transicionEntregaValida('despachada', 'fallida'), true);
  assert.equal(transicionEntregaValida('fallida', 'despachada'), true); // reprogramar
  assert.equal(transicionEntregaValida('despachada', 'cancelada'), false); // ya salio
  assert.equal(transicionEntregaValida('entregada', 'despachada'), false);
});

// ===========================================================================
// Los dos ejes no se pisan - el caso del webhook fuera de orden
// ===========================================================================

test('un pago que llega despues de cancelar no toca el eje de entrega', () => {
  const antes = { pago: 'pendiente' as EstadoPago, entrega: 'cancelada' as EstadoEntrega };
  // El webhook solo escribe SU eje.
  const despues = { ...antes, pago: 'pagada' as EstadoPago };

  assert.equal(transicionPagoValida(antes.pago, despues.pago), true);
  assert.equal(despues.entrega, 'cancelada', 'la entrega no se movio');
  assert.equal(entroEnPagada(antes.pago, despues.pago), true, 'el efecto de cobro igual corre');
});
