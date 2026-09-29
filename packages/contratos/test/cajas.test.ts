/**
 * Las cajas sugeridas.
 * spec: openspec/changes/cajas-de-seis/specs/cajas-sugeridas.
 */

import { test } from 'node:test';
import assert from 'node:assert/strict';

import { botellasEnCarrito, botellasSueltas, estadoDeLaCaja, resolverCarrito, sePuedeCobrar } from '../src/carrito.ts';
import {
  armarCajasSugeridas,
  LARGO_DEL_NOMBRE_DE_CAJA,
  llenarConLaCaja,
  resolverCajasSugeridas,
  TOPE_DE_CAJAS_SUGERIDAS,
  validarCajasSugeridas,
  verificarComposicion,
  type CajaSugerida,
} from '../src/cajas.ts';
import { centavos } from '../src/dinero.ts';
import type { ProductoPublicado } from '../src/producto.ts';

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
    descripcion: null,
    balde: 'disponible',
    tope: 12,
    puesto: null,
    ...cambios,
  };
}

const SEIS = ['a', 'b', 'c', 'd', 'e', 'f'];
const caja = (cambios: Partial<CajaSugerida> = {}): CajaSugerida => ({
  slug: 'variada',
  nombre: 'Caja variada',
  productoIds: SEIS,
  ...cambios,
});
const seisProductos = () => SEIS.map((id) => publicado(id));

// ------------------------------------------------------------------ la forma

test('el documento ausente son cero cajas, no un error', () => {
  for (const vacio of [undefined, null]) {
    const r = validarCajasSugeridas(vacio);
    assert.deepEqual(r.cajas, []);
    assert.deepEqual(r.descartes, []);
  }
});

test('un documento con otra forma se descarta entero y se informa', () => {
  const r = validarCajasSugeridas({ lista: [] });
  assert.deepEqual(r.cajas, []);
  assert.equal(r.descartes.length, 1);
  assert.match(r.descartes[0]!.motivo, /\{ cajas/);
});

test('seis ids de una botella pasan la forma', () => {
  const r = validarCajasSugeridas({ cajas: [caja()] });
  assert.equal(r.cajas.length, 1);
  assert.equal(r.descartes.length, 0);
});

test('mas entradas que el tamano de la caja no pasan', () => {
  const r = validarCajasSugeridas({ cajas: [caja({ productoIds: [...SEIS, 'g'] })] });
  assert.equal(r.cajas.length, 0);
  assert.match(r.descartes[0]!.motivo, /7 entradas/);
});

test('menos entradas TAMPOCO pasan: la caja es exacta', () => {
  // Desde ADR 009 §10 una caja armada es de botellas sueltas, y una suelta es
  // una entrada: la cuenta de entradas ES la de botellas. Antes cinco entradas
  // pasaban la forma porque una podia aportar dos.
  const r = validarCajasSugeridas({ cajas: [caja({ productoIds: SEIS.slice(0, 5) })] });
  assert.equal(r.cajas.length, 0);
  assert.match(r.descartes[0]!.motivo, /5 entradas/);
});

test('un slug invalido y un nombre vacio se informan por separado', () => {
  const r = validarCajasSugeridas({
    cajas: [caja({ slug: 'Con Mayusculas' }), caja({ slug: 'otra', nombre: '   ' })],
  });
  assert.equal(r.cajas.length, 0);
  assert.equal(r.descartes.length, 2);
});

test('un productoId con barra no pasa: apuntaria a otro documento', () => {
  const r = validarCajasSugeridas({ cajas: [caja({ productoIds: ['a/b', 'c', 'd', 'e', 'f', 'g'] })] });
  assert.equal(r.cajas.length, 0);
  assert.match(r.descartes[0]!.motivo, /productoId invalido/);
});

test('dos cajas con el mismo slug quedan afuera LAS DOS', () => {
  const r = validarCajasSugeridas({ cajas: [caja(), caja({ nombre: 'Otra' })] });
  assert.equal(r.cajas.length, 0);
  assert.equal(r.descartes.filter((d) => /slug duplicado/.test(d.motivo)).length, 2);
});

// ------------------------------------------------------------ la composicion

test('seis productos de una botella suman una caja', () => {
  const botellas = new Map(SEIS.map((id) => [id, 1]));
  const v = verificarComposicion(caja(), botellas);
  assert.equal(v.ok, true);
  assert.equal(v.ok && v.valor, 6);
});

test('un vino que viene en su propia caja NO arma caja, aunque la suma diera seis', () => {
  // Era el caso que probaba lo contrario hasta el 2026-09-15: tres packs de 2
  // "sumaban" una caja. Ya no: cada uno trae su embalaje y viaja solo, asi que
  // la sugerencia dejaria el carrito sin ninguna botella suelta que juntar.
  const botellas = new Map([
    ['p1', 2],
    ['p2', 2],
    ['p3', 2],
  ]);
  const v = verificarComposicion(caja({ productoIds: ['p1', 'p2', 'p3'] }), botellas);
  assert.equal(v.ok, false);
  assert.match(v.ok === false ? v.motivo : '', /propia caja/);
});

test('un solo pack entre cinco sueltas tambien tumba la composicion', () => {
  const botellas = new Map(SEIS.map((id) => [id, id === 'a' ? 2 : 1]));
  const v = verificarComposicion(caja(), botellas);
  assert.equal(v.ok, false);
  assert.match(v.ok === false ? v.motivo : '', /a viene en su propia caja/);
});

test('una sugerencia corta se rechaza con el numero adentro', () => {
  const botellas = new Map([
    ['a', 1],
    ['b', 1],
    ['c', 1],
    ['d', 1],
    ['e', 1],
  ]);
  const v = verificarComposicion(caja({ productoIds: ['a', 'b', 'c', 'd', 'e'] }), botellas);
  assert.equal(v.ok, false);
  assert.match(v.ok === false ? v.motivo : '', /suma 5 botellas/);
});

test('un producto inexistente es un error de composicion', () => {
  const v = verificarComposicion(caja(), new Map([['a', 1]]));
  assert.equal(v.ok, false);
  assert.match(v.ok === false ? v.motivo : '', /no existe/);
});

// -------------------------------------------------------------- el resuelto

test('una caja entera y disponible queda completa', () => {
  const r = resolverCajasSugeridas([caja()], seisProductos());
  assert.equal(r.cajas.length, 1);
  assert.equal(r.cajas[0]!.completa, true);
  assert.equal(r.cajas[0]!.botellasVigentes, 6);
  assert.equal(r.descartes.length, 0);
});

test('un componente despublicado deja la caja con cinco y el lugar marcado', () => {
  const r = resolverCajasSugeridas([caja()], seisProductos().filter((p) => p.id !== 'f'));
  assert.equal(r.cajas.length, 1, 'la sugerencia se muestra igual');
  const caido = r.cajas[0]!.lugares.find((l) => l.productoId === 'f');
  assert.equal(caido?.estado, 'no-disponible');
  assert.equal(caido?.producto, null);
  assert.equal(r.cajas[0]!.botellasVigentes, 5);
  assert.equal(r.cajas[0]!.completa, false);
});

test('un componente agotado se marca y el resto sigue normal', () => {
  const productos = seisProductos().map((p) => (p.id === 'c' ? publicado('c', { balde: 'agotado', tope: 0 }) : p));
  const r = resolverCajasSugeridas([caja()], productos);
  const lugares = r.cajas[0]!.lugares;
  assert.equal(lugares.find((l) => l.productoId === 'c')?.estado, 'agotado');
  assert.equal(lugares.filter((l) => l.estado === 'vigente').length, 5);
  assert.equal(r.cajas[0]!.botellasVigentes, 5);
});

test('con todos los vinos a la vista, una suma equivocada SI se descarta', () => {
  // La caja de cinco entradas no pasa la FORMA, asi que por el camino real no
  // llega hasta aca. Se la construye a mano a proposito: esta guarda es la que
  // cubre a un llamador que no valide -- una callable del panel, manana.
  const cinco = caja({ productoIds: SEIS.slice(0, 5) });
  const r = resolverCajasSugeridas([cinco], seisProductos());
  assert.equal(r.cajas.length, 0);
  assert.match(r.descartes[0]!.motivo, /suma 5 botellas/);
});

test('con un vino faltante NO se juzga la suma: no hay con que juzgarla', () => {
  // Control del test de arriba: la misma caja corta, pero sin poder ver uno.
  const cinco = caja({ productoIds: SEIS.slice(0, 5) });
  const r = resolverCajasSugeridas([cinco], seisProductos().filter((p) => p.id !== 'a'));
  assert.equal(r.cajas.length, 1, 'se muestra, no se descarta');
  assert.equal(r.descartes.length, 0);
});

test('un vino con caja propia se descarta SIN esperar a los otros cinco', () => {
  // No hace falta ver la caja entera para juzgarlo: un vino empacado no arma
  // caja con nadie. Por eso este descarte no depende de que esten todos, y el
  // control es el test de arriba -- con un faltante, la suma no se juzga.
  const productos = seisProductos()
    .map((p) => (p.id === 'a' ? publicado('a', { botellas: 2 }) : p))
    .filter((p) => p.id !== 'f');
  const r = resolverCajasSugeridas([caja()], productos);
  assert.equal(r.cajas.length, 0);
  assert.match(r.descartes[0]!.motivo, /a viene en su propia caja/);
});

test('el join no pierde el orden que cargo el vendedor', () => {
  const r = resolverCajasSugeridas([caja()], seisProductos());
  assert.deepEqual(
    r.cajas[0]!.lugares.map((l) => l.productoId),
    SEIS,
  );
});

test('un id repetido son dos botellas de ese vino', () => {
  const productos = [publicado('a'), publicado('b'), publicado('c'), publicado('d'), publicado('e')];
  const r = resolverCajasSugeridas([caja({ productoIds: ['a', 'a', 'b', 'c', 'd', 'e'] })], productos);
  assert.equal(r.cajas.length, 1);
  assert.equal(r.cajas[0]!.botellasVigentes, 6);
  assert.equal(r.cajas[0]!.completa, true);
});

test('sin cajas no hay nada que resolver', () => {
  const r = resolverCajasSugeridas([], seisProductos());
  assert.deepEqual(r.cajas, []);
  assert.deepEqual(r.descartes, []);
});

// ---------------------------------------------------- llenar el carrito

function carritoCon(lineas: { productoId: string; cantidad: number; botellas?: number }[]) {
  return {
    version: 2 as const,
    idCompra: '3f2b9c1e-7a4d-4e8f-9b21-5c6d7e8f9a0b',
    lineas: lineas.map((l) => ({ productoId: l.productoId, cantidad: l.cantidad, botellas: l.botellas ?? 1 })),
  };
}

const resolverUna = (productos: ProductoPublicado[], c = caja()) =>
  resolverCajasSugeridas([c], productos).cajas[0]!;

test('con el carrito vacio queda la caja completa', () => {
  const c = llenarConLaCaja(carritoCon([]), resolverUna(seisProductos()));
  assert.equal(c.lineas.length, 6);
  assert.equal(botellasEnCarrito(resolverCarrito(c, seisProductos())), 6);
  assert.equal(estadoDeLaCaja(resolverCarrito(c, seisProductos())).faltan, 0);
});

test('con algo adentro AGREGA, no reemplaza', () => {
  const productos = seisProductos();
  const antes = carritoCon([{ productoId: 'a', cantidad: 2 }]);
  const c = llenarConLaCaja(antes, resolverUna(productos));

  assert.equal(c.lineas.find((l) => l.productoId === 'a')?.cantidad, 3, 'lo que habia se suma');
  const e = estadoDeLaCaja(resolverCarrito(c, productos));
  assert.equal(e.botellas, 8);
  assert.equal(e.sobran, 2, 'y el carrito lo dice');
});

test('el tope corta el agregado y la caja queda incompleta', () => {
  // La caja pide DOS del mismo vino y de ese vino queda uno solo. Se agrega
  // uno y la caja queda en 5: el tope mandó sobre la sugerencia.
  const productos = [publicado('a', { tope: 1 }), publicado('b'), publicado('c'), publicado('d'), publicado('e')];
  const dosDeA = caja({ productoIds: ['a', 'a', 'b', 'c', 'd', 'e'] });
  const c = llenarConLaCaja(carritoCon([]), resolverUna(productos, dosDeA));

  assert.equal(c.lineas.find((l) => l.productoId === 'a')?.cantidad, 1, 'no pasó del tope');
  const e = estadoDeLaCaja(resolverCarrito(c, productos));
  assert.equal(e.botellas, 5);
  assert.equal(e.faltan, 1, 'y la caja quedó incompleta');
});

test('lo que YA estaba cuenta para la caja', () => {
  // Control del de arriba: con un tope que no corta, empezar con una botella
  // de la caja no deja nada afuera -- la caja cierra igual en 6.
  const productos = seisProductos();
  const c = llenarConLaCaja(carritoCon([{ productoId: 'a', cantidad: 1 }]), resolverUna(productos));
  const e = estadoDeLaCaja(resolverCarrito(c, productos));
  assert.equal(e.botellas, 7, 'la suya mas las seis de la caja');
  assert.equal(e.sobran, 1);
});

test('los lugares caidos no se agregan', () => {
  const productos = seisProductos().filter((p) => p.id !== 'f');
  const c = llenarConLaCaja(carritoCon([]), resolverUna(productos));
  assert.equal(c.lineas.length, 5);
  assert.equal(c.lineas.some((l) => l.productoId === 'f'), false);
});

test('un id repetido en la caja queda como cantidad 2, no como dos lineas', () => {
  const productos = [publicado('a'), publicado('b'), publicado('c'), publicado('d'), publicado('e')];
  const dosVeces = caja({ productoIds: ['a', 'a', 'b', 'c', 'd', 'e'] });
  const c = llenarConLaCaja(carritoCon([]), resolverUna(productos, dosVeces));
  assert.equal(c.lineas.length, 5);
  assert.equal(c.lineas.find((l) => l.productoId === 'a')?.cantidad, 2);
});

test('elegir una caja armada deja el carrito COBRABLE', () => {
  // Es para lo que existe el carril: la sugerencia cierra la caja de una. Si
  // alguna vez entrara un vino empacado en una caja armada, este test se cae
  // -- sus botellas no cuentan para las seis y el boton no aparece.
  const productos = seisProductos();
  const c = llenarConLaCaja(carritoCon([]), resolverUna(productos));
  const r = resolverCarrito(c, productos);
  assert.equal(botellasSueltas(r), 6);
  assert.equal(sePuedeCobrar(r), true);
  assert.ok(
    c.lineas.every((l) => l.botellas === 1),
    'las botellas de cada linea salen de la proyeccion',
  );
});

// ------------------------- el tope manda TAMBIEN sobre lo que dice la tarjeta

test('la tarjeta no puede decir seis si el tope entrega cinco', () => {
  // Lo encontro revisor-pagos: `llenarConLaCaja` respetaba el tope y
  // `resolverCajasSugeridas` no, asi que la tarjeta decia "6 botellas,
  // completa" y el boton entregaba cinco. Dos cuentas de lo mismo.
  const productos = [publicado('a', { tope: 1 }), publicado('b'), publicado('c'), publicado('d'), publicado('e')];
  const dosDeA = caja({ productoIds: ['a', 'a', 'b', 'c', 'd', 'e'] });
  const r = resolverUna(productos, dosDeA);

  assert.equal(r.botellasVigentes, 5, 'la tarjeta cuenta lo que se puede entregar');
  assert.equal(r.completa, false);

  // Y coincide con lo que realmente entrega el boton.
  const c = llenarConLaCaja(carritoCon([]), r);
  assert.equal(estadoDeLaCaja(resolverCarrito(c, productos)).botellas, r.botellasVigentes);
});

test('un vino de verdad agotado SI dice agotado', () => {
  // Control del de abajo: los dos estados existen y se distinguen.
  const productos = seisProductos().map((p) => (p.id === 'c' ? publicado('c', { balde: 'agotado', tope: 0 }) : p));
  const r = resolverUna(productos);
  assert.equal(r.lugares.find((l) => l.productoId === 'c')?.estado, 'agotado');
});

test('la segunda copia que no entra se marca, no desaparece', () => {
  const productos = [publicado('a', { tope: 1 }), publicado('b'), publicado('c'), publicado('d'), publicado('e')];
  const r = resolverUna(productos, caja({ productoIds: ['a', 'a', 'b', 'c', 'd', 'e'] }));
  const deA = r.lugares.filter((l) => l.productoId === 'a');
  assert.equal(deA.length, 2, 'los dos lugares siguen ahi');
  assert.equal(deA[0]!.estado, 'vigente');
  assert.equal(deA[1]!.estado, 'sin-suficiente', 'del segundo no alcanza');
  assert.notEqual(deA[1]!.estado, 'agotado', 'y NO es agotado: el vino esta a la venta');
});

test('control: con tope suficiente, la caja repetida SI esta completa', () => {
  // Sin este control, el test de arriba pasaria con un resolver que marcara
  // todo como agotado.
  const productos = [publicado('a', { tope: 12 }), publicado('b'), publicado('c'), publicado('d'), publicado('e')];
  const r = resolverUna(productos, caja({ productoIds: ['a', 'a', 'b', 'c', 'd', 'e'] }));
  assert.equal(r.botellasVigentes, 6);
  assert.equal(r.completa, true);
});

test('sin todos los vinos a la vista, la caja NO se declara completa', () => {
  // La suma declarada no se pudo juzgar, asi que "completa" seria una
  // afirmacion sobre una composicion que nunca se valido.
  const productos = seisProductos().filter((p) => p.id !== 'f').concat(publicado('a', { botellas: 2 }));
  const r = resolverUna(productos.filter((p, i, xs) => xs.findIndex((y) => y.id === p.id) === i));
  assert.equal(r.completa, false);
});

// ------------------------------------------------ el pedido del panel (ADR 024)

test('armar: el slug sale del nombre, y el orden es el del pedido', () => {
  const r = armarCajasSugeridas({
    cajas: [
      { nombre: '  Seis tintos de Mendoza ', productoIds: SEIS },
      { nombre: 'Para el asado', productoIds: ['a', 'a', 'a', 'b', 'b', 'b'] },
    ],
  });
  assert.ok(r.ok, r.ok ? '' : r.motivo);
  assert.deepEqual(
    r.valor.map((c) => [c.slug, c.nombre]),
    [
      ['seis-tintos-de-mendoza', 'Seis tintos de Mendoza'],
      ['para-el-asado', 'Para el asado'],
    ],
  );
  // Un id repetido son dos botellas: viaja tal cual.
  assert.deepEqual(r.valor[1]!.productoIds, ['a', 'a', 'a', 'b', 'b', 'b']);
});

test('armar: la lista vacia es valida -- el duenio saco todas', () => {
  const r = armarCajasSugeridas({ cajas: [] });
  assert.ok(r.ok);
  assert.deepEqual(r.valor, []);
});

test('armar: dos nombres que dan el mismo slug se rechazan, no se pierden en la tienda', () => {
  const r = armarCajasSugeridas({
    cajas: [
      { nombre: 'Seis tintos', productoIds: SEIS },
      { nombre: 'SEIS  TINTOS!', productoIds: SEIS },
    ],
  });
  assert.equal(r.ok, false);
  assert.match(r.ok ? '' : r.motivo, /se llaman igual/);
  // Control: con nombres distintos, pasa.
  assert.ok(armarCajasSugeridas({ cajas: [{ nombre: 'Seis tintos', productoIds: SEIS }, { nombre: 'Seis blancos', productoIds: SEIS }] }).ok);
});

test('armar: sin nombre, sin letras o demasiado largo, no', () => {
  for (const nombre of ['', '   ', '!!!', 'x'.repeat(LARGO_DEL_NOMBRE_DE_CAJA + 1), 7]) {
    assert.equal(armarCajasSugeridas({ cajas: [{ nombre, productoIds: SEIS }] }).ok, false, String(nombre));
  }
  // Control: justo el largo maximo entra.
  assert.ok(armarCajasSugeridas({ cajas: [{ nombre: 'x'.repeat(LARGO_DEL_NOMBRE_DE_CAJA), productoIds: SEIS }] }).ok);
});

test('armar: una caja que no tiene seis lugares no se arma', () => {
  assert.equal(armarCajasSugeridas({ cajas: [{ nombre: 'Cinco', productoIds: SEIS.slice(0, 5) }] }).ok, false);
  assert.equal(armarCajasSugeridas({ cajas: [{ nombre: 'Siete', productoIds: [...SEIS, 'g'] }] }).ok, false);
  assert.equal(armarCajasSugeridas({ cajas: [{ nombre: 'Rota', productoIds: ['a', 'b', 'c', 'd', 'e', ''] }] }).ok, false);
});

test(`armar: mas de ${TOPE_DE_CAJAS_SUGERIDAS} cajas, no; justo el tope, si`, () => {
  const cajas = (n: number) =>
    Array.from({ length: n }, (_, i) => ({ nombre: `Caja ${i + 1}`, productoIds: SEIS }));
  assert.equal(armarCajasSugeridas({ cajas: cajas(TOPE_DE_CAJAS_SUGERIDAS + 1) }).ok, false);
  assert.ok(armarCajasSugeridas({ cajas: cajas(TOPE_DE_CAJAS_SUGERIDAS) }).ok);
});

test('armar: lo que no es un pedido, no', () => {
  for (const entrada of [undefined, null, 'cajas', [], { cajas: 'x' }, { cajas: [null] }]) {
    assert.equal(armarCajasSugeridas(entrada).ok, false, JSON.stringify(entrada));
  }
});

test('armar da lo que validarCajasSugeridas acepta sin descartes: el pedido y el documento dicen lo mismo', () => {
  const r = armarCajasSugeridas({ cajas: [{ nombre: 'Seis tintos', productoIds: SEIS }] });
  assert.ok(r.ok);
  const leido = validarCajasSugeridas({ cajas: r.valor });
  assert.equal(leido.descartes.length, 0);
  assert.deepEqual(leido.cajas, r.valor);
});
