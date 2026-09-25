import { test } from 'node:test';
import assert from 'node:assert/strict';

import {
  CORREOS,
  MOTIVOS_DE_CANCELACION,
  MOTIVOS_DE_FALLA,
  MOTIVOS_SIN_REPONER,
  SOLO_LO_ESCRIBE_EL_SERVIDOR,
  laEscribeElPanel,
  parsearPedidoDeCancelacion,
  sePuedeDespachar,
} from '../src/despacho.ts';
import { ESTADOS_ENTREGA, ESTADOS_PAGO, TRANSICIONES_ENTREGA, transicionEntregaValida } from '../src/orden.ts';

const ID = '3f2b9c1e-7a4d-4e8f-9b21-5c6d7e8f9a0b';

// ------------------------------------------------------ quien escribe que

test('el panel escribe exactamente las transiciones de la tabla menos cancelar', () => {
  // Control positivo: las cinco que el panel SI escribe.
  const delPanel: string[] = [];
  for (const a of ESTADOS_ENTREGA) for (const d of ESTADOS_ENTREGA) if (laEscribeElPanel(a, d)) delPanel.push(`${a}>${d}`);
  assert.deepEqual(delPanel.sort(), [
    'despachada>entregada',
    'despachada>fallida',
    'fallida>despachada',
    'preparando>despachada',
    'sin_preparar>preparando',
  ]);
});

test('cancelar es valido en la tabla pero NO lo escribe el panel: repone stock', () => {
  assert.deepEqual([...SOLO_LO_ESCRIBE_EL_SERVIDOR], ['cancelada']);
  for (const desde of ['sin_preparar', 'preparando'] as const) {
    assert.ok(transicionEntregaValida(desde, 'cancelada'), `${desde} -> cancelada es de la tabla`);
    assert.equal(laEscribeElPanel(desde, 'cancelada'), false, `${desde} -> cancelada no es del panel`);
  }
});

test('ninguna transicion del panel queda fuera de la tabla de ADR 002', () => {
  for (const a of ESTADOS_ENTREGA) {
    for (const d of ESTADOS_ENTREGA) {
      if (laEscribeElPanel(a, d)) assert.ok(TRANSICIONES_ENTREGA[a].includes(d), `${a} -> ${d}`);
    }
  }
});

test('reescribir el mismo estado no es una transicion del panel', () => {
  // `transicionEntregaValida` la acepta (los webhooks reescriben); el panel no:
  // un segundo "despachar" sobre una orden ya despachada pisaria el seguimiento.
  for (const e of ESTADOS_ENTREGA) {
    assert.ok(transicionEntregaValida(e, e));
    assert.equal(laEscribeElPanel(e, e), false, e);
  }
});

// ----------------------------------------------------------------- despachar

test('WhatsApp se despacha sin mirar el pago; la vidriera solo pagada', () => {
  for (const pago of ESTADOS_PAGO) assert.ok(sePuedeDespachar('whatsapp', pago), `whatsapp/${pago}`);
  const deLaVidriera = ESTADOS_PAGO.filter((p) => sePuedeDespachar('vidriera', p));
  assert.deepEqual(deLaVidriera, ['pagada']);
});

// ------------------------------------------------------------------ las listas

test('las listas no repiten valores y todas tienen `otro` donde un motivo real puede faltar', () => {
  for (const [nombre, lista] of [
    ['CORREOS', CORREOS],
    ['MOTIVOS_DE_FALLA', MOTIVOS_DE_FALLA],
    ['MOTIVOS_DE_CANCELACION', MOTIVOS_DE_CANCELACION],
    ['MOTIVOS_SIN_REPONER', MOTIVOS_SIN_REPONER],
  ] as const) {
    assert.equal(new Set(lista).size, lista.length, `${nombre} repite`);
  }
  assert.ok((CORREOS as readonly string[]).includes('otro'));
  assert.ok((MOTIVOS_DE_FALLA as readonly string[]).includes('otro'));
  assert.ok((MOTIVOS_DE_CANCELACION as readonly string[]).includes('otro'));
});

test('la entrega fallida tiene el motivo legal: sin un mayor de 18 no se entrega', () => {
  assert.ok((MOTIVOS_DE_FALLA as readonly string[]).includes('sin_mayor'));
});

// ------------------------------------------------------------------ cancelar

test('control positivo: un pedido de cancelacion valido pasa', () => {
  const r = parsearPedidoDeCancelacion({ ordenId: ID, motivo: 'mal_cargado' });
  assert.ok(r.ok);
  assert.deepEqual(r.valor, { ordenId: ID, motivo: 'mal_cargado' });
});

test('cada motivo de la lista pasa', () => {
  for (const motivo of MOTIVOS_DE_CANCELACION) assert.ok(parsearPedidoDeCancelacion({ ordenId: ID, motivo }).ok, motivo);
});

test('rechaza lo que no cumple, sin corregirlo', () => {
  const malos: [string, unknown][] = [
    ['no es un objeto', 'cancelar'],
    ['null', null],
    ['una lista', [ID, 'otro']],
    ['sin motivo', { ordenId: ID }],
    ['sin ordenId', { motivo: 'otro' }],
    ['motivo inventado', { ordenId: ID, motivo: 'porque-si' }],
    ['motivo no texto', { ordenId: ID, motivo: 1 }],
    ['ordenId corto', { ordenId: 'abc', motivo: 'otro' }],
    ['ordenId con barra: seria otra ruta', { ordenId: `ordenes/${ID}`, motivo: 'otro' }],
    ['ordenId reservado de Firestore', { ordenId: '__pedido-de-prueba__', motivo: 'otro' }],
    // El estado lo decide el servidor, no quien cancela.
    ['una clave de mas', { ordenId: ID, motivo: 'otro', estadoEntrega: 'cancelada' }],
    ['reponer declarado por el cliente', { ordenId: ID, motivo: 'otro', reponer: false }],
  ];
  for (const [porque, entrada] of malos) {
    assert.equal(parsearPedidoDeCancelacion(entrada).ok, false, porque);
  }
});
