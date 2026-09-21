#!/usr/bin/env node
// auditar_varietales.mjs - que la lista cerrada de varietales sea la MISMA en
// firestore.rules, en packages/contratos y en el panel. Y, desde ADR 013, que
// el rango de la graduacion sea el mismo en los tres.
//
// ===========================================================================
// Ni las reglas ni Dart pueden importar TypeScript, asi que la lista vive tres
// veces. Tres copias del mismo dato se desincronizan (LECCIONES 6.4), y aca el
// modo de falla es silencioso EN TODAS LAS DIRECCIONES:
//
//   - una uva en contratos o en el panel y no en las reglas: el panel la
//     ofrece y la escritura rebota con un permission-denied que parece de
//     permisos.
//   - una uva en las reglas y no en contratos: se guarda, y la vidriera
//     descarta el producto entero porque no valida. Desaparece del catalogo
//     sin un error visible.
//   - una uva en contratos y no en el panel: nadie la puede cargar, y nadie
//     se entera de por que.
//
// Contra el panel se compara ademas el ORDEN: el formulario muestra las uvas
// en ese orden y un vino nuevo las guarda en ese orden.
// ===========================================================================
//
// Uso:  node scripts/ci/auditar_varietales.mjs [firestore.rules] [producto.dart]
//
// Los argumentos existen para el control negativo: apuntarlos a una copia con
// una uva de mas y ver que sale con 1.

import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { DESCRIPCION_MAXIMA, GRADUACION_MAXIMA, GRADUACION_MINIMA, VARIETALES } from '../../packages/contratos/src/producto.ts';

const RAIZ = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const rutaReglas = process.argv[2] ?? join(RAIZ, 'firestore.rules');
const rutaDart = process.argv[3] ?? join(RAIZ, 'apps', 'admin', 'lib', 'core', 'contratos', 'producto.dart');

let fallos = 0;
const problema = (msg) => {
  console.error(`::error::${msg}`);
  fallos++;
};

/** La lista entre las marcas, o `null` si las marcas no estan. */
function leerBloque(ruta) {
  const texto = readFileSync(ruta, 'utf8');
  const bloque = /\/\/ varietales:inicio([\s\S]*?)\/\/ varietales:fin/.exec(texto);
  if (!bloque) return { texto, lista: null };
  return { texto, lista: [...(bloque[1] ?? '').matchAll(/'([^']+)'/g)].map((m) => m[1]) };
}

const enContratos = [...VARIETALES];
const reglas = leerBloque(rutaReglas);
const dart = leerBloque(rutaDart);

// Un verificador que no encuentra que verificar no puede salir 0: seria
// indistinguible de uno que comparo y dio igual.
for (const [nombre, ruta, lista] of [
  ['las reglas', rutaReglas, reglas.lista],
  ['el panel', rutaDart, dart.lista],
]) {
  if (lista === null) {
    problema(`${ruta} no tiene el bloque "// varietales:inicio" ... "// varietales:fin"`);
    continue;
  }
  if (lista.length === 0) problema(`el bloque de varietales de ${nombre} esta vacio`);
  if (new Set(lista).size !== lista.length) problema(`${nombre} repite un varietal`);

  const soloEnContratos = enContratos.filter((v) => !lista.includes(v));
  const soloAca = lista.filter((v) => !enContratos.includes(v));
  if (soloEnContratos.length) problema(`en contratos y NO en ${nombre}: ${soloEnContratos.join(', ')}`);
  if (soloAca.length) problema(`en ${nombre} y NO en contratos: ${soloAca.join(', ')}`);
}

if (dart.lista && dart.lista.join('|') !== enContratos.join('|')) {
  if (dart.lista.length === enContratos.length && fallos === 0) {
    problema('el panel tiene las mismas uvas que contratos pero en OTRO ORDEN');
  }
}

// ------------------------------------------------------------- graduacion
//
// Tres copias de dos numeros. Si el panel acepta 4,5 % y las reglas no, la
// escritura rebota con un permission-denied; si las reglas aceptan 14 y
// contratos no, la vidriera descarta el vino sin avisar.
const enReglas = /f\.graduacion >= (\d+) && f\.graduacion <= (\d+)/.exec(reglas.texto);
const minDart = /const graduacionMinima = (\d+);/.exec(dart.texto);
const maxDart = /const graduacionMaxima = (\d+);/.exec(dart.texto);
if (!enReglas) problema(`${rutaReglas} no tiene el rango de la graduacion`);
if (!minDart || !maxDart) problema(`${rutaDart} no tiene graduacionMinima y graduacionMaxima`);
if (enReglas && minDart && maxDart) {
  const rangos = {
    contratos: `${GRADUACION_MINIMA}-${GRADUACION_MAXIMA}`,
    reglas: `${enReglas[1]}-${enReglas[2]}`,
    panel: `${minDart[1]}-${maxDart[1]}`,
  };
  if (new Set(Object.values(rangos)).size !== 1) {
    problema(`el rango de la graduacion no coincide: ${JSON.stringify(rangos)}`);
  }
}

// ------------------------------------------------------------ descripcion
//
// El tope tambien vive tres veces. Si el formulario deja escribir mas de lo
// que aceptan las reglas, el operador pierde lo que escribio en un
// permission-denied; si las reglas aceptan mas que contratos, el vino se cae
// de la vidriera sin un error visible. Y sin esta comparacion los tests de
// cada lado se miden contra si mismos: pasarian los tres con el tope en 5.
const topeReglas = /f\.descripcion\.size\(\) <= (\d+)/.exec(reglas.texto);
const topeDart = /const descripcionMaxima = (\d+);/.exec(dart.texto);
if (!topeReglas) problema(`${rutaReglas} no tiene el tope de la descripcion`);
if (!topeDart) problema(`${rutaDart} no tiene descripcionMaxima`);
if (topeReglas && topeDart) {
  const topes = {
    contratos: String(DESCRIPCION_MAXIMA),
    reglas: topeReglas[1],
    panel: topeDart[1],
  };
  if (new Set(Object.values(topes)).size !== 1) {
    problema(`el tope de la descripcion no coincide: ${JSON.stringify(topes)}`);
  }
}

if (fallos) {
  console.error(`\n${fallos} problema(s) con las listas cerradas del producto`);
  process.exit(1);
}
console.log(
  `ok  ${enContratos.length} varietales, los mismos y en el mismo orden en contratos, firestore.rules y el panel;` +
    ` graduacion ${GRADUACION_MINIMA}-${GRADUACION_MAXIMA} y descripcion <= ${DESCRIPCION_MAXIMA} en los tres`,
);
