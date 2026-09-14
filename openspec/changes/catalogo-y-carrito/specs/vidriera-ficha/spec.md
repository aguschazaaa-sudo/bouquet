## ADDED Requirements

### Requirement: La ficha sale de la misma proyección
`/vinos/[slug]` MUST renderizar un producto publicado a partir de la misma
proyección que `/vinos`, sin lecturas adicionales de Firestore. Un slug
inexistente o de un producto no publicado MUST devolver 404.

#### Scenario: Slug inventado
- **WHEN** se pide `/vinos/slug-inventado-de-control`
- **THEN** la respuesta es 404

#### Scenario: Una tarjeta del listado
- **WHEN** el comprador toca una tarjeta en `/vinos`
- **THEN** llega a la ficha de ese vino con respuesta 200

### Requirement: Los datos, el precio y el balde
La ficha MUST mostrar nombre, bodega, varietales, añada, región, presentación,
precio y balde. El precio MUST ir en cifras tabulares, y la mitad inferior
(datos, precio y agregar) MUST ir en modo papel.

#### Scenario: Una caja de 2
- **WHEN** se abre la ficha de una caja de 2
- **THEN** dice que es una caja de 2 y el precio es el de la caja

### Requirement: Agregar al carrito hasta el tope
La ficha MUST ofrecer un selector de cantidad que no pase el `tope` del
producto y un control para agregar al carrito. Si el balde es `agotado`, MUST
NOT ofrecer agregar y MUST decir "Se agotó".

#### Scenario: El selector llega al tope
- **WHEN** el tope del producto es 5 y el comprador intenta subir a 6
- **THEN** el selector queda en 5

#### Scenario: Agotado
- **WHEN** se abre la ficha de un producto agotado
- **THEN** no hay control para agregar y la ficha dice "Se agotó"

### Requirement: Caché de la ficha
`/vinos/[slug]` MUST responder con el mismo `Cache-Control` que `/vinos` y con
`Cache-Tag: catalogo, producto-<productoId>`.

#### Scenario: Cabeceras de la ficha
- **WHEN** se pide una ficha con `curl -I`
- **THEN** la respuesta trae los dos tags

### Requirement: Un vino sin foto no rompe la ficha
Un producto con `imagenes` vacío MUST mostrar el estado sin foto que define el
diseño, nunca una imagen rota.

#### Scenario: Sin foto
- **WHEN** se abre la ficha de un producto sin imágenes
- **THEN** no hay ningún `<img>` con `src` vacío y el estado sin foto es visible
