// ordenes.test.mjs - las reglas de `ordenes`, sus marcadores y `contadores`
// contra el emulador.  ADR 018, openspec/changes/pedidos-de-whatsapp/specs/
// bandeja-de-pedidos y crear-orden-del-panel.
//
// Corre con:
//   firebase emulators:exec --only firestore --project demo-bouquet \
//     "node --test scripts/reglas/ordenes.test.mjs"
//
// `demo-bouquet` a proposito (ver productos.test.mjs): no puede tocar un
// proyecto real.
//
// ⚠️ Corre EN SERIE con las otras suites de reglas (`--test-concurrency=1`):
// cada una llama a `clearFirestore` sobre el MISMO emulador, y `node --test`
// corre los archivos en paralelo.  Medido el 2026-09-24: con las dos suites
// juntas y en paralelo fallaron 8 casos --tambien de `productos`, que no se
// tocaron--; en serie, 83/83.
//
// Hasta esta suite `ordenes` no tenia NINGUN caso de reglas: la coleccion
// existia en `firestore.rules` y nadie la habia ejercitado, y desde HU-06.1 el
// panel la lee.  Cada requisito tiene un caso ACEPTADO y uno RECHAZADO: sin el
// aceptado, una regla que niega todo pasaria todos los rechazos.

import { after, before, beforeEach, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { collection, deleteDoc, deleteField, doc, getDoc, getDocs, limit, orderBy, query, serverTimestamp, setDoc, updateDoc, where } from 'firebase/firestore';

const RAIZ = join(dirname(fileURLToPath(import.meta.url)), '..', '..');

let entorno;
let admin;
let comprador;
let anonimo;

const ID = 'pedido-de-prueba-0001';

/** Una Orden como la deja `crearOrdenDelPanel` (sin los timestamps). */
function orden(cambios = {}) {
  return {
    numero: 7,
    origen: 'whatsapp',
    estadoPago: 'por_fuera',
    estadoEntrega: 'sin_preparar',
    items: [{ productoId: 'vino-a', nombre: 'Vino A', precioUnitario: 1990000, cantidad: 2, botellas: 1 }],
    subtotal: 3980000,
    envio: null,
    total: 3980000,
    contacto: { nombre: 'Marta Gomez', telefonoE164: '+5493515551234', email: null },
    entrega: {
      calle: 'San Martin',
      numero: '120',
      piso: null,
      referencia: null,
      destino: { codigoPostal: '5000', localidad: 'Cordoba', provincia: 'X', propio: false },
    },
    creadaPor: 'operador',
    creadaEn: new Date('2026-09-24T12:00:00Z'),
    actualizadaEn: new Date('2026-09-24T12:00:00Z'),
    ...cambios,
  };
}

const ordenDe = (db, id = ID) => doc(db, 'ordenes', id);
const coleccion = (db) => collection(db, 'ordenes');

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

// ------------------------------------------------------------------- leer

describe('el panel lee las ordenes', () => {
  test('un admin lee una orden por id', async () => {
    await sembrar(`ordenes/${ID}`, orden());
    const snap = await assertSucceeds(getDoc(ordenDe(admin)));
    assert.equal(snap.get('numero'), 7);
  });

  test('un admin lista con limite: la consulta REAL de la bandeja', async () => {
    await sembrar(`ordenes/${ID}`, orden());
    // La misma forma que `repositorio_de_pedidos_firebase.dart`: por estado de
    // entrega, los mas nuevos primero, una pagina de 25.
    const bandeja = query(
      coleccion(admin),
      where('estadoEntrega', '==', 'sin_preparar'),
      orderBy('creadaEn', 'desc'),
      limit(25),
    );
    const snap = await assertSucceeds(getDocs(bandeja));
    assert.equal(snap.size, 1, 'control positivo: la lista devuelve la orden sembrada');
  });

  test('el borde del limite: 50 pasa, 51 no', async () => {
    await sembrar(`ordenes/${ID}`, orden());
    await assertSucceeds(getDocs(query(coleccion(admin), limit(50))));
    await assertFails(getDocs(query(coleccion(admin), limit(51))));
  });

  test('listar SIN limite se rechaza: leeria todas las ordenes', async () => {
    await sembrar(`ordenes/${ID}`, orden());
    await assertFails(getDocs(coleccion(admin)));
    await assertFails(getDocs(query(coleccion(admin), where('estadoEntrega', '==', 'sin_preparar'))));
    await assertFails(getDocs(query(coleccion(admin), orderBy('creadaEn', 'desc'))));
  });

  test('un comprador y un anonimo no leen ni listan', async () => {
    await sembrar(`ordenes/${ID}`, orden());
    for (const db of [comprador, anonimo]) {
      await assertFails(getDoc(ordenDe(db)));
      await assertFails(getDocs(query(coleccion(db), limit(25))));
    }
  });
});

// ------------------------------------------------------------------ crear

describe('nadie crea ni borra una orden desde un cliente', () => {
  test('ni siquiera un admin: nacen por la transaccion de la callable', async () => {
    // Control positivo: sobre la MISMA orden sembrada el admin si lee.  Sin
    // esto el rechazo de abajo pasaria tambien con todo cerrado.
    await sembrar('ordenes/otra', orden());
    await assertSucceeds(getDoc(ordenDe(admin, 'otra')));

    await assertFails(setDoc(ordenDe(admin), orden({ creadaEn: serverTimestamp() })));
    await assertFails(setDoc(ordenDe(comprador), orden()));
    await assertFails(setDoc(ordenDe(anonimo), orden()));
  });

  test('una orden no se borra: se cancela', async () => {
    await sembrar(`ordenes/${ID}`, orden());
    await assertFails(deleteDoc(ordenDe(admin)));
  });
});

// ------------------------------------------------------------------ editar

describe('el panel mueve la entrega y anota, y nada mas', () => {
  test('estadoEntrega, notasOperador y actualizadaEn si', async () => {
    await sembrar(`ordenes/${ID}`, orden());
    await assertSucceeds(updateDoc(ordenDe(admin), { estadoEntrega: 'preparando' }));
    await assertSucceeds(updateDoc(ordenDe(admin), { notasOperador: 'llamar antes' }));
    await assertSucceeds(updateDoc(ordenDe(admin), { actualizadaEn: serverTimestamp() }));
  });

  test('estadoEntrega: uno de los seis, nunca borrado ni inventado', async () => {
    await sembrar(`ordenes/${ID}`, orden());
    // Control positivo: cada uno de los seis estados se acepta.
    for (const estado of ['preparando', 'despachada', 'entregada', 'fallida', 'cancelada', 'sin_preparar']) {
      await assertSucceeds(updateDoc(ordenDe(admin), { estadoEntrega: estado }));
    }
    // El hallazgo 4 de `revisor-pagos`: `affectedKeys()` incluye las claves
    // BORRADAS, asi que `deleteField()` pasaba el `hasOnly` y la orden
    // desaparecia de toda bandeja (`where('estadoEntrega', '==', X)` no la trae).
    await assertFails(updateDoc(ordenDe(admin), { estadoEntrega: deleteField() }));
    await assertFails(updateDoc(ordenDe(admin), { estadoEntrega: 'teletransportada' }));
    await assertFails(updateDoc(ordenDe(admin), { estadoEntrega: '' }));
    await assertFails(updateDoc(ordenDe(admin), { estadoEntrega: 3 }));
  });

  test('un update que no toca estadoEntrega sigue valiendo si el existente es valido', async () => {
    // Sin esto, exigir el estado en cada update tiraria una nota suelta.
    await sembrar(`ordenes/${ID}`, orden());
    await assertSucceeds(updateDoc(ordenDe(admin), { notasOperador: 'llamar antes' }));
  });

  test('notasOperador: un texto de hasta 1000 caracteres', async () => {
    await sembrar(`ordenes/${ID}`, orden());
    await assertSucceeds(updateDoc(ordenDe(admin), { notasOperador: 'x'.repeat(1000) }));
    await assertFails(updateDoc(ordenDe(admin), { notasOperador: 'x'.repeat(1001) }));
    await assertFails(updateDoc(ordenDe(admin), { notasOperador: 42 }));
    await assertFails(updateDoc(ordenDe(admin), { notasOperador: { a: 1 } }));
  });

  test('actualizadaEn: solo una hora', async () => {
    await sembrar(`ordenes/${ID}`, orden());
    await assertSucceeds(updateDoc(ordenDe(admin), { actualizadaEn: serverTimestamp() }));
    await assertFails(updateDoc(ordenDe(admin), { actualizadaEn: 'ayer' }));
  });

  // Cada uno es un campo que el panel NO puede tocar, y por que:
  const prohibidos = [
    // Si el panel escribiera `estadoPago`, marcaria "pagada" un pedido de
    // WhatsApp y dispararia `entroEnPagada` por un cobro que nadie comprobo.
    ['estadoPago', { estadoPago: 'pagada' }],
    // El origen decide una regla de plata (la caja de seis).
    ['origen', { origen: 'vidriera' }],
    // `items` es un SNAPSHOT: editarlo despues lo vuelve mentira.
    ['items', { items: [] }],
    ['numero', { numero: 8 }],
    ['total', { total: 1 }],
    ['subtotal', { subtotal: 1 }],
    ['contacto', { contacto: { nombre: 'Otro', telefonoE164: '+5493510000000', email: null } }],
    ['creadaPor', { creadaPor: 'otro' }],
  ];
  for (const [campo, cambio] of prohibidos) {
    test(`no puede escribir ${campo}`, async () => {
      await sembrar(`ordenes/${ID}`, orden());
      // Control positivo sobre la MISMA orden: un campo permitido si pasa.
      await assertSucceeds(updateDoc(ordenDe(admin), { notasOperador: 'ok' }));
      await assertFails(updateDoc(ordenDe(admin), cambio));
    });
  }

  test('un comprador y un anonimo no editan nada', async () => {
    await sembrar(`ordenes/${ID}`, orden());
    for (const db of [comprador, anonimo]) {
      await assertFails(updateDoc(ordenDe(db), { estadoEntrega: 'preparando' }));
    }
  });
});

// ------------------------------------------------------- lo que es del servidor

describe('los marcadores y el contador son del servidor', () => {
  test('marcadores: nadie lee ni escribe', async () => {
    await sembrar(`ordenes/${ID}`, orden());
    await sembrar(`ordenes/${ID}/marcadores/entroEnPagada`, { en: new Date() });
    // Control positivo: la orden madre si se lee.
    await assertSucceeds(getDoc(ordenDe(admin)));
    const marcador = doc(admin, 'ordenes', ID, 'marcadores', 'entroEnPagada');
    await assertFails(getDoc(marcador));
    await assertFails(setDoc(marcador, { en: new Date() }));
    await assertFails(deleteDoc(marcador));
  });

  test('contadores/ordenes: ni un admin lo lee ni lo escribe', async () => {
    // Dos escrituras concurrentes por fuera de la transaccion dan dos ordenes
    // con el mismo numero.
    await sembrar('contadores/ordenes', { ultimo: 6 });
    await assertFails(getDoc(doc(admin, 'contadores', 'ordenes')));
    await assertFails(setDoc(doc(admin, 'contadores', 'ordenes'), { ultimo: 100 }));
    await assertFails(updateDoc(doc(admin, 'contadores', 'ordenes'), { ultimo: 100 }));
  });
});
