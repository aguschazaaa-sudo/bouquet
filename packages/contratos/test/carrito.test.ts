import { test } from 'node:test';
import assert from 'node:assert/strict';

import {
  agregar,
  carritoVacio,
  parsearCarrito,
  quitar,
  resolverCarrito,
  unidadesEnCarrito,
  type Carrito,
  type PedidoDeCompra,
} from '../src/carrito.ts';
import { centavos, desdePesos } from '../src/dinero.ts';
import type { ProductoPublicado } from '../src/producto.ts';

const ID_COMPRA = '3f2b9c1e-7a4d-4e8f-9b21-5c6d7e8f9a0b';

function carrito(lineas: { productoId: string; cantidad: number }[]): Carrito {
  return { version: 1, idCompra: ID_COMPRA, lineas };
}

function publicado(id: string, cambios: Partial<ProductoPublicado> = {}): ProductoPublicado {
  return {
    id,
    slug: id,
    nombre: id,
    bodega: 'Rutini Wines',
    precio: centavos(1990000),
    botellas: 1,
    volumenMl: 750,
    imagenes: [],
    color: 'tinto',
    organico: false,
    varietales: ['Malbec'],
    esCorte: false,
    anada: 2023,
    region: 'Mendoza',
    balde: 'disponible',
    tope: 12,
    puesto: null,
    ...cambios,
  };
}

// ------------------------------------------------------------------ parser

test('un carrito bien formado pasa, como objeto y como texto', () => {
  const bueno = carrito([{ productoId: 'trumpeter-malbec', cantidad: 2 }]);
  assert.equal(parsearCarrito(bueno).ok, true);
  assert.equal(parsearCarrito(JSON.stringify(bueno)).ok, true);
  assert.equal(parsearCarrito(carrito([])).ok, true, 'el carrito vacio es valido');
});

test('una cantidad negativa se rechaza, no se corrige', () => {
  const r = parsearCarrito(carrito([{ productoId: 'a', cantidad: -5 }]));
  assert.equal(r.ok, false);
});

test('una linea repetida se rechaza', () => {
  const r = parsearCarrito(
    carrito([
      { productoId: 'a', cantidad: 1 },
      { productoId: 'a', cantidad: 2 },
    ]),
  );
  assert.equal(r.ok, false);
  assert.match(r.ok ? '' : r.motivo, /repetido/);
});

test('una version desconocida se rechaza', () => {
  assert.equal(parsearCarrito({ ...carrito([]), version: 2 }).ok, false);
  assert.equal(parsearCarrito({ idCompra: ID_COMPRA, lineas: [] }).ok, false, 'sin version tampoco');
});

test('cantidades no enteras, cero o por encima del tope por pedido se rechazan', () => {
  for (const cantidad of [2.5, 0, 13, '2', null]) {
    const r = parsearCarrito({ version: 1, idCompra: ID_COMPRA, lineas: [{ productoId: 'a', cantidad }] });
    assert.equal(r.ok, false, `cantidad ${String(cantidad)}`);
  }
  // Control: el borde de arriba entra.
  assert.equal(parsearCarrito(carrito([{ productoId: 'a', cantidad: 12 }])).ok, true);
});

test('lo que no es JSON se rechaza sin tirar', () => {
  assert.equal(parsearCarrito('{roto').ok, false);
  assert.equal(parsearCarrito(null).ok, false);
  assert.equal(parsearCarrito([]).ok, false);
});

test('un productoId con barra se rechaza: cambiaria la ruta en Firestore', () => {
  assert.equal(parsearCarrito(carrito([{ productoId: 'otro/doc', cantidad: 1 }])).ok, false);
  assert.equal(parsearCarrito(carrito([{ productoId: '..', cantidad: 1 }])).ok, false);
});

test('un id reservado de Firestore (__x__) se rechaza', () => {
  assert.equal(parsearCarrito(carrito([{ productoId: '__x__', cantidad: 1 }])).ok, false);
  // Control: guiones bajos adentro de un id común sí valen.
  assert.equal(parsearCarrito(carrito([{ productoId: 'vino_de_la_casa', cantidad: 1 }])).ok, true);
});

test('el carrito no guarda precios: una clave de mas se rechaza', () => {
  const conPrecio = { version: 1, idCompra: ID_COMPRA, lineas: [{ productoId: 'a', cantidad: 1, precio: 100 }] };
  assert.equal(parsearCarrito(conPrecio).ok, false);
  assert.equal(parsearCarrito({ ...carrito([]), total: 100 }).ok, false);
});

test('carritoVacio exige un idCompra con forma', () => {
  assert.equal(carritoVacio(ID_COMPRA).lineas.length, 0);
  assert.throws(() => carritoVacio('x'), RangeError);
});

// ------------------------------------------------------------------- tope

test('agregar por encima del tope deja la linea en el tope y lo avisa', () => {
  const con4 = carrito([{ productoId: 'a', cantidad: 4 }]);
  const r = agregar(con4, 'a', 3, 5);
  assert.equal(r.carrito.lineas[0]?.cantidad, 5);
  assert.equal(r.alTope, true);

  // Control: llegar justo al tope no es pasarlo.
  const justo = agregar(con4, 'a', 1, 5);
  assert.equal(justo.carrito.lineas[0]?.cantidad, 5);
  assert.equal(justo.alTope, false);
});

test('agregar un agotado no agrega nada', () => {
  const vacio = carrito([]);
  const r = agregar(vacio, 'a', 1, 0);
  assert.equal(r.carrito.lineas.length, 0);
  assert.equal(r.alTope, true);
});

test('agregar un vino nuevo crea su linea, y el contador suma todo', () => {
  let c = carrito([{ productoId: 'a', cantidad: 2 }]);
  c = agregar(c, 'b', 3, 12).carrito;
  assert.deepEqual(c.lineas, [
    { productoId: 'a', cantidad: 2 },
    { productoId: 'b', cantidad: 3 },
  ]);
  assert.equal(unidadesEnCarrito(c), 5);
  assert.equal(parsearCarrito(c).ok, true, 'lo que produce agregar vuelve a pasar el parser');
});

test('quitar saca la linea y deja las demas', () => {
  const c = quitar(
    carrito([
      { productoId: 'a', cantidad: 1 },
      { productoId: 'b', cantidad: 1 },
    ]),
    'a',
  );
  assert.deepEqual(c.lineas, [{ productoId: 'b', cantidad: 1 }]);
});

// ----------------------------------------------- carrito contra proyeccion

test('si el tope bajo, la linea se ajusta y el ajustado es el que se guarda', () => {
  const r = resolverCarrito(carrito([{ productoId: 'a', cantidad: 8 }]), [publicado('a', { tope: 5 })]);
  assert.equal(r.lineas[0]?.cantidad, 5);
  assert.equal(r.lineas[0]?.ajustada, true);
  assert.equal(r.ajustado, true);
  assert.equal(r.carrito.lineas[0]?.cantidad, 5, 'lo que se guarda es 5');
  assert.equal(r.total, 5 * 1990000, 'y el total usa 5');
});

test('sin cambios, el carrito resuelto es el mismo', () => {
  const c = carrito([{ productoId: 'a', cantidad: 2 }]);
  const r = resolverCarrito(c, [publicado('a')]);
  assert.equal(r.ajustado, false);
  assert.equal(r.carrito, c);
});

test('una linea agotada queda marcada, no suma y conserva su cantidad', () => {
  const r = resolverCarrito(
    carrito([
      { productoId: 'a', cantidad: 3 },
      { productoId: 'b', cantidad: 1 },
    ]),
    [publicado('a', { balde: 'agotado', tope: 0 }), publicado('b')],
  );
  assert.equal(r.lineas[0]?.estado, 'agotada');
  assert.equal(r.lineas[0]?.subtotal, 0);
  assert.equal(r.lineas[0]?.cantidad, 3, 'bajarla a 0 dejaria guardado un carrito invalido');
  assert.equal(r.total, 1990000, 'solo suma la vigente');
  assert.equal(parsearCarrito(r.carrito).ok, true);
});

test('una linea de un producto que ya no esta queda marcada y no suma', () => {
  const r = resolverCarrito(carrito([{ productoId: 'despublicado', cantidad: 2 }]), [publicado('a')]);
  assert.equal(r.lineas[0]?.estado, 'no-disponible');
  assert.equal(r.lineas[0]?.producto, null);
  assert.equal(r.total, 0);
});

test('el total: 2 x $ 19.900 + 1 x $ 76.000 = $ 115.800', () => {
  const r = resolverCarrito(
    carrito([
      { productoId: 'trumpeter', cantidad: 2 },
      { productoId: 'caja', cantidad: 1 },
    ]),
    [publicado('trumpeter', { precio: desdePesos('19900') }), publicado('caja', { precio: desdePesos('76000'), botellas: 2 })],
  );
  assert.equal(r.total, desdePesos('115800'));
});

// ------------------------------------------------------- pedido de compra

test('el pedido de compra lleva idCompra y el precio visto por linea', () => {
  // Es sobre todo un chequeo de tipos: si el campo cambia de nombre, esto no
  // compila en `tsc --noEmit`, que es donde tiene que fallar.
  const pedido: PedidoDeCompra = {
    idCompra: ID_COMPRA,
    lineas: [{ productoId: 'a', cantidad: 2, precioUnitarioVisto: desdePesos('19900') }],
  };
  assert.equal(pedido.lineas[0]?.precioUnitarioVisto, 1990000);
});
