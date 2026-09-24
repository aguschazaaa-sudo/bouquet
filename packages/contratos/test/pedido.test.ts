import { test } from 'node:test';
import assert from 'node:assert/strict';

import { ENTRADAS_DE_TELEFONO, LARGOS_DE_ENTREGA, normalizarTelefonoAR } from '../src/envio.ts';
import { TOPE_DE_STOCK } from '../src/stock.ts';
import { PRECIO_MAXIMO, TOPE_DE_LINEAS, contactoYEntrega, parsearPedidoDelPanel } from '../src/pedido.ts';

// El pedido de una carga normal: el que arma el formulario del panel.
const entrega = (cambios: Record<string, unknown> = {}) => ({
  nombre: 'Marta Gomez',
  telefono: '0351 15-555-1234',
  email: '',
  calle: 'San Martin',
  numero: '120',
  piso: '',
  referencia: 'porton verde',
  destino: { codigoPostal: '5000', localidad: 'Cordoba', provincia: 'X' },
  ...cambios,
});

const linea = (productoId: string, cantidad = 2, precioUnitarioVisto = 1990000) => ({
  productoId,
  cantidad,
  precioUnitarioVisto,
});

const pedido = (cambios: Record<string, unknown> = {}) => ({
  idPedido: 'pedido-de-prueba-0001',
  lineas: [linea('vino-a'), linea('vino-b', 1, 2500000)],
  entrega: entrega(),
  ...cambios,
});

const rechaza = (entrada: unknown, motivo: RegExp) => {
  const r = parsearPedidoDelPanel(entrada);
  assert.equal(r.ok, false, 'deberia haberlo rechazado');
  if (!r.ok) assert.match(r.motivo, motivo);
};

// ---------------------------------------------------------------- lo que pasa

test('un pedido normal valida, y sale normalizado', () => {
  const r = parsearPedidoDelPanel(pedido());
  assert.equal(r.ok, true);
  if (!r.ok) return;
  assert.equal(r.valor.idPedido, 'pedido-de-prueba-0001');
  assert.equal(r.valor.lineas.length, 2);
  assert.equal(r.valor.entrega.telefonoE164, '+5493515551234', 'el 15 se saco y el 9 se puso');
  assert.equal(r.valor.entrega.email, null, 'un email vacio es null, no una cadena vacia');
  assert.equal(r.valor.entrega.piso, null);
});

test('las cuatro botellas sueltas NO se rechazan: la regla de la caja no aplica a WhatsApp', () => {
  // Respuesta 7 del dueno.  El parser no sabe de cajas, y este caso lo fija.
  const r = parsearPedidoDelPanel(pedido({ lineas: [linea('vino-a', 4)] }));
  assert.equal(r.ok, true);
});

test('`propio` lo decide el servidor: aunque el cliente diga true, sale false', () => {
  const r = parsearPedidoDelPanel(
    pedido({ entrega: entrega({ destino: { codigoPostal: '5000', localidad: 'Cordoba', provincia: 'X', propio: true } }) }),
  );
  assert.equal(r.ok, true);
  if (r.ok) assert.equal(r.valor.entrega.destino.propio, false);
});

// ---------------------------------------------------- el origen no se declara

test('un pedido que trae `origen` se rechaza', () => {
  rechaza(pedido({ origen: 'vidriera' }), /forma/);
  rechaza(pedido({ origen: 'whatsapp' }), /forma/);
});

test('un pedido que trae `estadoPago` se rechaza', () => {
  rechaza(pedido({ estadoPago: 'pagada' }), /forma/);
});

test('una linea con un campo de mas se rechaza', () => {
  rechaza(pedido({ lineas: [{ ...linea('vino-a'), precio: 1 }] }), /linea 1/);
});

// ------------------------------------------------------------------ idPedido

test('idPedido: 16 a 64 caracteres seguros', () => {
  assert.equal(parsearPedidoDelPanel(pedido({ idPedido: 'a'.repeat(16) })).ok, true);
  assert.equal(parsearPedidoDelPanel(pedido({ idPedido: 'a'.repeat(64) })).ok, true);
  rechaza(pedido({ idPedido: 'a'.repeat(15) }), /idPedido/);
  rechaza(pedido({ idPedido: 'a'.repeat(65) }), /idPedido/);
  rechaza(pedido({ idPedido: 'con/barra-de-16-caracteres' }), /idPedido/, );
  rechaza(pedido({ idPedido: 42 }), /idPedido/);
});

test('idPedido: un id reservado de Firestore (`__x__`) se rechaza', () => {
  // Como es el id de la Orden, pasaba el parser y Firestore lo rechazaba: el
  // operador veia `internal` en vez de un motivo.
  rechaza(pedido({ idPedido: '__pedido-reservado__' }), /idPedido/);
  // Control positivo: con guiones bajos en el medio o en un solo extremo, si.
  assert.equal(parsearPedidoDelPanel(pedido({ idPedido: 'pedido__de__prueba__1' })).ok, true);
  assert.equal(parsearPedidoDelPanel(pedido({ idPedido: '__pedido-de-prueba-1' })).ok, true);
});

// -------------------------------------------------------------------- lineas

test('sin lineas, o demasiadas', () => {
  rechaza(pedido({ lineas: [] }), /no tiene lineas/);
  rechaza(pedido({ lineas: 'nada' }), /no tiene lineas/);

  const n = (cuantas: number) => Array.from({ length: cuantas }, (_, i) => linea(`vino-${i}`));
  assert.equal(parsearPedidoDelPanel(pedido({ lineas: n(TOPE_DE_LINEAS) })).ok, true, 'el tope exacto pasa');
  rechaza(pedido({ lineas: n(TOPE_DE_LINEAS + 1) }), /mas de 30 lineas/);
});

test('un producto repetido se rechaza, no se suma', () => {
  rechaza(pedido({ lineas: [linea('vino-a', 1), linea('vino-a', 2)] }), /repetido/);
});

test('la cantidad es un entero de 1 a TOPE_DE_STOCK', () => {
  assert.equal(parsearPedidoDelPanel(pedido({ lineas: [linea('vino-a', 1)] })).ok, true);
  assert.equal(parsearPedidoDelPanel(pedido({ lineas: [linea('vino-a', TOPE_DE_STOCK)] })).ok, true);
  for (const mala of [0, -1, TOPE_DE_STOCK + 1, 1.5, NaN, '2', null, -0]) {
    rechaza(pedido({ lineas: [linea('vino-a', mala as number)] }), /cantidad/);
  }
});

test('el precio visto es un entero de centavos mayor que cero', () => {
  for (const malo of [0, -5, 19.9, NaN, '1990000', null]) {
    rechaza(pedido({ lineas: [linea('vino-a', 1, malo as number)] }), /precio visto/);
  }
});

test('un precio por encima de PRECIO_MAXIMO se RECHAZA con un motivo, no lanza', () => {
  // `centavos()` lanza un RangeError fuera del rango seguro, y la callable lo
  // contestaba `internal` en vez de `invalid-argument` (hallazgo 6).
  assert.equal(parsearPedidoDelPanel(pedido({ lineas: [linea('vino-a', 1, PRECIO_MAXIMO)] })).ok, true, 'el borde exacto pasa');
  rechaza(pedido({ lineas: [linea('vino-a', 1, PRECIO_MAXIMO + 1)] }), /precio visto/);
  rechaza(pedido({ lineas: [linea('vino-a', 1, 1e300)] }), /precio visto/);
  rechaza(pedido({ lineas: [linea('vino-a', 1, Number.MAX_SAFE_INTEGER + 2)] }), /precio visto/);
});

test('el peor pedido posible no desborda: 30 lineas x cantidad maxima x precio maximo', () => {
  // La razon de ser de PRECIO_MAXIMO: la suma tiene que ser un entero seguro.
  const peor = PRECIO_MAXIMO * TOPE_DE_STOCK * TOPE_DE_LINEAS;
  assert.ok(Number.isSafeInteger(peor), `${peor} no es un entero seguro`);
  assert.ok(peor <= Number.MAX_SAFE_INTEGER);
});

test('un productoId con barra o reservado se rechaza', () => {
  rechaza(pedido({ lineas: [linea('otro/doc')] }), /productoId/);
  rechaza(pedido({ lineas: [linea('__reservado__')] }), /productoId/);
  rechaza(pedido({ lineas: [linea('')] }), /productoId/);
});

// ---------------------------------------------------------------- la entrega

test('los datos de entrega los valida el MISMO validador que la vidriera', () => {
  rechaza(pedido({ entrega: entrega({ nombre: 'M' }) }), /datos de entrega: nombre/);
  rechaza(pedido({ entrega: entrega({ telefono: '12345678' }) }), /datos de entrega: telefono/);
  rechaza(pedido({ entrega: entrega({ destino: { codigoPostal: '50', localidad: 'x', provincia: 'X' } }) }), /codigo postal/);
  rechaza(pedido({ entrega: entrega({ destino: { codigoPostal: '5000', localidad: 'x', provincia: 'ZZ' } }) }), /provincia/);
  rechaza(pedido({ entrega: null }), /datos de entrega/);
});

test('cada texto libre tiene su tope de largo: el borde pasa y uno mas no', () => {
  // Una `referencia` de 900.000 caracteres dejaba la Orden cerca del MiB de
  // Firestore (hallazgo 8).  Cada campo, con su control positivo al lado.
  const campos: [string, number][] = [
    ['calle', LARGOS_DE_ENTREGA.calle],
    ['numero', LARGOS_DE_ENTREGA.numero],
    ['piso', LARGOS_DE_ENTREGA.piso],
    ['referencia', LARGOS_DE_ENTREGA.referencia],
    ['nombre', LARGOS_DE_ENTREGA.nombre],
  ];
  for (const [campo, largo] of campos) {
    assert.equal(parsearPedidoDelPanel(pedido({ entrega: entrega({ [campo]: 'x'.repeat(largo) }) })).ok, true, `${campo} en el borde`);
    rechaza(pedido({ entrega: entrega({ [campo]: 'x'.repeat(largo + 1) }) }), /larg/);
  }
  const localidad = (n: number) => entrega({ destino: { codigoPostal: '5000', localidad: 'x'.repeat(n), provincia: 'X' } });
  assert.equal(parsearPedidoDelPanel(pedido({ entrega: localidad(LARGOS_DE_ENTREGA.localidad) })).ok, true);
  rechaza(pedido({ entrega: localidad(LARGOS_DE_ENTREGA.localidad + 1) }), /localidad larga/);
  // El mail: la forma valida y el largo.
  const mail = (n: number) => `${'a'.repeat(n - '@e.co'.length)}@e.co`;
  assert.equal(parsearPedidoDelPanel(pedido({ entrega: entrega({ email: mail(LARGOS_DE_ENTREGA.email) }) })).ok, true);
  rechaza(pedido({ entrega: entrega({ email: mail(LARGOS_DE_ENTREGA.email + 1) }) }), /email largo/);
});

test('las claves de mas DENTRO de entrega no llegan a la Orden, aunque no se rechacen', () => {
  const r = parsearPedidoDelPanel(
    pedido({ entrega: entrega({ origen: 'vidriera', estadoPago: 'pagada', telefonoE164: '+5490000000000' }) }),
  );
  assert.equal(r.ok, true);
  if (!r.ok) return;
  const guardado = JSON.stringify(r.valor.entrega);
  assert.ok(!/origen|estadoPago|0000000000/.test(guardado), guardado);
});

test('el pedido no es un objeto', () => {
  for (const x of [null, undefined, 'pedido', 3, []]) rechaza(x, /forma/);
});

// ------------------------------------------------------------ contacto/entrega

test('contactoYEntrega parte los datos sin perder ninguno', () => {
  const r = parsearPedidoDelPanel(pedido({ entrega: entrega({ email: 'marta@ejemplo.com', piso: '3B' }) }));
  assert.equal(r.ok, true);
  if (!r.ok) return;
  const { contacto, entrega: e } = contactoYEntrega(r.valor.entrega);
  assert.deepEqual(contacto, { nombre: 'Marta Gomez', telefonoE164: '+5493515551234', email: 'marta@ejemplo.com' });
  assert.equal(e.calle, 'San Martin');
  assert.equal(e.piso, '3B');
  assert.equal(e.referencia, 'porton verde');
  assert.equal(e.destino.provincia, 'X');
  // El telefono va en `contacto` y NO en `entrega`: el indice
  // `numero + contacto.email` espera esa forma.
  assert.ok(!('telefonoE164' in e));
});

// --------------------------------------------------------- fixtures de telefono

test('las fixtures de telefono tienen los dos lados', () => {
  const salidas = ENTRADAS_DE_TELEFONO.map((t) => normalizarTelefonoAR(t));
  assert.ok(salidas.some((s) => s !== null), 'falta el control positivo');
  assert.ok(salidas.some((s) => s === null), 'falta el control negativo');
  for (const s of salidas) if (s !== null) assert.match(s, /^\+549\d{10}$/);
});
