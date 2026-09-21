import { test } from 'node:test';
import assert from 'node:assert/strict';

import {
  DESCRIPCION_MAXIMA,
  VARIETALES,
  armarCatalogo,
  balde,
  esCorte,
  textoDelBalde,
  tope,
  validarProducto,
  viajaSolo,
  type DocumentoCrudo,
} from '../src/producto.ts';

// Un documento valido de `productos`, con la forma que deja el seed. Cada test
// rompe UNA cosa, asi el control positivo es el mismo documento sin romper.
function vino(id: string, cambios: Record<string, unknown> = {}, ficha: Record<string, unknown> = {}): DocumentoCrudo {
  return {
    id,
    datos: {
      tipo: 'simple',
      slug: id,
      nombre: `Vino ${id}`,
      precio: 1990000,
      stock: 20,
      presentacion: { botellas: 1 },
      imagenes: ['https://firebasestorage.googleapis.com/v0/b/bouquet-vinos/o/x.webp?alt=media'],
      publicado: true,
      fichaVino: {
        bodegaId: 'rutini',
        varietales: ['Malbec'],
        color: 'tinto',
        organico: false,
        anada: 2023,
        region: 'Mendoza',
        volumenMl: 750,
        ...ficha,
      },
      ...cambios,
    },
  };
}

function sinCampo(doc: DocumentoCrudo, campo: string): DocumentoCrudo {
  const datos = { ...(doc.datos as Record<string, unknown>) };
  delete datos[campo];
  return { id: doc.id, datos };
}

const BODEGAS: DocumentoCrudo[] = [{ id: 'rutini', datos: { nombre: 'Rutini Wines', slug: 'rutini' } }];

const ids = (docs: DocumentoCrudo[], popularidad?: unknown) =>
  armarCatalogo(docs, BODEGAS, popularidad).catalogo.productos.map((p) => p.id);

// ------------------------------------------------------------------ corte

test('un solo varietal es cepa; dos o mas, corte', () => {
  assert.equal(esCorte(['Malbec']), false);
  assert.equal(esCorte(['Malbec', 'Cabernet Sauvignon']), true);

  const { catalogo } = armarCatalogo(
    [vino('cepa'), vino('corte', {}, { varietales: ['Malbec', 'Cabernet Sauvignon'] })],
    BODEGAS,
    undefined,
  );
  const porId = new Map(catalogo.productos.map((p) => [p.id, p]));
  assert.equal(porId.get('corte')?.esCorte, true, 'la proyeccion lo marca como corte');
  assert.equal(porId.get('cepa')?.esCorte, false);
});

// ------------------------------------------------------------- viaja solo

test('mas de una botella es una caja, y una caja viaja sola', () => {
  // De este predicado cuelgan las tres decisiones de ADR 009 §10: qué cuenta
  // para la caja de seis, qué viaja en su propio bulto y qué puede armar una
  // caja sugerida. Se deriva de `presentacion`, que es inmutable por regla.
  assert.equal(viajaSolo({ botellas: 2 }), true);
  assert.equal(viajaSolo({ botellas: 6 }), true);
  assert.equal(viajaSolo({ botellas: 1 }), false, 'la botella suelta necesita la caja de seis');
});

test('se lee igual de la proyeccion que del documento', () => {
  // La proyeccion aplana `presentacion.botellas` a `botellas`; el documento no.
  // Por eso toma `{ botellas }` y no un Producto entero.
  const documento = { presentacion: { botellas: 2 } };
  const proyectado = { botellas: 2 };
  assert.equal(viajaSolo(documento.presentacion), viajaSolo(proyectado));
});

// ------------------------------------------------------------------ balde

test('el balde se mide en botellas: tres cajas de 2 ya son pocas', () => {
  assert.equal(balde({ stock: 3, presentacion: { botellas: 2 } }), 'quedan-pocas', '3 cajas = 6 botellas');
  // Control: la misma caja con una unidad mas son 8 botellas, y ya no es poco.
  assert.equal(balde({ stock: 4, presentacion: { botellas: 2 } }), 'disponible');
  assert.equal(balde({ stock: 6, presentacion: { botellas: 1 } }), 'quedan-pocas', 'el umbral es inclusivo');
  assert.equal(balde({ stock: 7, presentacion: { botellas: 1 } }), 'disponible');
});

test('sin stock es agotado, y con una unidad no', () => {
  assert.equal(balde({ stock: 0, presentacion: { botellas: 1 } }), 'agotado');
  assert.equal(balde({ stock: -2, presentacion: { botellas: 1 } }), 'agotado', 'un negativo por error de datos');
  assert.equal(balde({ stock: 1, presentacion: { botellas: 1 } }), 'quedan-pocas');
});

test('el balde tiene un texto por estado, y disponible no dice nada', () => {
  assert.equal(textoDelBalde('disponible'), null);
  assert.equal(textoDelBalde('quedan-pocas'), 'Quedan pocas');
  assert.equal(textoDelBalde('agotado'), 'Se agotó');
});

// ------------------------------------------------------------------- tope

test('el tope es max(0, min(stock, 12))', () => {
  assert.equal(tope({ stock: 48 }), 12, 'stock alto');
  assert.equal(tope({ stock: 12 }), 12);
  assert.equal(tope({ stock: 5 }), 5, 'debajo de 12 el tope es el stock');
  assert.equal(tope({ stock: 0 }), 0);
  assert.equal(tope({ stock: -2 }), 0, 'un negativo por error de datos no da un tope negativo');
});

// ------------------------------------------------------------- proyeccion

test('un documento roto no tira el catalogo: queda afuera y en los descartes', () => {
  const { catalogo, descartes } = armarCatalogo([vino('a'), sinCampo(vino('b'), 'precio')], BODEGAS, undefined);
  assert.deepEqual(
    catalogo.productos.map((p) => p.id),
    ['a'],
  );
  assert.equal(descartes.length, 1);
  assert.equal(descartes[0]?.id, 'b');
  assert.match(descartes[0]?.motivo ?? '', /precio/);

  // Control: el mismo documento con precio entra.
  assert.deepEqual(ids([vino('a'), vino('b')]), ['a', 'b']);
});

test('dos productos con el mismo slug quedan afuera los dos', () => {
  const { catalogo, descartes } = armarCatalogo(
    [vino('a', { slug: 'mismo' }), vino('b', { slug: 'mismo' }), vino('c')],
    BODEGAS,
    undefined,
  );
  assert.deepEqual(
    catalogo.productos.map((p) => p.id),
    ['c'],
  );
  assert.equal(descartes.filter((d) => /duplicado/.test(d.motivo)).length, 2);
});

test('la proyeccion no lleva el stock ni las unidades', () => {
  const { catalogo } = armarCatalogo([vino('a', { stock: 5 })], BODEGAS, { unidades: { a: 30 } });
  const p = catalogo.productos[0];
  assert.ok(p);
  const claves = Object.keys(p);
  for (const prohibida of ['stock', 'unidades', 'muestra', 'publicado', 'tipo']) {
    assert.ok(!claves.includes(prohibida), `la proyeccion no puede llevar ${prohibida}`);
  }
  // Control: lo que si tiene que llegar.
  assert.equal(p.balde, 'quedan-pocas');
  assert.equal(p.tope, 5);
  assert.equal(p.puesto, 1);
  assert.equal(p.bodega, 'Rutini Wines');
});

test('la caja de 2 lleva el precio de la caja y dice cuantas botellas trae', () => {
  const { catalogo } = armarCatalogo(
    [vino('caja', { presentacion: { botellas: 2 }, precio: 7600000, stock: 3 })],
    BODEGAS,
    undefined,
  );
  const p = catalogo.productos[0];
  assert.equal(p?.botellas, 2);
  assert.equal(p?.precio, 7600000);
  assert.equal(p?.balde, 'quedan-pocas');
  assert.equal(p?.tope, 3);
});

test('un varietal fuera de la lista cerrada deja el producto afuera', () => {
  assert.deepEqual(ids([vino('a', {}, { varietales: ['Cab. Sauv.'] })]), []);
  // Controles: la forma canonica entra, y la tilde de la lista tambien.
  assert.deepEqual(ids([vino('a', {}, { varietales: ['Cabernet Sauvignon'] })]), ['a']);
  assert.deepEqual(ids([vino('a', {}, { varietales: ['Torrontés'], color: 'blanco' })]), ['a']);
});

test('la lista de varietales no repite ninguno', () => {
  assert.equal(new Set(VARIETALES).size, VARIETALES.length);
});

test('un compuesto no entra a la vidriera todavia', () => {
  const compuesto = sinCampo(vino('mixta', { tipo: 'compuesto' }), 'stock');
  const { catalogo, descartes } = armarCatalogo([compuesto, vino('a')], BODEGAS, undefined);
  assert.deepEqual(
    catalogo.productos.map((p) => p.id),
    ['a'],
  );
  assert.match(descartes[0]?.motivo ?? '', /compuesto/);

  // Y un compuesto CON stock es un documento mal cargado, no un simple.
  const conStock = armarCatalogo([vino('mixta', { tipo: 'compuesto' })], BODEGAS, undefined);
  assert.match(conStock.descartes[0]?.motivo ?? '', /stock propio/);
});

test('sin tipo explicito, el producto queda afuera', () => {
  assert.deepEqual(ids([sinCampo(vino('a'), 'tipo')]), []);
});

test('una bodega que no existe deja el producto afuera', () => {
  assert.deepEqual(ids([vino('a', {}, { bodegaId: 'nadie' })]), []);
});

test('lo no publicado no entra aunque llegue', () => {
  assert.deepEqual(ids([vino('a', { publicado: false })]), []);
});

// ------------------------------------------------------------ popularidad

test('sin metricas no hay popularidad ni puestos', () => {
  for (const popularidad of [undefined, null, { unidades: {} }, { unidades: { a: 0 } }]) {
    const { catalogo } = armarCatalogo([vino('a'), vino('b')], BODEGAS, popularidad);
    assert.equal(catalogo.hayPopularidad, false, JSON.stringify(popularidad));
    assert.ok(catalogo.productos.every((p) => p.puesto === null));
  }
});

test('el puesto 1 es el mas vendido, y el empate se resuelve por id', () => {
  const { catalogo } = armarCatalogo([vino('a'), vino('b'), vino('c')], BODEGAS, {
    unidades: { a: 5, b: 9, c: 5 },
  });
  assert.equal(catalogo.hayPopularidad, true);
  const puesto = Object.fromEntries(catalogo.productos.map((p) => [p.id, p.puesto]));
  assert.deepEqual(puesto, { a: 2, b: 1, c: 3 });
});

test('unas metricas rotas cuentan como ninguna, y se informan', () => {
  const { catalogo, descartes } = armarCatalogo([vino('a')], BODEGAS, { unidades: { a: -1 } });
  assert.equal(catalogo.hayPopularidad, false);
  assert.equal(descartes[0]?.id, 'metricas/popularidad');
});

// --------------------------------------------------------------- muestra

test('deMuestra delata los datos de prueba, y sin ellos no aparece', () => {
  assert.equal(armarCatalogo([vino('a', { muestra: true }), vino('b')], BODEGAS, undefined).catalogo.deMuestra, true);
  assert.equal(armarCatalogo([vino('a'), vino('b')], BODEGAS, undefined).catalogo.deMuestra, false);
});

// ------------------------------------------------------------- graduacion

test('la graduacion va en decimas enteras, y puede faltar', () => {
  // Control positivo: el mismo documento, con y sin el campo, valida.
  const con = validarProducto('con', vino('con', {}, { graduacion: 135 }).datos);
  assert.ok(con.ok, 'con 135 (13,5 %) valida');
  assert.equal(con.ok && con.valor.fichaVino.graduacion, 135);

  const sin = validarProducto('sin', vino('sin').datos);
  assert.ok(sin.ok, 'un vino anterior, sin el campo, sigue validando');
  assert.equal(sin.ok && sin.valor.fichaVino.graduacion, null);

  assert.ok(validarProducto('nulo', vino('nulo', {}, { graduacion: null }).datos).ok, 'null es "no se cargo"');
  assert.ok(validarProducto('piso', vino('piso', {}, { graduacion: 50 }).datos).ok, 'el piso entra');
  assert.ok(validarProducto('techo', vino('techo', {}, { graduacion: 250 }).datos).ok, 'el techo entra');
});

test('cada confusion de unidad rebota', () => {
  // El piso en 50 no describe a los vinos: atrapa el `14` escrito pensando en
  // 14 %, que valdria 1,4 %. ADR 013.
  const rechazos: [string, unknown][] = [
    ['14 pensando en 14 %', 14],
    ['13.5 pensando en 13,5 %', 13.5],
    ['1350, un cero de mas', 1350],
    ['un texto', '13,5'],
    ['justo abajo del piso', 49],
    ['justo arriba del techo', 251],
  ];
  for (const [caso, graduacion] of rechazos) {
    const v = validarProducto('x', vino('x', {}, { graduacion }).datos);
    assert.equal(v.ok, false, caso);
    assert.match(!v.ok ? v.motivo : '', /graduacion/, `${caso}: el motivo nombra el campo`);
  }
});

test('un vino con graduacion entra al catalogo, y la proyeccion no la lleva todavia', () => {
  const { catalogo } = armarCatalogo([vino('grad', {}, { graduacion: 140 })], BODEGAS, undefined);
  assert.deepEqual(catalogo.productos.map((p) => p.id), ['grad']);
  assert.equal('graduacion' in catalogo.productos[0]!, false, 'la vidriera no la muestra en este cambio');
});

// ------------------------------------------------------------ descripcion

test('la descripcion es opcional, y ausente es lo mismo que null', () => {
  // Control positivo: el MISMO documento con el campo valida, asi que un
  // rechazo de abajo es del contenido y no de que el campo exista.
  const con = validarProducto('con', vino('con', {}, { descripcion: 'Un Malbec de altura.' }).datos);
  assert.ok(con.ok, 'con texto valida');
  assert.equal(con.ok && con.valor.fichaVino.descripcion, 'Un Malbec de altura.');

  const sin = validarProducto('sin', vino('sin').datos);
  assert.ok(sin.ok, 'un vino anterior, sin el campo, sigue validando');
  assert.equal(sin.ok && sin.valor.fichaVino.descripcion, null);

  const nulo = validarProducto('nulo', vino('nulo', {}, { descripcion: null }).datos);
  assert.ok(nulo.ok, 'null es "no se cargo"');
  assert.equal(nulo.ok && nulo.valor.fichaVino.descripcion, null);
});

test('la descripcion se guarda recortada, y en blanco NO es "sin descripcion"', () => {
  const v = validarProducto('x', vino('x', {}, { descripcion: '  con espacios al borde  ' }).datos);
  assert.ok(v.ok);
  assert.equal(v.ok && v.valor.fichaVino.descripcion, 'con espacios al borde');

  // Dos maneras de decir nada serian dos maneras de leer nada: para eso esta
  // null. Y un vino descartado por esto NO aparece en la vidriera.
  for (const [caso, descripcion] of [
    ['cadena vacia', ''],
    ['solo espacios', '   '],
    ['solo saltos de linea', String.fromCharCode(10, 10)],
  ] as [string, unknown][]) {
    const r = validarProducto('x', vino('x', {}, { descripcion }).datos);
    assert.equal(r.ok, false, caso);
    assert.match(!r.ok ? r.motivo : '', /descripcion/, `${caso}: el motivo nombra el campo`);
  }
});

test('el tope de la descripcion es exacto: el ultimo caracter entra y el siguiente no', () => {
  // El numero va ESCRITO, no leido de la constante: un test que arma el caso
  // con `DESCRIPCION_MAXIMA` se mide contra si mismo y pasaria con el tope en
  // 5. Y 600 vive tres veces -aca, en firestore.rules y en el panel-, asi que
  // `auditar_varietales.mjs` compara las tres.
  assert.equal(DESCRIPCION_MAXIMA, 600, 'si esto cambia, cambialo tambien en firestore.rules y en el panel');

  const justo = 'a'.repeat(DESCRIPCION_MAXIMA);
  assert.ok(validarProducto('justo', vino('justo', {}, { descripcion: justo }).datos).ok,
    `${DESCRIPCION_MAXIMA} caracteres entran`);

  const unoMas = validarProducto('mas', vino('mas', {}, { descripcion: 'a'.repeat(DESCRIPCION_MAXIMA + 1) }).datos);
  assert.equal(unoMas.ok, false, `${DESCRIPCION_MAXIMA + 1} no entran`);
  assert.match(!unoMas.ok ? unoMas.motivo : '', /descripcion/);
});

test('la descripcion tiene que ser texto', () => {
  for (const descripcion of [123, true, ['un', 'array'], { un: 'mapa' }]) {
    const r = validarProducto('x', vino('x', {}, { descripcion }).datos);
    assert.equal(r.ok, false, `${JSON.stringify(descripcion)} no es un texto`);
  }
});

// --------------------------------------- publicado con precio 0 (hallazgo 2)

test('un publicado con precio 0 NO valida, y sin publicar si', () => {
  // La vidriera lee con el Admin SDK, que no pasa por firestore.rules: esta
  // funcion es la ULTIMA puerta antes del comprador, no la regla. Sin esto,
  // un seed o una reposicion escriben un vino en $ 0,00 y se publica.
  const publicado = validarProducto('x', vino('x', { publicado: true, precio: 0 }).datos);
  assert.equal(publicado.ok, false, 'publicado en 0 rebota');
  assert.match(!publicado.ok ? publicado.motivo : '', /precio/);

  // Control positivo: el MISMO documento con precio valida, asi que el
  // rechazo es por el precio y no por otra cosa del documento.
  assert.ok(validarProducto('x', vino('x', { publicado: true, precio: 1 }).datos).ok, 'publicado en 1 valida');
  assert.ok(validarProducto('x', vino('x', { publicado: false, precio: 0 }).datos).ok, 'un borrador en 0 valida');
});

test('un publicado con precio 0 se cae del catalogo, con su motivo', () => {
  const { catalogo, descartes } = armarCatalogo(
    [vino('bueno'), vino('roto', { publicado: true, precio: 0 })],
    BODEGAS,
    undefined,
  );
  // Control positivo: el otro vino SI entra. Sin este caso, un armarCatalogo
  // que descarta todo pasaria el assert de abajo.
  assert.deepEqual(catalogo.productos.map((p) => p.id), ['bueno']);
  assert.equal(descartes.length, 1);
  const descarte = descartes[0]!;
  assert.equal(descarte.id, 'roto');
  assert.match(descarte.motivo, /precio/);
});
