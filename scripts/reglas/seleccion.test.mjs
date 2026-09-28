// seleccion.test.mjs - las reglas de `seleccion/publica`, la seleccion de la
// portada que elige el duenio.  HU-09.1, ADR 023.
//
// Corre con:
//   firebase emulators:exec --only firestore --project demo-bouquet \
//     "node --test scripts/reglas/seleccion.test.mjs"
//
// Cada requisito tiene un caso ACEPTADO y uno RECHAZADO, como la suite de
// productos: sin el aceptado, una regla que niega todo pasaria todos los
// rechazos.
//
// El tope NO se escribe aca: sale de `generated/contratos.json`, que lo calcula
// `LUGARES_DE_LA_SELECCION` de contratos.  Las reglas lo repiten como literal
// (no importan TypeScript), y esta suite es lo que las ata.

import { after, before, beforeEach, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { deleteDoc, doc, getDoc, setDoc } from 'firebase/firestore';

const RAIZ = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const CONTRATO = JSON.parse(readFileSync(join(RAIZ, 'packages', 'contratos', 'generated', 'contratos.json'), 'utf8'));
const LUGARES = CONTRATO.vidriera.lugaresDeLaSeleccion;

let entorno;
let admin;
let comprador;
let anonimo;

const ids = (n) => Array.from({ length: n }, (_, i) => `vino-${i + 1}`);
const seleccion = (db, id = 'publica') => doc(db, 'seleccion', id);
const guardar = (db, datos, id) => setDoc(seleccion(db, id), datos);

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

describe('el tope es el de contratos', () => {
  test('el contrato generado trae un tope, y es un numero razonable', () => {
    // Control del instrumento: sin esto, un JSON sin la seccion daria
    // `undefined`, `ids(undefined)` una lista vacia, y los dos casos de abajo
    // pasarian por el motivo equivocado.
    assert.equal(typeof LUGARES, 'number');
    assert.ok(LUGARES >= 1 && LUGARES <= 12);
  });

  test(`el admin guarda ${LUGARES}; uno mas, no`, async () => {
    await assertSucceeds(guardar(admin, { productoIds: ids(LUGARES) }));
    await assertFails(guardar(admin, { productoIds: ids(LUGARES + 1) }));
  });

  test('menos que el tope y la lista vacia tambien se guardan', async () => {
    await assertSucceeds(guardar(admin, { productoIds: ids(2) }));
    await assertSucceeds(guardar(admin, { productoIds: [] }));
  });
});

describe('la forma', () => {
  test('un id repetido: rechazado; los mismos sin repetir: aceptado', async () => {
    await assertFails(guardar(admin, { productoIds: ['vino-1', 'vino-2', 'vino-1'] }));
    await assertSucceeds(guardar(admin, { productoIds: ['vino-1', 'vino-2', 'vino-3'] }));
  });

  test('algo que no es un id, en la primera y en la ULTIMA posicion: rechazado', async () => {
    // La ultima importa: las reglas miran cada indice a mano, y un indice
    // olvidado dejaria pasar basura justo ahi.
    const ultima = ids(LUGARES);
    ultima[LUGARES - 1] = 7;
    await assertFails(guardar(admin, { productoIds: ultima }));
    await assertFails(guardar(admin, { productoIds: ['con espacio', 'vino-2'] }));
    await assertFails(guardar(admin, { productoIds: [''] }));
    // Control: los ids de muestra, con prefijo, SI son ids.
    await assertSucceeds(guardar(admin, { productoIds: ['muestra-trumpeter-malbec', 'vino-2'] }));
  });

  test('la lista que no es lista: rechazada', async () => {
    await assertFails(guardar(admin, { productoIds: 'vino-1' }));
    await assertFails(guardar(admin, { productoIds: { 0: 'vino-1' } }));
  });

  test('un campo de mas: rechazado; sin el: aceptado', async () => {
    await assertFails(guardar(admin, { productoIds: ids(1), muestra: true }));
    await assertSucceeds(guardar(admin, { productoIds: ids(1) }));
  });

  test('otro documento de la coleccion: rechazado', async () => {
    await assertFails(guardar(admin, { productoIds: ids(1) }, 'otra'));
    await assertSucceeds(guardar(admin, { productoIds: ids(1) }, 'publica'));
  });
});

describe('quien', () => {
  test('ni el comprador ni el anonimo la escriben', async () => {
    await assertFails(guardar(comprador, { productoIds: ids(1) }));
    await assertFails(guardar(anonimo, { productoIds: ids(1) }));
    await assertSucceeds(guardar(admin, { productoIds: ids(1) }));
  });

  test('la lee solo el admin: la vidriera la lee con el Admin SDK', async () => {
    await guardar(admin, { productoIds: ids(1) });
    await assertSucceeds(getDoc(seleccion(admin)));
    await assertFails(getDoc(seleccion(comprador)));
    await assertFails(getDoc(seleccion(anonimo)));
  });

  test('no se borra, ni siendo admin: sacar todo es la lista vacia', async () => {
    await guardar(admin, { productoIds: ids(1) });
    await assertFails(deleteDoc(seleccion(admin)));
    await assertSucceeds(guardar(admin, { productoIds: [] }));
  });
});
