## ADDED Requirements

### Requirement: La siembra sólo corre contra bouquet-vinos
`scripts/seed/` MUST fijar `projectId: 'bouquet-vinos'` y MUST negarse a
escribir si el proyecto resuelto es otro, sea cual sea la configuración activa
de gcloud.

#### Scenario: gcloud apunta a otro proyecto
- **WHEN** el proyecto activo de gcloud es `red-social-ryb3mf` y se corre el seed
- **THEN** el seed escribe en `bouquet-vinos`, o se niega a correr, y nunca escribe en el otro proyecto

### Requirement: La siembra es re-ejecutable
El seed MUST usar ids deterministas y `set`, nunca `add`, y MUST nombrar cada
foto por el hash de su contenido. Correrlo dos veces MUST dejar la misma
cantidad de documentos y de archivos.

#### Scenario: Correr dos veces
- **WHEN** se corre el seed dos veces seguidas
- **THEN** `productos` tiene 20 documentos y cada carpeta de fotos, un solo archivo

### Requirement: El catálogo de muestra cubre los estados feos
El seed MUST escribir 20 vinos argentinos de gama media que incluyan tintos,
blancos y rosados; cepas y cortes; al menos tres orgánicos; dos cajas de 2; al
menos un agotado; al menos dos en "quedan pocas", y un vino sin foto. MUST
escribir también sus bodegas y `metricas/popularidad` con `simulada: true`.

#### Scenario: Revisar la siembra
- **WHEN** se lee la proyección después de sembrar
- **THEN** están presentes los tres colores, un corte, un orgánico, una caja de 2, un agotado y un vino sin foto

### Requirement: Las fotos van a Storage en WebP y ninguna es un placeholder
Cada foto MUST subirse a `productos/{productoId}/{hash}.webp`, convertida con
`sharp`. El seed MUST rechazar un archivo que no sea una imagen, o que sea la
imagen genérica de "no disponible" de una vinoteca.

#### Scenario: Una foto de placeholder
- **WHEN** una de las fotos candidatas es la imagen de "Imagen no disponible"
- **THEN** el seed no la sube y lo informa

### Requirement: Todo lo sembrado se puede borrar sin tocar nada más
Todo documento sembrado MUST llevar `muestra: true`. El script de borrado MUST
borrar por la lista de ids que escribió el seed, y MUST NOT borrar por
`where('muestra', '==', true)`.

#### Scenario: Un producto real convive con los de muestra
- **WHEN** existe un producto real y se corre el borrado
- **THEN** se borran los 20 de muestra y el real queda intacto
