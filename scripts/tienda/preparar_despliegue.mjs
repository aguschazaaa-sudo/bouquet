#!/usr/bin/env node
// preparar_despliegue.mjs - arma `.deploy/tienda/`, una app de Next
// AUTOCONTENIDA lista para `firebase deploy --only apphosting`.
// docs/vault/architecture/decisions/017-preview-cerrada.md.
//
// POR QUE EXISTE (NO REVERTIR)
//
// App Hosting no deploya bien un workspace de npm. Medido el 2026-09-23: el
// buildpack de Next (`google.nodejs.firebasenextjs`) toma como "raiz de la
// aplicacion" el `rootDir` -- `/workspace/apps/tienda` --, busca ahi el
// lockfile, y no lo busca mas arriba. Nuestro `package-lock.json` esta en la
// raiz del monorepo, como corresponde a un workspace, asi que el build falla a
// los 18 segundos con `fah/missing-lock-file` aunque el lockfile VIAJE en el
// zip. Dos rollouts perdidos.
//
// Salir de ahi sin tocar la estructura del repo: deployar una copia. La tienda
// pasa a ser una app de Next comun -- el caso que App Hosting soporta -- con
// su propio package-lock, y `@bouquet/contratos` entra como dependencia LOCAL
// (`file:./vendor/contratos`), igual que `procesarFoto` lleva contratos
// adentro de su bundle. La copia se genera cada vez y NO se commitea.
//
// EL LOCKFILE PARTE DEL DE LA RAIZ, a proposito: un `npm install` en frio
// resolveria `@opentelemetry/api ^1.9.1` y todo lo transitivo a lo que salga
// hoy, y lo que se deploya dejaria de ser lo que se probo. Con el lock de la
// raiz de semilla, npm conserva las versiones y solo poda lo que sobra.

import { cpSync, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { dirname, join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';

const RAIZ = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const TIENDA = join(RAIZ, 'apps', 'tienda');
const CONTRATOS = join(RAIZ, 'packages', 'contratos');
export const DESTINO = join(RAIZ, '.deploy', 'tienda');

const BACKEND = 'bouquet-tienda';
const PROYECTO = 'bouquet-vinos';

const falla = (msg) => {
  console.error(`NO  ${msg}`);
  process.exit(1);
};
const ok = (msg) => console.log(`ok  ${msg}`);

if (!existsSync(join(RAIZ, 'package-lock.json'))) falla('no hay package-lock.json en la raiz');

rmSync(DESTINO, { recursive: true, force: true });
mkdirSync(DESTINO, { recursive: true });

// --- 1. La app. Sin lo que no se deploya: dependencias, salida de build,
// los tests (un Next no los necesita y `tsconfig` los incluiria), los .env
// (un secreto no viaja NUNCA en un zip) y la documentacion.
const SOBRA = /(^|\/)(node_modules|\.next|test)(\/|$)|(^|\/)\.env(\.|$)|\.tsbuildinfo$|\.md$/;
cpSync(TIENDA, DESTINO, {
  recursive: true,
  filter: (origen) => {
    const rel = relative(TIENDA, origen).replaceAll('\\', '/');
    return rel === '' || !SOBRA.test(rel);
  },
});
ok('la app copiada (src, public, next.config, tsconfig, apphosting.yaml)');

// --- 2. contratos, como dependencia local. Solo lo que Next necesita: el
// paquete se publica como fuente TypeScript (`exports: ./src/index.ts`).
const VENDOR = join(DESTINO, 'vendor', 'contratos');
mkdirSync(VENDOR, { recursive: true });
cpSync(join(CONTRATOS, 'package.json'), join(VENDOR, 'package.json'));
cpSync(join(CONTRATOS, 'src'), join(VENDOR, 'src'), { recursive: true });
ok('contratos en vendor/contratos (package.json + src)');

// --- 3. package.json: contratos deja de ser "*" del workspace.
const paquete = JSON.parse(readFileSync(join(DESTINO, 'package.json'), 'utf8'));
if (paquete.dependencies?.['@bouquet/contratos'] !== '*') {
  falla('la tienda ya no declara @bouquet/contratos como "*": revisar este script');
}
paquete.dependencies['@bouquet/contratos'] = 'file:./vendor/contratos';
writeFileSync(join(DESTINO, 'package.json'), JSON.stringify(paquete, null, 2) + '\n');
ok('package.json: @bouquet/contratos -> file:./vendor/contratos');

// --- 4. El lockfile, sembrado con el de la raiz.
cpSync(join(RAIZ, 'package-lock.json'), join(DESTINO, 'package-lock.json'));
execFileSync(
  'npm',
  ['install', '--package-lock-only', '--prefer-offline', '--no-audit', '--no-fund', '--ignore-scripts'],
  { cwd: DESTINO, stdio: 'inherit', shell: process.platform === 'win32' },
);

const lock = JSON.parse(readFileSync(join(DESTINO, 'package-lock.json'), 'utf8'));

// npm NO borra las entradas de los workspaces que dejaron de existir: las marca
// `"extraneous": true` y las deja. Un lock con `apps/tienda` adentro y sin
// esa carpeta es un lock que `npm ci` puede rechazar por inconsistente, y en
// la nube eso se entera uno a los 18 segundos de un build.
let podadas = 0;
for (const [clave, valor] of Object.entries(lock.packages)) {
  if (valor.extraneous) {
    delete lock.packages[clave];
    podadas++;
  }
}
writeFileSync(join(DESTINO, 'package-lock.json'), JSON.stringify(lock, null, 2) + '\n');
ok(`${podadas} entradas extraneous podadas del lock`);
const raiz = JSON.parse(readFileSync(join(RAIZ, 'package-lock.json'), 'utf8'));
const paquetes = Object.keys(lock.packages);
ok(`package-lock.json: ${paquetes.length - 1} paquetes (el de la raiz tiene ${Object.keys(raiz.packages).length - 1})`);

// Nada de otro workspace se puede haber colado, y contratos tiene que estar
// enlazado a la copia local.
const intrusos = paquetes.filter((p) => /^(apps|functions|packages)\//.test(p) && p !== 'vendor/contratos');
if (intrusos.length) falla(`el lock trae workspaces ajenos: ${intrusos.join(', ')}`);
if (lock.packages['node_modules/@bouquet/contratos']?.resolved !== 'vendor/contratos') {
  falla('el lock no enlaza @bouquet/contratos a vendor/contratos');
}

// Las versiones que se prueban son las que se deployan: las de la tienda no
// pueden haberse movido respecto del lock de la raiz.
const movidas = [];
for (const nombre of ['next', 'react', 'react-dom', 'firebase-admin', '@opentelemetry/api']) {
  const antes = raiz.packages[`node_modules/${nombre}`]?.version;
  const ahora = lock.packages[`node_modules/${nombre}`]?.version;
  if (!ahora || antes !== ahora) movidas.push(`${nombre}: ${antes} -> ${ahora}`);
}
if (movidas.length) falla(`versiones que cambiaron respecto del lock de la raiz: ${movidas.join('; ')}`);
ok('next, react, react-dom, firebase-admin y @opentelemetry/api: las mismas versiones que el lock de la raiz');

// El control que importa: la misma comprobacion que hace `npm ci` en la nube,
// de que package.json y package-lock.json dicen lo mismo. `--dry-run` no
// instala nada.
execFileSync('npm', ['ci', '--dry-run', '--ignore-scripts', '--prefer-offline', '--no-audit', '--no-fund'], {
  cwd: DESTINO,
  stdio: 'pipe',
  shell: process.platform === 'win32',
});
ok('npm ci --dry-run: package.json y package-lock.json coinciden');

// --- 5. La configuracion de Firebase de la copia. `rootDir` es "." porque
// esta carpeta ES la app; y se deploya DESDE ella, porque el CLI empaqueta el
// directorio que contiene el firebase.json.
writeFileSync(
  join(DESTINO, 'firebase.json'),
  JSON.stringify(
    {
      apphosting: {
        backendId: BACKEND,
        rootDir: '.',
        ignore: ['node_modules', '.git'],
        alwaysDeployFromSource: true,
      },
    },
    null,
    2,
  ) + '\n',
);
writeFileSync(join(DESTINO, '.firebaserc'), JSON.stringify({ projects: { default: PROYECTO } }, null, 2) + '\n');
ok(`firebase.json y .firebaserc de la copia (backend ${BACKEND})`);

console.log(`\nListo: ${DESTINO}\n  cd .deploy/tienda && firebase deploy --only apphosting --project ${PROYECTO}`);
