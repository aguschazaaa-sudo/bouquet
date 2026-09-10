## ADDED Requirements

### Requirement: La barra nombra secciones con sustantivos

La barra principal SHALL nombrar cada sección con un **sustantivo**, nunca con
un imperativo. La voz de la marca vive en el cuerpo de cada página; la barra es
señalética.

Un imperativo suelto —`Escribinos`— adentro de una lista de sustantivos se lee
como un botón perdido entre etiquetas, y por eso el contacto no vuelve a la
barra aunque su contenido siga existiendo.

#### Scenario: Ningún nombre es un verbo conjugado

- **WHEN** se leen los `nombre` de `SECCIONES` y de `CARRITO`
- **THEN** todos son sustantivos o frases nominales

### Requirement: Las secciones son dos, más el carrito aparte

`SECCIONES` MUST contener exactamente `Vinos` y `El oficio`, en ese orden.
`CARRITO` MUST seguir declarado aparte: no es una sección del catálogo, es el
estado del comprador, y mezclarlo en la lista lo convierte en "una página más"
justo cuando es la única que tiene plata adentro.

#### Scenario: La lista quedó en dos

- **WHEN** se lee `SECCIONES` de `apps/tienda/src/features/navegacion/secciones.ts`
- **THEN** tiene dos entradas: `/vinos` → `Vinos` y `/oficio` → `El oficio`

#### Scenario: El carrito no está en la lista

- **WHEN** se busca `/carrito` dentro de `SECCIONES`
- **THEN** no aparece; está en la constante `CARRITO`

### Requirement: Todo `href` de la barra tiene una página que lo sirve

Cada `href` declarado en `SECCIONES` y en `CARRITO` MUST tener un
`app/<ruta>/page.tsx` que lo sirva. Una barra que nombra una ruta inexistente
produce un 404 desde la pieza más visible del sitio.

#### Scenario: Las rutas existen

- **WHEN** se recorre cada `href` de la barra sobre una build de producción
- **THEN** todos responden 200

#### Scenario: Control negativo

- **WHEN** se pide una ruta que la barra no nombra y que no existe
- **THEN** responde 404, lo que prueba que el chequeo anterior distingue

### Requirement: `Custodia` deja de ser un nombre de sección

La barra MUST NOT nombrar ninguna sección `Custodia`, y la palabra MUST seguir
existiendo como término del léxico de la marca (`voz.md §7.2`) y como nombre del
segundo tramo **adentro** de `/oficio`.

El motivo es que la sección pasó a cubrir tres tramos —elegir, guardar y abrir—
y `Custodia` nombraba sólo el del medio. Lo que desaparece es su uso como rótulo
de navegación, no la palabra.

#### Scenario: La barra ya no la nombra

- **WHEN** se lee `SECCIONES`
- **THEN** ninguna entrada dice `Custodia`

#### Scenario: La palabra sobrevive donde rinde

- **WHEN** se busca la palabra en el contenido de `/oficio`
- **THEN** aparece como nombre del tramo `II`
