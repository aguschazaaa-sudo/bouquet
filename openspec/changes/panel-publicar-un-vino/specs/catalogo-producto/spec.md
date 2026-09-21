## ADDED Requirements

### Requirement: Un producto no se borra
`firestore.rules` MUST rechazar el `delete` de cualquier documento de
`productos`, para todos los clientes, incluido un admin. Sacar un producto de
la venta se hace con `publicado: false`.

**El motivo es de plata, no de higiene** (hallazgo 1 de `revisor-pagos`, ADR
008): borrar y recrear con el mismo id se saltea la inmutabilidad de `tipo` y
de `presentacion.botellas`. Una botella suelta con stock 10 recreada como caja
de 2 deja 12 botellas a la venta sobre 10 físicas después de una cancelación.

El Admin SDK saltea las reglas por diseño, así que el seed
(`scripts/seed/borrar.mjs`) MUST seguir funcionando.

#### Scenario: Un admin intenta borrar
- **WHEN** un cliente con el claim `rol: admin` hace `delete` sobre `productos/un-vino`
- **THEN** las reglas lo rechazan

#### Scenario: Despublicar sí se puede
- **WHEN** el mismo admin hace `update` poniendo `publicado: false`
- **THEN** las reglas lo aceptan

#### Scenario: El seed sigue borrando
- **WHEN** `scripts/seed/borrar.mjs` corre con el Admin SDK
- **THEN** borra los productos de muestra, porque el Admin SDK no pasa por las reglas

### Requirement: Un producto publicado tiene precio mayor que cero
`firestore.rules` MUST rechazar cualquier `create` o `update` cuyo documento
resultante tenga `publicado == true` y `precio <= 0`. Un producto **no**
publicado MUST poder tener precio 0: nace así y se completa después.

Sin esta regla se puede publicar con `precio: 0`, pasa el validador de
`contratos`, y un `precioUnitarioVisto: 0` coincidiría cuando exista
`crearOrden` (hallazgo 2 de `revisor-pagos`, ADR 008).

#### Scenario: Publicar con precio cero
- **WHEN** un admin escribe un producto con `publicado: true` y `precio: 0`
- **THEN** las reglas lo rechazan

#### Scenario: Publicar con precio
- **WHEN** el mismo producto va con `publicado: true` y `precio: 1`
- **THEN** las reglas lo aceptan

#### Scenario: Un borrador sin precio
- **WHEN** un admin crea un producto con `publicado: false` y `precio: 0`
- **THEN** las reglas lo aceptan

#### Scenario: Publicar uno que tenía precio cero
- **WHEN** un admin pone `publicado: true` sobre un producto guardado con `precio: 0`, sin tocar el precio
- **THEN** las reglas lo rechazan

### Requirement: Cada imagen de un producto es una URL https
`firestore.rules` MUST exigir que `imagenes` sea una lista de hasta 10 textos y
que **cada entrada empiece con `https://`**. Una lista vacía MUST seguir siendo
válida.

Hoy las reglas sólo miran el largo. `armarCatalogo` exige el `https://`, así
que una entrada que no lo cumple **descarta el producto entero de la vidriera
sin un error visible**: la regla y la proyección tienen que pedir lo mismo.

#### Scenario: Una URL que no es https
- **WHEN** un admin escribe `imagenes: ['http://ejemplo/foto.webp']`
- **THEN** las reglas lo rechazan

#### Scenario: Algo que no es texto
- **WHEN** un admin escribe `imagenes: [123]`
- **THEN** las reglas lo rechazan

#### Scenario: Sin fotos
- **WHEN** un admin escribe `imagenes: []`
- **THEN** las reglas lo aceptan

#### Scenario: Una foto de Storage
- **WHEN** un admin escribe una URL `https://` de Firebase Storage
- **THEN** las reglas lo aceptan

### Requirement: El contrato generado publica el balde, el tope y los descartes
`packages/contratos/generated/contratos.json` MUST llevar un bloque con
fixtures **calculadas por el TypeScript de hoy**: pares de entrada y salida
para `balde` y `tope`, y documentos de ejemplo con el motivo con que
`armarCatalogo` los descarta —o su ausencia, cuando entran—.

Lo que viaja MUST ser el resultado, no la implementación: es lo único que un
test de Dart puede leer sin ejecutar TypeScript.

#### Scenario: El bloque existe y es estable
- **WHEN** se regenera el contrato dos veces sobre el mismo código
- **THEN** los bytes son idénticos

#### Scenario: Las fixtures cubren los tres baldes
- **WHEN** se lee el bloque del balde
- **THEN** hay al menos un caso `disponible`, uno `quedan-pocas` y uno `agotado`

#### Scenario: Las fixtures de descarte tienen los dos lados
- **WHEN** se lee el bloque de descartes
- **THEN** hay al menos un documento que entra al catálogo y uno de cada motivo que lo deja afuera

### Requirement: La ficha de un vino lleva una descripción
`FichaVino` MUST aceptar `descripcion`, un texto opcional que el dueño escribe
sobre el vino. Ausente o `null` significa "no se cargó", igual que `anada` y
que `graduacion`. Si viene, MUST tener contenido después de recortar los
espacios y MUST NOT pasar de **600 caracteres**.

El tope MUST vivir en `firestore.rules` y no sólo en el formulario: el catálogo
entero viaja al navegador para filtrarse en memoria, así que un texto sin
límite lo paga cada visitante. Con 600 y 200 vinos el peor caso son 120 kB
crudos, ~35 kB comprimidos.

`descripcion` MUST llegar a `ProductoPublicado`. Un campo que el panel escribe
y el comprador no ve repite lo que ya pasa con `graduacion`: se carga y no lo
lee nadie.

#### Scenario: Un vino sin descripción
- **WHEN** un admin escribe una ficha sin la clave `descripcion`
- **THEN** las reglas lo aceptan y el contrato la proyecta como `null`

#### Scenario: Una descripción normal
- **WHEN** un admin escribe `descripcion: 'Un Malbec de altura, con taninos redondos.'`
- **THEN** las reglas lo aceptan y el texto llega a `ProductoPublicado`

#### Scenario: Una descripción en blanco
- **WHEN** un admin escribe `descripcion: '   '`
- **THEN** las reglas lo rechazan: para "sin descripción" está `null`

#### Scenario: Una descripción que se pasa del tope
- **WHEN** un admin escribe una `descripcion` de 601 caracteres
- **THEN** las reglas la rechazan

#### Scenario: Una descripción de exactamente el tope
- **WHEN** un admin escribe una `descripcion` de 600 caracteres
- **THEN** las reglas la aceptan
