#!/usr/bin/env node
// verificar_enlaces.mjs - todo enlace relativo entre documentos resuelve,
// anclas incluidas.
//
// Por que vale la pena tenerlo desde el dia 1: la documentacion de este
// proyecto se referencia entre archivos (ARQUITECTURA -> ADRs -> glosario), y
// un enlace roto no falla ruidosamente: falla cuando alguien lo sigue, meses
// despues, y concluye que el documento no existe.
//
// Sin dependencias a proposito. Node y nada mas.

import { readFileSync, existsSync } from 'node:fs';
import { readdir } from 'node:fs/promises';
import { join, dirname, relative, resolve, sep } from 'node:path';

const RAIZ = resolve(process.argv[2] ?? '.');
const IGNORAR = new Set(['node_modules', '.git', '.next', 'build', '.dart_tool']);

// Las skills de terceros traen su propia documentacion, con enlaces a archivos
// que ese repo no vendoriza. No son nuestras para arreglar y hacian fallar el
// check entero. Se ignora .agents/ por RUTA, no por nombre, para no ignorar de
// rebote cualquier carpeta que se llame asi.
const IGNORAR_RUTAS = new Set(['.agents']);

// Y bajo .claude/skills/ conviven las nuestras con las de terceros. La lista
// autoritativa de cuales son ajenas es skills-lock.json, no el tipo de archivo:
// el CLI de skills.sh a veces symlinkea y a veces COPIA (medido: openspec-sync-specs
// y writing-guidelines quedaron como carpetas reales). Filtrar por symlink
// dejaba pasar las copiadas y volvia a romper el check.
const SKILLS_AJENAS = (() => {
  const lock = join(RAIZ, 'skills-lock.json');
  if (!existsSync(lock)) return new Set();
  try {
    return new Set(Object.keys(JSON.parse(readFileSync(lock, 'utf8')).skills ?? {}));
  } catch {
    return new Set();
  }
})();
const DIR_SKILLS = join('.claude', 'skills');

async function markdowns(dir) {
  const salida = [];
  for (const e of await readdir(dir, { withFileTypes: true })) {
    if (IGNORAR.has(e.name)) continue;
    const p = join(dir, e.name);
    const rel = relative(RAIZ, p);
    if (IGNORAR_RUTAS.has(rel)) continue;
    if (dirname(rel) === DIR_SKILLS && SKILLS_AJENAS.has(e.name)) continue;
    if (e.isDirectory()) salida.push(...(await markdowns(p)));
    else if (e.name.endsWith('.md')) salida.push(p);
  }
  return salida;
}

// Mismo algoritmo de slug que GitHub: minusculas, se cae la puntuacion,
// los espacios pasan a guiones.
function anclas(texto) {
  const s = new Set();
  for (const m of texto.matchAll(/^#{1,6}\s+(.*)$/gm)) {
    s.add(
      m[1]
        .trim()
        .toLowerCase()
        .replace(/[^\p{L}\p{N}\s-]/gu, '')
        .trim()
        .replace(/\s+/g, '-')
    );
  }
  return s;
}

const archivos = await markdowns(RAIZ);
const rotos = [];
let revisados = 0;

for (const archivo of archivos) {
  const texto = readFileSync(archivo, 'utf8');
  for (const m of texto.matchAll(/\]\(([^)\s]+)\)/g)) {
    const destino = m[1];
    if (/^(https?:|mailto:|#)/.test(destino)) continue;
    const [ruta, ancla] = destino.split('#');
    const resuelto = resolve(dirname(archivo), ruta);
    revisados++;
    if (!existsSync(resuelto)) {
      rotos.push([relative(RAIZ, archivo), destino, 'el archivo no existe']);
      continue;
    }
    if (ancla && !anclas(readFileSync(resuelto, 'utf8')).has(ancla)) {
      rotos.push([relative(RAIZ, archivo), destino, 'el ancla no existe']);
    }
  }
}

console.log(`archivos .md: ${archivos.length}`);
console.log(`enlaces relativos verificados: ${revisados}`);

if (rotos.length) {
  console.error(`\n${rotos.length} enlace(s) roto(s):`);
  for (const [a, d, m] of rotos) console.error(`  ${a.split(sep).join('/')}  ->  ${d}   (${m})`);
  process.exit(1);
}
console.log('todos resuelven');
