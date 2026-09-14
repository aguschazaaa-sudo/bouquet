## ADDED Requirements

### Requirement: `/vinos` muestra el catálogo publicado entero en el HTML
`/vinos` MUST renderizar del lado servidor todos los productos de la
proyección publicada, de modo que el HTML servido contenga cada vino sin
ejecutar JavaScript.

#### Scenario: Un buscador lee la página
- **WHEN** se pide `/vinos` con `curl`
- **THEN** el HTML contiene el nombre de cada producto publicado, y ninguno de los no publicados

### Requirement: Como máximo tres vinos por fila
La grilla MUST mostrar como máximo 3 vinos por fila en escritorio, 2 en tablet y
1 en móvil, con la tarjeta en retrato vertical.

#### Scenario: Pantalla ancha
- **WHEN** el listado se ve a 1920 px de ancho
- **THEN** ninguna fila tiene más de 3 vinos

### Requirement: Filtros por color, cepa o corte, y orgánico
El listado MUST ofrecer filtros combinables por color (tinto, blanco, rosado),
por cepa (cada cepa presente en el catálogo) o corte, y por orgánico. Filtrar
MUST ocurrir en el navegador sin ningún pedido de red, y el estado MUST quedar
en la URL con `history.replaceState`.

#### Scenario: Filtrar blancos orgánicos
- **WHEN** el comprador elige "blanco" y "orgánico"
- **THEN** la grilla muestra sólo esos vinos, la URL refleja los dos filtros y no sale ningún pedido de red

#### Scenario: Una cepa no incluye los cortes
- **WHEN** el comprador elige la cepa Malbec
- **THEN** aparecen los Malbec de una sola cepa y no los cortes que llevan Malbec

#### Scenario: Sin resultados
- **WHEN** una combinación de filtros no deja ningún vino
- **THEN** la página lo dice y ofrece quitar los filtros

### Requirement: Orden por precio, nombre y popularidad
El listado MUST ordenar por precio (de menor a mayor y de mayor a menor), por
nombre (comparación en español, con acentos) y por popularidad, y MUST abrir en
un orden por defecto fijo, declarado en `design.md`. El orden por popularidad
MUST NOT ofrecerse cuando no hay métricas.

#### Scenario: Sin métricas
- **WHEN** `metricas/popularidad` no existe o está vacío
- **THEN** el control de orden no ofrece la popularidad

### Requirement: El stock se muestra en baldes y lo agotado va al final
Cada vino MUST mostrar su balde con los textos de `voz.md §9.2`: nada para
`disponible`, "Quedan pocas" y "Se agotó". Lo agotado MUST ir al final en
cualquier orden, y ninguna pantalla MUST mostrar el número de unidades.

#### Scenario: Orden por precio con un agotado barato
- **WHEN** el vino más barato está agotado y se ordena por precio de menor a mayor
- **THEN** ese vino aparece después de todos los disponibles

### Requirement: La caja de 2 se nombra como tal
Un producto con `presentacion.botellas === 2` MUST decir que es una caja de 2
junto a su precio, que es el de la caja.

#### Scenario: Caja de 2 en la grilla
- **WHEN** el listado incluye una caja de 2
- **THEN** su tarjeta dice "caja de 2" y el precio corresponde a la caja

### Requirement: Cero lecturas por visita y caché explícita
La proyección MUST salir de `server/catalogo.ts`, con una caché de datos que
venza a los 60 segundos. `/vinos` MUST responder con
`Cache-Control: public, s-maxage=60, stale-while-revalidate=300` y
`Cache-Tag: catalogo`, y MUST NOT leer `searchParams`.

#### Scenario: Cabeceras de caché
- **WHEN** se pide `/vinos` con `curl -I` a una build de producción
- **THEN** la respuesta trae `s-maxage=60` y `Cache-Tag: catalogo`

### Requirement: Los datos de muestra se delatan en el HTML
El HTML de `/vinos` MUST llevar el atributo `data-catalogo-de-muestra` si algún
producto de la proyección tiene `muestra: true`, y MUST NOT llevarlo si ninguno
lo tiene.

#### Scenario: Catálogo sembrado
- **WHEN** el catálogo tiene los datos de muestra
- **THEN** el HTML servido contiene `data-catalogo-de-muestra`, y con la constante del gate apagada no lo contiene
