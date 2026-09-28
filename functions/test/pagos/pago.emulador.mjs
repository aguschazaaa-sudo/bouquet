// pago.emulador.mjs -- EL PEDIDO FALSO: el cobro de la vidriera contra el
// emulador de Firestore, sin credenciales de Mercado Pago.  HU-08.1 y HU-08.3,
// ADR 003 (el contrato del webhook) y ADR 022.
//
// Corre con:
//   firebase emulators:exec --only firestore --project demo-bouquet \
//     "node --test functions/test/pagos/pago.emulador.mjs"
//
// En CI la corre el job `suite_emulador`, EN SERIE con las otras suites que usan
// el mismo emulador.
//
// LO UNICO FALSO ES LA API DE PAGOS DE MERCADO PAGO: una cuenta en memoria que
// contesta `GET /v1/payments/{id}` y la busqueda por referencia con la forma de
// la API.  Todo lo demas corre de verdad: el adaptador (la traduccion de
// estados y el `WebhookSignatureValidator` del SDK oficial), el nucleo del
// aviso, la transaccion con su marcador y la re-consulta.  Los avisos se firman
// armando el texto con la PLANTILLA DE LA DOCUMENTACION de Mercado Pago, no con
// el codigo del SDK: si el SDK y la documentacion no dijeran lo mismo, esto lo
// ve.
//
// Lo que esto NO prueba, y queda para cuando existan las credenciales de
// prueba: que la API real conteste con esta forma, y que Mercado Pago firme
// como dice su documentacion.  ADR 022, "Lo que falta".
//
// La Orden de la vidriera se arma con `crearOrdenDelPanel` de verdad y se le
// cambian SOLO los dos campos que `crearOrden` de la vidriera todavia no
// decidio escribir: `origen` y `estadoPago`.  Todo lo demas tiene la forma real.

import assert from 'node:assert/strict';
import { createHmac, randomUUID } from 'node:crypto';
import { beforeEach, describe, test } from 'node:test';

const PROYECTO = 'demo-bouquet';
assert.ok(process.env.FIRESTORE_EMULATOR_HOST, 'falta FIRESTORE_EMULATOR_HOST: correlo con emulators:exec');
process.env.GCLOUD_PROJECT = PROYECTO;

const { initializeApp } = await import('firebase-admin/app');
const { getFirestore, Timestamp } = await import('firebase-admin/firestore');
const { crearOrdenDelPanel } = await import('../../src/pedidos/crear.ts');
const { cancelarOrden } = await import('../../src/pedidos/cancelar.ts');
const { avisoDesdeHttp, procesarAviso } = await import('../../src/pagos/aviso.ts');
const { revisarPago } = await import('../../src/pagos/revisar.ts');
const { proveedorMercadoPago } = await import('../../src/pagos/mercadopago.ts');
const { parsearPedidoDelPanel, proyectarEstadoPublico } = await import('@bouquet/contratos');

const db = getFirestore(initializeApp({ projectId: PROYECTO }, 'test-pago'));
const ordenes = db.collection('ordenes');

// ------------------------------------------------------------- la tienda

const PRECIO = 1990000; // $19.900,00 la botella
const TOTAL = PRECIO * 6; // 11.940.000 centavos: $119.400,00

const vino = (id) => ({
  tipo: 'simple',
  slug: id,
  nombre: `Vino ${id}`,
  precio: PRECIO,
  stock: 60,
  presentacion: { botellas: 1 },
  imagenes: [],
  publicado: true,
  fichaVino: { bodegaId: 'b', varietales: ['Malbec'], color: 'tinto', organico: false, region: 'Mendoza', volumenMl: 750 },
});

let secuencia = 0;
const nuevoId = () => `pedido-de-cobro-${String(++secuencia).padStart(8, '0')}`;

const entrega = {
  nombre: 'Marta Gomez',
  telefono: '0351 15-555-1234',
  calle: 'San Martin',
  numero: '120',
  destino: { codigoPostal: '5000', localidad: 'Cordoba', provincia: 'X' },
};

/** Una Orden de WhatsApp de verdad: seis botellas. */
async function pedidoDeWhatsapp() {
  await db.collection('productos').doc('vino-a').set(vino('vino-a'));
  const r = parsearPedidoDelPanel({
    idPedido: nuevoId(),
    lineas: [{ productoId: 'vino-a', cantidad: 6, precioUnitarioVisto: PRECIO }],
    entrega,
  });
  assert.ok(r.ok, `la fixture tiene que validar: ${r.ok ? '' : r.motivo}`);
  return (await crearOrdenDelPanel(db, r.valor, 'operador')).ordenId;
}

/** EL PEDIDO FALSO de la vidriera: la forma real, menos lo que `crearOrden` todavia no decidio. */
async function pedidoDeLaVidriera() {
  const id = await pedidoDeWhatsapp();
  await ordenes.doc(id).update({ origen: 'vidriera', estadoPago: 'pendiente' });
  const o = (await ordenes.doc(id).get()).data();
  assert.equal(o.total, TOTAL, 'control: el total del pedido falso es el que se va a cobrar');
  return id;
}

const orden = async (id) => (await ordenes.doc(id).get()).data();
const marcadores = async (id) => (await ordenes.doc(id).collection('marcadores').get()).docs.map((d) => ({ id: d.id, ...d.data() }));
const todosLosMarcadores = async () => (await db.collectionGroup('marcadores').get()).size;

// -------------------------------------------- la cuenta falsa de Mercado Pago

let fecha = Date.parse('2026-09-28T10:00:00.000-03:00');

/** Un pago con la forma de `GET /v1/payments/{id}`.  El monto va en PESOS, como en la API. */
const pagoDeMP = (id, ordenId, status, cambios = {}) => ({
  id: Number(id),
  status,
  status_detail: { approved: 'accredited', in_process: 'pending_contingency', rejected: 'cc_rejected_other_reason' }[status] ?? null,
  external_reference: ordenId,
  transaction_amount: TOTAL / 100,
  currency_id: 'ARS',
  date_created: new Date((fecha += 60_000)).toISOString(),
  live_mode: false,
  payment_method_id: 'visa',
  ...cambios,
});

function cuentaFalsa() {
  const pagos = new Map();
  const cuenta = {
    pagos,
    caida: false,
    consultas: 0,
    poner(pago) {
      pagos.set(String(pago.id), pago);
      return String(pago.id);
    },
    cliente: {
      async obtener(id) {
        cuenta.consultas++;
        if (cuenta.caida) throw new Error('503 de Mercado Pago');
        return pagos.get(id) ?? null;
      },
      async buscarPorReferencia(ordenId) {
        cuenta.consultas++;
        if (cuenta.caida) throw new Error('503 de Mercado Pago');
        return [...pagos.values()].filter((p) => p.external_reference === ordenId);
      },
    },
  };
  return cuenta;
}

const SECRETO = 'secreto-de-prueba-que-no-es-de-mercado-pago';

/**
 * Un aviso como lo manda Mercado Pago, firmado con la PLANTILLA de su
 * documentacion: `id:[data.id_url];request-id:[x-request-id_header];ts:[ts_header];`.
 */
function avisoFirmado(operacionId, { secreto = SECRETO, tema = 'payment', idFirmado = operacionId } = {}) {
  const requestId = randomUUID();
  const ts = String(Math.floor(Date.now() / 1000));
  const plantilla = 'id:[data.id_url];request-id:[x-request-id_header];ts:[ts_header];';
  const texto = plantilla
    .replace('[data.id_url]', idFirmado)
    .replace('[x-request-id_header]', requestId)
    .replace('[ts_header]', ts);
  const v1 = createHmac('sha256', secreto).update(texto).digest('hex');
  return avisoDesdeHttp(
    // Con mayusculas y como lista, como puede llegar: el nucleo los normaliza.
    { 'X-Signature': `ts=${ts},v1=${v1}`, 'X-Request-Id': [requestId], 'Content-Type': 'application/json' },
    { 'data.id': operacionId, type: tema },
    { action: 'payment.updated', api_version: 'v1', data: { id: operacionId }, type: tema, live_mode: false },
  );
}

let cuenta;
let proveedor;
const avisar = (aviso) => procesarAviso(db, proveedor, aviso);
const revisar = (ordenId, uid = 'operador') => revisarPago(db, proveedor, { ordenId }, uid);

async function fallo(promesa) {
  try {
    await promesa;
    return null;
  } catch (e) {
    return { code: e.code, details: e.details };
  }
}

beforeEach(async () => {
  await fetch(`http://${process.env.FIRESTORE_EMULATOR_HOST}/emulator/v1/projects/${PROYECTO}/databases/(default)/documents`, {
    method: 'DELETE',
  });
  cuenta = cuentaFalsa();
  proveedor = proveedorMercadoPago(cuenta.cliente, SECRETO);
});

// ======================================================= el aviso que cobra

describe('el aviso de un pago aprobado', () => {
  test('pasa el pedido falso a pagada, con el numero de operacion y el monto', async () => {
    const id = await pedidoDeLaVidriera();
    const op = cuenta.poner(pagoDeMP('1318431457', id, 'approved'));

    const r = await avisar(avisoFirmado(op));

    assert.deepEqual(r, { status: 200, cuerpo: 'aplicado' });
    const o = await orden(id);
    assert.equal(o.estadoPago, 'pagada');
    assert.equal(o.estadoEntrega, 'sin_preparar', 'el eje de entrega no se toca');
    assert.equal(o.pago.operacionId, '1318431457');
    assert.equal(o.pago.estadoDelProveedor, 'approved');
    assert.equal(o.pago.detalle, 'accredited');
    assert.equal(o.pago.monto, TOTAL, 'los pesos de la API vuelven a centavos exactos');
    assert.ok(o.pago.consultadoEn instanceof Timestamp, 'la hora la pone el servidor');
    assert.equal(proyectarEstadoPublico(o.estadoPago, o.estadoEntrega), 'pagada');

    const [m, ...otros] = await marcadores(id);
    assert.equal(otros.length, 0);
    assert.equal(m.id, 'pago-mercadopago-1318431457-approved');
    assert.equal(m.aplicado, true);
    assert.equal(m.antes, 'pendiente');
    assert.equal(m.despues, 'pagada');
    assert.equal(m.por, 'aviso:mercadopago');
  });

  test('el mismo aviso tres veces, dos a la vez: un solo efecto, contado', async () => {
    const id = await pedidoDeLaVidriera();
    const op = cuenta.poner(pagoDeMP('2000000001', id, 'approved'));

    const respuestas = await Promise.all([avisar(avisoFirmado(op)), avisar(avisoFirmado(op))]);
    respuestas.push(await avisar(avisoFirmado(op)));

    assert.ok(respuestas.every((r) => r.status === 200), 'un reintento no es un error: Mercado Pago no tiene que insistir');
    assert.equal(respuestas.filter((r) => r.cuerpo === 'aplicado').length, 1, 'se aplico UNA vez');
    assert.equal(respuestas.filter((r) => r.cuerpo === 'repetido').length, 2);
    assert.equal((await marcadores(id)).length, 1);
    assert.equal((await orden(id)).estadoPago, 'pagada');
  });

  test('en proceso y dias despues aprobado, con el MISMO id: la venta no se pierde', async () => {
    // El caso que un marcador `pago-{paymentId}` (ADR 003) se comia: la
    // aprobacion se tomaba por repetida y la Orden quedaba "en proceso" cobrada.
    const id = await pedidoDeLaVidriera();
    const op = cuenta.poner(pagoDeMP('2000000002', id, 'in_process'));

    assert.equal((await avisar(avisoFirmado(op))).cuerpo, 'aplicado');
    assert.equal((await orden(id)).estadoPago, 'en_proceso', 'control: el primer hecho se aplico');

    cuenta.pagos.get(op).status = 'approved';
    assert.equal((await avisar(avisoFirmado(op))).cuerpo, 'aplicado');

    assert.equal((await orden(id)).estadoPago, 'pagada');
    assert.deepEqual((await marcadores(id)).map((m) => m.id).sort(), [
      'pago-mercadopago-2000000002-approved',
      'pago-mercadopago-2000000002-in_process',
    ]);
  });

  test('un aviso VIEJO que llega tarde no retrocede: la consulta dice lo de ahora', async () => {
    const id = await pedidoDeLaVidriera();
    const op = cuenta.poner(pagoDeMP('2000000003', id, 'approved'));
    await avisar(avisoFirmado(op));
    // El aviso de `in_process` se habia demorado: cuando llega, la API ya dice
    // `approved`.  El cuerpo del aviso no se lee.
    const r = await avisar(avisoFirmado(op));
    assert.equal(r.cuerpo, 'repetido');
    assert.equal((await orden(id)).estadoPago, 'pagada');
  });

  test('un SEGUNDO cobro aprobado por el total: no pisa al primero y deja la alerta', async () => {
    // Hallazgo ALTO 2 de `revisor-pagos`: dos preferencias por un reintento, dos
    // pagos aprobados.  Al comprador le cobraron dos veces y alguien tiene que devolver uno.
    const id = await pedidoDeLaVidriera();
    const a = cuenta.poner(pagoDeMP('7000000001', id, 'approved'));
    const b = cuenta.poner(pagoDeMP('7000000002', id, 'approved'));
    await avisar(avisoFirmado(a));

    assert.deepEqual(await avisar(avisoFirmado(b)), { status: 200, cuerpo: 'sin-aplicar' });

    const o = await orden(id);
    assert.equal(o.estadoPago, 'pagada');
    assert.equal(o.pago.operacionId, '7000000001', 'el primer cobro sigue siendo el de la orden');
    assert.equal(o.alertaDePago.motivo, 'pago-duplicado');
    assert.equal(o.alertaDePago.operacionId, '7000000002', 'la alerta dice CUAL devolver');
    assert.equal(o.alertaDePago.monto, TOTAL);
    assert.ok(o.alertaDePago.en instanceof Timestamp);
  });

  test('un reembolso PARCIAL es otro hecho: se ve lo devuelto, y el estado no se mueve', async () => {
    // Hallazgo ALTO 1: el estado crudo sigue `approved`.  Con el marcador sin lo
    // devuelto, el aviso de la devolucion se tomaba por repetido.
    const id = await pedidoDeLaVidriera();
    const op = cuenta.poner(pagoDeMP('7000000003', id, 'approved'));
    await avisar(avisoFirmado(op));
    assert.equal((await orden(id)).pago.reembolsado, 0, 'control: sin devolucion');

    cuenta.pagos.get(op).transaction_amount_refunded = 19900;
    assert.deepEqual(await avisar(avisoFirmado(op)), { status: 200, cuerpo: 'aplicado' });

    const o = await orden(id);
    assert.equal(o.estadoPago, 'pagada', 'una devolucion parcial no es reembolsada');
    assert.equal(o.pago.reembolsado, 1990000);
    assert.equal((await marcadores(id)).length, 2);
  });

  test('un contracargo no mueve el eje, pero deja la alerta', async () => {
    const id = await pedidoDeLaVidriera();
    const op = cuenta.poner(pagoDeMP('7000000004', id, 'approved'));
    await avisar(avisoFirmado(op));
    cuenta.pagos.get(op).status = 'charged_back';

    assert.deepEqual(await avisar(avisoFirmado(op)), { status: 200, cuerpo: 'sin-aplicar' });

    const o = await orden(id);
    assert.equal(o.estadoPago, 'pagada', 'reembolsada es terminal y un contracargo se puede ganar');
    assert.equal(o.alertaDePago.motivo, 'estado-sin-traduccion');
    assert.equal(o.alertaDePago.estadoDelProveedor, 'charged_back');
  });

  test('un reembolso hecho en Mercado Pago llega como reembolsada', async () => {
    const id = await pedidoDeLaVidriera();
    const op = cuenta.poner(pagoDeMP('2000000004', id, 'approved'));
    await avisar(avisoFirmado(op));
    cuenta.pagos.get(op).status = 'refunded';
    await avisar(avisoFirmado(op));
    const o = await orden(id);
    assert.equal(o.estadoPago, 'reembolsada');
    assert.equal(o.pago.estadoDelProveedor, 'refunded');
  });
});

// ============================================================== el desorden

describe('fuera de orden: cada eje escribe el suyo (ADR 003, regla 4)', () => {
  test('pagado DESPUES de cancelado: queda cancelada con pago, y la entrega no se mueve', async () => {
    const id = await pedidoDeLaVidriera();
    await cancelarOrden(db, { ordenId: id, motivo: 'cliente' }, 'operador');
    assert.equal((await orden(id)).estadoEntrega, 'cancelada', 'control: estaba cancelada');

    const op = cuenta.poner(pagoDeMP('3000000001', id, 'approved'));
    assert.equal((await avisar(avisoFirmado(op))).cuerpo, 'aplicado');

    const o = await orden(id);
    assert.equal(o.estadoEntrega, 'cancelada');
    assert.equal(o.estadoPago, 'pagada');
    assert.equal(proyectarEstadoPublico(o.estadoPago, o.estadoEntrega), 'cancelada_con_pago', 'el operador ve que hay que devolver');
  });

  test('un rechazo de otro intento, sobre una orden ya pagada, no la despaga y queda registrado', async () => {
    const id = await pedidoDeLaVidriera();
    const bueno = cuenta.poner(pagoDeMP('3000000002', id, 'approved'));
    const malo = cuenta.poner(pagoDeMP('3000000003', id, 'rejected'));
    await avisar(avisoFirmado(bueno));

    const r = await avisar(avisoFirmado(malo));

    assert.deepEqual(r, { status: 200, cuerpo: 'sin-aplicar' });
    assert.equal((await orden(id)).estadoPago, 'pagada');
    const m = (await marcadores(id)).find((x) => x.id.includes('3000000003'));
    assert.equal(m.aplicado, false);
    assert.equal(m.motivo, 'transicion-invalida');
    assert.equal((await orden(id)).alertaDePago, undefined, 'un rechazo no movio plata: no es una alerta');
  });
});

// ============================================================ lo que NO cobra

describe('lo que no se aplica, y por que', () => {
  test('firma invalida: 401, sin consultar a nadie y sin escribir nada', async () => {
    const id = await pedidoDeLaVidriera();
    const op = cuenta.poner(pagoDeMP('4000000001', id, 'approved'));

    const conOtroSecreto = await avisar(avisoFirmado(op, { secreto: 'otro-secreto' }));
    // Firmado para OTRO pago: el id de la URL no es el que se firmo.
    const cambiado = await avisar(avisoFirmado(op, { idFirmado: '4000000999' }));
    const sinFirma = await avisar(avisoDesdeHttp({}, { 'data.id': op, type: 'payment' }, { data: { id: op } }));

    for (const r of [conOtroSecreto, cambiado, sinFirma]) assert.equal(r.status, 401);
    assert.equal(cuenta.consultas, 0, 'la firma va ANTES de la consulta');
    assert.equal((await orden(id)).estadoPago, 'pendiente');
    assert.equal((await marcadores(id)).length, 0);
  });

  test('un pago que Mercado Pago no conoce: 200 y nada escrito', async () => {
    const id = await pedidoDeLaVidriera();
    const r = await avisar(avisoFirmado('4000000002'));
    assert.deepEqual(r, { status: 200, cuerpo: 'pago desconocido' });
    assert.equal((await orden(id)).estadoPago, 'pendiente');
    assert.equal(await todosLosMarcadores(), 0);
  });

  test('aprobado por un centavo menos: no es pagada, y queda registrado', async () => {
    const id = await pedidoDeLaVidriera();
    // $119.399,99: un centavo menos que los $119.400,00 del pedido.
    const op = cuenta.poner(pagoDeMP('4000000003', id, 'approved', { transaction_amount: 119399.99 }));

    assert.deepEqual(await avisar(avisoFirmado(op)), { status: 200, cuerpo: 'sin-aplicar' });

    const o = await orden(id);
    assert.equal(o.estadoPago, 'pendiente');
    assert.equal(o.pago, undefined, 'la orden no muestra un pago que no se aplico');
    assert.equal(o.alertaDePago.motivo, 'monto-distinto', 'pero SI muestra que hay algo que mirar');
    assert.equal(o.alertaDePago.monto, TOTAL - 1);
    const [m] = await marcadores(id);
    assert.equal(m.motivo, 'monto-distinto');
    assert.equal(m.consulta.monto, TOTAL - 1);
  });

  test('un pago aprobado que dice ser de un pedido de WhatsApp no lo cobra', async () => {
    const id = await pedidoDeWhatsapp();
    const op = cuenta.poner(pagoDeMP('4000000004', id, 'approved'));
    assert.equal((await avisar(avisoFirmado(op))).cuerpo, 'sin-aplicar');
    assert.equal((await orden(id)).estadoPago, 'por_fuera');
    assert.equal((await marcadores(id))[0].motivo, 'no-es-de-la-vidriera');
    assert.equal((await orden(id)).alertaDePago, undefined);
  });

  test('un pago de otra venta de la cuenta (sin referencia nuestra) se contesta y se ignora', async () => {
    await pedidoDeLaVidriera();
    const sinReferencia = cuenta.poner(pagoDeMP('4000000005', undefined, 'approved'));
    const ajena = cuenta.poner(pagoDeMP('4000000006', 'venta del posnet', 'approved'));
    assert.deepEqual(await avisar(avisoFirmado(sinReferencia)), { status: 200, cuerpo: 'sin-orden' });
    assert.deepEqual(await avisar(avisoFirmado(ajena)), { status: 200, cuerpo: 'sin-orden' });
    assert.equal(await todosLosMarcadores(), 0);
  });

  test('un pago que apunta a una orden que no existe: 200, sin crear nada', async () => {
    const op = cuenta.poner(pagoDeMP('4000000007', 'orden-que-no-existe-000001', 'approved'));
    assert.deepEqual(await avisar(avisoFirmado(op)), { status: 200, cuerpo: 'orden-inexistente' });
    assert.equal((await ordenes.doc('orden-que-no-existe-000001').get()).exists, false);
  });

  test('otro tema (merchant_order): se contesta sin consultar', async () => {
    const r = await avisar(avisoFirmado('5000000001', { tema: 'merchant_order' }));
    assert.deepEqual(r, { status: 200, cuerpo: 'ignorado: merchant_order' });
    assert.equal(cuenta.consultas, 0);
  });

  test('Mercado Pago caido: el aviso LANZA, para que el envoltorio conteste 500 y se reintente', async () => {
    const id = await pedidoDeLaVidriera();
    const op = cuenta.poner(pagoDeMP('5000000002', id, 'approved'));
    cuenta.caida = true;
    await assert.rejects(avisar(avisoFirmado(op)), /503/);
    assert.equal((await marcadores(id)).length, 0, 'nada a medias: el reintento lo aplica');

    cuenta.caida = false;
    assert.equal((await avisar(avisoFirmado(op))).cuerpo, 'aplicado', 'control: el reintento cobra');
  });
});

// ================================================== la re-consulta (HU-08.3)

describe('volver a consultar el pago', () => {
  test('el aviso nunca llego: revisar encuentra los dos intentos y queda pagada', async () => {
    const id = await pedidoDeLaVidriera();
    cuenta.poner(pagoDeMP('6000000001', id, 'rejected'));
    cuenta.poner(pagoDeMP('6000000002', id, 'approved'));

    const r = await revisar(id, 'uid-de-marta');

    assert.deepEqual(r, { estadoPago: 'pagada', cambio: true, encontrados: 2 });
    const o = await orden(id);
    assert.equal(o.pago.operacionId, '6000000002', 'se ve el intento que cobro');
    const ms = await marcadores(id);
    assert.equal(ms.length, 2);
    assert.ok(ms.every((m) => m.aplicado && m.por === 'uid-de-marta'), 'del mas viejo al mas nuevo, cada paso es valido');
  });

  test('sin pagos en Mercado Pago: encontrados 0, y no cambia nada', async () => {
    const id = await pedidoDeLaVidriera();
    assert.deepEqual(await revisar(id), { estadoPago: 'pendiente', cambio: false, encontrados: 0 });
    assert.equal((await marcadores(id)).length, 0);
  });

  test('revisar dos veces no aplica dos veces', async () => {
    const id = await pedidoDeLaVidriera();
    cuenta.poner(pagoDeMP('6000000003', id, 'approved'));
    assert.equal((await revisar(id)).cambio, true);
    assert.deepEqual(await revisar(id), { estadoPago: 'pagada', cambio: false, encontrados: 1 });
    assert.equal((await marcadores(id)).length, 1);
  });

  test('revisar y el aviso A LA VEZ: el mismo hecho tiene efecto una vez', async () => {
    const id = await pedidoDeLaVidriera();
    const op = cuenta.poner(pagoDeMP('6000000004', id, 'approved'));
    await Promise.all([revisar(id), avisar(avisoFirmado(op)), revisar(id)]);
    const ms = await marcadores(id);
    assert.equal(ms.length, 1, 'los dos caminos escriben el MISMO marcador');
    assert.equal((await orden(id)).estadoPago, 'pagada');
  });

  test('un pedido de WhatsApp no se revisa: su cobro va por fuera', async () => {
    const id = await pedidoDeWhatsapp();
    assert.deepEqual(await fallo(revisar(id)), {
      code: 'failed-precondition',
      details: { codigo: 'por-fuera' },
    });
    assert.equal(cuenta.consultas, 0, 'no se le pregunta a nadie');
  });

  test('una orden que no existe', async () => {
    assert.deepEqual(await fallo(revisar('orden-que-no-existe-000002')), {
      code: 'not-found',
      details: { codigo: 'no-existe' },
    });
  });

  test('Mercado Pago caido: unavailable, con un codigo que el panel sabe decir, y nada escrito', async () => {
    const id = await pedidoDeLaVidriera();
    cuenta.caida = true;
    const f = await fallo(revisar(id));
    assert.equal(f.code, 'unavailable');
    assert.equal(f.details.codigo, 'proveedor-caido');
    assert.equal((await marcadores(id)).length, 0);
    assert.equal((await orden(id)).estadoPago, 'pendiente');
  });
});
