#!/usr/bin/env node
// auditar_estados.mjs - que el contrato generado este FRESCO, y que el lado de
// Dart lo cubra entero.
//
// El nombre dice "estados" porque nacio con ellos; hoy el contrato generado
// lleva ademas las FIXTURES DE TEXTO (ARQUITECTURA §7).  Se audita lo mismo y
// por el mismo motivo: el espejo en Dart se verifica contra ese JSON, asi que
// un JSON viejo convierte el test de Dart en teatro.
//
// ===========================================================================
// POR QUE ESTE ARCHIVO ES OBLIGATORIO Y NO UN LUJO
//
// El panel en Flutter espeja los estados en un enum de Dart y un test compara
// ese enum contra generated/contratos.json. Suena suficiente y NO LO ES: si
// nadie verifica que el JSON este al dia, el JSON envejece, el test de Dart
// pasa contra un contrato que ya no existe, y el test se vuelve teatro.
//
// Es el mismo modo de falla que el vault documentando la intencion en vez del
// comportamiento, pero en codigo - y con la agravante de que hay un test verde
// dando confianza.
// ===========================================================================

import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';

import { DESTINO, construirContrato, serializar } from '../../packages/contratos/scripts/generar.mjs';

let fallos = 0;
const problema = (msg) => {
  console.error(`::error::${msg}`);
  fallos++;
};

// ---------------------------------------------------------------------------
// 1. El JSON committeado es exactamente lo que produce el TypeScript de hoy.
// ---------------------------------------------------------------------------
const esperado = serializar(construirContrato());

if (!existsSync(DESTINO)) {
  problema(`falta ${DESTINO}. Corre: npm run -w @bouquet/contratos generar`);
} else {
  const enDisco = readFileSync(DESTINO, 'utf8');
  if (enDisco !== esperado) {
    problema(
      'generated/contratos.json esta desactualizado respecto del TypeScript.\n' +
        '  Corre: npm run -w @bouquet/contratos generar   y commitea el resultado.\n' +
        '  Si no, el test de Dart compara contra un contrato viejo y pasa por nada.',
    );
  } else {
    console.log('ok  contratos.json esta fresco');
  }
}

const contrato = construirContrato();

// ---------------------------------------------------------------------------
// 2. Coherencia interna del contrato.
// ---------------------------------------------------------------------------
for (const eje of ['pago', 'entrega']) {
  const { estados, naceEn, transiciones } = contrato[eje];
  for (const e of naceEn) {
    if (!estados.includes(e)) problema(`${eje}: naceEn incluye "${e}", que no es un estado`);
  }
  for (const [desde, hacia] of Object.entries(transiciones)) {
    if (!estados.includes(desde)) problema(`${eje}: transicion desde "${desde}", que no existe`);
    for (const h of hacia) {
      if (!estados.includes(h)) problema(`${eje}: "${desde}" va a "${h}", que no existe`);
    }
  }
  // Un estado inalcanzable es codigo muerto con nombre: ni nace ni se llega.
  for (const e of estados) {
    const alcanzable =
      naceEn.includes(e) || Object.values(transiciones).some((h) => h.includes(e));
    if (!alcanzable) problema(`${eje}: a "${e}" no se llega desde ningun lado`);
  }
}

const pares = Object.keys(contrato.publico.proyeccion).length;
const esperados = contrato.pago.estados.length * contrato.entrega.estados.length;
if (pares !== esperados) {
  problema(`la proyeccion cubre ${pares} pares y deberian ser ${esperados}`);
} else {
  console.log(`ok  la proyeccion cubre los ${pares} pares`);
}

for (const [par, publico] of Object.entries(contrato.publico.proyeccion)) {
  if (!contrato.publico.estados.includes(publico)) {
    problema(`el par ${par} proyecta a "${publico}", que no es un estado publico`);
  }
  if (!contrato.publico.rotulos[publico]) {
    problema(`"${publico}" no tiene rotulo`);
  }
}

// ---------------------------------------------------------------------------
// 2 bis. Las fixtures de texto (ARQUITECTURA §7).
//
// Un set de fixtures sin control negativo no distingue una implementacion
// correcta de una que devuelve siempre lo mismo.  Por eso no alcanza con que
// la seccion exista: tiene que tener los dos lados de cada pregunta.
// ---------------------------------------------------------------------------
const texto = contrato.texto;
const antes = fallos;

if (!texto || !Array.isArray(texto.casos) || !Array.isArray(texto.pares)) {
  problema('el contrato no trae la seccion `texto` con `casos` y `pares`');
} else {
  const slugs = texto.casos.map((c) => c.aSlug);
  if (!slugs.some((s) => s !== '')) {
    problema('texto: ninguna fixture produce un slug -- falta el control positivo');
  }
  if (!slugs.some((s) => s === '')) {
    problema('texto: ninguna fixture deja el slug vacio -- falta el control negativo');
  }

  // El slug generado tiene que ser el que firestore.rules acepta, o el panel
  // escribe documentos que las reglas rechazan recien en produccion.
  const ES_SLUG = /^[a-z0-9]+(-[a-z0-9]+)*$/;
  for (const c of texto.casos) {
    if (c.aSlug !== '' && !ES_SLUG.test(c.aSlug)) {
      problema(`texto: "${c.entrada}" da el slug "${c.aSlug}", que esSlug rechaza`);
    }
  }

  const parecen = texto.pares.map((p) => p.seParecen);
  if (!parecen.includes(true)) problema('texto: ningun par se parece -- falta el control positivo');
  if (!parecen.includes(false)) problema('texto: todos los pares se parecen -- falta el control negativo');

  if (fallos === antes) {
    console.log(
      `ok  las fixtures de texto tienen sus dos controles ` +
        `(${texto.casos.length} casos, ${texto.pares.length} pares)`,
    );
  }
}

// ---------------------------------------------------------------------------
// 2 ter. Las fixtures de plata.
//
// El panel muestra los mismos precios que la vidriera, y "$12,500.00" contra
// "$ 12.500,00" no es un formato distinto: es otro numero para quien lo lee.
// ---------------------------------------------------------------------------
if (!contrato.plata || !Array.isArray(contrato.plata.casos) || !contrato.plata.casos.length) {
  problema('el contrato no trae la seccion `plata` con sus casos');
} else {
  const montos = contrato.plata.casos.map((c) => c.centavos);
  // Sin un monto de mas de mil, una implementacion sin separador de miles
  // pasa; sin uno negativo, una que ignora el signo tambien.
  if (!montos.some((c) => c >= 100000)) problema('plata: ninguna fixture tiene separador de miles');
  if (!montos.some((c) => c < 0)) problema('plata: ninguna fixture es negativa');
  if (!contrato.plata.casos.every((c) => typeof c.ars === 'string' && c.ars.includes(' '))) {
    problema('plata: alguna fixture no lleva el espacio duro U+00A0 entre el signo y la cifra');
  }
  console.log(`ok  las fixtures de plata cubren miles, negativo y el espacio duro (${montos.length} casos)`);
}

// ---------------------------------------------------------------------------
// 2 ter bis. El pedido del panel (HU-10.1, ADR 018).
//
// El panel muestra como quedo un telefono antes de confirmar, y el servidor
// guarda el que sale de `normalizarTelefonoAR`.  Si los dos difieren, `wa.me`
// abre el chat de otra persona.  Mismas dos preguntas que en el texto: sin un
// numero que se normaliza y uno que se rechaza, una implementacion que
// acepta todo o que rechaza todo pasa.
//
// Y el origen: `whatsapp` y `vidriera` tienen que nacer con estados de pago
// DISTINTOS, o la funcion no decide nada.
// ---------------------------------------------------------------------------
const pedido = contrato.pedido;
const antesDelPedido = fallos;

if (!pedido || !Array.isArray(pedido.telefonos) || !pedido.estadoDePagoInicial) {
  problema('el contrato no trae la seccion `pedido` con `telefonos` y `estadoDePagoInicial`');
} else {
  const salidas = pedido.telefonos.map((t) => t.e164);
  if (!salidas.some((s) => s !== null)) problema('pedido: ningun telefono se normaliza -- falta el control positivo');
  if (!salidas.some((s) => s === null)) problema('pedido: ningun telefono se rechaza -- falta el control negativo');
  for (const s of salidas) {
    if (s !== null && !/^\+549\d{10}$/.test(s)) problema(`pedido: "${s}" no es E.164 argentino movil`);
  }

  const inicial = pedido.estadoDePagoInicial;
  for (const o of pedido.origenes) {
    if (!contrato.pago.estados.includes(inicial[o])) problema(`pedido: ${o} nace en "${inicial[o]}", que no es un estado de pago`);
    if (!contrato.pago.naceEn.includes(inicial[o])) problema(`pedido: ${o} nace en "${inicial[o]}", que no esta en naceEn`);
  }
  if (new Set(pedido.origenes.map((o) => inicial[o])).size !== pedido.origenes.length) {
    problema('pedido: dos origenes nacen con el mismo estado de pago -- la funcion no decide nada');
  }
  // `por_fuera` no se alcanza por transicion: el unico camino es nacer asi.
  if (contrato.pago.transiciones.por_fuera?.length) {
    problema('pedido: `por_fuera` tiene transiciones de salida y tiene que ser terminal');
  }
  if (Object.values(contrato.pago.transiciones).some((h) => h.includes('por_fuera'))) {
    problema('pedido: algun estado de pago pasa a `por_fuera`; sólo se nace asi');
  }

  if (fallos === antesDelPedido) {
    console.log(`ok  el pedido del panel: ${salidas.length} telefonos con sus dos controles, y los origenes nacen distinto`);
  }
}

// ---------------------------------------------------------------------------
// 2 quater. Las fixtures del catalogo: el balde, el tope y los descartes.
//
// El panel dice si un vino se ve en la tienda, y cuando no se ve dice por que.
// Esa regla vive en `armarCatalogo` y el panel la ESPEJA en Dart, asi que vale
// lo mismo que para el texto: sin los dos controles, el espejo puede estar
// roto y pasar igual.
//
//   · Sin los TRES baldes, un espejo que devuelve siempre `disponible` pasa.
//   · Sin un documento que ENTRA al catalogo, uno que descarta todo pasa.
//
// Y ademas se compara la etiqueta declarada en la fixture (`clase`) contra lo
// que `armarCatalogo` hizo de verdad: si manana deja de descartar por uno de
// esos motivos, la fixture lo dice en vez de envejecer en silencio.
// ---------------------------------------------------------------------------
const catalogo = contrato.catalogo;
const antesDelCatalogo = fallos;

if (!catalogo || !Array.isArray(catalogo.casosDeBalde) || !Array.isArray(catalogo.casosDeDescarte)) {
  problema('el contrato no trae la seccion `catalogo` con `casosDeBalde` y `casosDeDescarte`');
} else {
  // --- el balde: los tres, y las dos formas de unidad -----------------------
  const baldes = new Set(catalogo.casosDeBalde.map((c) => c.balde));
  const sinCaso = (catalogo.baldes ?? []).filter((b) => !baldes.has(b));
  if (sinCaso.length) {
    problema(
      `catalogo: ninguna fixture da el balde ${sinCaso.join(', ')} -- ` +
        'un espejo que devuelve siempre el mismo balde pasaria',
    );
  }
  for (const b of baldes) {
    if (!(catalogo.baldes ?? []).includes(b)) problema(`catalogo: la fixture da el balde "${b}", que no existe`);
  }
  // El balde se mide en BOTELLAS: un espejo que compara el stock contra el
  // umbral sin multiplicar por la presentacion acierta en toda botella suelta.
  if (!catalogo.casosDeBalde.some((c) => c.botellas === 1)) {
    problema('catalogo: ninguna fixture del balde es una botella suelta');
  }
  if (!catalogo.casosDeBalde.some((c) => c.botellas > 1)) {
    problema('catalogo: ninguna fixture del balde es una caja -- el balde se mide en botellas');
  }
  // El tope se corta de los dos lados. Sin un stock arriba de 12 no se
  // distingue `min(stock, 12)` de `stock`; sin uno negativo, `max(0, ...)`.
  if (!catalogo.casosDeBalde.some((c) => c.stock > catalogo.topePorPedido)) {
    problema('catalogo: ninguna fixture pasa el tope por pedido -- el corte de arriba no se mide');
  }
  if (!catalogo.casosDeBalde.some((c) => c.stock < 0)) {
    problema('catalogo: ninguna fixture tiene stock negativo -- el corte en 0 no se mide');
  }

  // --- los descartes: el que entra y uno por motivo -------------------------
  const entran = catalogo.casosDeDescarte.filter((c) => c.entra);
  if (!entran.length) {
    problema(
      'catalogo: ninguna fixture entra al catalogo -- falta el control positivo, ' +
        'y un espejo que descarta todo pasaria',
    );
  }
  const descartados = catalogo.casosDeDescarte.filter((c) => !c.entra);
  if (!descartados.length) {
    problema('catalogo: ninguna fixture queda afuera -- falta el control negativo');
  }
  const clases = new Set(descartados.map((c) => c.clase));
  const sinFixture = (catalogo.clasesDeDescarte ?? []).filter((c) => c !== 'entra' && !clases.has(c));
  if (sinFixture.length) {
    problema(`catalogo: ningun documento se descarta por: ${sinFixture.join(', ')}`);
  }

  // --- la etiqueta contra lo que paso de verdad -----------------------------
  for (const c of catalogo.casosDeDescarte) {
    if (c.entra !== (c.motivo === null)) {
      problema(`catalogo: "${c.id}" dice entra=${c.entra} y motivo=${JSON.stringify(c.motivo)}`);
    }
    if ((c.clase === 'entra') !== c.entra) {
      problema(
        `catalogo: "${c.id}" esta declarado como "${c.clase}" y armarCatalogo ` +
          (c.entra ? 'lo deja entrar' : `lo descarta: ${c.motivo}`),
      );
    }
  }

  // --- la clase contra el MOTIVO real, no solo contra entra/no-entra --------
  // BAJO 2 de revisor-pagos (ADR 014): tener el motivo en la mano y sólo
  // comparar entra/no-entra deja pasar una etiqueta mal puesta -- una
  // fixture declarada "no-valida" cuyo motivo real es "no publicado" pasaba
  // igual. `no-valida` es la excepcion: agrupa motivos muy distintos
  // (precio 0, un varietal fuera de la lista, el slug, el volumen...) y no
  // tiene un patron unico, asi que se confirma por EXCLUSION de los otros
  // cuatro.
  const PATRON_POR_CLASE = {
    'slug-duplicado': /^slug duplicado/,
    'no-publicado': /^no publicado$/,
    compuesto: /^compuesto:/,
    'bodega-inexistente': /^bodega inexistente:/,
  };
  for (const c of descartados) {
    if (c.clase === 'no-valida') {
      const otraClase = Object.entries(PATRON_POR_CLASE).find(([, p]) => p.test(c.motivo ?? ''));
      if (otraClase) {
        problema(
          `catalogo: "${c.id}" declarado "no-valida" pero el motivo real es ` +
            `de la clase "${otraClase[0]}": ${c.motivo}`,
        );
      }
    } else {
      const patron = PATRON_POR_CLASE[c.clase];
      if (patron && !patron.test(c.motivo ?? '')) {
        problema(`catalogo: "${c.id}" declarado "${c.clase}" pero el motivo no calza: ${c.motivo}`);
      }
    }
  }

  const ids = catalogo.casosDeDescarte.map((c) => c.id);
  if (new Set(ids).size !== ids.length) {
    problema('catalogo: hay ids repetidos en las fixtures -- el motivo se mapea por id');
  }

  if (fallos === antesDelCatalogo) {
    console.log(
      `ok  las fixtures del catalogo cubren los ${baldes.size} baldes y ` +
        `${clases.size} motivos, con ${entran.length} que entra(n) ` +
        `(${catalogo.casosDeBalde.length} casos de balde, ${catalogo.casosDeDescarte.length} documentos)`,
    );
  }
}

// ---------------------------------------------------------------------------
// 3. El lado de Dart.
//
// Si todavia no existe, se DICE que no se verifico. Un verificador que se
// saltea en silencio es indistinguible de uno que paso.
// ---------------------------------------------------------------------------
const DIR_ADMIN = 'apps/admin/lib';

if (!existsSync(DIR_ADMIN)) {
  console.log(`--  Dart NO verificado: todavia no existe ${DIR_ADMIN}`);
} else {
  const dart = [];
  const recorrer = (d) => {
    for (const e of readdirSync(d, { withFileTypes: true })) {
      const p = join(d, e.name);
      if (e.isDirectory()) recorrer(p);
      else if (e.name.endsWith('.dart')) dart.push(readFileSync(p, 'utf8'));
    }
  };
  recorrer(DIR_ADMIN);
  const fuente = dart.join('\n');

  const faltantes = [
    ...contrato.pago.estados,
    ...contrato.entrega.estados,
    ...contrato.publico.estados,
  ].filter((e) => !new RegExp(`\\b${e}\\b`).test(fuente));

  if (faltantes.length) {
    problema(`el panel en Dart no menciona estos estados: ${faltantes.join(', ')}`);
  } else {
    console.log('ok  el panel en Dart cubre todos los estados del contrato');
  }

  // El espejo de la normalizacion.  Sin esto, alguien puede agregar una
  // funcion a texto.ts, regenerar el JSON, y el panel seguir con su propia
  // implementacion sin que nada lo diga -- que es exactamente la segunda
  // implementacion que ARQUITECTURA §7 existe para no tener.
  const sinEspejo = ['normalizar', 'clave', 'aSlug', 'seParecen', 'enPesos', 'normalizarTelefonoAR'].filter(
    (f) => !new RegExp(String.raw`\b` + f + String.raw`\(`).test(fuente),
  );
  if (sinEspejo.length) {
    problema(`el panel en Dart no espeja: ${sinEspejo.join(', ')} (ARQUITECTURA §7)`);
  } else {
    console.log('ok  el panel en Dart espeja la normalizacion y el formato de plata');
  }
}

if (fallos) {
  console.error(`\n${fallos} problema(s) en el contrato de estados`);
  process.exit(1);
}
console.log('\ncontrato de estados: sin problemas');
