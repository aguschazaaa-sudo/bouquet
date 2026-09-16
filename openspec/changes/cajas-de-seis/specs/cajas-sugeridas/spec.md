## ADDED Requirements

### Requirement: Una caja sugerida no es un producto

Una caja sugerida SHALL ser una lista de `productoId` con un nombre y un slug.
MUST NOT tener precio propio, stock propio ni documento en `productos`. El
precio de llevarla es siempre la suma de lo que quede en el carrito.

#### Scenario: No aparece en el catálogo como producto

- **WHEN** se arma la proyección del catálogo
- **THEN** ninguna caja sugerida aparece en la lista de productos
- **AND** ninguna caja sugerida tiene ficha propia en `/vinos/[slug]`

### Requirement: Las cajas sugeridas viven en un solo documento

El sistema SHALL guardar todas las cajas sugeridas en un único documento,
reescrito entero, con el mismo patrón que `metricas/popularidad`. Leerlas MUST
costar **una** lectura, adentro de la misma caché que ya envuelve al catálogo.

#### Scenario: Una lectura por reconstrucción

- **WHEN** se reconstruye una página de la vidriera
- **THEN** las cajas sugeridas cuestan exactamente una lectura de Firestore

#### Scenario: Cero lecturas por visita

- **WHEN** un visitante abre `/vinos` con la caché vigente
- **THEN** las cajas sugeridas no disparan ninguna lectura

### Requirement: Una caja sugerida suma exactamente una caja, con botellas sueltas

El validador SHALL exigir que una caja sugerida tenga exactamente
`BOTELLAS_POR_CAJA` entradas y que **todas** nombren productos que se venden
sueltos (`presentacion.botellas = 1`). Una sugerencia que no arma una caja
completa MUST quedar afuera.

⚠️ **Enmendada el 2026-09-15 por [ADR 009 §10](../../../../../docs/vault/architecture/decisions/009-venta-por-caja.md).**
Un producto de más de una botella trae su propio embalaje, viaja solo y no
cuenta para la caja de seis: una sugerencia que lo incluya dejaría el carrito
con la caja abierta y sin botón de pagar. Por eso el escenario de los tres
packs, que antes era válido, ahora es el que **no** puede pasar.

#### Scenario: Seis productos de una botella

- **WHEN** una sugerencia nombra 6 productos de 1 botella cada uno
- **THEN** la sugerencia es válida

#### Scenario: Tres productos de dos botellas

- **WHEN** una sugerencia nombra 3 productos de 2 botellas cada uno
- **THEN** queda excluida: cada uno viaja solo y ninguno arma caja

#### Scenario: Un solo pack entre cinco sueltas

- **WHEN** una sugerencia nombra 5 productos de 1 botella y 1 de 2 botellas
- **THEN** queda excluida, y el motivo nombra al producto empacado

#### Scenario: Una sugerencia corta queda afuera

- **WHEN** una sugerencia tiene 5 entradas
- **THEN** queda excluida y se informa el motivo en los descartes

### Requirement: Un documento roto no tira el render

Una caja sugerida inválida SHALL excluirse e informarse en `descartes`, con la
misma disciplina que `armarCatalogo` aplica a los productos. El render de
`/vinos` MUST NOT fallar por una sugerencia mal cargada.

#### Scenario: El documento entero es inválido

- **WHEN** el documento de cajas sugeridas no tiene la forma esperada
- **THEN** la vidriera se sirve sin carril de cajas y registra el descarte

#### Scenario: Una sugerencia repite un slug

- **WHEN** dos sugerencias tienen el mismo slug
- **THEN** quedan excluidas las dos, y se informa el motivo

### Requirement: Una sugerencia con un vino caído se muestra igual

La vidriera SHALL mostrar una sugerencia que nombre un producto ausente de la
proyección o agotado, con ese lugar marcado. MUST NOT descartar la sugerencia
entera: los vinos que sí están siguen siendo una idea válida.

#### Scenario: Un componente despublicado

- **WHEN** una sugerencia nombra 6 vinos y 1 ya no está publicado
- **THEN** la sugerencia se muestra con 5 vinos y el faltante marcado

#### Scenario: Un componente agotado

- **WHEN** una sugerencia nombra un vino con `balde` `agotado`
- **THEN** ese lugar se marca como agotado y el resto se muestra normal

### Requirement: Elegir una sugerencia agrega al carrito, no lo reemplaza

Elegir una caja sugerida SHALL agregar sus productos a lo que ya haya en el
carrito, respetando el `tope` de cada producto. MUST NOT borrar líneas que el
comprador ya tenía.

#### Scenario: Carrito vacío

- **WHEN** el carrito está vacío y se elige una sugerencia de 6 botellas
- **THEN** el carrito queda con esas 6 botellas y la caja completa

#### Scenario: Carrito con algo adentro

- **WHEN** el carrito tiene 2 botellas y se elige una sugerencia de 6
- **THEN** el carrito queda con 8 botellas
- **AND** el carrito informa que sobran 2

#### Scenario: El tope corta el agregado

- **WHEN** una sugerencia pide más unidades de un producto que su `tope` de hoy
- **THEN** la cantidad queda en el tope
- **AND** la pantalla dice que la caja quedó incompleta

#### Scenario: Después de elegirla se puede cambiar

- **WHEN** se elige una sugerencia y después se quita uno de sus vinos
- **THEN** el vino se quita como cualquier línea del carrito

### Requirement: El carril sólo aparece si hay algo que mostrar

`/vinos` SHALL mostrar el carril de cajas sugeridas únicamente cuando haya al
menos una sugerencia válida. MUST NOT mostrar un carril vacío con su título.

#### Scenario: Sin sugerencias

- **WHEN** no hay ninguna caja sugerida válida
- **THEN** `/vinos` se sirve sin carril, y el listado no cambia

### Requirement: Nadie toca las cajas sugeridas desde el navegador

Las reglas de Firestore MUST negar toda lectura y toda escritura del documento
de cajas sugeridas al navegador anónimo, con la misma postura que `metricas` y
`zonas`: la vidriera lo lee con el Admin SDK desde el servidor, que no pasa por
las reglas, y el visitante nunca tiene un SDK de Firestore en la mano
(ARQUITECTURA §9). El panel SHALL poder leerlo.

La escritura MUST quedar del lado del servidor incluso para un admin: la
composición sólo se puede verificar mirando `presentacion.botellas` de cada
producto, y hacerlo en las reglas costaría una lectura facturada por producto
en cada escritura.

#### Scenario: Lectura anónima rechazada

- **WHEN** un cliente sin autenticar lee el documento
- **THEN** la lectura se rechaza

#### Scenario: Escritura anónima rechazada

- **WHEN** un cliente sin autenticar intenta escribir el documento
- **THEN** la escritura se rechaza

#### Scenario: El panel puede leer

- **WHEN** un cliente con el claim de admin lee el documento
- **THEN** la lectura se permite

#### Scenario: Ni el admin escribe directo

- **WHEN** un cliente con el claim de admin intenta escribir el documento
- **THEN** la escritura se rechaza
