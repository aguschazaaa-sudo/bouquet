/**
 * La venta por caja. spec: openspec/changes/cajas-de-seis/specs/venta-por-caja.
 *
 * Un caso por escenario de la spec, mas el control que prueba que
 * `parsearCarrito` NO cambio.
 */

import { test } from 'node:test';
import assert from 'node:assert/strict';

import {
  BOTELLAS_POR_CAJA,
  botellasEnCarrito,
  botellasGuardadas,
  botellasSueltas,
  botellasSueltasGuardadas,
  cargaDelPedido,
  carritoVacio,
  contarCaja,
  estadoDeLaCaja,
  parsearCarrito,
  resolverCarrito,
  sePuedeCobrar,
  unidadesEnCarrito,
  type Carrito,
} from '../src/carrito.ts';
import { centavos } from '../src/dinero.ts';
import type { ProductoPublicado } from '../src/producto.ts';

const ID_COMPRA = '3f2b9c1e-7a4d-4e8f-9b21-5c6d7e8f9a0b';

/**
 * Las `botellas` guardadas salen de los productos, como en la vida real: las
 * escribe `agregar` desde la proyeccion del momento. Un id que no esta en la
 * lista guarda 1, que es el caso del vino que ya no existe.
 */
function carrito(lineas: { productoId: string; cantidad: number }[], productos: ProductoPublicado[] = []): Carrito {
  const botellas = new Map(productos.map((p) => [p.id, p.botellas]));
  return {
    version: 2,
    idCompra: ID_COMPRA,
    lineas: lineas.map((l) => ({ ...l, botellas: botellas.get(l.productoId) ?? 1 })),
  };
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

/** Resuelve un carrito contra una proyeccion armada al vuelo. */
function estado(lineas: { productoId: string; cantidad: number }[], productos: ProductoPublicado[]) {
  return estadoDeLaCaja(resolverCarrito(carrito(lineas, productos), productos));
}

// --------------------------- la cuenta es en botellas, y solo de las sueltas

test('un producto que viene en su propia caja NO cuenta para la caja de seis', () => {
  // ADR 009 §10: trae su embalaje y viaja solo. Tres packs de 2 son seis
  // botellas y CERO botellas sueltas -- no hay caja que completar.
  const e = estado([{ productoId: 'pack', cantidad: 3 }], [publicado('pack', { botellas: 2 })]);
  assert.equal(e.botellas, 0);
  assert.equal(e.cajasCompletas, 0);
  assert.equal(e.faltan, 0);
});

test('mezcla de presentaciones: la caja la miden las sueltas, el total las cuenta a todas', () => {
  const productos = [publicado('pack', { botellas: 2 }), publicado('suelta')];
  const lineas = [
    { productoId: 'pack', cantidad: 2 },
    { productoId: 'suelta', cantidad: 2 },
  ];
  const e = estado(lineas, productos);
  const r = resolverCarrito(carrito(lineas, productos), productos);

  // SEIS botellas en el pedido y la caja abierta: es el caso que hace falta
  // decir bien en pantalla, o el comprador ve seis y un boton que no aparece.
  assert.equal(botellasEnCarrito(r), 6);
  assert.equal(botellasSueltas(r), 2);
  assert.equal(e.botellas, 2);
  assert.equal(e.faltan, 4);
  assert.equal(sePuedeCobrar(r), false);
});

test('contar unidades en vez de botellas daria el numero equivocado', () => {
  // Control: 3 unidades de un pack de 2 son 3 unidades y SEIS botellas.
  const resuelto = resolverCarrito(carrito([{ productoId: 'pack', cantidad: 3 }], [
    publicado('pack', { botellas: 2 }),
  ]), [
    publicado('pack', { botellas: 2 }),
  ]);
  assert.equal(botellasEnCarrito(resuelto), 6);
  assert.notEqual(botellasEnCarrito(resuelto), 3);
});

// ------------------------------------------- solo las lineas vigentes cuentan

test('una linea agotada no completa la caja', () => {
  const e = estado(
    [
      { productoId: 'vigente', cantidad: 5 },
      { productoId: 'agotado', cantidad: 1 },
    ],
    [publicado('vigente'), publicado('agotado', { balde: 'agotado', tope: 0 })],
  );
  assert.equal(e.botellas, 5);
  assert.equal(e.faltan, 1);
});

test('una linea de un vino que ya no esta no cuenta', () => {
  const e = estado(
    [
      { productoId: 'vigente', cantidad: 5 },
      { productoId: 'fantasma', cantidad: 1 },
    ],
    [publicado('vigente')],
  );
  assert.equal(e.botellas, 5);
  assert.equal(e.faltan, 1);
});

// ------------------------------------------------------ los cuatro estados

test('carrito incompleto: 4 botellas', () => {
  const e = estado([{ productoId: 'a', cantidad: 4 }], [publicado('a')]);
  assert.deepEqual(e, { botellas: 4, cajasCompletas: 0, faltan: 2, sobran: 4 });
});

test('carrito completo: 12 botellas', () => {
  const e = estado([{ productoId: 'a', cantidad: 12 }], [publicado('a')]);
  assert.deepEqual(e, { botellas: 12, cajasCompletas: 2, faltan: 0, sobran: 0 });
});

test('carrito pasado de una caja: 7 botellas', () => {
  const e = estado(
    [
      { productoId: 'a', cantidad: 6 },
      { productoId: 'b', cantidad: 1 },
    ],
    [publicado('a'), publicado('b')],
  );
  assert.deepEqual(e, { botellas: 7, cajasCompletas: 1, faltan: 5, sobran: 1 });
});

test('carrito vacio', () => {
  const e = estado([], []);
  assert.deepEqual(e, { botellas: 0, cajasCompletas: 0, faltan: 0, sobran: 0 });
});

// -------------------------------------------------- la precondicion de cobro

test('una caja completa se puede cobrar', () => {
  const r = resolverCarrito(carrito([{ productoId: 'a', cantidad: 6 }], [publicado('a')]), [publicado('a')]);
  assert.equal(sePuedeCobrar(r), true);
});

test('un carrito incompleto no se puede cobrar', () => {
  const r = resolverCarrito(carrito([{ productoId: 'a', cantidad: 5 }], [publicado('a')]), [publicado('a')]);
  assert.equal(sePuedeCobrar(r), false);
});

test('un carrito vacio no se puede cobrar, aunque cero sea multiplo', () => {
  assert.equal(contarCaja(0).faltan, 0);
  assert.equal(sePuedeCobrar(resolverCarrito(carritoVacio(ID_COMPRA), [])), false);
});

test('un carrito de solo lineas agotadas no se puede cobrar', () => {
  const r = resolverCarrito(carrito([{ productoId: 'x', cantidad: 6 }], [
    publicado('x', { balde: 'agotado', tope: 0 }),
  ]), [
    publicado('x', { balde: 'agotado', tope: 0 }),
  ]);
  assert.equal(sePuedeCobrar(r), false);
});

test('un pedido de un solo pack se puede cobrar: viaja solo', () => {
  // Cero sueltas es multiplo de seis Y hay algo que despachar. Las dos
  // condiciones de `sePuedeCobrar`, y esta es la que las separa.
  const p = publicado('pack', { botellas: 2 });
  const r = resolverCarrito(carrito([{ productoId: 'pack', cantidad: 1 }], [p]), [p]);
  assert.equal(botellasSueltas(r), 0);
  assert.equal(sePuedeCobrar(r), true);
});

test('un pack NO completa la caja de las sueltas', () => {
  // Control discriminante: las mismas seis botellas, cobrables si son seis
  // sueltas y no cobrables si son cuatro sueltas y un pack.
  const pack = publicado('pack', { botellas: 2 });
  const suelta = publicado('suelta');
  const conPack = resolverCarrito(
    carrito(
      [
        { productoId: 'suelta', cantidad: 4 },
        { productoId: 'pack', cantidad: 1 },
      ],
      [suelta, pack],
    ),
    [suelta, pack],
  );
  assert.equal(botellasEnCarrito(conPack), 6);
  assert.equal(sePuedeCobrar(conPack), false, 'las cuatro sueltas siguen sin caja');

  const seisSueltas = resolverCarrito(carrito([{ productoId: 'suelta', cantidad: 6 }], [suelta]), [suelta]);
  assert.equal(botellasEnCarrito(seisSueltas), 6);
  assert.equal(sePuedeCobrar(seisSueltas), true);
});

// -------------------------------------------------- lo que de verdad viaja

test('la carga separa lo suelto de lo que trae su caja, una entrada por unidad', () => {
  const pack = publicado('pack', { botellas: 2 });
  const suelta = publicado('suelta');
  const r = resolverCarrito(
    carrito(
      [
        { productoId: 'suelta', cantidad: 6 },
        { productoId: 'pack', cantidad: 2 },
      ],
      [suelta, pack],
    ),
    [suelta, pack],
  );
  // Dos packs son DOS bultos, no un 4: cada uno pesa y mide por su cuenta.
  assert.deepEqual(cargaDelPedido(r), { sueltas: 6, propias: [2, 2] });
});

test('lo que no se puede vender no viaja', () => {
  const agotado = publicado('pack', { botellas: 2, balde: 'agotado', tope: 0 });
  const r = resolverCarrito(carrito([{ productoId: 'pack', cantidad: 1 }], [agotado]), [agotado]);
  assert.deepEqual(cargaDelPedido(r), { sueltas: 0, propias: [] });
});

// ------------------------------------- un carrito incompleto SIGUE siendo valido

test('parsearCarrito acepta un carrito de 4 botellas', () => {
  const guardado = JSON.stringify(carrito([{ productoId: 'a', cantidad: 4 }]));
  const v = parsearCarrito(guardado);
  assert.equal(v.ok, true);
  assert.equal(v.ok && v.valor.lineas[0]?.cantidad, 4);
});

test('el carrito a medio llenar sobrevive al round-trip', () => {
  const original = carrito([
    { productoId: 'a', cantidad: 2 },
    { productoId: 'b', cantidad: 1 },
  ]);
  const v = parsearCarrito(JSON.stringify(original));
  assert.equal(v.ok, true);
  assert.deepEqual(v.ok && v.valor, original);
});

// ------------------------------------------------------- la regla es parametrica

test('con cajas de 3 la aritmetica da los valores de cajas de 3', () => {
  assert.deepEqual(contarCaja(4, 3), { botellas: 4, cajasCompletas: 1, faltan: 2, sobran: 1 });
  assert.deepEqual(contarCaja(6, 3), { botellas: 6, cajasCompletas: 2, faltan: 0, sobran: 0 });
  assert.deepEqual(contarCaja(0, 3), { botellas: 0, cajasCompletas: 0, faltan: 0, sobran: 0 });
});

test('la regla se sostiene para cualquier tamano', () => {
  for (const porCaja of [1, 2, 3, 6, 12]) {
    for (let botellas = 0; botellas <= 25; botellas++) {
      const e = contarCaja(botellas, porCaja);
      const donde = `${botellas} botellas en cajas de ${porCaja}`;
      // Lo que hay = cajas enteras + lo que sobra.
      assert.equal(e.cajasCompletas * porCaja + e.sobran, botellas, donde);
      // Si sobra algo, lo que falta lo completa hasta una caja. Si no, los dos en 0.
      if (e.sobran === 0) assert.equal(e.faltan, 0, donde);
      else assert.equal(e.faltan + e.sobran, porCaja, donde);
    }
  }
});

test('un tamano de caja invalido explota en vez de dar NaN', () => {
  assert.throws(() => contarCaja(6, 0), RangeError);
  assert.throws(() => contarCaja(6, 1.5), RangeError);
});

test('el tamano vigente es el que usa estadoDeLaCaja', () => {
  const e = estado([{ productoId: 'a', cantidad: BOTELLAS_POR_CAJA }], [publicado('a', { tope: 99 })]);
  assert.equal(e.cajasCompletas, 1);
  assert.equal(e.faltan, 0);
  assert.equal(e.sobran, 0);
});

// ------------------------------- las botellas guardadas, y su autocorreccion

test('la barra puede contar botellas SIN catalogo', () => {
  // Es lo unico que puede hacer el contador del layout: lee localStorage y no
  // tiene proyeccion. 3 packs de 2 son 6 botellas en el pedido...
  const c = carrito([{ productoId: 'pack', cantidad: 3 }], [publicado('pack', { botellas: 2 })]);
  assert.equal(botellasGuardadas(c), 6);
  // ...y NINGUNA que necesite caja: la barra no puede pedir que se complete
  // algo que ya viaja. El campo `botellas` de la linea es lo que deja hacer
  // esta distincion sin leer Firestore.
  assert.equal(botellasSueltasGuardadas(c), 0);
  assert.equal(contarCaja(botellasSueltasGuardadas(c)).faltan, 0);
});

test('la barra distingue dos sueltas de un pack de dos', () => {
  // Control positivo y negativo del test de arriba: el mismo numero de
  // botellas guardadas, una cuenta de sueltas distinta.
  const conPack = carrito([{ productoId: 'pack', cantidad: 1 }], [publicado('pack', { botellas: 2 })]);
  const sueltas = carrito([{ productoId: 'a', cantidad: 2 }], [publicado('a')]);
  assert.equal(botellasGuardadas(conPack), botellasGuardadas(sueltas));
  assert.equal(botellasSueltasGuardadas(conPack), 0);
  assert.equal(botellasSueltasGuardadas(sueltas), 2);
});

test('contar UNIDADES en la barra daria 3 donde hay 6 botellas', () => {
  // El control que justifica guardar `botellas`: sin el campo, la barra diria
  // 3 y la pagina 6.
  const c = carrito([{ productoId: 'pack', cantidad: 3 }], [publicado('pack', { botellas: 2 })]);
  assert.equal(unidadesEnCarrito(c), 3);
  assert.equal(botellasGuardadas(c), 6);
  assert.notEqual(unidadesEnCarrito(c), botellasGuardadas(c));
});

test('un botellas guardado que no coincide se CORRIGE y se marca para guardar', () => {
  // El agujero es real: borrar y recrear un producto con el mismo id saltea la
  // inmutabilidad de `presentacion` (hallazgo 1 de revisor-pagos).
  const viejo: Carrito = {
    version: 2,
    idCompra: ID_COMPRA,
    lineas: [{ productoId: 'pack', cantidad: 2, botellas: 1 }],
  };
  const r = resolverCarrito(viejo, [publicado('pack', { botellas: 2 })]);
  assert.equal(r.ajustado, true, 'hay que volver a guardarlo');
  assert.equal(r.carrito.lineas[0]?.botellas, 2, 'quedo corregido');
  assert.equal(botellasEnCarrito(r), 4, 'y la cuenta usa la proyeccion, no lo guardado');
});

test('sin nada que corregir, el carrito guardado no se toca', () => {
  // Control negativo del test de arriba: si `ajustado` diera siempre true,
  // aquel no probaria nada.
  const c = carrito([{ productoId: 'pack', cantidad: 2 }], [publicado('pack', { botellas: 2 })]);
  const r = resolverCarrito(c, [publicado('pack', { botellas: 2 })]);
  assert.equal(r.ajustado, false);
  assert.equal(r.carrito, c, 'devuelve el MISMO objeto');
});

test('de un vino que ya no esta se conserva lo guardado', () => {
  const c = carrito([{ productoId: 'fantasma', cantidad: 2 }]);
  const r = resolverCarrito(c, []);
  assert.equal(r.carrito.lineas[0]?.botellas, 1, 'no hay con que mejorarlo');
  assert.equal(botellasEnCarrito(r), 0, 'y no cuenta para la caja');
});

test('una linea sin botellas no pasa el parser', () => {
  const sinCampo = { version: 2, idCompra: ID_COMPRA, lineas: [{ productoId: 'a', cantidad: 1 }] };
  assert.equal(parsearCarrito(sinCampo).ok, false);
  for (const botellas of [0, -1, 1.5, '2', null]) {
    const r = parsearCarrito({ version: 2, idCompra: ID_COMPRA, lineas: [{ productoId: 'a', cantidad: 1, botellas }] });
    assert.equal(r.ok, false, `botellas ${String(botellas)}`);
  }
  // Control positivo: con el campo bien, pasa.
  assert.equal(parsearCarrito(carrito([{ productoId: 'a', cantidad: 1 }])).ok, true);
});
