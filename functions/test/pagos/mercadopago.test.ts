// El adaptador de Mercado Pago, sin red y sin emulador.  ADR 022.
//
// La firma se prueba contra la PLANTILLA DE LA DOCUMENTACION de Mercado Pago
// (`id:[data.id_url];request-id:[x-request-id_header];ts:[ts_header];`), armada
// aca a mano: si el validador del SDK dejara de decir lo mismo que la
// documentacion, esto lo ve.  Un test que firmara con el mismo codigo que
// verifica daria verde con los dos rotos.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';

import { ESTADOS_PAGO } from '@bouquet/contratos';

import { avisoDesdeHttp } from '../../src/pagos/aviso.ts';
import {
  ESTADOS_DE_MERCADO_PAGO,
  estadoDeMercadoPago,
  leerAvisoDeMercadoPago,
  proveedorMercadoPago,
  traducirPagoDeMercadoPago,
  type ClienteDeMercadoPago,
} from '../../src/pagos/mercadopago.ts';

const ORDEN = '3f2b9c1e-7a4d-4e8f-9b21-5c6d7e8f9a0b';
const SECRETO = 'secreto-de-prueba';

/** Un pago con la forma de `GET /v1/payments/{id}` (recortado a lo que se lee, mas ruido). */
const pagoDeLaApi = (cambios: Record<string, unknown> = {}) => ({
  id: 1318431457,
  date_created: '2026-09-28T10:00:00.000-04:00',
  date_approved: '2026-09-28T10:00:03.000-04:00',
  status: 'approved',
  status_detail: 'accredited',
  currency_id: 'ARS',
  transaction_amount: 119400,
  transaction_amount_refunded: 0,
  external_reference: ORDEN,
  payment_method_id: 'visa',
  live_mode: false,
  ...cambios,
});

function firmar(dataId: string, requestId: string, ts: string, secreto = SECRETO): string {
  const texto = 'id:[data.id_url];request-id:[x-request-id_header];ts:[ts_header];'
    .replace('[data.id_url]', dataId)
    .replace('[x-request-id_header]', requestId)
    .replace('[ts_header]', ts);
  return `ts=${ts},v1=${createHmac('sha256', secreto).update(texto).digest('hex')}`;
}

const aviso = (dataId: string, firma: string | undefined, tema = 'payment') =>
  avisoDesdeHttp(
    firma === undefined ? { 'x-request-id': 'req-1' } : { 'x-signature': firma, 'x-request-id': 'req-1' },
    { 'data.id': dataId, type: tema },
    { data: { id: dataId }, type: tema },
  );

// ----------------------------------------------------------- los estados

test('cada estado de Mercado Pago cae en un estado de pago nuestro, o en null a proposito', () => {
  assert.deepEqual(
    Object.entries(ESTADOS_DE_MERCADO_PAGO).sort(),
    [
      ['approved', 'pagada'],
      ['authorized', 'en_proceso'],
      ['cancelled', 'rechazada'],
      ['charged_back', null],
      ['in_mediation', null],
      ['in_process', 'en_proceso'],
      ['pending', 'en_proceso'],
      ['refunded', 'reembolsada'],
      ['rejected', 'rechazada'],
    ],
  );
  for (const e of Object.values(ESTADOS_DE_MERCADO_PAGO)) {
    if (e !== null) assert.ok((ESTADOS_PAGO as readonly string[]).includes(e), e);
  }
});

test('ninguno traduce a pendiente ni a por_fuera: esos no los decide un proveedor', () => {
  const traducidos = Object.values(ESTADOS_DE_MERCADO_PAGO);
  assert.ok(!traducidos.includes('pendiente'));
  assert.ok(!traducidos.includes('por_fuera'));
});

test('un estado desconocido, o una propiedad heredada, no se adivina', () => {
  for (const s of ['approved_v2', '', 'toString', 'constructor', '__proto__']) {
    assert.equal(estadoDeMercadoPago(s), null, s);
  }
});

// ---------------------------------------------------------- la traduccion

test('un pago aprobado de la API se traduce entero, con el monto en centavos exactos', () => {
  assert.deepEqual(traducirPagoDeMercadoPago(pagoDeLaApi()), {
    ok: true,
    valor: {
      proveedor: 'mercadopago',
      operacionId: '1318431457',
      ordenId: ORDEN,
      estado: 'pagada',
      estadoDelProveedor: 'approved',
      detalle: 'accredited',
      monto: 11940000,
      reembolsado: 0,
      moneda: 'ARS',
      creadoEn: '2026-09-28T10:00:00.000-04:00',
    },
  });
});

test('lo devuelto pasa a centavos; ausente es 0; lo que no es plata se rechaza', () => {
  const devuelto = (x: unknown) => {
    const t = traducirPagoDeMercadoPago(pagoDeLaApi({ transaction_amount_refunded: x }));
    return t.ok ? t.valor.reembolsado : 'rechazado';
  };
  // Un reembolso PARCIAL: el estado sigue `approved` y solo esto se mueve.
  assert.equal(devuelto(19900), 1990000);
  assert.equal(devuelto(undefined), 0, 'la busqueda no siempre lo trae');
  assert.equal(devuelto(null), 0);
  assert.equal(devuelto('19900'), 'rechazado');
  assert.equal(devuelto(-1), 'rechazado');
  assert.equal(devuelto(1.005), 'rechazado');
});

test('los pesos con decimales pasan a centavos sin perder uno', () => {
  for (const [pesos, esperado] of [
    [19.99, 1999],
    [1.005, null], // tres decimales: no es plata, es un dato roto
    [0.1, 10],
    [119399.99, 11939999],
  ] as const) {
    const t = traducirPagoDeMercadoPago(pagoDeLaApi({ transaction_amount: pesos }));
    assert.equal(t.ok ? t.valor.monto : null, esperado, String(pesos));
  }
});

test('una referencia que no es un id nuestro es de otra venta: ordenId null', () => {
  for (const ref of [undefined, null, '', 'venta del posnet', '__reservado-por-firestore__', 42]) {
    const t = traducirPagoDeMercadoPago(pagoDeLaApi({ external_reference: ref }));
    assert.ok(t.ok, String(ref));
    assert.equal(t.ok && t.valor.ordenId, null, String(ref));
  }
});

test('un pago ilegible se rechaza con un motivo, no se arregla', () => {
  const malos: unknown[] = [
    null,
    'texto',
    pagoDeLaApi({ id: undefined }),
    pagoDeLaApi({ id: 'con/barra' }), // terminaria en el id de un documento
    pagoDeLaApi({ status: undefined }),
    pagoDeLaApi({ status: 'APPROVED' }),
    pagoDeLaApi({ transaction_amount: '119400' }),
    pagoDeLaApi({ transaction_amount: Number.NaN }),
    pagoDeLaApi({ currency_id: undefined }),
    pagoDeLaApi({ date_created: undefined }),
  ];
  for (const m of malos) assert.equal(traducirPagoDeMercadoPago(m).ok, false, JSON.stringify(m));
});

// ---------------------------------------------------------------- la firma

test('control positivo: un aviso firmado como dice la documentacion se lee como pago', () => {
  const r = leerAvisoDeMercadoPago(aviso('1318431457', firmar('1318431457', 'req-1', '1727528400')), SECRETO);
  assert.deepEqual(r, { es: 'pago', operacionId: '1318431457' });
});

test('controles negativos: otro secreto, otro id, otro ts, otro request-id, sin firma, rota', () => {
  const ts = '1727528400';
  const casos: [string, ReturnType<typeof aviso>][] = [
    ['otro secreto', aviso('1318431457', firmar('1318431457', 'req-1', ts, 'otro'))],
    ['firmado para otro pago', aviso('1318431457', firmar('1318431458', 'req-1', ts))],
    ['otro request-id', aviso('1318431457', firmar('1318431457', 'req-2', ts))],
    // La firma de un ts, presentada con otro: el hash no cierra.
    ['ts cambiado', aviso('1318431457', firmar('1318431457', 'req-1', ts).replace(`ts=${ts}`, 'ts=1727528401'))],
    ['sin firma', aviso('1318431457', undefined)],
    ['rota', aviso('1318431457', 'cualquier-cosa')],
  ];
  for (const [nombre, a] of casos) {
    assert.equal(leerAvisoDeMercadoPago(a, SECRETO).es, 'firma-invalida', nombre);
  }
});

test('un id alfanumerico se firma en minusculas, como pide la documentacion', () => {
  const a = aviso('ABC123', firmar('abc123', 'req-1', '1727528400'), 'otro_tema');
  assert.deepEqual(leerAvisoDeMercadoPago(a, SECRETO), { es: 'otro-tema', tema: 'otro_tema' });
});

test('sin data.id en la URL, se usa el del cuerpo', () => {
  const a = avisoDesdeHttp(
    { 'x-signature': firmar('1318431457', 'req-1', '1727528400'), 'x-request-id': 'req-1' },
    { type: 'payment' },
    { type: 'payment', data: { id: 1318431457 } },
  );
  assert.deepEqual(leerAvisoDeMercadoPago(a, SECRETO), { es: 'pago', operacionId: '1318431457' });
});

test('un tema que no es un pago, bien firmado, se lee como otro tema', () => {
  const a = aviso('9001', firmar('9001', 'req-1', '1727528400'), 'merchant_order');
  assert.deepEqual(leerAvisoDeMercadoPago(a, SECRETO), { es: 'otro-tema', tema: 'merchant_order' });
});

// ------------------------------------------------------------ el adaptador

function clienteCon(pagos: Record<string, unknown>, busqueda: unknown[] = []): ClienteDeMercadoPago {
  return {
    obtener: async (id) => pagos[id] ?? null,
    buscarPorReferencia: async () => busqueda,
  };
}

test('consultarPago: null si Mercado Pago no lo conoce, la consulta si lo conoce', async () => {
  const p = proveedorMercadoPago(clienteCon({ '1318431457': pagoDeLaApi() }), SECRETO);
  assert.equal(await p.consultarPago('999'), null);
  assert.equal((await p.consultarPago('1318431457'))?.estado, 'pagada');
});

test('consultarPago: un pago ilegible es un ERROR, no un "no existe"', async () => {
  const p = proveedorMercadoPago(clienteCon({ '1': pagoDeLaApi({ status: undefined }) }), SECRETO);
  await assert.rejects(p.consultarPago('1'), /ilegible/);
});

test('buscarPagosDeLaOrden descarta lo que la busqueda trajo de otra orden', async () => {
  const p = proveedorMercadoPago(
    clienteCon({}, [pagoDeLaApi({ id: 1 }), pagoDeLaApi({ id: 2, external_reference: 'otra-orden-00000000000001' })]),
    SECRETO,
  );
  assert.deepEqual((await p.buscarPagosDeLaOrden(ORDEN)).map((c) => c.operacionId), ['1']);
});

// --------------------------------------------------------- la request HTTP

test('avisoDesdeHttp: encabezados en minusculas, listas al primero, parametros tal cual', () => {
  const a = avisoDesdeHttp(
    { 'X-Signature': ['ts=1,v1=a', 'ts=2,v1=b'], 'X-Request-Id': 'r', 'X-Otro': 3 },
    { 'data.id': '12', Type: 'payment' },
    { cualquier: 'cosa' },
  );
  assert.deepEqual(a.encabezados, { 'x-signature': 'ts=1,v1=a', 'x-request-id': 'r', 'x-otro': undefined });
  assert.deepEqual(a.parametros, { 'data.id': '12', Type: 'payment' });
  assert.deepEqual(a.cuerpo, { cualquier: 'cosa' });
});
