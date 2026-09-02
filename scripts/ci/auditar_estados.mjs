#!/usr/bin/env node
// auditar_estados.mjs - que el contrato generado este FRESCO, y que el lado de
// Dart lo cubra entero.
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
}

if (fallos) {
  console.error(`\n${fallos} problema(s) en el contrato de estados`);
  process.exit(1);
}
console.log('\ncontrato de estados: sin problemas');
