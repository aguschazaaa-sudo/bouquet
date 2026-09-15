## ADDED Requirements

### Requirement: La restricción se dice antes de agregar

La vidriera SHALL decir que el vino se vende de a `BOTELLAS_POR_CAJA` botellas
en el listado y en la ficha, **junto al control de compra**, no sólo en el
carrito. El aviso MUST estar en el HTML servido, sin depender de JavaScript.

#### Scenario: El aviso llega sin JavaScript

- **WHEN** se pide `/vinos` y se lee el HTML servido, sin ejecutar JavaScript
- **THEN** el aviso de venta por caja aparece
- **AND** aparece también en el HTML de una ficha `/vinos/[slug]`

#### Scenario: El aviso no se repite por tarjeta

- **WHEN** el listado muestra 20 vinos
- **THEN** el aviso aparece una vez para el listado, no 20 veces

### Requirement: El contador de la barra muestra el avance de la caja

El contador de la barra de navegación SHALL mostrar cuántas botellas hay sobre
el tamaño de la caja, en lugar de sólo las unidades. MUST salir de
`localStorage` y costar **cero** lecturas de Firestore.

#### Scenario: Avance parcial

- **WHEN** el carrito tiene 4 botellas vigentes
- **THEN** el contador comunica 4 de 6

#### Scenario: Más de una caja

- **WHEN** el carrito tiene 8 botellas vigentes
- **THEN** el contador comunica una caja completa y 2 botellas de la siguiente

#### Scenario: Cero lecturas

- **WHEN** un visitante navega la vidriera con un carrito cargado
- **THEN** el contador no dispara ninguna lectura de Firestore

### Requirement: El carrito dice cuántas faltan o cuántas sobran

`/carrito` SHALL decir, en una sola frase, qué le falta al carrito para poder
despacharse. Cuando `faltan` y `sobran` sean los dos distintos de cero, MUST
ofrecer el camino más corto —agregar si `faltan ≤ sobran`, sacar si no— y MUST
NOT afirmar los dos a la vez.

#### Scenario: Faltan pocas

- **WHEN** el carrito tiene 5 botellas vigentes
- **THEN** el carrito dice que falta 1

#### Scenario: Sobra una

- **WHEN** el carrito tiene 7 botellas vigentes
- **THEN** el carrito dice que sobra 1, y no dice que faltan 5

#### Scenario: Caja completa

- **WHEN** el carrito tiene 6 botellas vigentes
- **THEN** el carrito no pide ni agregar ni sacar

#### Scenario: Una línea agotada explica el faltante

- **WHEN** el carrito tiene 6 botellas de las cuales 1 está agotada
- **THEN** el carrito dice que falta 1
- **AND** la línea agotada sigue marcada como tal

### Requirement: El carrito vacío no reclama

El estado vacío del carrito MUST NOT pedir botellas para completar una caja: no
hay caja empezada que completar.

#### Scenario: Carrito vacío

- **WHEN** el carrito no tiene líneas
- **THEN** se muestra el estado vacío existente, sin mensaje de faltante

### Requirement: La vidriera no ofrece terminar la compra

Mientras `crearOrden` no exista, la vidriera MUST NOT mostrar un botón de
terminar la compra, ni con la caja completa. Una caja completa SHALL informarse
como tal y nada más.

#### Scenario: Caja completa sin checkout

- **WHEN** el carrito tiene 6 botellas vigentes
- **THEN** no aparece ningún control que prometa cobrar o iniciar un pago
