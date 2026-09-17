## ADDED Requirements

### Requirement: Ver el catálogo entero (HU-03.1)
Catálogo MUST mostrar **todos** los productos, publicados y no publicados, con
su nombre, su bodega y su precio, y MUST distinguir a simple vista cuáles están
a la venta en la tienda. MUST NOT ocultar los no publicados: son justamente los
que hay que terminar de cargar.

#### Scenario: Un vino no publicado
- **WHEN** hay un producto con `publicado: false`
- **THEN** aparece en la lista, marcado como que no está en la tienda

#### Scenario: Un vino de una bodega que no existe
- **WHEN** un producto apunta a un `bodegaId` que no está en `bodegas`
- **THEN** el renglón lo dice, porque `armarCatalogo` lo deja afuera de la vidriera sin avisar

### Requirement: Buscar escribiendo (HU-03.1)
La búsqueda MUST filtrar **en memoria** con un `contains` sobre el texto
normalizado del nombre y de la bodega. MUST NOT hacer una lectura de Firestore
por tecla. MUST NOT ser difusa (ARQUITECTURA §7).

#### Scenario: Buscar sin acentos
- **WHEN** el operador escribe "torrontes"
- **THEN** aparecen los vinos cuyo nombre o bodega contiene "Torrontés"

#### Scenario: Buscar por bodega
- **WHEN** el operador escribe el nombre de una bodega
- **THEN** aparecen sus vinos

#### Scenario: No hay ninguno
- **WHEN** lo que se escribe no coincide con nada
- **THEN** el panel lo dice y ofrece limpiar la búsqueda, y no queda una lista vacía sin explicación

### Requirement: El catálogo se lee una vez por sesión
El catálogo MUST mantenerse en memoria mientras dure la sesión y MUST NOT
llevar `autoDispose`: descartarlo hace releer los 230 documentos en cada
navegación entre secciones (ARQUITECTURA §6.3).

#### Scenario: Ir a Pedidos y volver
- **WHEN** el operador va a Pedidos y vuelve a Catálogo
- **THEN** la lista ya está, sin volver a leer Firestore

### Requirement: Cargando y error se ven
Mientras el catálogo se lee, MUST verse que se está leyendo. Si la lectura
falla, MUST verse el fallo y MUST haber forma de reintentar. MUST NOT quedar una
lista vacía indistinguible de "todavía no cargaste nada".

#### Scenario: Se cae la red
- **WHEN** la lectura de productos falla
- **THEN** el operador ve que falló y un botón para reintentar, no un catálogo vacío
