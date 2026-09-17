## ADDED Requirements

### Requirement: Una sola normalización, en contratos
La normalización de texto —acentos, mayúsculas, espacios— MUST vivir en
`packages/contratos` y MUST NOT tener una segunda implementación en el panel
(ARQUITECTURA §7). El panel MUST espejarla en Dart y ese espejo MUST verificarse
contra fixtures generadas desde el TypeScript, igual que el enum de estados
(ADR 002).

#### Scenario: El espejo de Dart se corre contra las fixtures
- **WHEN** corre la suite de Dart del panel
- **THEN** cada fixture de `generated/contratos.json` da en Dart el mismo resultado que en TypeScript

#### Scenario: Las fixtures se quedan viejas
- **WHEN** alguien cambia `normalizar` en TypeScript y no regenera el JSON
- **THEN** `scripts/ci/auditar_estados.mjs` falla y lo dice

### Requirement: Normalizar para buscar
`normalizar` MUST pasar a minúsculas, MUST sacar los acentos, MUST recortar los
extremos y MUST colapsar los espacios internos en uno. MUST NOT sacar los
espacios ni la puntuación: es lo que se usa para un `contains`.

#### Scenario: Buscar sin acentos y sin mayúsculas
- **WHEN** se normaliza `"  Bodega   Catena ZAPATA "`
- **THEN** da `"bodega catena zapata"`

#### Scenario: Buscar un nombre con tilde
- **WHEN** se normaliza `"Torrontés"`
- **THEN** da `"torrontes"`

### Requirement: Clave para comparar nombres
`clave` MUST normalizar y además MUST sacar todo lo que no sea letra o número,
para que dos formas de escribir el mismo nombre den la misma clave.

#### Scenario: El mismo nombre escrito de tres formas
- **WHEN** se toma la clave de `"Catena Zapata"`, `"catena-zapata"` y `"CATENA  ZAPATA"`
- **THEN** las tres dan `"catenazapata"`

### Requirement: Slug derivado del nombre
`aSlug` MUST devolver un slug que cumpla `esSlug` de `firestore.rules`
—minúsculas, números y guiones simples, sin guión al principio ni al final— o
MUST devolver la cadena vacía si del nombre no sale ningún carácter válido.

#### Scenario: Un nombre con tildes y símbolos
- **WHEN** se pide el slug de `"Bodega Ñandú & Cía."`
- **THEN** da `"bodega-nandu-cia"`

#### Scenario: Un nombre del que no sale nada
- **WHEN** se pide el slug de `"···"`
- **THEN** da `""`, y quien lo llama tiene que tratarlo como un nombre inválido

### Requirement: Dos nombres que se parecen
`seParecen` MUST dar verdadero cuando la clave de uno contiene a la del otro, y
MUST NOT usar búsqueda difusa: con menos de 200 productos no hace falta, y una
segunda implementación de búsqueda es lo que ARQUITECTURA §7 existe para evitar.

#### Scenario: Un nombre contenido en el otro
- **WHEN** se comparan `"Catena"` y `"Catena Zapata"`
- **THEN** se parecen

#### Scenario: Dos bodegas distintas
- **WHEN** se comparan `"Catena"` y `"Norton"`
- **THEN** no se parecen

#### Scenario: Una clave vacía
- **WHEN** se compara `"···"` con cualquier nombre
- **THEN** no se parecen: una clave vacía está contenida en todas, y decir que sí
  haría que toda bodega nueva pareciera un duplicado
