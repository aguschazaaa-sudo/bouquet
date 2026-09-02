import { test } from 'node:test';
import assert from 'node:assert/strict';

import { ESTADOS_ENTREGA, ESTADOS_PAGO } from '../src/orden.ts';
import {
  ESTADOS_PUBLICOS,
  ROTULOS,
  proyectarEstadoPublico,
} from '../src/proyeccion.ts';

// ===========================================================================
// El test que hace que la proyeccion sea confiable: recorre los 30 pares.
//
// Sin esto, un par sin rama devolveria undefined y la UI dibujaria un rotulo
// vacio. Es el equivalente de "un test que pasa por omision" (LECCIONES 4.1.9)
// pero al reves: aca la omision se busca a proposito.
// ===========================================================================

test('los 30 pares tienen un estado publico definido, con rotulo', () => {
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

  assert.equal(pares, 30, 'la aritmetica: 5 estados de pago x 6 de entrega');

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
