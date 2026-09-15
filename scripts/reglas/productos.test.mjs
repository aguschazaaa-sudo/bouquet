// productos.test.mjs - las reglas de productos, bodegas, metricas y cajas
// sugeridas contra el emulador.  ADR 008, specs/catalogo-producto;
// openspec/changes/cajas-de-seis/specs/cajas-sugeridas.
//
// Corre con:
//   firebase emulators:exec --only firestore --project demo-bouquet \
//     "node --test scripts/reglas/productos.test.mjs"
//
// `demo-bouquet` a proposito: un projectId con prefijo demo- no puede tocar
// ningun proyecto real, aunque la configuracion activa de gcloud apunte a otro
// (hoy apunta a red-social-ryb3mf, medido).
//
// Cada requisito tiene un caso ACEPTADO y uno RECHAZADO.  Sin el aceptado, una
// regla que niega todo pasaria todos los rechazos: el control positivo es lo
// que distingue "la regla funciona" de "la regla no deja escribir nada".

import { after, before, beforeEach, describe, test } from 'node:test';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { deleteField, doc, getDoc, setDoc, updateDoc } from 'firebase/firestore';

const RAIZ = join(dirname(fileURLToPath(import.meta.url)), '..', '..');

let entorno;
let admin;
let comprador;
let anonimo;

function vino(cambios = {}, ficha = {}) {
  return {
    tipo: 'simple',
    slug: 'trumpeter-malbec',
    nombre: 'Trumpeter Malbec',
    precio: 1990000,
    stock: 0,
    presentacion: { botellas: 1 },
    imagenes: [],
    publicado: true,
    fichaVino: {
      bodegaId: 'rutini',
      varietales: ['Malbec'],
      color: 'tinto',
      organico: false,
      anada: 2023,
      region: 'Tupungato, Mendoza',
      volumenMl: 750,
      ...ficha,
    },
    ...cambios,
  };
}

function sin(obj, campo) {
  const copia = { ...obj };
  delete copia[campo];
  return copia;
}

const producto = (db, id = 'a') => doc(db, 'productos', id);

/** Lo que deja el servidor: el Admin SDK no pasa por las reglas. */
async function sembrar(ruta, datos) {
  await entorno.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), ruta), datos);
  });
}

before(async () => {
  entorno = await initializeTestEnvironment({
    projectId: 'demo-bouquet',
    firestore: {
      rules: readFileSync(join(RAIZ, 'firestore.rules'), 'utf8'),
      host: '127.0.0.1',
      port: 8080,
    },
  });
  admin = entorno.authenticatedContext('operador', { rol: 'admin' }).firestore();
  comprador = entorno.authenticatedContext('comprador').firestore();
  anonimo = entorno.unauthenticatedContext().firestore();
});

beforeEach(async () => {
  await entorno.clearFirestore();
});

after(async () => {
  await entorno?.cleanup();
});

// ------------------------------------------------------------------ tipo

// ⚠️ La regla de `tipo` inmutable NUNCA es la unica razon de un rechazo:
// cambiar de tipo obliga a agregar o sacar `stock`, y eso ya lo prohibe la regla
// del stock. Es defensa en profundidad. revisor-pagos lo midio: sin esa linea
// de las reglas, estos casos siguen en verde. Se dejan porque prueban el
// requisito, no la linea.
describe('el tipo es explicito e inmutable', () => {
  test('alta sin tipo: rechazada; con tipo: aceptada', async () => {
    await assertFails(setDoc(producto(admin), sin(vino(), 'tipo')));
    await assertSucceeds(setDoc(producto(admin), vino()));
  });

  test('de simple a compuesto: rechazado; editar el nombre: aceptado', async () => {
    await sembrar('productos/a', vino({ stock: 10 }));
    await assertFails(updateDoc(producto(admin), { tipo: 'compuesto', stock: deleteField() }));
    await assertSucceeds(updateDoc(producto(admin), { nombre: 'Trumpeter Malbec 2023' }));
  });

  test('de compuesto a simple: rechazado', async () => {
    await sembrar('productos/a', sin(vino({ tipo: 'compuesto' }), 'stock'));
    await assertFails(updateDoc(producto(admin), { tipo: 'simple' }));
  });
});

// ----------------------------------------------------------------- stock

describe('el stock lo escribe solo el servidor', () => {
  test('el panel sobrescribe el stock: rechazado; edita el precio sin tocarlo: aceptado', async () => {
    await sembrar('productos/a', vino({ stock: 10 }));
    await assertFails(updateDoc(producto(admin), { stock: 50 }));
    await assertFails(updateDoc(producto(admin), { stock: deleteField() }));
    await assertSucceeds(updateDoc(producto(admin), { precio: 2100000 }));
  });

  test('alta de un simple con stock 5: rechazada; con 0: aceptada', async () => {
    await assertFails(setDoc(producto(admin), vino({ stock: 5 })));
    await assertSucceeds(setDoc(producto(admin), vino({ stock: 0 })));
  });

  test('un simple sin stock: rechazado', async () => {
    await assertFails(setDoc(producto(admin), sin(vino(), 'stock')));
  });

  test('un compuesto con stock: rechazado; sin stock: aceptado', async () => {
    await assertFails(setDoc(producto(admin), vino({ tipo: 'compuesto' })));
    await assertSucceeds(setDoc(producto(admin), sin(vino({ tipo: 'compuesto' }), 'stock')));
  });

  test('muestra: el panel no la escribe, pero puede editar un vino de muestra', async () => {
    await assertFails(setDoc(producto(admin), vino({ muestra: true })));
    await sembrar('productos/b', vino({ stock: 10, muestra: true }));
    await assertSucceeds(updateDoc(producto(admin, 'b'), { precio: 2100000 }));
    await assertFails(updateDoc(producto(admin, 'b'), { muestra: false }));
    await assertFails(updateDoc(producto(admin, 'b'), { muestra: deleteField() }));
  });
});

// ----------------------------------------------------------- presentacion

describe('la presentacion es inmutable', () => {
  test('una botella suelta pasa a caja de 2: rechazado', async () => {
    await sembrar('productos/a', vino({ stock: 10 }));
    await assertFails(updateDoc(producto(admin), { 'presentacion.botellas': 2 }));
    await assertFails(updateDoc(producto(admin), { presentacion: { botellas: 1, caja: true } }));
    // Control: reescribir el mismo valor no es cambiarlo.
    await assertSucceeds(updateDoc(producto(admin), { presentacion: { botellas: 1 } }));
  });

  test('una caja de 2 nace como tal: aceptada', async () => {
    await assertSucceeds(setDoc(producto(admin), vino({ presentacion: { botellas: 2 } })));
    await assertFails(setDoc(producto(admin, 'b'), vino({ presentacion: { botellas: 0 } })));
  });
});

// ------------------------------------------------------------ obligatorios

describe('los campos obligatorios no se pueden borrar', () => {
  test('un update que borra el precio: rechazado; que lo cambia: aceptado', async () => {
    await sembrar('productos/a', vino({ stock: 10 }));
    await assertFails(updateDoc(producto(admin), { precio: deleteField() }));
    await assertSucceeds(updateDoc(producto(admin), { precio: 1800000 }));
  });

  test('borrar publicado, imagenes, nombre, color u organico: rechazado', async () => {
    await sembrar('productos/a', vino({ stock: 10 }));
    for (const campo of ['publicado', 'imagenes', 'nombre', 'fichaVino.color', 'fichaVino.organico']) {
      await assertFails(updateDoc(producto(admin), { [campo]: deleteField() }), campo);
    }
  });

  test('un campo desconocido: rechazado, tambien adentro de fichaVino', async () => {
    await assertFails(setDoc(producto(admin), vino({ descuento: 10 })));
    await assertFails(setDoc(producto(admin), vino({}, { puntaje: 92 })));
    await assertSucceeds(setDoc(producto(admin), vino()));
  });

  test('precio con decimales o como texto: rechazado', async () => {
    await assertFails(setDoc(producto(admin), vino({ precio: 1990000.5 })));
    await assertFails(setDoc(producto(admin), vino({ precio: '1990000' })));
    await assertFails(setDoc(producto(admin), vino({ precio: -1 })));
  });

  test('un color fuera de la lista o un slug con mayusculas: rechazado', async () => {
    await assertFails(setDoc(producto(admin), vino({}, { color: 'naranjo' })));
    await assertFails(setDoc(producto(admin), vino({ slug: 'Trumpeter Malbec' })));
  });
});

// ------------------------------------------------------------ varietales

describe('los varietales salen de una lista cerrada', () => {
  test('"Cab. Sauv.": rechazado; "Cabernet Sauvignon": aceptado', async () => {
    await assertFails(setDoc(producto(admin), vino({}, { varietales: ['Cab. Sauv.'] })));
    await assertSucceeds(setDoc(producto(admin), vino({}, { varietales: ['Cabernet Sauvignon'] })));
  });

  test('Torrontés, con tilde: aceptado', async () => {
    // Control de codificacion: si el archivo de reglas perdiera la tilde, este
    // es el caso que lo delata.
    await assertSucceeds(setDoc(producto(admin), vino({}, { varietales: ['Torrontés'], color: 'blanco' })));
    await assertFails(setDoc(producto(admin, 'b'), vino({}, { varietales: ['Torrontes'], color: 'blanco' })));
  });

  test('una lista vacia o con una uva repetida: rechazada; un corte: aceptado', async () => {
    await assertFails(setDoc(producto(admin), vino({}, { varietales: [] })));
    await assertFails(setDoc(producto(admin), vino({}, { varietales: ['Malbec', 'Malbec'] })));
    await assertSucceeds(setDoc(producto(admin), vino({}, { varietales: ['Malbec', 'Cabernet Sauvignon'] })));
  });
});

// ------------------------------------------------------------------ quien

describe('quien lee y quien escribe productos', () => {
  test('un comprador o un anonimo no escriben; el admin si', async () => {
    await assertFails(setDoc(producto(comprador), vino()));
    await assertFails(setDoc(producto(anonimo), vino()));
    await assertSucceeds(setDoc(producto(admin), vino()));
  });

  test('desde el navegador solo lee el admin', async () => {
    await sembrar('productos/a', vino({ stock: 10 }));
    await assertFails(getDoc(producto(anonimo)));
    await assertFails(getDoc(producto(comprador)));
    await assertSucceeds(getDoc(producto(admin)));
  });
});

// --------------------------------------------------------------- metricas

describe('la popularidad es un documento del servidor', () => {
  const popularidad = { simulada: true, calculadaEn: new Date(), unidades: { a: 10 } };

  test('un cliente no la escribe, ni siendo admin', async () => {
    await assertFails(setDoc(doc(admin, 'metricas', 'popularidad'), popularidad));
    await assertFails(setDoc(doc(anonimo, 'metricas', 'popularidad'), popularidad));
  });

  test('el admin la lee; un comprador no', async () => {
    await sembrar('metricas/popularidad', popularidad);
    await assertSucceeds(getDoc(doc(admin, 'metricas', 'popularidad')));
    await assertFails(getDoc(doc(comprador, 'metricas', 'popularidad')));
  });
});

// ---------------------------------------------------------------- bodegas

describe('bodegas: la forma cerrada', () => {
  const bodega = (db, id = 'rutini') => doc(db, 'bodegas', id);

  test('alta con nombre y slug: aceptada; con un campo de mas: rechazada', async () => {
    await assertSucceeds(setDoc(bodega(admin), { nombre: 'Rutini Wines', slug: 'rutini' }));
    await assertFails(setDoc(bodega(admin, 'otra'), { nombre: 'Otra', slug: 'otra', web: 'x' }));
  });

  test('muestra es del servidor tambien aca', async () => {
    await assertFails(setDoc(bodega(admin), { nombre: 'Rutini Wines', slug: 'rutini', muestra: true }));
    await sembrar('bodegas/rutini', { nombre: 'Rutini Wines', slug: 'rutini', muestra: true });
    await assertSucceeds(updateDoc(bodega(admin), { nombre: 'Rutini' }));
    await assertFails(updateDoc(bodega(admin), { muestra: false }));
  });
});

// -------------------------------------------------------- cajas sugeridas

describe('las cajas sugeridas son un documento del servidor', () => {
  const cajas = {
    cajas: [
      { slug: 'variada', nombre: 'Caja variada', productoIds: ['a', 'b', 'c', 'd', 'e', 'f'] },
    ],
  };

  test('nadie las escribe desde el navegador, ni siendo admin', async () => {
    await assertFails(setDoc(doc(admin, 'cajasSugeridas', 'publicas'), cajas));
    await assertFails(setDoc(doc(anonimo, 'cajasSugeridas', 'publicas'), cajas));
    await assertFails(setDoc(doc(comprador, 'cajasSugeridas', 'publicas'), cajas));
  });

  test('el admin las lee; el anonimo y el comprador no', async () => {
    await sembrar('cajasSugeridas/publicas', cajas);
    // Control positivo: sin este, una regla que niega TODO pasaria los dos
    // rechazos de abajo y el test seria teatro.
    await assertSucceeds(getDoc(doc(admin, 'cajasSugeridas', 'publicas')));
    await assertFails(getDoc(doc(anonimo, 'cajasSugeridas', 'publicas')));
    await assertFails(getDoc(doc(comprador, 'cajasSugeridas', 'publicas')));
  });
});
