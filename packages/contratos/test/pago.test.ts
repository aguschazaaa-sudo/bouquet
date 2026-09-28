import { test } from 'node:test';
import assert from 'node:assert/strict';

import { centavos } from '../src/dinero.ts';
import { ESTADOS_PAGO, transicionPagoValida, type EstadoPago } from '../src/orden.ts';
import {
  MOTIVOS_SIN_APLICAR,
  alertaDePago,
  idDelMarcadorDePago,
  pagoDeOrden,
  requiereAtencion,
  parsearPedidoDeRevision,
  resolverConsulta,
  type ConsultaDePago,
  type OrdenParaCobrar,
} from '../src/pago.ts';

const ID = '3f2b9c1e-7a4d-4e8f-9b21-5c6d7e8f9a0b';

const orden = (cambios: Partial<OrdenParaCobrar> = {}): OrdenParaCobrar => ({
  ordenId: ID,
  origen: 'vidriera',
  estadoPago: 'pendiente',
  total: centavos(11940000),
  operacionId: null,
  ...cambios,
});

const consulta = (cambios: Partial<ConsultaDePago> = {}): ConsultaDePago => ({
  proveedor: 'mercadopago',
  operacionId: '1318431457',
  ordenId: ID,
  estado: 'pagada',
  estadoDelProveedor: 'approved',
  detalle: 'accredited',
  monto: centavos(11940000),
  reembolsado: centavos(0),
  moneda: 'ARS',
  creadoEn: '2026-09-28T10:00:00.000-03:00',
  ...cambios,
});

// ------------------------------------------------------------- la decision

test('un pago aprobado por el total sobre una orden pendiente la pasa a pagada', () => {
  assert.deepEqual(resolverConsulta(orden(), consulta()), { aplica: true, estadoPago: 'pagada', cambia: true });
});

test('la misma consulta sobre una orden ya pagada aplica sin cambiar: es un reintento', () => {
  assert.deepEqual(resolverConsulta(orden({ estadoPago: 'pagada' }), consulta()), {
    aplica: true,
    estadoPago: 'pagada',
    cambia: false,
  });
});

test('una consulta de OTRA orden no se aplica, aunque todo lo demas cierre', () => {
  const r = resolverConsulta(orden(), consulta({ ordenId: 'otra-orden-0000000000000' }));
  assert.deepEqual(r, { aplica: false, motivo: 'otra-orden' });
  // Y un pago sin referencia nuestra (un link de pago, un posnet) tampoco.
  assert.deepEqual(resolverConsulta(orden(), consulta({ ordenId: null })), { aplica: false, motivo: 'otra-orden' });
});

test('un pedido de WhatsApp no se cobra por aca, ni con un pago aprobado por el total', () => {
  const r = resolverConsulta(orden({ origen: 'whatsapp', estadoPago: 'por_fuera' }), consulta());
  assert.deepEqual(r, { aplica: false, motivo: 'no-es-de-la-vidriera' });
});

test('un estado del proveedor sin traduccion no mueve el eje', () => {
  const r = resolverConsulta(orden({ estadoPago: 'pagada' }), consulta({ estado: null, estadoDelProveedor: 'in_mediation' }));
  assert.deepEqual(r, { aplica: false, motivo: 'estado-sin-traduccion' });
});

test('un pago en otra moneda no se aplica', () => {
  assert.deepEqual(resolverConsulta(orden(), consulta({ moneda: 'USD' })), { aplica: false, motivo: 'otra-moneda' });
});

test('un pago aprobado por UN centavo menos no es pagada', () => {
  const r = resolverConsulta(orden(), consulta({ monto: centavos(11939999) }));
  assert.deepEqual(r, { aplica: false, motivo: 'monto-distinto' });
  // Ni por uno de mas: cobrar de mas tambien es algo que alguien tiene que mirar.
  assert.deepEqual(resolverConsulta(orden(), consulta({ monto: centavos(11940001) })), {
    aplica: false,
    motivo: 'monto-distinto',
  });
});

test('el monto se compara SOLO al pagar: un rechazo por otro monto se aplica igual', () => {
  const r = resolverConsulta(
    orden(),
    consulta({ estado: 'rechazada', estadoDelProveedor: 'rejected', monto: centavos(1) }),
  );
  assert.deepEqual(r, { aplica: true, estadoPago: 'rechazada', cambia: true });
});

test('la tabla de ADR 002 decide: un rechazo tardio no despaga una orden pagada', () => {
  const r = resolverConsulta(orden({ estadoPago: 'pagada' }), consulta({ estado: 'rechazada', estadoDelProveedor: 'rejected' }));
  assert.deepEqual(r, { aplica: false, motivo: 'transicion-invalida' });
});

test('resolverConsulta acepta EXACTAMENTE los pares que acepta la tabla (vidriera, monto justo)', () => {
  // Los 36 pares: si alguien cambia la tabla de pago, esto cambia con ella, y no
  // hay una segunda copia de la tabla escondida en la decision.
  for (const antes of ESTADOS_PAGO) {
    for (const despues of ESTADOS_PAGO) {
      const r = resolverConsulta(orden({ estadoPago: antes }), consulta({ estado: despues }));
      assert.equal(r.aplica, transicionPagoValida(antes, despues), `${antes} -> ${despues}`);
    }
  }
});

test('las guardas van en orden: la de la orden gana a la del monto', () => {
  // Control de que el motivo registrado es el primero que falla, no uno cualquiera.
  const r = resolverConsulta(orden({ origen: 'whatsapp' }), consulta({ ordenId: null, monto: centavos(1) }));
  assert.equal(r.aplica ? '' : r.motivo, 'otra-orden');
  assert.equal(MOTIVOS_SIN_APLICAR.length, 7);
});

// --------------------------------------------------------------- el marcador

test('el marcador es por HECHO: el mismo pago en proceso y aprobado da dos marcadores', () => {
  const enProceso = idDelMarcadorDePago(consulta({ estado: 'en_proceso', estadoDelProveedor: 'in_process' }));
  const aprobado = idDelMarcadorDePago(consulta());
  assert.equal(aprobado, 'pago-mercadopago-1318431457-approved');
  assert.notEqual(enProceso, aprobado, 'con un marcador por id, la aprobacion se tomaria por repetida');
});

test('dos estados crudos que traducen igual son dos hechos distintos', () => {
  const pending = consulta({ estado: 'en_proceso', estadoDelProveedor: 'pending' });
  const inProcess = consulta({ estado: 'en_proceso', estadoDelProveedor: 'in_process' });
  assert.notEqual(idDelMarcadorDePago(pending), idDelMarcadorDePago(inProcess));
});

test('lo que se guarda en la orden es la consulta sin la orden, la moneda ni la fecha', () => {
  assert.deepEqual(pagoDeOrden(consulta()), {
    proveedor: 'mercadopago',
    operacionId: '1318431457',
    estadoDelProveedor: 'approved',
    detalle: 'accredited',
    monto: 11940000,
    reembolsado: 0,
  });
});

// ------------------------------------- los hallazgos ALTOS de revisor-pagos

test('un SEGUNDO cobro aprobado, sobre una orden ya pagada por otro, no se aplica', () => {
  const pagadaPorA = orden({ estadoPago: 'pagada', operacionId: 'A-1318431457' });
  assert.deepEqual(resolverConsulta(pagadaPorA, consulta({ operacionId: 'B-1318431458' })), {
    aplica: false,
    motivo: 'pago-duplicado',
  });
  // Control: el MISMO cobro que vuelve (un reintento, un reembolso parcial) si aplica.
  assert.deepEqual(resolverConsulta(pagadaPorA, consulta({ operacionId: 'A-1318431457' })), {
    aplica: true,
    estadoPago: 'pagada',
    cambia: false,
  });
});

test('una orden pagada sin operacion registrada no toma el cobro por duplicado', () => {
  const r = resolverConsulta(orden({ estadoPago: 'pagada', operacionId: null }), consulta());
  assert.deepEqual(r, { aplica: true, estadoPago: 'pagada', cambia: false });
});

test('un reembolso parcial es OTRO hecho; sin devolucion la llave no cambia', () => {
  const entero = consulta();
  const conDevolucion = consulta({ reembolsado: centavos(1990000) });
  assert.equal(idDelMarcadorDePago(entero), 'pago-mercadopago-1318431457-approved', 'los marcadores viejos siguen valiendo');
  assert.equal(idDelMarcadorDePago(conDevolucion), 'pago-mercadopago-1318431457-approved-r1990000');
  const otraDevolucion = consulta({ reembolsado: centavos(3980000) });
  assert.notEqual(idDelMarcadorDePago(otraDevolucion), idDelMarcadorDePago(conDevolucion), 'cada devolucion es un hecho');
});

test('requiereAtencion: lo que movio plata y no se aplico se ve', () => {
  const pagadaPorA = orden({ estadoPago: 'pagada', operacionId: 'A-1318431457' });
  const casos: [string, OrdenParaCobrar, ConsultaDePago][] = [
    ['segundo cobro', pagadaPorA, consulta({ operacionId: 'B-1318431458' })],
    ['monto distinto', orden(), consulta({ monto: centavos(1) })],
    ['cobro sobre una orden ya devuelta', orden({ estadoPago: 'reembolsada' }), consulta()],
    ['contracargo', orden({ estadoPago: 'pagada' }), consulta({ estado: null, estadoDelProveedor: 'charged_back' })],
  ];
  for (const [nombre, o, c] of casos) assert.equal(requiereAtencion(c, resolverConsulta(o, c)), true, nombre);
});

test('requiereAtencion: lo que no movio plata, o no es de esta tienda, no se muestra', () => {
  const casos: [string, OrdenParaCobrar, ConsultaDePago][] = [
    ['aplicado', orden(), consulta()],
    ['rechazo tardio sobre una pagada', orden({ estadoPago: 'pagada' }), consulta({ estado: 'rechazada', estadoDelProveedor: 'rejected' })],
    ['en proceso viejo sobre una pagada', orden({ estadoPago: 'pagada' }), consulta({ estado: 'en_proceso', estadoDelProveedor: 'in_process' })],
    ['pago de otra venta de la cuenta', orden(), consulta({ ordenId: null })],
    ['pedido de WhatsApp', orden({ origen: 'whatsapp', estadoPago: 'por_fuera' }), consulta()],
  ];
  for (const [nombre, o, c] of casos) assert.equal(requiereAtencion(c, resolverConsulta(o, c)), false, nombre);
});

test('la alerta lleva el motivo, la operacion, el estado crudo y el monto', () => {
  assert.deepEqual(alertaDePago(consulta({ operacionId: 'B-1318431458' }), 'pago-duplicado'), {
    motivo: 'pago-duplicado',
    operacionId: 'B-1318431458',
    estadoDelProveedor: 'approved',
    monto: 11940000,
  });
});

// ------------------------------------------------------ el pedido de revision

test('parsearPedidoDeRevision acepta un ordenId y nada mas', () => {
  assert.deepEqual(parsearPedidoDeRevision({ ordenId: ID }), { ok: true, valor: { ordenId: ID } });
});

test('parsearPedidoDeRevision rechaza lo que no es un pedido de revision', () => {
  const malos: unknown[] = [
    null,
    [],
    'texto',
    {},
    { ordenId: 'corto' },
    { ordenId: '__reservado-por-firestore__' },
    { ordenId: 42 },
    { ordenId: ID, estadoPago: 'pagada' },
  ];
  for (const m of malos) assert.equal(parsearPedidoDeRevision(m).ok, false, JSON.stringify(m));
});

test('los estados que resolverConsulta puede devolver son estados de pago', () => {
  const posibles = new Set<EstadoPago>();
  for (const e of ESTADOS_PAGO) {
    const r = resolverConsulta(orden({ estadoPago: 'pendiente' }), consulta({ estado: e }));
    if (r.aplica) posibles.add(r.estadoPago);
  }
  // Desde pendiente: en proceso, pagada, rechazada y el mismo pendiente.
  assert.deepEqual([...posibles].sort(), ['en_proceso', 'pagada', 'pendiente', 'rechazada']);
});
