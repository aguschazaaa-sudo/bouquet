#!/usr/bin/env node
// generar_verdad.mjs - escribe docs/vault/_verdad.md DESDE EL CODIGO.
//
// ===========================================================================
// POR QUE ESTE ARCHIVO EXISTE
//
// El vault documenta la INTENCION. Este archivo documenta el COMPORTAMIENTO,
// derivado de leer el repo. La diferencia entre los dos es la deuda del
// proyecto, MEDIDA.
//
// En el proyecto anterior el vault declaro CUATRO VECES en seis meses que una
// feature estaba entregada cuando no tenia puerta: una decia "59/59 completa"
// y no tenia ni ruta ni entrada de navegacion. La skill que generaba el vault
// desde el codigo existia y NADIE LA CORRIA (SKILLS-AGENTES-MCP.md 3.3).
//
// Por eso esto es un script de CI y no una skill: lo que documenta el
// comportamiento no puede depender de que alguien se acuerde de invocarlo.
// Una skill que hay que acordarse de correr tiene la misma tasa de ejecucion
// que una nota mental.
//
// La seccion que mas vale es la 7: por cada simbolo exportado, QUIEN LO ABRE.
// Un simbolo cuyo unico consumidor es su propio test esta escrito, no
// entregado.
//
// Sin dependencias a proposito. Node y nada mas: 7,9 GB de RAM.
// ===========================================================================
//
// Uso:
//   node scripts/ci/generar_verdad.mjs .            escribe el archivo
//   node scripts/ci/generar_verdad.mjs . --check    exit 1 si difiere (CI)
//
// El repo esta en fase temprana: hoy solo existe packages/contratos. Toda
// seccion cuya fuente no exista se emite VACIA y dice que no existe. Un
// generador que se saltea una seccion en silencio es indistinguible de uno
// que la encontro vacia.

import { existsSync, mkdirSync, readdirSync, readFileSync, writeFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { dirname, extname, join, relative, resolve } from 'node:path';

// ---------------------------------------------------------------------------
// Argumentos - mismo contrato que los otros scripts de scripts/ci/.
// ---------------------------------------------------------------------------
const ARGS = process.argv.slice(2);
const MODO_CHECK = ARGS.includes('--check');
const RAIZ = resolve(ARGS.find((a) => !a.startsWith('-')) ?? '.');
const DESTINO = join(RAIZ, 'docs', 'vault', '_verdad.md');

// La linea de procedencia (fecha + commit) NO entra en la comparacion del
// --check, y eso es deliberado: si entrara, el archivo quedaria desactualizado
// por construccion. Es imposible que _verdad.md contenga el hash del commit
// que lo contiene, y una fecha de pared haria fallar el CI al dia siguiente
// sin que el codigo hubiera cambiado. El --check compara el CUERPO: lo que el
// codigo hace. La procedencia es procedencia.
const MARCA_PROCEDENCIA = '> **Generado:**';

const IGNORAR_NOMBRE = new Set([
  'node_modules',
  '.git',
  '.next',
  '.dart_tool',
  '.firebase',
  '.vercel',
  'build',
  'dist',
  'out',
  'coverage',
]);

// Por RUTA, no por nombre: bajo .claude/skills/ viven 27 skills de terceros
// que el CLI a veces symlinkea y a veces COPIA. Sus archivos de ejemplo
// inventarian consumidores que no son de este repo.
const IGNORAR_RUTA = ['.claude/skills', '.agents'];

const EXT_CODIGO = new Set(['.ts', '.tsx', '.js', '.jsx', '.mjs', '.cjs']);

// ---------------------------------------------------------------------------
// Utilidades
// ---------------------------------------------------------------------------
const rel = (p) => relative(RAIZ, p).split('\\').join('/');
const hay = (...partes) => existsSync(join(RAIZ, ...partes));

function leer(ruta) {
  try {
    return readFileSync(ruta, 'utf8');
  } catch {
    return null;
  }
}

function leerJSON(ruta) {
  const t = leer(ruta);
  if (t === null) return null;
  try {
    return JSON.parse(t);
  } catch {
    return null;
  }
}

function git(...a) {
  try {
    return execFileSync('git', a, {
      cwd: RAIZ,
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    }).trim();
  } catch {
    return '';
  }
}

function esDirectorio(p) {
  try {
    readdirSync(p);
    return true;
  } catch {
    return false;
  }
}

function caminar(dir, aceptar, salida = []) {
  let entradas;
  try {
    entradas = readdirSync(dir, { withFileTypes: true });
  } catch {
    return salida;
  }
  for (const e of entradas) {
    if (IGNORAR_NOMBRE.has(e.name)) continue;
    const p = join(dir, e.name);
    const r = rel(p);
    if (IGNORAR_RUTA.some((x) => r === x || r.startsWith(x + '/'))) continue;
    if (e.isDirectory()) caminar(p, aceptar, salida);
    else if (e.isFile() && aceptar(p, r)) salida.push(p);
  }
  return salida;
}

// Escapa lo que va adentro de una celda de tabla markdown.
const celda = (s) => String(s).split('|').join('\\|');
const codigo = (s) => '`' + String(s) + '`';
const lista = (a) => (a.length ? a.map(codigo).join(', ') : '-');

const L = [];
const linea = (s = '') => L.push(s);
const nota = (s) => linea(`> **No verificado:** ${s}`);

// ===========================================================================
// Recoleccion
// ===========================================================================

// --- paquetes del workspace -----------------------------------------------
function paquetes() {
  const raizPkg = leerJSON(join(RAIZ, 'package.json'));
  const declarados = raizPkg?.workspaces ?? [];
  const globs = Array.isArray(declarados) ? declarados : (declarados.packages ?? []);
  const dirs = [];
  for (const g of globs) {
    if (g.endsWith('/*')) {
      const base = join(RAIZ, g.slice(0, -2));
      try {
        for (const e of readdirSync(base, { withFileTypes: true })) {
          if (e.isDirectory() && existsSync(join(base, e.name, 'package.json'))) {
            dirs.push(join(base, e.name));
          }
        }
      } catch {
        // el glob apunta a una carpeta que todavia no existe: no es un error
      }
    } else if (existsSync(join(RAIZ, g, 'package.json'))) {
      dirs.push(join(RAIZ, g));
    }
  }
  return {
    raiz: raizPkg,
    paquetes: dirs.map((d) => ({ dir: d, pkg: leerJSON(join(d, 'package.json')) })),
  };
}

// --- simbolos exportados ---------------------------------------------------
const CLASE = {
  const: 'valor',
  let: 'valor',
  var: 'valor',
  function: 'funcion',
  class: 'clase',
  type: 'tipo',
  interface: 'tipo',
  enum: 'enum',
};

function resolverEspecificador(desde, especificador) {
  const base = resolve(dirname(desde), especificador);
  for (const c of [base, base + '.ts', base + '.js', join(base, 'index.ts')]) {
    if (existsSync(c) && !esDirectorio(c)) return c;
  }
  return base;
}

function exportadosDe(archivo, vistos = new Set()) {
  if (vistos.has(archivo)) return [];
  vistos.add(archivo);
  const texto = leer(archivo);
  if (texto === null) return [];
  const salida = [];

  for (const m of texto.matchAll(
    /^export\s+(?:declare\s+)?(?:async\s+)?(const|let|var|function|class|type|interface|enum)\s+([A-Za-z_$][\w$]*)/gm,
  )) {
    salida.push({ nombre: m[2], clase: CLASE[m[1]], modulo: archivo });
  }

  for (const m of texto.matchAll(/^export\s*\{([^}]*)\}(?:\s*from\s*['"]([^'"]+)['"])?/gm)) {
    const modulo = m[2] ? resolverEspecificador(archivo, m[2]) : archivo;
    for (const parte of m[1].split(',')) {
      const t = parte.trim().replace(/^type\s+/, '');
      if (!t) continue;
      const nombre = t.split(/\s+as\s+/).pop().trim();
      if (nombre && nombre !== 'default') salida.push({ nombre, clase: 'reexport', modulo });
    }
  }

  for (const m of texto.matchAll(/^export\s+\*\s+from\s*['"]([^'"]+)['"]/gm)) {
    salida.push(...exportadosDe(resolverEspecificador(archivo, m[1]), vistos));
  }

  return salida;
}

// Un consumidor no vale lo mismo segun quien sea. Esta funcion ES el criterio
// de "tiene puerta", asi que esta escrita aparte para que se pueda discutir.
function tipoDeConsumidor(r) {
  if (/(^|\/)tests?\//.test(r) || /\.test\.[cm]?[jt]sx?$/.test(r)) return 'test';
  if (r.startsWith('packages/') && /(^|\/)scripts\//.test(r)) return 'generador';
  return 'productivo';
}

function puertas(dirSrc, archivosCodigo) {
  const indice = join(dirSrc, 'index.ts');
  const simbolos = [];
  const vistosNombre = new Set();
  for (const s of exportadosDe(indice)) {
    if (vistosNombre.has(s.nombre)) continue;
    vistosNombre.add(s.nombre);
    simbolos.push(s);
  }

  const prefijoPropio = rel(dirSrc) + '/';
  const externos = archivosCodigo
    .map((p) => ({ r: rel(p), texto: leer(p) ?? '' }))
    .filter((f) => !f.r.startsWith(prefijoPropio));

  for (const s of simbolos) {
    const re = new RegExp(`\\b${s.nombre}\\b`);
    s.consumidores = externos.filter((f) => re.test(f.texto)).map((f) => f.r);
    const tipos = new Set(s.consumidores.map(tipoDeConsumidor));
    s.veredicto = tipos.has('productivo')
      ? 'abierto'
      : tipos.has('generador')
        ? 'generador'
        : tipos.has('test')
          ? 'solo-tests'
          : 'nadie';
  }
  return simbolos;
}

// --- tests ------------------------------------------------------------------
// Conteo LEXICO, no ejecucion: correr las suites es otro job y en esta maquina
// no se corren. Verificado contra `npm test` el 2026-09-02: el contador dice
// lo mismo que el runner (26). No cuenta `test.skip(` ni `test.only(`, a
// proposito: un test salteado no es un test que corre.
const RE_TEST = /(^|[^.\w$])(test|it)\s*\(/g;

function tests(archivosTest) {
  return archivosTest
    .map((p) => ({ r: rel(p), n: (leer(p) ?? '').match(RE_TEST)?.length ?? 0 }))
    .sort((a, b) => a.r.localeCompare(b.r));
}

// --- hooks ------------------------------------------------------------------
function hooks(settings) {
  const salida = [];
  for (const [evento, entradas] of Object.entries(settings?.hooks ?? {})) {
    for (const entrada of entradas) {
      for (const h of entrada.hooks ?? []) {
        const m = /hooks\/([\w.-]+\.sh)/.exec(h.command ?? '');
        salida.push({
          evento,
          matcher: entrada.matcher ?? '(todos)',
          script: m ? `scripts/hooks/${m[1]}` : (h.command ?? '?'),
          timeout: h.timeout ?? '-',
          existe: m ? hay('scripts', 'hooks', m[1]) : false,
        });
      }
    }
  }
  return salida;
}

// --- agentes ----------------------------------------------------------------
function agentes(dir) {
  return caminar(dir, (_p, r) => r.endsWith('.md'))
    .map((p) => {
      const texto = leer(p) ?? '';
      const fm = /^---\r?\n([\s\S]*?)\r?\n---/.exec(texto)?.[1] ?? '';
      const campo = (k) => new RegExp(`^${k}:\\s*(.+)$`, 'm').exec(fm)?.[1]?.trim() ?? '';
      const tools = campo('tools')
        .split(',')
        .map((t) => t.trim())
        .filter(Boolean);
      return {
        nombre: campo('name') || rel(p),
        modelo: campo('model') || '-',
        tools,
        escribe: tools.includes('Edit') || tools.includes('Write'),
        bash: tools.includes('Bash'),
      };
    })
    .sort((a, b) => a.nombre.localeCompare(b.nombre));
}

// ===========================================================================
// Construccion del cuerpo
// ===========================================================================
const archivosCodigo = caminar(RAIZ, (p) => EXT_CODIGO.has(extname(p)));
const archivosTest = caminar(RAIZ, (_p, r) => /(\.test\.[cm]?[jt]sx?|_test\.dart)$/.test(r));
const ws = paquetes();
const settings = leerJSON(join(RAIZ, '.claude', 'settings.json'));

linea('# _verdad.md - lo que el codigo hace hoy');
linea();
linea('> ## AVISO: ARCHIVO GENERADO. NO SE EDITA A MANO.');
linea('>');
linea('> Lo produce `scripts/ci/generar_verdad.mjs` leyendo el repo. Cualquier');
linea('> edicion a mano se pierde en la proxima corrida y hace fallar el CI.');
linea('>');
linea('> ```');
linea('> node scripts/ci/generar_verdad.mjs .           # regenerar');
linea('> node scripts/ci/generar_verdad.mjs . --check   # exit 1 si difiere');
linea('> ```');
linea('>');
linea('> [`_index.md`](_index.md) documenta la **INTENCION**. Este archivo documenta el');
linea('> **COMPORTAMIENTO**, derivado del codigo. **La diferencia entre los dos es la');
linea('> deuda del proyecto, medida.** Si se contradicen, este tiene razon.');
linea('>');
linea('> Sin tildes a proposito: lo escribe un script, como todo lo de `scripts/ci/`.');
linea(`${MARCA_PROCEDENCIA} PROCEDENCIA`);
linea();
linea('---');
linea();

// ---------------------------------------------------------------------------
// 1. Estados de Orden
// ---------------------------------------------------------------------------
linea('## 1. La maquina de estados de Orden');
linea();
const RUTA_CONTRATO = join(RAIZ, 'packages', 'contratos', 'generated', 'contratos.json');
const contrato = leerJSON(RUTA_CONTRATO);

if (!contrato) {
  nota(
    '`packages/contratos/generated/contratos.json` no existe o no parsea. ' +
      'Corre `npm run contratos:generar`.',
  );
  linea();
} else {
  linea(
    `Fuente: \`${rel(RUTA_CONTRATO)}\` (version ${contrato.version}), emitido por ` +
      `\`${contrato.generadoPor}\`. Que ese JSON este FRESCO lo verifica ` +
      '`scripts/ci/auditar_estados.mjs`; este archivo solo lo lee.',
  );
  linea();

  for (const eje of ['pago', 'entrega']) {
    const e = contrato[eje];
    if (!e) continue;
    const terminales = e.estados.filter((x) => (e.transiciones[x] ?? []).length === 0);
    linea(`### Eje ${eje} - ${e.estados.length} estados`);
    linea();
    linea('| Estado | Nace ahi | Transiciona a |');
    linea('|---|---|---|');
    for (const x of e.estados) {
      const salidas = e.transiciones[x] ?? [];
      linea(
        `| \`${x}\` | ${e.naceEn.includes(x) ? 'SI' : ''} | ` +
          `${salidas.length ? lista([...salidas]) : '**terminal**'} |`,
      );
    }
    linea();
    linea(`Nace en: ${lista([...e.naceEn])}. Terminales: ${lista(terminales)}.`);
    linea();
  }

  const pub = contrato.publico ?? {};
  const proy = pub.proyeccion ?? {};
  const pares = Object.keys(proy);
  const esperados = (contrato.pago?.estados.length ?? 0) * (contrato.entrega?.estados.length ?? 0);
  const cuenta = {};
  for (const v of Object.values(proy)) cuenta[v] = (cuenta[v] ?? 0) + 1;
  const huerfanos = (pub.estados ?? []).filter((x) => !cuenta[x]);

  linea(`### Proyeccion - ${pares.length} pares sobre ${esperados} posibles`);
  linea();
  linea(
    '| Estado publico | Pares que lo producen | Requiere accion | Rotulo cliente | Rotulo operador |',
  );
  linea('|---|---|---|---|---|');
  for (const x of pub.estados ?? []) {
    const r = pub.rotulos?.[x] ?? {};
    linea(
      `| \`${x}\` | ${cuenta[x] ?? 0} | ${(pub.requierenAccion ?? []).includes(x) ? 'SI' : ''} | ` +
        `${celda(r.cliente ?? '-')} | ${celda(r.operador ?? '-')} |`,
    );
  }
  linea();
  linea(
    huerfanos.length
      ? `**${huerfanos.length} estado(s) publico(s) que NINGUN par produce: ${lista(huerfanos)}.** ` +
          'Son rotulos sin camino: o falta una rama en la proyeccion, o sobra el estado.'
      : 'Todos los estados publicos son alcanzables: cada uno lo produce al menos un par.',
  );
  linea();
}

// ---------------------------------------------------------------------------
// 2. Paquetes
// ---------------------------------------------------------------------------
linea('## 2. Paquetes del workspace');
linea();
if (!ws.paquetes.length) {
  nota('la raiz no declara `workspaces`, o ninguno tiene `package.json` todavia.');
  linea();
} else {
  linea('| Paquete | Version | Ruta | Scripts |');
  linea('|---|---|---|---|');
  for (const { dir, pkg } of ws.paquetes) {
    linea(
      `| \`${pkg?.name ?? '?'}\` | ${pkg?.version ?? '-'} | \`${rel(dir)}\` | ` +
        `${lista(Object.keys(pkg?.scripts ?? {}))} |`,
    );
  }
  linea();
  linea(`### Scripts de la raiz - \`${ws.raiz?.name ?? '?'}\` ${ws.raiz?.version ?? ''}`);
  linea();
  linea('| Script | Comando |');
  linea('|---|---|');
  for (const [k, v] of Object.entries(ws.raiz?.scripts ?? {})) {
    linea(`| \`${k}\` | ${celda(codigo(v))} |`);
  }
  linea();
  const deps = { ...(ws.raiz?.dependencies ?? {}), ...(ws.raiz?.devDependencies ?? {}) };
  linea(
    `Dependencias declaradas en la raiz: ${lista(Object.keys(deps))}. ` +
      `Node exigido: \`${ws.raiz?.engines?.node ?? '(sin declarar)'}\`.`,
  );
  linea();
}

// ---------------------------------------------------------------------------
// 3. Tests
// ---------------------------------------------------------------------------
linea('## 3. Tests - contados, no declarados');
linea();
const conteo = tests(archivosTest);
const totalTests = conteo.reduce((a, b) => a + b.n, 0);
if (!conteo.length) {
  nota('no hay archivos `*.test.ts`, `*.test.js` ni `*_test.dart` en el repo.');
  linea();
} else {
  linea('| Archivo | Casos |');
  linea('|---|---|');
  for (const c of conteo) linea(`| \`${c.r}\` | ${c.n} |`);
  linea(`| **total** | **${totalTests}** |`);
  linea();
  linea(
    'Conteo lexico de `test(` e `it(`. Se cuenta y no se escribe porque el ' +
      '`_index.md` del proyecto anterior decia 1929 cuando el runner iba por 2003. ' +
      'No incluye `test.skip(` ni `test.only(`: un test salteado no es un test que corre.',
  );
  linea();
}

// ---------------------------------------------------------------------------
// 4. Hooks
// ---------------------------------------------------------------------------
linea('## 4. Hooks activos');
linea();
if (!settings) {
  nota('`.claude/settings.json` no existe o no parsea: **no hay hooks configurados**.');
  linea();
} else {
  const hs = hooks(settings);
  linea('Leidos de `.claude/settings.json`, que es lo que el harness ejecuta de verdad.');
  linea();
  linea('| Evento | Matcher | Script | Timeout | El script existe |');
  linea('|---|---|---|---|---|');
  for (const h of hs) {
    linea(
      `| ${h.evento} | ${celda(codigo(h.matcher))} | \`${h.script}\` | ${h.timeout}s | ` +
        `${h.existe ? 'si' : '**NO**'} |`,
    );
  }
  linea();
  const rotos = hs.filter((h) => !h.existe);
  linea(
    rotos.length
      ? `**${rotos.length} hook(s) apuntan a un script que no existe.** Un hook cuyo ` +
          'script falta no bloquea nada y no avisa: es un guardia que no esta.'
      : `Los ${hs.length} hooks apuntan a scripts que existen. Que existan no prueba ` +
          'que midan: eso lo prueba `bash scripts/hooks/probar_hooks.sh`.',
  );
  linea();
  linea('### Permisos del harness');
  linea();
  const perm = settings.permissions ?? {};
  for (const clave of ['deny', 'ask', 'allow']) {
    linea(`- **${clave}**: ${lista(perm[clave] ?? [])}`);
  }
  linea();
  linea(
    'Se listan porque `SKILLS-AGENTES-MCP.md` 5 documenta el caso contrario: un ' +
      '`CLAUDE.md` que prohibia lo que el allowlist pre-aprobaba. **La configuracion ' +
      'le gana al documento, siempre.**',
  );
  linea();
  const local = join(RAIZ, '.claude', 'settings.local.json');
  if (existsSync(local)) {
    const p = leerJSON(local)?.permissions ?? {};
    linea(
      'Ademas hay `.claude/settings.local.json` (no versionado): ' +
        `allow ${(p.allow ?? []).length}, ask ${(p.ask ?? []).length}, deny ${(p.deny ?? []).length}.`,
    );
    linea();
  }
}

// ---------------------------------------------------------------------------
// 5. Agentes
// ---------------------------------------------------------------------------
linea('## 5. Subagentes');
linea();
const DIR_AGENTES = join(RAIZ, '.claude', 'agents');
if (!existsSync(DIR_AGENTES)) {
  nota('`.claude/agents/` no existe: no hay subagentes reales, solo prompts.');
  linea();
} else {
  const ag = agentes(DIR_AGENTES);
  const verificadores = ag.filter((a) => !a.escribe);
  linea(
    'El `tools:` del frontmatter es **enforcement estructural**: restringe ' +
      'herramientas, no rutas. Un agente sin `Edit` ni `Write` no puede escribir, y ' +
      'eso si es real. Las fronteras por ruta las miden los hooks, no el frontmatter.',
  );
  linea();
  linea('| Agente | Modelo | Escribe | Tools |');
  linea('|---|---|---|---|');
  for (const a of ag) {
    linea(
      `| \`${a.nombre}\` | ${a.modelo} | ${a.escribe ? 'si' : '**NO - verificador**'} | ` +
        `${lista(a.tools)} |`,
    );
  }
  linea();
  linea(
    `**${ag.length} subagentes: ${ag.length - verificadores.length} escriben, ` +
      `${verificadores.length} verifican sin \`Edit\` ni \`Write\`** ` +
      `(${lista(verificadores.map((a) => a.nombre))}).`,
  );
  const sinBash = ag.filter((a) => a.escribe && !a.bash);
  if (sinBash.length) {
    linea();
    linea(
      'Escriben pero no tienen `Bash`, o sea que no pueden desplegar ni commitear: ' +
        `${lista(sinBash.map((a) => a.nombre))}.`,
    );
  }
  linea();
}

// ---------------------------------------------------------------------------
// 6. Skills
// ---------------------------------------------------------------------------
linea('## 6. Skills declaradas');
linea();
const lock = leerJSON(join(RAIZ, 'skills-lock.json'));
if (!lock?.skills) {
  nota('`skills-lock.json` no existe o no declara skills.');
  linea();
} else {
  const porOrigen = new Map();
  for (const [nombre, s] of Object.entries(lock.skills)) {
    const o = s.source ?? '(sin origen)';
    if (!porOrigen.has(o)) porOrigen.set(o, []);
    porOrigen.get(o).push(nombre);
  }
  linea(
    `**${Object.keys(lock.skills).length} skills de terceros**, declaradas en ` +
      '`skills-lock.json` con su hash y **no commiteadas** (`.gitignore` ignora ' +
      '`.claude/skills/*`). Restaurar en un clon: `bash scripts/skills_restaurar.sh`.',
  );
  linea();
  linea('| Origen | Cuantas | Cuales |');
  linea('|---|---|---|');
  for (const [o, ns] of [...porOrigen].sort((a, b) => a[0].localeCompare(b[0]))) {
    linea(`| \`${o}\` | ${ns.length} | ${lista(ns.sort())} |`);
  }
  linea();
  const dirSkills = join(RAIZ, '.claude', 'skills');
  const enDisco = existsSync(dirSkills)
    ? readdirSync(dirSkills, { withFileTypes: true }).map((e) => e.name)
    : [];
  const nuestras = enDisco.filter((n) => !lock.skills[n]);
  linea(
    nuestras.length
      ? `Propias del proyecto, commiteadas porque mencionan nuestro dominio: ${lista(nuestras.sort())}.`
      : 'No hay skills propias en `.claude/skills/`.',
  );
  // El conteo de carpetas EN DISCO no puede vivir en el documento. En la
  // maquina de desarrollo son 29 y en el runner de CI son 2, porque las de
  // terceros no se commitean -- y `--check` compara TEXTO EXACTO. Esa linea
  // hacia que el job `guardas` fuera IMPOSIBLE de pasar, regeneraras las veces
  // que regeneraras: el numero cambia con el entorno, no con el codigo.
  //
  // Se descubrio en la PRIMERA corrida real del CI, el dia que el repo tuvo
  // remote. Antes de eso el defecto existia igual y nadie lo veia: un workflow
  // que nunca corrio no es un workflow verde, es un workflow desconocido.
  //
  // El dato sigue sirviendo, asi que va por stderr: se lee al correr el
  // script y no contamina lo que se compara. Y dice cuales faltan, que es
  // accionable, en vez de un total que no lo es.
  const faltan = Object.keys(lock.skills).filter((n) => !enDisco.includes(n));
  if (faltan.length) {
    console.error(
      `aviso  faltan ${faltan.length} de las ${Object.keys(lock.skills).length} skills ` +
        'del lock en .claude/skills/: bash scripts/skills_restaurar.sh',
    );
  }
  linea();
}

// ---------------------------------------------------------------------------
// 7. Puertas
// ---------------------------------------------------------------------------
linea('## 7. Simbolos publicos y quien los abre');
linea();
const DIR_SRC = join(RAIZ, 'packages', 'contratos', 'src');
if (!existsSync(join(DIR_SRC, 'index.ts'))) {
  nota('`packages/contratos/src/index.ts` no existe: no hay superficie publica que auditar.');
  linea();
} else {
  const simbolos = puertas(DIR_SRC, archivosCodigo);
  const VEREDICTO = {
    abierto: 'abierto',
    generador: 'solo el generador',
    'solo-tests': '**SIN PUERTA - solo tests**',
    nadie: '**SIN PUERTA - nadie**',
  };
  const sinPuerta = simbolos.filter((s) => s.veredicto === 'solo-tests' || s.veredicto === 'nadie');

  linea(
    'La seccion que mas vale. Por cada simbolo exportado por ' +
      `\`${rel(join(DIR_SRC, 'index.ts'))}\`, **quien lo referencia** fuera de su propio ` +
      'modulo. Un simbolo cuyo unico consumidor es su test esta escrito, no entregado: ' +
      'es el modo de falla que se repitio cuatro veces en seis meses en el proyecto anterior.',
  );
  linea();
  linea(
    'Se buscan referencias en `.ts .tsx .js .jsx .mjs .cjs` del repo entero. El panel ' +
      'en Dart NO importa TypeScript: lo espeja via `generated/contratos.json`, asi que ' +
      'no cuenta como consumidor aca aunque exista.',
  );
  linea();
  linea('| Simbolo | Clase | Estado | Quien lo abre |');
  linea('|---|---|---|---|');
  for (const s of simbolos) {
    linea(
      `| \`${s.nombre}\` | ${s.clase} | ${VEREDICTO[s.veredicto]} | ` +
        `${s.consumidores.length ? lista(s.consumidores) : '-'} |`,
    );
  }
  linea();
  linea(`**${simbolos.length} simbolos exportados. ${sinPuerta.length} SIN PUERTA.**`);
  if (sinPuerta.length) {
    linea();
    linea(`Sin puerta hoy: ${lista(sinPuerta.map((s) => s.nombre))}.`);
    linea();
    linea(
      'Que aparezcan aca **no es un bug**: `functions/` y `apps/` todavia no existen y ' +
        'este paquete se escribio primero a proposito. Lo que si es un bug es que esta ' +
        'lista no baje cuando esas carpetas aparezcan. **La lista es la deuda.**',
    );
  }
  linea();
}

// ---------------------------------------------------------------------------
// 8. Lo que todavia no existe
// ---------------------------------------------------------------------------
linea('## 8. Lo que todavia no existe');
linea();
linea('Se comprueba por ruta, en cada corrida. Un `si` aca no dice que funcione.');
linea();
linea('| Ruta | Que seria | Existe |');
linea('|---|---|---|');
for (const [ruta, que] of [
  ['apps/tienda', 'vidriera Next.js'],
  ['apps/admin', 'panel Flutter'],
  ['functions', 'Cloud Functions'],
  ['firestore.rules', 'reglas de Firestore'],
  ['storage.rules', 'reglas de Storage'],
  ['firestore.indexes.json', 'indices compuestos'],
  ['firebase.json', 'proyecto Firebase'],
  ['.mcp.json', 'MCP versionado en el repo'],
]) {
  linea(`| \`${ruta}\` | ${que} | ${hay(...ruta.split('/')) ? 'si' : '**no**'} |`);
}
linea();
linea(
  'Las secciones de arriba que dependen de estas rutas se emiten vacias con su nota. ' +
    'Un generador que se saltea una seccion en silencio es indistinguible de uno que la ' +
    'encontro vacia.',
);
linea();
linea('---');
linea();
linea(
  `Archivos de codigo recorridos: ${archivosCodigo.length}. Archivos de test: ` +
    `${archivosTest.length}. Casos de test: ${totalTests}.`,
);

// ===========================================================================
// Salida
// ===========================================================================
const CUERPO = L.join('\n') + '\n';

const COMMIT = git('rev-parse', '--short', 'HEAD') || 'sin-commit';
const SUCIO = git('status', '--porcelain') !== '';
const FECHA = new Date().toISOString().slice(0, 10);
const HUELLA = createHash('sha256').update(CUERPO).digest('hex').slice(0, 12);
const PROCEDENCIA =
  `${MARCA_PROCEDENCIA} ${FECHA} - commit \`${COMMIT}\`` +
  `${SUCIO ? ' **+ cambios sin commitear**' : ''} - huella del cuerpo \`${HUELLA}\``;

const TEXTO = CUERPO.replace(`${MARCA_PROCEDENCIA} PROCEDENCIA`, PROCEDENCIA);

// El --check compara el CUERPO, no la procedencia: ver el comentario de
// MARCA_PROCEDENCIA arriba. Y normaliza CRLF, por si un clon en Windows se
// salteo el .gitattributes.
const comparable = (t) =>
  t
    .split('\r\n')
    .join('\n')
    .split('\n')
    .filter((l) => !l.startsWith(MARCA_PROCEDENCIA))
    .join('\n');

if (MODO_CHECK) {
  const enDisco = leer(DESTINO);
  if (enDisco === null) {
    console.error(`::error::falta ${rel(DESTINO)}. Corre: node scripts/ci/generar_verdad.mjs .`);
    process.exit(1);
  }
  const a = comparable(enDisco).split('\n');
  const b = comparable(TEXTO).split('\n');

  // Comparar por POSICION solo sirve para decir SI hay diferencia, no CUANTA:
  // una sola linea insertada corre todas las de abajo y el contador se dispara.
  // Medido: se agrego 1 script a package.json y el check reporto "145 lineas
  // distintas" cuando habian cambiado 5.
  //
  // Un CI que grita 145 cuando cambiaron 5 ensena a ignorarlo, que es
  // exactamente como un guardia deja de ser un guardia. Asi que el conteo sale
  // de una diferencia de multiconjuntos, que no se corre con las inserciones.
  const bolsa = (ls) => {
    const m = new Map();
    for (const l of ls) m.set(l, (m.get(l) ?? 0) + 1);
    return m;
  };
  const [ba, bb] = [bolsa(a), bolsa(b)];
  const sobran = []; // estan en disco y no deberian
  const faltan = []; // deberian estar y no estan
  for (const [l, n] of ba) {
    const d = n - (bb.get(l) ?? 0);
    for (let i = 0; i < d; i++) sobran.push(l);
  }
  for (const [l, n] of bb) {
    const d = n - (ba.get(l) ?? 0);
    for (let i = 0; i < d; i++) faltan.push(l);
  }

  if (sobran.length || faltan.length) {
    let primera = 0;
    while (primera < Math.max(a.length, b.length) && a[primera] === b[primera]) primera++;
    console.error(
      `::error::${rel(DESTINO)} no coincide con el codigo: ` +
        `${faltan.length} linea(s) faltan, ${sobran.length} sobran ` +
        `(primera divergencia en la linea ${primera + 1}).`,
    );
    for (const l of faltan.slice(0, 5)) console.error(`  falta:  ${l}`);
    if (faltan.length > 5) console.error(`  ... y ${faltan.length - 5} mas`);
    for (const l of sobran.slice(0, 5)) console.error(`  sobra:  ${l}`);
    if (sobran.length > 5) console.error(`  ... y ${sobran.length - 5} mas`);
    console.error('\nCorre: node scripts/ci/generar_verdad.mjs .   y commitea el resultado.');
    process.exit(1);
  }
  console.log(`ok  ${rel(DESTINO)} coincide con el codigo (huella ${HUELLA})`);
  process.exit(0);
}

mkdirSync(dirname(DESTINO), { recursive: true });
writeFileSync(DESTINO, TEXTO, 'utf8');
console.log(`escrito: ${rel(DESTINO)}  (${TEXTO.split('\n').length - 1} lineas, huella ${HUELLA})`);
