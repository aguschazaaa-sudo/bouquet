import { test } from 'node:test';
import assert from 'node:assert/strict';

import { ESTADOS_ENTREGA, ESTADOS_PAGO } from '../src/orden.ts';
import {
  ESTADOS_PUBLICOS,
  REQUIEREN_ACCION,
  ROTULOS,
  proyectarEstadoPublico,
} from '../src/proyeccion.ts';

// ===========================================================================
// El test que hace que la proyeccion sea confiable: recorre los 36 pares.
//
// Sin esto, un par sin rama devolveria undefined y la UI dibujaria un rotulo
// vacio. Es el equivalente de "un test que pasa por omision" (LECCIONES 4.1.9)
// pero al reves: aca la omision se busca a proposito.
// ===========================================================================

test('los 36 pares tienen un estado publico definido, con rotulo', () => {
  let pares = 0;
  const vistos = new Set<string>();

  for (const pago of ESTADOS_PAGO) {
    for (const entrega of ESTADOS_ENTREGA) {
      pares++;
      const publico = proyectarEstadoPublico(pago, entrega);
      assert.ok(
        ESTADOS_PUBLICOS.includes(publico),
        `(${pago}, ${entrega}) devolvio "${publico}", que no es un estado publico`,
      );
      const r = ROTULOS[publico];
      assert.ok(r?.cliente && r?.operador, `${publico} no tiene rotulo completo`);
      vistos.add(publico);
    }
  }

  assert.equal(pares, 36, 'la aritmetica: 6 estados de pago x 6 de entrega');

  // Control al reves: ningun estado publico declarado queda sin producirse.
  // Un estado que nadie puede alcanzar es codigo muerto con rotulo.
  const inalcanzables = ESTADOS_PUBLICOS.filter((e) => !vistos.has(e));
  assert.deepEqual(inalcanzables, [], 'hay estados publicos que ningun par produce');
});

// ===========================================================================
// Los casos que importan, nombrados
// ===========================================================================

test('el transitorio NO se llama pendiente', () => {
  assert.equal(proyectarEstadoPublico('en_proceso', 'sin_preparar'), 'confirmando');
  assert.equal(ROTULOS.confirmando.cliente, 'Confirmando...');
  // La misma palabra con la que se lee una espera de dias no puede nombrar una
  // espera de dos segundos.
  assert.ok(!ROTULOS.confirmando.cliente.toLowerCase().includes('pendiente'));
});

test('pagada y cancelada es un caso visible, no un estado inventado', () => {
  assert.equal(proyectarEstadoPublico('pagada', 'cancelada'), 'cancelada_con_pago');
  assert.match(ROTULOS.cancelada_con_pago.operador, /devolver/);
  // Al cliente no se le anuncia el lio interno.
  assert.equal(ROTULOS.cancelada_con_pago.cliente, 'Pedido cancelado');
});

test('entregada sin cobrar no queda disfrazada de entregada', () => {
  assert.equal(proyectarEstadoPublico('pendiente', 'entregada'), 'entregada_impaga');
  assert.equal(proyectarEstadoPublico('pagada', 'entregada'), 'entregada');
  assert.notEqual(ROTULOS.entregada_impaga.operador, ROTULOS.entregada.operador);
});

test('cancelar manda sobre el avance de entrega', () => {
  assert.equal(proyectarEstadoPublico('pendiente', 'cancelada'), 'cancelada');
  assert.equal(proyectarEstadoPublico('reembolsada', 'cancelada'), 'reembolsada');
});

test('el avance normal', () => {
  assert.equal(proyectarEstadoPublico('pendiente', 'sin_preparar'), 'recibida');
  assert.equal(proyectarEstadoPublico('pagada', 'sin_preparar'), 'pagada');
  assert.equal(proyectarEstadoPublico('pagada', 'preparando'), 'en_preparacion');
  assert.equal(proyectarEstadoPublico('pagada', 'despachada'), 'en_camino');
  assert.equal(proyectarEstadoPublico('pagada', 'entregada'), 'entregada');
});

// ===========================================================================
// `por_fuera`: el cobro de un pedido de WhatsApp, que el sistema no sigue.
// ADR 018 §3.
// ===========================================================================

test('un pedido de WhatsApp recorre la entrega sin caer en un estado de plata', () => {
  assert.equal(proyectarEstadoPublico('por_fuera', 'sin_preparar'), 'por_preparar');
  assert.equal(proyectarEstadoPublico('por_fuera', 'preparando'), 'en_preparacion');
  assert.equal(proyectarEstadoPublico('por_fuera', 'despachada'), 'en_camino');
  assert.equal(proyectarEstadoPublico('por_fuera', 'fallida'), 'no_entregada');
});

test('un pedido de WhatsApp entregado NO es entregada_impaga', () => {
  // El caso que justifica el estado: con `pendiente` este par daria
  // `entregada_impaga` y el pedido quedaria para siempre entre los que
  // requieren accion.
  assert.equal(proyectarEstadoPublico('por_fuera', 'entregada'), 'entregada');
  assert.equal(proyectarEstadoPublico('pendiente', 'entregada'), 'entregada_impaga');
});

test('un pedido de WhatsApp cancelado NO pide devolver plata', () => {
  assert.equal(proyectarEstadoPublico('por_fuera', 'cancelada'), 'cancelada');
  assert.notEqual(proyectarEstadoPublico('por_fuera', 'cancelada'), 'cancelada_con_pago');
});

test('por_preparar requiere accion y no afirma un cobro', () => {
  assert.ok(REQUIEREN_ACCION.includes('por_preparar'));
  for (const rotulo of [ROTULOS.por_preparar.cliente, ROTULOS.por_preparar.operador]) {
    assert.ok(!/acreditad|cobrar/i.test(rotulo), `"${rotulo}" afirma o reclama un cobro`);
  }
  assert.equal(ROTULOS.por_preparar.operador, 'Cobro por fuera - falta preparar');
});

test('por_preparar solo lo produce por_fuera: ningun otro par de pago llega ahi', () => {
  for (const pago of ESTADOS_PAGO) {
    for (const entrega of ESTADOS_ENTREGA) {
      const esperado = pago === 'por_fuera' && entrega === 'sin_preparar';
      assert.equal(
        proyectarEstadoPublico(pago, entrega) === 'por_preparar',
        esperado,
        `(${pago}, ${entrega})`,
      );
    }
  }
});
