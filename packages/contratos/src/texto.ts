/**
 * La normalizacion de texto. ARQUITECTURA §7: *"la normalizacion (acentos,
 * mayusculas) vive en `packages/contratos` con sus fixtures. Un solo lugar."*
 *
 * Hasta hoy no vivia en ninguno: lo unico parecido era un slugify escrito a
 * mano adentro de `apps/tienda/src/features/catalogo/PanelDeFiltros.tsx`.
 *
 * Son CUATRO funciones y no una porque BUSCAR Y COMPARAR NO SON LO MISMO:
 *
 *   · `normalizar` conserva los espacios, porque alimenta un `contains`.
 *   · `clave` los saca, porque compara nombres ENTEROS.
 *
 * Si `normalizar` sacara los espacios, buscar "catena zapata" no encontraria
 * nada: el operador escribe con espacios y el texto indexado no los tendria.
 *
 * El panel en Flutter lo ESPEJA en Dart y verifica el espejo contra
 * FIXTURES_DE_TEXTO, que viajan en `generated/contratos.json`. No viaja la
 * implementacion -no se puede transportar en JSON-: viajan pares
 * entrada->salida calculados por el TypeScript de HOY, y
 * `scripts/ci/auditar_estados.mjs` verifica que ese JSON no envejezca.
 */

/**
 * Minusculas, sin acentos, sin espacios en los extremos y con los internos
 * colapsados en uno. Lo que se compara con `contains` al buscar.
 *
 * Saca las marcas combinantes DESPUES de descomponer en NFD: asi `Ñ` es `n` y
 * `Torrontés` es `torrontes` sin una tabla de caracteres escrita a mano.
 */
export function normalizar(texto: string): string {
  return texto
    .normalize('NFD')
    .replace(/\p{M}/gu, '')
    .toLowerCase()
    .trim()
    .replace(/\s+/g, ' ');
}

/**
 * `normalizar` y ademas sin nada que no sea letra latina o numero, para que
 * "Catena Zapata", "catena-zapata" y "CATENA  ZAPATA" den lo mismo.
 *
 * Puede dar la cadena vacia: un nombre hecho solo de puntuacion no tiene
 * clave. Quien la usa TIENE que tratar ese caso -- ver `seParecen`.
 */
export function clave(texto: string): string {
  return normalizar(texto).replace(/[^a-z0-9]+/g, '');
}

/**
 * El slug que sale de un nombre. Cumple `esSlug` de `firestore.rules`
 * -`[a-z0-9]+(-[a-z0-9]+)*`- o devuelve la cadena vacia, que NO lo cumple y
 * que quien llama tiene que leer como "este nombre no sirve".
 *
 * Devolver `''` en vez de lanzar es a proposito: el panel lo muestra mientras
 * se escribe, y una excepcion por cada tecla intermedia no es un error, es el
 * estado normal de un campo a medio llenar.
 */
export function aSlug(texto: string): string {
  return normalizar(texto)
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

/**
 * true si una clave contiene a la otra. Resuelve el caso que pide HU-02.2:
 * "Catena" contra "Catena Zapata".
 *
 * NO es difusa a proposito. ARQUITECTURA §7: con menos de 200 productos el
 * panel *"no necesita busqueda difusa, asi que no hay una segunda
 * implementacion que mantener sincronizada"*. Un Levenshtein aca seria
 * exactamente esa segunda implementacion.
 *
 * ⚠️ LA CADENA VACIA ESTA CONTENIDA EN TODAS. Sin el corte de abajo,
 * `seParecen('···', 'Norton')` daria true por algebra y TODA bodega nueva
 * pareceria un duplicado de todo.
 */
export function seParecen(a: string, b: string): boolean {
  const x = clave(a);
  const y = clave(b);
  if (x === '' || y === '') return false;
  return x.includes(y) || y.includes(x);
}

// --------------------------------------------------------------- fixtures

/**
 * Las ENTRADAS de las fixtures. Las salidas las calcula `scripts/generar.mjs`
 * con las funciones de arriba, asi que el JSON siempre dice lo que el
 * TypeScript hace hoy -- no lo que alguien escribio que hacia.
 *
 * Cada entrada esta por un motivo:
 */
export const ENTRADAS_DE_TEXTO: readonly string[] = [
  // El caso plano: no tiene nada raro y tiene que salir intacto.
  'Norton',
  // Espacios en los extremos y dobles adentro: los tres los colapsa.
  '  Bodega   Catena ZAPATA ',
  // La tilde del castellano.
  'Torrontés',
  // La enie: el caracter que una tabla escrita a mano olvida.
  'Bodega Ñandú',
  // Ampersand y punto: no son letras, y cada funcion los trata distinto.
  'Ñandú & Cía.',
  // El circunflejo del frances: NFD lo descompone, una tabla a mano no.
  'Château Vieux',
  // La dieresis del castellano.
  'Pingüino',
  // Solo puntuacion: `aSlug` da '' y `seParecen` tiene que dar false.
  '···',
  // Ya viene en forma de slug: normalizar no lo tiene que romper.
  'catena-zapata',
  // Vacio.
  '',
];

/** Los pares que prueban `seParecen`, con el porque de cada uno. */
export const PARES_DE_TEXTO: readonly (readonly [string, string])[] = [
  // El caso de la historia: uno contenido en el otro.
  ['Catena', 'Catena Zapata'],
  // Dos bodegas que no tienen nada que ver.
  ['Catena', 'Norton'],
  // El mismo nombre escrito de dos formas.
  ['Catena Zapata', 'catena-zapata'],
  // La clave vacia contra un nombre real: NO se parecen.
  ['···', 'Norton'],
  // Dos claves vacias.
  ['···', ''],
  // Contencion al reves: el largo primero.
  ['Bodega Ñandú', 'ñandu'],
];
