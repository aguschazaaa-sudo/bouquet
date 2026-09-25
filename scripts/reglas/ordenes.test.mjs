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

  test('estadoEntrega: nunca borrado ni inventado', async () => {
    await sembrar(`ordenes/${ID}`, orden());
    // Control positivo: el paso que la tabla permite desde `sin_preparar`. Los
    // demas pares los recorre la matriz de EP-07, mas abajo.
    await assertSucceeds(updateDoc(ordenDe(admin), { estadoEntrega: 'preparando' }));
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

// --------------------------------------------------- mover la entrega (EP-07)
//
// ADR 019.  La tabla de transiciones vive en `contratos`, en Dart y -desde
// EP-07- en las reglas.  La tercera copia NO se sincroniza sola: esta suite saca
// del JSON generado que pares tiene que aceptar (`despacho.laEscribeElPanel`) y
// las listas de correos y motivos, asi que cambiar la tabla o una lista en
// `contratos` sin tocar las reglas pone esto en rojo.

const CONTRATO = JSON.parse(readFileSync(join(RAIZ, 'packages', 'contratos', 'generated', 'contratos.json'), 'utf8'));
const ESTADOS = CONTRATO.entrega.estados;
const DESPACHO = CONTRATO.despacho;

const despacho = (cambios = {}) => ({ correo: 'andreani', seguimiento: 'AND-000123', en: serverTimestamp(), ...cambios });
const falla = (cambios = {}) => ({ motivo: 'sin_mayor', en: serverTimestamp(), ...cambios });

/** Lo que el panel manda para llegar a `despues`: el estado y los campos de ESE paso. */
function paso(despues) {
  const base = { estadoEntrega: despues, actualizadaEn: serverTimestamp() };
  if (despues === 'despachada') return { ...base, despacho: despacho() };
  if (despues === 'fallida') return { ...base, entregaFallida: falla() };
  return base;
}

describe('EP-07: la entrega se mueve por la tabla de ADR 002, y nada mas', () => {
  test('la matriz: cada par contra lo que el contrato dice que escribe el panel', async () => {
    let aceptados = 0;
    for (const antes of ESTADOS) {
      for (const despues of ESTADOS) {
        if (antes === despues) continue; // el mismo estado es "anotar": abajo
        await sembrar(`ordenes/${ID}`, orden({ estadoEntrega: antes }));
        const intento = updateDoc(ordenDe(admin), paso(despues));
        if (DESPACHO.laEscribeElPanel[antes].includes(despues)) {
          await assertSucceeds(intento);
          aceptados += 1;
        } else {
          await assertFails(intento);
        }
      }
    }
    // El control de la matriz misma: con un JSON vacio todos los rechazos
    // pasarian y esto no probaria nada.
    assert.equal(aceptados, 5);
  });

  test('cancelar NO lo escribe ningun cliente, ni desde donde la tabla lo permite', async () => {
    // Cancelar devuelve el stock, y eso lo hace `cancelarOrden` en la misma
    // transaccion. Escrito desde el panel, el vino quedaria vendido para siempre.
    assert.deepEqual(DESPACHO.soloLoEscribeElServidor, ['cancelada']);
    for (const desde of ['sin_preparar', 'preparando']) {
      assert.ok(CONTRATO.entrega.transiciones[desde].includes('cancelada'), `la tabla SI lo permite desde ${desde}`);
      await sembrar(`ordenes/${ID}`, orden({ estadoEntrega: desde }));
      await assertFails(updateDoc(ordenDe(admin), { estadoEntrega: 'cancelada' }));
      await assertFails(
        updateDoc(ordenDe(admin), { estadoEntrega: 'cancelada', cancelacion: { motivo: 'otro', sinReponer: [] } }),
      );
    }
    // Control positivo sobre la misma orden: un paso del panel si pasa.
    await assertSucceeds(updateDoc(ordenDe(admin), paso('despachada')));
  });

  test('`cancelacion` no se escribe a mano, ni anotando', async () => {
    await sembrar(`ordenes/${ID}`, orden());
    await assertSucceeds(updateDoc(ordenDe(admin), { notasOperador: 'ok' }));
    await assertFails(updateDoc(ordenDe(admin), { cancelacion: { motivo: 'otro', sinReponer: [] } }));
  });

  test('otra pantalla vieja: despachar lo que ya salio se rechaza, anotarlo no', async () => {
    // Dos personas con el pedido abierto: una despacha, la otra aprieta
    // "despachar" despues. Pisaria el seguimiento de la primera.
    await sembrar(`ordenes/${ID}`, orden({ estadoEntrega: 'despachada', despacho: { correo: 'oca', seguimiento: 'OCA-1', en: new Date() } }));
    await assertFails(updateDoc(ordenDe(admin), paso('despachada')));
    await assertFails(updateDoc(ordenDe(admin), { despacho: despacho() }));
    await assertSucceeds(updateDoc(ordenDe(admin), { notasOperador: 'llamar antes', actualizadaEn: serverTimestamp() }));
  });
});

describe('EP-07: despachar lleva el correo y, si hay, el seguimiento', () => {
  const despachar = (d) => updateDoc(ordenDe(admin), { estadoEntrega: 'despachada', despacho: d, actualizadaEn: serverTimestamp() });

  test('cada correo del contrato pasa', async () => {
    for (const correo of DESPACHO.correos) {
      await sembrar(`ordenes/${ID}`, orden({ estadoEntrega: 'preparando' }));
      await assertSucceeds(despachar(despacho({ correo })));
    }
  });

  test('el seguimiento es opcional, y si esta tiene de 1 al largo del contrato', async () => {
    const largo = DESPACHO.largoDelSeguimiento;
    for (const [seguimiento, pasa] of [
      [null, true],
      ['x', true],
      ['x'.repeat(largo), true],
      ['', false],
      ['x'.repeat(largo + 1), false],
      [123, false],
    ]) {
      await sembrar(`ordenes/${ID}`, orden({ estadoEntrega: 'preparando' }));
      const intento = despachar(despacho({ seguimiento }));
      if (pasa) await assertSucceeds(intento);
      else await assertFails(intento);
    }
  });

  test('lo que no es un despacho se rechaza', async () => {
    const malos = [
      ['sin despacho', undefined],
      ['un texto', 'andreani'],
      ['correo inventado', despacho({ correo: 'paloma' })],
      ['sin seguimiento: la clave va, aunque sea null', { correo: 'oca', en: serverTimestamp() }],
      ['sin hora', { correo: 'oca', seguimiento: null }],
      // Un cliente no fecha un despacho para atras.
      ['una hora del cliente', despacho({ en: new Date('2026-01-01T00:00:00Z') })],
      ['una clave de mas', despacho({ costo: 1 })],
    ];
    for (const [porque, d] of malos) {
      await sembrar(`ordenes/${ID}`, orden({ estadoEntrega: 'preparando' }));
      const cambio = { estadoEntrega: 'despachada', actualizadaEn: serverTimestamp() };
      if (d !== undefined) cambio.despacho = d;
      await assertFails(updateDoc(ordenDe(admin), cambio), porque);
    }
  });

  test('un pedido de la vidriera impago NO sale; pagado, si', async () => {
    await sembrar(`ordenes/${ID}`, orden({ origen: 'vidriera', estadoPago: 'pendiente', estadoEntrega: 'preparando' }));
    await assertFails(updateDoc(ordenDe(admin), paso('despachada')));
    await sembrar(`ordenes/${ID}`, orden({ origen: 'vidriera', estadoPago: 'pagada', estadoEntrega: 'preparando' }));
    await assertSucceeds(updateDoc(ordenDe(admin), paso('despachada')));
  });

  test('los otros pasos no llevan despacho', async () => {
    await sembrar(`ordenes/${ID}`, orden());
    await assertFails(updateDoc(ordenDe(admin), { ...paso('preparando'), despacho: despacho() }));
    await sembrar(`ordenes/${ID}`, orden({ estadoEntrega: 'despachada', despacho: { correo: 'oca', seguimiento: null, en: new Date() } }));
    await assertFails(updateDoc(ordenDe(admin), { ...paso('entregada'), despacho: despacho() }));
    // Control positivo: entregar, sin tocar el despacho, pasa.
    await assertSucceeds(updateDoc(ordenDe(admin), paso('entregada')));
  });
});

describe('EP-07: una entrega que fallo lleva su motivo, y se vuelve a despachar', () => {
  const fallar = (f) => updateDoc(ordenDe(admin), { estadoEntrega: 'fallida', entregaFallida: f, actualizadaEn: serverTimestamp() });
  const enCamino = () => orden({ estadoEntrega: 'despachada', despacho: { correo: 'oca', seguimiento: null, en: new Date() } });

  test('cada motivo del contrato pasa, y el legal esta', async () => {
    assert.ok(DESPACHO.motivosDeFalla.includes('sin_mayor'));
    for (const motivo of DESPACHO.motivosDeFalla) {
      await sembrar(`ordenes/${ID}`, enCamino());
      await assertSucceeds(fallar(falla({ motivo })));
    }
  });

  test('sin motivo, o con uno inventado, no', async () => {
    for (const [porque, f] of [
      ['sin motivo', { en: serverTimestamp() }],
      ['motivo inventado', falla({ motivo: 'llovio' })],
      ['una hora del cliente', falla({ en: new Date('2026-01-01T00:00:00Z') })],
      ['una clave de mas', falla({ quien: 'x' })],
    ]) {
      await sembrar(`ordenes/${ID}`, enCamino());
      await assertFails(fallar(f), porque);
    }
    await sembrar(`ordenes/${ID}`, enCamino());
    await assertFails(updateDoc(ordenDe(admin), { estadoEntrega: 'fallida', actualizadaEn: serverTimestamp() }), 'sin el campo');
  });

  test('volver a despachar: con un despacho nuevo, y la falla queda escrita', async () => {
    await sembrar(`ordenes/${ID}`, orden({ estadoEntrega: 'fallida', entregaFallida: { motivo: 'nadie', en: new Date() } }));
    await assertSucceeds(updateDoc(ordenDe(admin), paso('despachada')));
    // `withSecurityRulesDisabled` NO devuelve lo que devuelve el callback: se lee
    // a una variable de afuera (medido en CI, corrida 36184205692).
    let o;
    await entorno.withSecurityRulesDisabled(async (ctx) => {
      o = (await getDoc(doc(ctx.firestore(), 'ordenes', ID))).data();
    });
    assert.equal(o.estadoEntrega, 'despachada');
    assert.equal(o.entregaFallida.motivo, 'nadie', 'el despacho nuevo no borra por que fallo el anterior');
  });

  test('volver a despachar no deja borrar ni cambiar la falla', async () => {
    await sembrar(`ordenes/${ID}`, orden({ estadoEntrega: 'fallida', entregaFallida: { motivo: 'nadie', en: new Date() } }));
    await assertFails(updateDoc(ordenDe(admin), { ...paso('despachada'), entregaFallida: deleteField() }));
    await assertFails(updateDoc(ordenDe(admin), { ...paso('despachada'), entregaFallida: falla({ motivo: 'otro' }) }));
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
