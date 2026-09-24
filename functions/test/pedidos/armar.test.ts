import { test } from 'node:test';
import assert from 'node:assert/strict';

import { PRECIO_MAXIMO, parsearPedidoDelPanel, type PedidoDelPanel } from '@bouquet/contratos';

import { armarOrden, firmaDeLineas, firmaDelPedido, type ResultadoDeArmar } from '../../src/pedidos/armar.ts';

// Lo que el panel deja en `productos/{id}`: los mismos campos que
// `documento_del_vino.dart`, y que `validarProducto` acepta.
const vino = (id: string, cambios: Record<string, unknown> = {}) => ({
  tipo: 'simple',
  slug: id,
  nombre: `Vino ${id}`,
  precio: 1990000,
  stock: 10,
  presentacion: { botellas: 1 },
  imagenes: [],
  publicado: true,
  fichaVino: { bodegaId: 'b', varietales: ['Malbec'], color: 'tinto', organico: false, region: 'Mendoza', volumenMl: 750 },
  ...cambios,
});

const entrega = {
  nombre: 'Marta Gomez',
  telefono: '0351 15-555-1234',
  calle: 'San Martin',
  numero: '120',
  destino: { codigoPostal: '5000', localidad: 'Cordoba', provincia: 'X' },
};

/** Un pedido ya validado, como lo recibe `armarOrden`. */
function pedido(lineas: [string, number, number][]): PedidoDelPanel {
  const r = parsearPedidoDelPanel({
    idPedido: 'pedido-de-prueba-0001',
    lineas: lineas.map(([productoId, cantidad, precioUnitarioVisto]) => ({ productoId, cantidad, precioUnitarioVisto })),
    entrega,
  });
  assert.ok(r.ok, 'el pedido de la fixture tiene que validar');
  return r.valor;
}

const CONTEXTO = { numero: 7, uid: 'operador', origen: 'whatsapp' } as const;
const leidos = (o: Record<string, unknown>) => new Map<string, unknown>(Object.entries(o));

function rechazo(r: ResultadoDeArmar) {
  assert.equal(r.ok, false, 'deberia haberlo rechazado');
  return r.ok ? undefined : r.rechazo;
}

// ------------------------------------------------------------ lo que aplica

test('un pedido de dos vinos: descuenta cada uno y arma la Orden', () => {
  const r = armarOrden(
    pedido([['a', 2, 1990000], ['b', 3, 2500000]]),
    leidos({ a: vino('a', { stock: 10 }), b: vino('b', { stock: 5, precio: 2500000 }) }),
    CONTEXTO,
  );
  assert.equal(r.ok, true);
  if (!r.ok) return;

  assert.deepEqual(r.stock, [
    { productoId: 'a', antes: 10, despues: 8 },
    { productoId: 'b', antes: 5, despues: 2 },
  ]);
  assert.equal(r.orden.numero, 7);
  assert.equal(r.orden.creadaPor, 'operador');
  assert.equal(r.orden.subtotal, 2 * 1990000 + 3 * 2500000);
  assert.equal(r.orden.total, r.orden.subtotal);
  assert.equal(r.orden.envio, null, 'envio va escrito como null, no ausente');
});

test('nace con los estados del origen: whatsapp es por_fuera y sin preparar', () => {
  const r = armarOrden(pedido([['a', 1, 1990000]]), leidos({ a: vino('a') }), CONTEXTO);
  assert.ok(r.ok);
  if (!r.ok) return;
  assert.equal(r.orden.origen, 'whatsapp');
  assert.equal(r.orden.estadoPago, 'por_fuera');
  assert.equal(r.orden.estadoEntrega, 'sin_preparar');
});

test('el snapshot guarda nombre, precio, cantidad y botellas del momento', () => {
  const r = armarOrden(
    pedido([['caja', 2, 3980000]]),
    leidos({ caja: vino('caja', { precio: 3980000, presentacion: { botellas: 2 }, nombre: 'Caja de dos' }) }),
    CONTEXTO,
  );
  assert.ok(r.ok);
  if (!r.ok) return;
  assert.deepEqual(r.orden.items, [
    { productoId: 'caja', nombre: 'Caja de dos', precioUnitario: 3980000, cantidad: 2, botellas: 2 },
  ]);
  // El stock baja en unidades de VENTA, no en botellas: 2 cajas, no 4 botellas.
  assert.deepEqual(r.stock, [{ productoId: 'caja', antes: 10, despues: 8 }]);
});

test('lleva contacto y entrega separados, con el telefono en E.164', () => {
  const r = armarOrden(pedido([['a', 1, 1990000]]), leidos({ a: vino('a') }), CONTEXTO);
  assert.ok(r.ok);
  if (!r.ok) return;
  assert.equal(r.orden.contacto.telefonoE164, '+5493515551234');
  assert.equal(r.orden.entrega.calle, 'San Martin');
  assert.equal(r.orden.entrega.destino.propio, false);
});

test('el stock puede quedar en cero, y nunca por debajo', () => {
  const justo = armarOrden(pedido([['a', 10, 1990000]]), leidos({ a: vino('a', { stock: 10 }) }), CONTEXTO);
  assert.ok(justo.ok);
  if (justo.ok) assert.equal(justo.stock[0]?.despues, 0);

  const pasado = armarOrden(pedido([['a', 11, 1990000]]), leidos({ a: vino('a', { stock: 10 }) }), CONTEXTO);
  assert.deepEqual(rechazo(pasado), { codigo: 'sin-stock', productoId: 'a', actual: 10 });
});

test('cuatro botellas sueltas se aceptan: la caja de seis no aplica a WhatsApp', () => {
  const r = armarOrden(pedido([['a', 4, 1990000]]), leidos({ a: vino('a') }), CONTEXTO);
  assert.equal(r.ok, true);
});

test('un vino NO publicado se vende igual', () => {
  const r = armarOrden(pedido([['a', 1, 1990000]]), leidos({ a: vino('a', { publicado: false }) }), CONTEXTO);
  assert.equal(r.ok, true);
});

// ---------------------------------------------------------- lo que rechaza

test('un producto que no existe', () => {
  const r = armarOrden(pedido([['a', 1, 1990000]]), leidos({}), CONTEXTO);
  assert.deepEqual(rechazo(r), { codigo: 'no-existe', productoId: 'a' });
});

test('un vino de muestra: su stock es inventado', () => {
  const r = armarOrden(pedido([['a', 1, 1990000]]), leidos({ a: vino('a', { muestra: true }) }), CONTEXTO);
  assert.deepEqual(rechazo(r), { codigo: 'de-muestra', productoId: 'a' });
  // Control positivo: el MISMO vino con `muestra: false` si se vende.
  assert.equal(armarOrden(pedido([['a', 1, 1990000]]), leidos({ a: vino('a', { muestra: false }) }), CONTEXTO).ok, true);
});

test('un compuesto no tiene stock propio', () => {
  const compuesto = vino('a', { tipo: 'compuesto' });
  delete (compuesto as { stock?: number }).stock;
  const r = armarOrden(pedido([['a', 1, 1990000]]), leidos({ a: compuesto }), CONTEXTO);
  assert.deepEqual(rechazo(r), { codigo: 'compuesto', productoId: 'a' });
});

test('un documento roto se dice, con su motivo', () => {
  const r = armarOrden(pedido([['a', 1, 1990000]]), leidos({ a: vino('a', { nombre: '' }) }), CONTEXTO);
  const x = rechazo(r);
  assert.equal(x?.codigo, 'producto-roto');
  assert.match(x?.motivo ?? '', /nombre/);
});

test('un stock negativo es un dato roto, no una venta', () => {
  const r = armarOrden(pedido([['a', 1, 1990000]]), leidos({ a: vino('a', { stock: -3 }) }), CONTEXTO);
  assert.equal(rechazo(r)?.codigo, 'producto-roto');
});

test('el precio cambio: rechaza con el de ahora', () => {
  const r = armarOrden(pedido([['a', 1, 1990000]]), leidos({ a: vino('a', { precio: 2100000 }) }), CONTEXTO);
  assert.deepEqual(rechazo(r), { codigo: 'cambio-el-precio', productoId: 'a', actual: 2100000 });
});

test('una linea mala tira todo el pedido, aunque las otras esten bien', () => {
  const r = armarOrden(
    pedido([['a', 2, 1990000], ['b', 6, 1990000]]),
    leidos({ a: vino('a', { stock: 10 }), b: vino('b', { stock: 5 }) }),
    CONTEXTO,
  );
  assert.deepEqual(rechazo(r), { codigo: 'sin-stock', productoId: 'b', actual: 5 });
});

test('un vino sin precio: sin-precio, NO cambio-el-precio', () => {
  // El parser no deja mandar un precio visto de 0: un `cambio-el-precio` con
  // `actual: 0` ofreceria reintentar a $0 y volveria a rebotar.
  const r = armarOrden(pedido([['a', 1, 1990000]]), leidos({ a: vino('a', { precio: 0, publicado: false }) }), CONTEXTO);
  assert.deepEqual(rechazo(r), { codigo: 'sin-precio', productoId: 'a' });
});

test('un precio absurdo no desborda la suma: producto-roto, no una excepcion', () => {
  const absurdo = PRECIO_MAXIMO + 1;
  const r = armarOrden(pedido([['a', 1, 1990000]]), leidos({ a: vino('a', { precio: absurdo }) }), CONTEXTO);
  const x = rechazo(r);
  assert.equal(x?.codigo, 'producto-roto');
  assert.match(x?.motivo ?? '', /absurdo/);
  // Control positivo: el borde exacto se vende.
  assert.equal(armarOrden(pedido([['a', 1, PRECIO_MAXIMO]]), leidos({ a: vino('a', { precio: PRECIO_MAXIMO }) }), CONTEXTO).ok, true);
});

test('el peor pedido posible arma la Orden sin lanzar', () => {
  // 30 lineas, la cantidad maxima y el precio maximo: la razon de PRECIO_MAXIMO.
  const ids = Array.from({ length: 30 }, (_, i) => `vino-${i}`);
  const p = pedido(ids.map((id) => [id, 5000, PRECIO_MAXIMO]));
  const r = armarOrden(p, leidos(Object.fromEntries(ids.map((id) => [id, vino(id, { precio: PRECIO_MAXIMO, stock: 5000 })]))), CONTEXTO);
  assert.equal(r.ok, true);
  if (r.ok) assert.ok(Number.isSafeInteger(r.orden.total));
});

// ---------------------------------------------------------------- la firma

test('firmaDeLineas: el mismo pedido en otro orden es el mismo', () => {
  const a = firmaDeLineas([{ productoId: 'a', cantidad: 2 }, { productoId: 'b', cantidad: 3 }]);
  const b = firmaDeLineas([{ productoId: 'b', cantidad: 3 }, { productoId: 'a', cantidad: 2 }]);
  assert.equal(a, b);
});

test('firmaDeLineas: cambiar una cantidad, un producto o quitar una linea cambia la firma', () => {
  const base = [{ productoId: 'a', cantidad: 2 }, { productoId: 'b', cantidad: 3 }];
  const firma = firmaDeLineas(base);
  assert.notEqual(firmaDeLineas([{ productoId: 'a', cantidad: 3 }, { productoId: 'b', cantidad: 3 }]), firma);
  assert.notEqual(firmaDeLineas([{ productoId: 'a', cantidad: 2 }, { productoId: 'c', cantidad: 3 }]), firma);
  assert.notEqual(firmaDeLineas([{ productoId: 'a', cantidad: 2 }]), firma);
});

// --------------------------------------------------- la firma del pedido entero

const contacto = { nombre: 'Marta Gomez', telefonoE164: '+5493515551234', email: null };
const direccion = {
  calle: 'San Martin',
  numero: '120',
  piso: null,
  referencia: null,
  destino: { codigoPostal: '5000', localidad: 'Cordoba', provincia: 'X', propio: false },
};
const lineas = [{ productoId: 'a', cantidad: 2 }];

test('firmaDelPedido: el mismo pedido con las claves en otro orden es el mismo', () => {
  // Firestore devuelve los mapas con las claves ordenadas, no como se escribieron.
  const otroOrden = {
    destino: { propio: false, provincia: 'X', localidad: 'Cordoba', codigoPostal: '5000' },
    referencia: null,
    piso: null,
    numero: '120',
    calle: 'San Martin',
  };
  assert.equal(
    firmaDelPedido({ lineas, contacto, entrega: direccion }),
    firmaDelPedido({ lineas, contacto, entrega: otroOrden }),
  );
});

test('firmaDelPedido: cambiar CUALQUIER dato de contacto o de entrega cambia la firma', () => {
  // El hallazgo 3: con la firma de solo las lineas, un reintento con la
  // direccion corregida se leia como "el mismo" y la correccion se perdia.
  const base = firmaDelPedido({ lineas, contacto, entrega: direccion });
  const cambios: [string, unknown, unknown][] = [
    ['nombre', { ...contacto, nombre: 'Otra' }, direccion],
    ['telefono', { ...contacto, telefonoE164: '+5493510000000' }, direccion],
    ['email', { ...contacto, email: 'a@b.co' }, direccion],
    ['calle', contacto, { ...direccion, calle: 'Belgrano' }],
    ['numero', contacto, { ...direccion, numero: '1200' }],
    ['piso', contacto, { ...direccion, piso: '3B' }],
    ['referencia', contacto, { ...direccion, referencia: 'porton verde' }],
    ['codigo postal', contacto, { ...direccion, destino: { ...direccion.destino, codigoPostal: '5001' } }],
    ['localidad', contacto, { ...direccion, destino: { ...direccion.destino, localidad: 'Carlos Paz' } }],
    ['provincia', contacto, { ...direccion, destino: { ...direccion.destino, provincia: 'B' } }],
  ];
  for (const [campo, c, e] of cambios) {
    assert.notEqual(firmaDelPedido({ lineas, contacto: c, entrega: e }), base, campo);
  }
  assert.notEqual(firmaDelPedido({ lineas: [{ productoId: 'a', cantidad: 3 }], contacto, entrega: direccion }), base, 'cantidad');
});

test('firmaDelPedido: un null y el texto "null" no se confunden', () => {
  const a = firmaDelPedido({ lineas, contacto, entrega: { ...direccion, piso: null } });
  const b = firmaDelPedido({ lineas, contacto, entrega: { ...direccion, piso: 'null' } });
  assert.notEqual(a, b);
});
