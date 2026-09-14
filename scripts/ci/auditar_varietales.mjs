#!/usr/bin/env node
// auditar_varietales.mjs - que la lista cerrada de varietales de
// firestore.rules sea la MISMA que la de packages/contratos.
//
// ===========================================================================
// Las reglas no pueden importar TypeScript, asi que la lista vive dos veces.
// Dos copias del mismo dato se desincronizan (LECCIONES 6.4), y aca el modo de
// falla es silencioso EN LAS DOS DIRECCIONES:
//
//   - una uva en contratos y no en las reglas: el panel la ofrece y la
//     escritura rebota con un permission-denied que parece de permisos.
//   - una uva en las reglas y no en contratos: se guarda, y la vidriera
//     descarta el producto entero porque no valida. Desaparece del catalogo
//     sin un error visible.
// ===========================================================================
//
// Uso:  node scripts/ci/auditar_varietales.mjs [ruta/a/firestore.rules]
//
// El argumento existe para el control negativo: apuntarlo a una copia con una
// uva de mas y ver que sale con 1.

import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import { VARIETALES } from '../../packages/contratos/src/producto.ts';

const RAIZ = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const ruta = process.argv[2] ?? join(RAIZ, 'firestore.rules');
const reglas = readFileSync(ruta, 'utf8');

const bloque = /\/\/ varietales:inicio([\s\S]*?)\/\/ varietales:fin/.exec(reglas);
if (!bloque) {
  // Un verificador que no encuentra que verificar no puede salir 0: seria
  // indistinguible de uno que comparo y dio igual.
  console.error(`::error::${ruta} no tiene el bloque "// varietales:inicio" ... "// varietales:fin"`);
  process.exit(1);
}

const enReglas = [...(bloque[1] ?? '').matchAll(/'([^']+)'/g)].map((m) => m[1]);
const enContratos = [...VARIETALES];

let fallos = 0;
const problema = (msg) => {
  console.error(`::error::${msg}`);
  fallos++;
};

if (enReglas.length === 0) problema('el bloque de varietales de las reglas esta vacio');
if (new Set(enReglas).size !== enReglas.length) problema('las reglas repiten un varietal');

const soloEnContratos = enContratos.filter((v) => !enReglas.includes(v));
const soloEnReglas = enReglas.filter((v) => !enContratos.includes(v));
if (soloEnContratos.length) {
  problema(`en contratos y NO en las reglas (el panel los ofrece y la escritura rebota): ${soloEnContratos.join(', ')}`);
}
if (soloEnReglas.length) {
  problema(`en las reglas y NO en contratos (se guardan y la vidriera los descarta): ${soloEnReglas.join(', ')}`);
}

if (fallos) {
  console.error(`\n${fallos} problema(s) con la lista de varietales`);
  process.exit(1);
}
console.log(`ok  ${enReglas.length} varietales, los mismos en firestore.rules y en contratos`);
