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
  const IMPORTA_LA_CACHE = /import\s*\{[^}]*\b(obtenerCatalogo|obtenerVidriera)\b[^}]*\}\s*from/;
  assert.match(leer('src/app/vinos/page.tsx'), IMPORTA_LA_CACHE);

  const home = leer('src/app/page.tsx');
  assert.match(home, /leerCatalogoSinCache\(\)/);
  assert.doesNotMatch(home, IMPORTA_LA_CACHE);
  assert.doesNotMatch(home, /export const revalidate/);
});

test('la home no paga la lectura de las cajas sugeridas', () => {
  // La home llama a `leerCatalogoSinCache` y NO dibuja carril: si la lectura
  // de `cajasSugeridas` viviera ahí, pagaría por un documento que no
  // renderiza. Tiene que vivir en `leerVidrieraSinCache`, más abajo.
  const fuente = leer('src/server/catalogo.ts');

  const sinCache = fuente.indexOf('async function leerCatalogoSinCache');
  const vidriera = fuente.indexOf('async function leerVidrieraSinCache');
  const cajas = fuente.indexOf('cajasSugeridas/publicas');

  // Control positivo: las tres cosas existen y están en este orden.
  assert.ok(sinCache > 0, 'no encontré leerCatalogoSinCache');
  assert.ok(vidriera > sinCache, 'no encontré leerVidrieraSinCache después');
  assert.ok(cajas > vidriera, 'la lectura de cajas quedó ANTES de leerVidrieraSinCache');

  // Y una sola vez: dos lecturas del mismo documento serían dos lecturas.
  assert.equal(fuente.split('cajasSugeridas/publicas').length - 1, 1);

  // La home tampoco la nombra por su cuenta.
  assert.doesNotMatch(leer('src/app/page.tsx'), /cajasSugeridas/);
});

test('las cajas se leen en la MISMA entrada de caché que el catálogo', () => {
  // Un segundo unstable_cache con revalidate numérico le baja el revalidate a
  // la página que lo llama. Tiene que haber exactamente uno.
  const fuente = leer('src/server/catalogo.ts');
  assert.equal(fuente.split('unstable_cache(').length - 1, 1, 'hay más de un unstable_cache');
});

test('expireTime deja el stale-while-revalidate en 300 s', () => {
  // specs/vidriera-catalogo: s-maxage=60, stale-while-revalidate=300.
  assert.equal(numero('next.config.ts', /expireTime: (\d+)/) - datos(), 300);
});

test('la selección del dueño la lee SÓLO la home, sin caché y una sola vez', () => {
  // ADR 023: un documento más por build, cero por visita. Si /vinos lo leyera
  // pagaría por algo que no dibuja; si entrara en `unstable_cache`, la home
  // pasaría a ISR (ADR 008 §7).
  const fuente = leer('src/server/catalogo.ts');
  const funcion = fuente.indexOf('async function leerSeleccionSinCache');
  const lectura = fuente.indexOf('seleccion/publica');

  // Control positivo: la función existe y la lectura está adentro de ella.
  assert.ok(funcion > 0, 'no encontré leerSeleccionSinCache');
  assert.ok(lectura > funcion, 'la lectura de seleccion/publica quedó fuera de leerSeleccionSinCache');
  assert.equal(fuente.split("doc('seleccion/publica')").length - 1, 1);

  assert.match(leer('src/app/page.tsx'), /leerSeleccionSinCache\(\)/);
  for (const ruta of ['src/app/vinos/page.tsx', 'src/app/vinos/[slug]/page.tsx', 'src/app/carrito/page.tsx']) {
    assert.doesNotMatch(leer(ruta), /leerSeleccionSinCache/, ruta);
  }
});

test('el umbral de la entrega sin cargo lo lee SÓLO /pedido, con su mismo 60', () => {
  // ADR 026: un documento por reconstrucción, en su propia caché. Si la home lo
  // importara, un unstable_cache de 60 la pasaría sola a ISR (ADR 008 §7); si
  // lo importaran /vinos o /carrito, pagarían por algo que no dibujan.
  const IMPORTA_EL_UMBRAL = /import\s*\{[^}]*\bobtenerEnvioSinCargo\b[^}]*\}\s*from/;

  // Control positivo: /pedido sí lo importa, así que el patrón detecta un
  // import de verdad.
  assert.match(leer('src/app/pedido/page.tsx'), IMPORTA_EL_UMBRAL);
  for (const ruta of ['src/app/page.tsx', 'src/app/vinos/page.tsx', 'src/app/vinos/[slug]/page.tsx', 'src/app/carrito/page.tsx']) {
    assert.doesNotMatch(leer(ruta), IMPORTA_EL_UMBRAL, ruta);
  }

  const config = numero('src/server/config.ts', /SEGUNDOS_DE_CONFIG = (\d+)/);
  assert.equal(numero('src/app/pedido/page.tsx', /export const revalidate = (\d+)/), config);
  // Una sola lectura del documento.
  assert.equal(leer('src/server/config.ts').split("doc('config/envios')").length - 1, 1);
});
