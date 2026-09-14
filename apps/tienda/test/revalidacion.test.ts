import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

// Next exige un literal en `export const revalidate`, así que el 60 de la caché
// vive cuatro veces: en server/catalogo.ts y en las tres rutas. Esto es lo que
// impide que se desincronicen (lo encontró cazador-de-puertas).

const TIENDA = join(dirname(fileURLToPath(import.meta.url)), '..');
const leer = (ruta: string) => readFileSync(join(TIENDA, ruta), 'utf8');

function numero(ruta: string, patron: RegExp): number {
  const m = patron.exec(leer(ruta));
  assert.ok(m, `no encontré ${patron} en ${ruta}`);
  return Number(m[1]);
}

const datos = () => numero('src/server/catalogo.ts', /SEGUNDOS_DE_CATALOGO = (\d+)/);

test('las tres rutas del catálogo revalidan con el mismo número que la caché de datos', () => {
  for (const ruta of ['src/app/vinos/page.tsx', 'src/app/vinos/[slug]/page.tsx', 'src/app/carrito/page.tsx']) {
    assert.equal(numero(ruta, /export const revalidate = (\d+)/), datos(), ruta);
  }
});

test('la home lee el catálogo sin la caché de 60 s: con ella pasaría sola a ISR', () => {
  // unstable_cache con revalidate numérico le baja el revalidate a la página
  // que lo llama, y la home leería Firestore por visita (ADR 008 §7).
  //
  // Se busca el IMPORT, no la palabra: el comentario de la home nombra a
  // `obtenerCatalogo` para decir que no lo usa, y un grep de la palabra daba
  // rojo con el código bien. Los dos controles: /vinos sí lo importa, así que
  // el patrón detecta un import de verdad; y la home sí lee el catálogo, así
  // que no pasa por estar leyendo el archivo equivocado.
  const IMPORTA_LA_CACHE = /import\s*\{[^}]*\bobtenerCatalogo\b[^}]*\}\s*from/;
  assert.match(leer('src/app/vinos/page.tsx'), IMPORTA_LA_CACHE);

  const home = leer('src/app/page.tsx');
  assert.match(home, /leerCatalogoSinCache\(\)/);
  assert.doesNotMatch(home, IMPORTA_LA_CACHE);
  assert.doesNotMatch(home, /export const revalidate/);
});

test('expireTime deja el stale-while-revalidate en 300 s', () => {
  // specs/vidriera-catalogo: s-maxage=60, stale-while-revalidate=300.
  assert.equal(numero('next.config.ts', /expireTime: (\d+)/) - datos(), 300);
});
