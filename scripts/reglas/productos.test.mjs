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
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { arrayRemove, arrayUnion, collection, collectionGroup, deleteDoc, deleteField, doc, getDoc, getDocs, limit, orderBy, query, setDoc, updateDoc, writeBatch } from 'firebase/firestore';

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

// El slug de `vino()`, y por lo tanto el id de su documento: desde ADR 013 las
// reglas exigen `slug == productoId` al crear.
const SLUG = 'trumpeter-malbec';

const producto = (db, id = SLUG) => doc(db, 'productos', id);

/**
 * Un alta en `productos/{slug}`. TODA alta de esta suite pasa por aca: con el
 * id distinto del slug, un `assertFails` pasaria por el slug y no por lo que
 * el caso dice probar. Es el control positivo al reves: un rechazo por el
 * motivo equivocado confirma cualquier cosa.
 */
const alta = (db, datos) => setDoc(producto(db, datos.slug), datos);

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
    await assertFails(alta(admin, sin(vino(), 'tipo')));
    await assertSucceeds(alta(admin, vino()));
  });

  test('de simple a compuesto: rechazado; editar el nombre: aceptado', async () => {
    await sembrar(`productos/${SLUG}`, vino({ stock: 10 }));
    await assertFails(updateDoc(producto(admin), { tipo: 'compuesto', stock: deleteField() }));
    await assertSucceeds(updateDoc(producto(admin), { nombre: 'Trumpeter Malbec 2023' }));
  });

  test('de compuesto a simple: rechazado', async () => {
    await sembrar(`productos/${SLUG}`, sin(vino({ tipo: 'compuesto' }), 'stock'));
    await assertFails(updateDoc(producto(admin), { tipo: 'simple' }));
  });
});

// ----------------------------------------------------------------- stock

describe('el stock lo escribe solo el servidor', () => {
  test('el panel sobrescribe el stock: rechazado; edita el precio sin tocarlo: aceptado', async () => {
    await sembrar(`productos/${SLUG}`, vino({ stock: 10 }));
    await assertFails(updateDoc(producto(admin), { stock: 50 }));
    await assertFails(updateDoc(producto(admin), { stock: deleteField() }));
    await assertSucceeds(updateDoc(producto(admin), { precio: 2100000 }));
  });

  test('alta de un simple con stock 5: rechazada; con 0: aceptada', async () => {
    await assertFails(alta(admin, vino({ stock: 5 })));
    await assertSucceeds(alta(admin, vino({ stock: 0 })));
  });

  test('un simple sin stock: rechazado', async () => {
    await assertFails(alta(admin, sin(vino(), 'stock')));
  });

  test('un compuesto con stock: rechazado; sin stock: aceptado', async () => {
    await assertFails(alta(admin, vino({ tipo: 'compuesto' })));
    await assertSucceeds(alta(admin, sin(vino({ tipo: 'compuesto' }), 'stock')));
  });

  test('muestra: el panel no la escribe, pero puede editar un vino de muestra', async () => {
    await assertFails(alta(admin, vino({ muestra: true })));
    await sembrar('productos/muestra-trumpeter-malbec', vino({ stock: 10, muestra: true }));
    const deMuestra = producto(admin, 'muestra-trumpeter-malbec');
    await assertSucceeds(updateDoc(deMuestra, { precio: 2100000 }));
    await assertFails(updateDoc(deMuestra, { muestra: false }));
    await assertFails(updateDoc(deMuestra, { muestra: deleteField() }));
  });
});

// ------------------------------------------------------------ movimientos

// El marcador de `moverStock` (EP-05, ADR 016).  Lo escribe el servidor con
// el Admin SDK, que no pasa por las reglas: se simula con `sembrar`.
describe('los movimientos de stock: el panel los lee, el servidor los escribe', () => {
  const movimiento = (db, id = 'mov-0000000000000001') => doc(db, 'productos', SLUG, 'movimientos', id);
  const coleccion = (db) => collection(db, 'productos', SLUG, 'movimientos');
  const datos = { antes: 4, despues: 10, por: 'operador' };

  test('el panel no crea, ni corrige, ni borra un movimiento', async () => {
    // Control positivo: sobre el MISMO producto el panel si lee y edita.  Sin
    // esto, un `assertFails` de abajo pasaria tambien con todo cerrado.
    await sembrar(`productos/${SLUG}`, vino({ stock: 4 }));
    await assertSucceeds(getDoc(producto(admin)));
    await assertSucceeds(updateDoc(producto(admin), { precio: 2100000 }));

    await assertFails(setDoc(movimiento(admin), datos));
    await sembrar(`productos/${SLUG}/movimientos/mov-0000000000000001`, datos);
    await assertFails(updateDoc(movimiento(admin), { despues: 999 }));
    await assertFails(deleteDoc(movimiento(admin)));
  });

  test('el panel lee uno y lista los ultimos, con limite (HU-05.4)', async () => {
    await sembrar(`productos/${SLUG}`, vino({ stock: 4 }));
    await sembrar(`productos/${SLUG}/movimientos/mov-0000000000000001`, datos);
    await assertSucceeds(getDoc(movimiento(admin)));
    // La consulta REAL del panel: los mas nuevos primero, 20.
    await assertSucceeds(getDocs(query(coleccion(admin), orderBy('en', 'desc'), limit(20))));
    // El borde: 50 pasa, 51 no.
    await assertSucceeds(getDocs(query(coleccion(admin), limit(50))));
    await assertFails(getDocs(query(coleccion(admin), limit(51))));
  });

  test('listarlos SIN limite se rechaza: leeria la coleccion entera', async () => {
    await sembrar(`productos/${SLUG}`, vino({ stock: 4 }));
    await sembrar(`productos/${SLUG}/movimientos/mov-0000000000000001`, datos);
    await assertFails(getDocs(coleccion(admin)));
    await assertFails(getDocs(query(coleccion(admin), orderBy('antes', 'desc'))));
  });

  test('un collectionGroup sobre movimientos se rechaza, tambien siendo admin', async () => {
    // Hoy lo niega el `/{documento=**}` de mas abajo.  Si alguien agrega un
    // `match /{path=**}/movimientos/{id}` (p. ej. para crearOrden), esto avisa.
    await sembrar(`productos/${SLUG}`, vino({ stock: 4 }));
    await sembrar(`productos/${SLUG}/movimientos/mov-0000000000000001`, datos);
    await assertFails(getDocs(query(collectionGroup(admin, 'movimientos'), limit(20))));
  });

  test('un comprador y un anonimo no leen ni escriben', async () => {
    await sembrar(`productos/${SLUG}`, vino({ stock: 4 }));
    await sembrar(`productos/${SLUG}/movimientos/mov-0000000000000001`, datos);
    for (const db of [comprador, anonimo]) {
      await assertFails(getDoc(movimiento(db)));
      await assertFails(getDocs(query(coleccion(db), limit(20))));
      await assertFails(setDoc(movimiento(db, 'mov-0000000000000002'), datos));
    }
  });

  test('despues de que el servidor mueve el stock, el panel sigue pudiendo editar el vino', async () => {
    // El dia que esto falle, cada reposicion deja el producto sin poder
    // editarse: el `hasOnly` de la ficha o la regla del stock verian un campo
    // que el panel no escribio.  Lo que la callable escribe es SOLO `stock`.
    await sembrar(`productos/${SLUG}`, vino({ stock: 4 }));
    await sembrar(`productos/${SLUG}`, vino({ stock: 10 }));
    await sembrar(`productos/${SLUG}/movimientos/mov-0000000000000001`, datos);
    await assertSucceeds(updateDoc(producto(admin), { nombre: 'Trumpeter Malbec Reserva' }));
    // Y el panel sigue sin poder tocar el numero que el servidor dejo.
    await assertFails(updateDoc(producto(admin), { stock: 999 }));
  });
});

// ----------------------------------------------------------- presentacion

describe('la presentacion es inmutable', () => {
  test('una botella suelta pasa a caja de 2: rechazado', async () => {
    await sembrar(`productos/${SLUG}`, vino({ stock: 10 }));
    await assertFails(updateDoc(producto(admin), { 'presentacion.botellas': 2 }));
    await assertFails(updateDoc(producto(admin), { presentacion: { botellas: 1, caja: true } }));
    // Control: reescribir el mismo valor no es cambiarlo.
    await assertSucceeds(updateDoc(producto(admin), { presentacion: { botellas: 1 } }));
  });

  test('una caja de 2 nace como tal: aceptada', async () => {
    await assertSucceeds(alta(admin, vino({ presentacion: { botellas: 2 } })));
    await assertFails(alta(admin, vino({ slug: 'otro-vino', presentacion: { botellas: 0 } })));
  });
});

// ------------------------------------------------------------ obligatorios

describe('los campos obligatorios no se pueden borrar', () => {
  test('un update que borra el precio: rechazado; que lo cambia: aceptado', async () => {
    await sembrar(`productos/${SLUG}`, vino({ stock: 10 }));
    await assertFails(updateDoc(producto(admin), { precio: deleteField() }));
    await assertSucceeds(updateDoc(producto(admin), { precio: 1800000 }));
  });

  test('borrar publicado, imagenes, nombre, color u organico: rechazado', async () => {
    await sembrar(`productos/${SLUG}`, vino({ stock: 10 }));
    for (const campo of ['publicado', 'imagenes', 'nombre', 'fichaVino.color', 'fichaVino.organico']) {
      await assertFails(updateDoc(producto(admin), { [campo]: deleteField() }), campo);
    }
  });

  test('un campo desconocido: rechazado, tambien adentro de fichaVino', async () => {
    await assertFails(alta(admin, vino({ descuento: 10 })));
    await assertFails(alta(admin, vino({}, { puntaje: 92 })));
    await assertSucceeds(alta(admin, vino()));
  });

  test('precio con decimales o como texto: rechazado', async () => {
    await assertFails(alta(admin, vino({ precio: 1990000.5 })));
    await assertFails(alta(admin, vino({ precio: '1990000' })));
    await assertFails(alta(admin, vino({ precio: -1 })));
  });

  test('un color fuera de la lista o un slug con mayusculas: rechazado', async () => {
    await assertFails(alta(admin, vino({}, { color: 'naranjo' })));
    await assertFails(alta(admin, vino({ slug: 'Trumpeter Malbec' })));
  });
});

// ------------------------------------------------------------ varietales

describe('los varietales salen de una lista cerrada', () => {
  test('"Cab. Sauv.": rechazado; "Cabernet Sauvignon": aceptado', async () => {
    await assertFails(alta(admin, vino({}, { varietales: ['Cab. Sauv.'] })));
    await assertSucceeds(alta(admin, vino({}, { varietales: ['Cabernet Sauvignon'] })));
  });

  test('Torrontés, con tilde: aceptado', async () => {
    // Control de codificacion: si el archivo de reglas perdiera la tilde, este
    // es el caso que lo delata.
    await assertSucceeds(alta(admin, vino({}, { varietales: ['Torrontés'], color: 'blanco' })));
    await assertFails(alta(admin, vino({ slug: 'otro-vino' }, { varietales: ['Torrontes'], color: 'blanco' })));
  });

  test('una lista vacia o con una uva repetida: rechazada; un corte: aceptado', async () => {
    await assertFails(alta(admin, vino({}, { varietales: [] })));
    await assertFails(alta(admin, vino({}, { varietales: ['Malbec', 'Malbec'] })));
    await assertSucceeds(alta(admin, vino({}, { varietales: ['Malbec', 'Cabernet Sauvignon'] })));
  });
});

// ------------------------------------------------------------ el id es el slug

// ADR 013: la unicidad del slug la da la base, porque el slug ES el id.
describe('el id de un producto nuevo es su slug', () => {
  test('alta con otro id: rechazada; con el id igual al slug: aceptada', async () => {
    await assertFails(setDoc(producto(admin, 'abc123'), vino()));
    await assertSucceeds(alta(admin, vino()));
  });

  test('cambiar el slug: rechazado; corregir el nombre sin tocarlo: aceptado', async () => {
    await sembrar(`productos/${SLUG}`, vino({ stock: 10 }));
    await assertFails(updateDoc(producto(admin), { slug: 'otro-slug' }));
    await assertSucceeds(updateDoc(producto(admin), { nombre: 'Trumpeter Malbec Reserva' }));
  });

  test('uno de muestra, con el id distinto del slug, se sigue corrigiendo; su slug tampoco cambia', async () => {
    // Los documentos anteriores a la regla: el seed usa `muestra-<slug>`.
    await sembrar('productos/muestra-trumpeter-malbec', vino({ stock: 10, muestra: true }));
    const deMuestra = producto(admin, 'muestra-trumpeter-malbec');
    await assertSucceeds(updateDoc(deMuestra, { nombre: 'Trumpeter Malbec' }));
    // Ni siquiera para "arreglarlo" igualandolo al id: cambiar es cambiar.
    await assertFails(updateDoc(deMuestra, { slug: 'muestra-trumpeter-malbec' }));
  });

  test('un alta encima de un vino con stock: la frena el stock', async () => {
    // Un `setDoc` sobre un documento que existe es un UPDATE para las reglas.
    // El documento que arma el alta trae `stock: 0`, asi que pisar un vino
    // con stock rebota por la regla del stock, no por esta.
    await sembrar(`productos/${SLUG}`, vino({ stock: 10 }));
    await assertFails(alta(admin, vino({ stock: 0, nombre: 'Otro' })));
  });

  test('lo que las reglas NO frenan: un alta encima de un vino sin stock', async () => {
    // Escrito a proposito, como tripwire: sobre un vino con stock 0 y la misma
    // presentacion, un `setDoc` completo es un update legitimo. Lo que lo
    // impide es la TRANSACCION del panel, que se niega si el documento
    // existe (`RepositorioDeProductosFirestore.crear`). Si alguien endurece
    // las reglas, este caso falla y hay que actualizar ADR 013.
    await sembrar(`productos/${SLUG}`, vino({ stock: 0 }));
    await assertSucceeds(alta(admin, vino({ stock: 0, nombre: 'Otro' })));
  });
});

// ------------------------------------------------------------- graduacion

describe('la graduacion es opcional y va en decimas', () => {
  test('con 135, sin el campo, en null, en el piso y en el techo: aceptada', async () => {
    await assertSucceeds(alta(admin, vino({ slug: 'con' }, { graduacion: 135 })));
    await assertSucceeds(alta(admin, vino({ slug: 'sin' })));
    await assertSucceeds(alta(admin, vino({ slug: 'nula' }, { graduacion: null })));
    await assertSucceeds(alta(admin, vino({ slug: 'piso' }, { graduacion: 50 })));
    await assertSucceeds(alta(admin, vino({ slug: 'techo' }, { graduacion: 250 })));
  });

  test('cada confusion de unidad rebota: 13.5, 14, 1350, texto, 49 y 251', async () => {
    for (const graduacion of [13.5, 14, 1350, '13,5', 49, 251]) {
      await assertFails(alta(admin, vino({}, { graduacion })), String(graduacion));
    }
  });

  test('un vino anterior sin el campo se corrige; ponerle 14 rebota, 140 no', async () => {
    await sembrar(`productos/${SLUG}`, vino({ stock: 10 }));
    await assertSucceeds(updateDoc(producto(admin), { 'fichaVino.region': 'Gualtallary, Mendoza' }));
    await assertFails(updateDoc(producto(admin), { 'fichaVino.graduacion': 14 }));
    await assertSucceeds(updateDoc(producto(admin), { 'fichaVino.graduacion': 140 }));
  });
});

// ------------------------------------------------ corregir varietales, en batch

// ARQUITECTURA §5.3: nunca reescribir la lista. Un mismo `update` no puede
// llevar arrayUnion y arrayRemove sobre el mismo campo, asi que el panel
// corrige en un WriteBatch con dos `update` al mismo documento.
describe('los varietales se corrigen sin reescribir la lista', () => {
  async function varietales() {
    let v;
    await entorno.withSecurityRulesDisabled(async (ctx) => {
      v = (await getDoc(doc(ctx.firestore(), 'productos', SLUG))).data().fichaVino.varietales;
    });
    return v;
  }

  test('reemplazar el UNICO varietal, union y despues remove en un batch: aceptado', async () => {
    await sembrar(`productos/${SLUG}`, vino({ stock: 10 }));
    const batch = writeBatch(admin);
    batch.update(producto(admin), { 'fichaVino.varietales': arrayUnion('Syrah') });
    batch.update(producto(admin), { 'fichaVino.varietales': arrayRemove('Malbec') });
    await assertSucceeds(batch.commit());
    assert.deepEqual(await varietales(), ['Syrah']);
  });

  test('las reglas ven el estado FINAL del batch: al reves tambien pasa', async () => {
    // MEDIDO el 2026-09-18, no supuesto: el diseño temia que las reglas
    // evaluaran el estado intermedio, y que sacar primero dejara la lista
    // vacia. No lo evaluan. El panel igual une primero, que no cuesta nada.
    await sembrar(`productos/${SLUG}`, vino({ stock: 10 }));
    const batch = writeBatch(admin);
    batch.update(producto(admin), { 'fichaVino.varietales': arrayRemove('Malbec') });
    batch.update(producto(admin), { 'fichaVino.varietales': arrayUnion('Syrah') });
    await assertSucceeds(batch.commit());
    assert.deepEqual(await varietales(), ['Syrah']);
  });

  test('quitar el ultimo varietal: rechazado, y el documento queda como estaba', async () => {
    // El control: sin este, los dos de arriba no distinguen "las reglas
    // miraron la lista" de "las reglas no miran los batches".
    await sembrar(`productos/${SLUG}`, vino({ stock: 10 }));
    const batch = writeBatch(admin);
    batch.update(producto(admin), { 'fichaVino.varietales': arrayRemove('Malbec') });
    await assertFails(batch.commit());
    assert.deepEqual(await varietales(), ['Malbec']);
  });

  test('dos personas: una agrega Merlot y otra quita Syrah, y quedan las dos cosas', async () => {
    await sembrar(`productos/${SLUG}`, vino({ stock: 10 }, { varietales: ['Malbec', 'Syrah'] }));
    const otra = entorno.authenticatedContext('otra-persona', { rol: 'admin' }).firestore();
    await assertSucceeds(updateDoc(producto(admin), { 'fichaVino.varietales': arrayUnion('Merlot') }));
    await assertSucceeds(updateDoc(producto(otra), { 'fichaVino.varietales': arrayRemove('Syrah') }));
    assert.deepEqual(await varietales(), ['Malbec', 'Merlot']);
  });
});

// ------------------------------------------------------------------ quien

describe('quien lee y quien escribe productos', () => {
  test('un comprador o un anonimo no escriben; el admin si', async () => {
    await assertFails(alta(comprador, vino()));
    await assertFails(alta(anonimo, vino()));
    await assertSucceeds(alta(admin, vino()));
  });

  test('desde el navegador solo lee el admin', async () => {
    await sembrar(`productos/${SLUG}`, vino({ stock: 10 }));
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

// ------------------------------------------------- no se borra, se despublica

describe('un producto no se borra, se saca de la tienda', () => {
  test('el admin no puede borrar, y SI puede despublicar', async () => {
    await sembrar(`productos/${SLUG}`, vino({ stock: 10 }));
    // Control positivo primero: si despublicar tambien fallara, el rechazo de
    // abajo no probaria nada sobre `delete` -probaria que no se escribe-.
    await assertSucceeds(updateDoc(producto(admin), { publicado: false }));
    await assertFails(deleteDoc(producto(admin)));
  });

  test('borrar y recrear con otra presentacion: la puerta que esto cierra', async () => {
    // Sin `allow delete: if false` esta era la vuelta para saltearse la
    // inmutabilidad de `presentacion`: borrar la botella suelta y recrear el
    // mismo id como caja de 2 (hallazgo 1 de revisor-pagos).
    await sembrar(`productos/${SLUG}`, vino({ stock: 10 }));
    await assertFails(deleteDoc(producto(admin)));
    await assertFails(updateDoc(producto(admin), { 'presentacion.botellas': 2 }));
  });

  test('el seed sigue borrando: el Admin SDK no pasa por las reglas', async () => {
    await sembrar(`productos/${SLUG}`, vino({ stock: 10 }));
    await entorno.withSecurityRulesDisabled(async (ctx) => {
      await deleteDoc(doc(ctx.firestore(), 'productos', SLUG));
    });
    // `withSecurityRulesDisabled` no devuelve lo que retorna el callback:
    // leerlo de su valor da `undefined` y el assert pasaria con cualquier cosa.
    let quedo = null;
    await entorno.withSecurityRulesDisabled(async (ctx) => {
      quedo = (await getDoc(doc(ctx.firestore(), 'productos', SLUG))).exists();
    });
    assert.equal(quedo, false, 'scripts/seed/borrar.mjs tiene que seguir funcionando');
  });
});

// ------------------------------------------------ un publicado tiene precio

describe('un producto publicado tiene precio mayor que cero', () => {
  test('publicado con 0 rebota; con 1 pasa; el borrador en 0 pasa', async () => {
    await assertFails(alta(admin, vino({ slug: 'cero', precio: 0 })), 'publicado con precio 0');
    await assertSucceeds(alta(admin, vino({ slug: 'uno', precio: 1 })), 'publicado con precio 1');
    await assertSucceeds(alta(admin, vino({ slug: 'borrador', precio: 0, publicado: false })), 'sin publicar, el 0 vale');
  });

  test('publicar uno guardado en 0, sin tocar el precio, rebota', async () => {
    await sembrar(`productos/${SLUG}`, vino({ precio: 0, publicado: false, stock: 10 }));
    // Control positivo: el mismo update con un precio arriba de 0 pasa, asi
    // que el rechazo es por el precio y no porque el update no funcione.
    await assertFails(updateDoc(producto(admin), { publicado: true }));
    await assertSucceeds(updateDoc(producto(admin), { publicado: true, precio: 1990000 }));
  });

  test('bajar a 0 el precio de uno publicado rebota; despublicando, no', async () => {
    await sembrar(`productos/${SLUG}`, vino({ stock: 10 }));
    await assertFails(updateDoc(producto(admin), { precio: 0 }));
    await assertSucceeds(updateDoc(producto(admin), { precio: 0, publicado: false }));
  });
});

// ---------------------------------------------------- cada imagen es https

describe('cada entrada de imagenes es una URL https', () => {
  const FOTO = 'https://firebasestorage.googleapis.com/v0/b/x/o/y.webp?alt=media';

  test('sin fotos, una foto y diez fotos: aceptadas', async () => {
    await assertSucceeds(alta(admin, vino({ slug: 'sin-fotos', imagenes: [] })));
    await assertSucceeds(alta(admin, vino({ slug: 'una-foto', imagenes: [FOTO] })));
    await assertSucceeds(alta(admin, vino({ slug: 'diez-fotos', imagenes: Array(10).fill(FOTO) })));
  });

  test('once fotos siguen rebotando', async () => {
    await assertFails(alta(admin, vino({ imagenes: Array(11).fill(FOTO) })));
  });

  test('http, un numero, null y un mapa rebotan en CUALQUIER posicion', async () => {
    for (const mala of ['http', 'http://ejemplo/foto.webp', 123, null, { url: FOTO }]) {
      await assertFails(alta(admin, vino({ imagenes: [mala] })), `primera: ${JSON.stringify(mala)}`);
      // La ultima posicion importa tanto como la primera: una condicion escrita
      // solo para el indice 0 pasaria este caso.
      await assertFails(alta(admin, vino({ imagenes: [...Array(9).fill(FOTO), mala] })), `decima: ${JSON.stringify(mala)}`);
    }
  });

  test('matches() no deja colar un https:// en el medio', async () => {
    // Si `matches` midiera una coincidencia PARCIAL y no la cadena entera,
    // estos tres pasarian. Es la pregunta que el emulador contesta.
    await assertFails(alta(admin, vino({ imagenes: ['xhttps://ejemplo/foto.webp'] })), 'prefijo delante');
    await assertFails(alta(admin, vino({ imagenes: ['javascript:alert(1)#https://x'] })), 'https en el medio');
    await assertFails(alta(admin, vino({ imagenes: ['https://'] })), 'el esquema solo, sin host');
  });
});

// ------------------------------------------------------------ descripcion

describe('la descripcion es opcional y tiene tope', () => {
  test('sin el campo, en null y con texto: aceptadas', async () => {
    await assertSucceeds(alta(admin, vino({ slug: 'sin' })));
    await assertSucceeds(alta(admin, vino({ slug: 'nula' }, { descripcion: null })));
    await assertSucceeds(alta(admin, vino({ slug: 'con' }, { descripcion: 'Un Malbec de altura.' })));
  });

  test('en blanco rebota: para "sin descripcion" esta null', async () => {
    const enBlanco = ['', '   ', String.fromCharCode(10, 10), String.fromCharCode(9, 32)];
    for (const descripcion of enBlanco) {
      await assertFails(alta(admin, vino({}, { descripcion })), JSON.stringify(descripcion));
    }
  });

  test('600 entra, 601 no, y lo que no es texto rebota', async () => {
    await assertSucceeds(alta(admin, vino({ slug: 'justo' }, { descripcion: 'a'.repeat(600) })));
    await assertFails(alta(admin, vino({ slug: 'mas' }, { descripcion: 'a'.repeat(601) })));
    await assertFails(alta(admin, vino({ slug: 'num' }, { descripcion: 123 })));
  });

  test('size() cuenta CARACTERES y no bytes: 600 enies entran', async () => {
    // Si contara bytes UTF-8, 600 enies serian 1200 y el tope real en
    // castellano seria la mitad del que dice el formulario. El contrato y el
    // panel cuentan caracteres; esto verifica que las reglas tambien.
    const enie = String.fromCharCode(241);
    await assertSucceeds(alta(admin, vino({ slug: 'acentos' }, { descripcion: enie.repeat(600) })));
  });

  test('a un vino anterior se le agrega la descripcion despues', async () => {
    await sembrar(`productos/${SLUG}`, vino({ stock: 10 }));
    await assertSucceeds(updateDoc(producto(admin), { 'fichaVino.descripcion': 'Agregada despues.' }));
    await assertFails(updateDoc(producto(admin), { 'fichaVino.descripcion': '   ' }));
  });
});

describe('que cuenta size(): la pregunta que el numero 600 no contesta', () => {
  // Las tres copias dicen 600. auditar_varietales compara EL NUMERO, no QUE se
  // cuenta: si las reglas contaran puntos de codigo y JS/Dart unidades UTF-16,
  // los tres archivos coincidirian y el contador del formulario mentiria.
  //
  // Un caracter fuera del BMP vale 1 punto de codigo y 2 unidades UTF-16.
  const FUERA_DEL_BMP = String.fromCodePoint(0x1f347); // uva
  const PUNTOS = 350; // 350 puntos de codigo = 700 unidades UTF-16

  test('350 caracteres fuera del BMP: 350 puntos, 700 unidades UTF-16', async () => {
    const texto = FUERA_DEL_BMP.repeat(PUNTOS);
    // Control del propio caso: si esto no fuera 700, el caso no discrimina.
    assert.equal(texto.length, 700, 'en JS son 700 unidades UTF-16');
    assert.equal([...texto].length, 350, 'y 350 puntos de codigo');

    // Control positivo: el mismo documento con un texto corto pasa.
    await assertSucceeds(alta(admin, vino({ slug: 'corto' }, { descripcion: 'ab' })));

    // MEDIDO el 2026-09-21: rebota. O sea que size() cuenta UNIDADES UTF-16,
    // igual que `.length` de JS y de Dart: los tres lados cuentan lo mismo y
    // el contador del formulario no miente. Si algun dia esto pasa a verde,
    // las reglas se volvieron mas permisivas que el panel.
    await assertFails(alta(admin, vino({ slug: 'bmp' }, { descripcion: texto })));

    // Y el limite por el otro lado: 300 puntos son 600 unidades y entran.
    await assertSucceeds(alta(admin, vino({ slug: 'justo' }, { descripcion: FUERA_DEL_BMP.repeat(300) })));
  });
});
