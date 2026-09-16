## ADDED Requirements

### Requirement: El tamaño de la caja es una sola constante

El sistema SHALL definir el tamaño de la caja en una única constante exportada
por `packages/contratos`, `BOTELLAS_POR_CAJA`. Ningún otro archivo MUST escribir
el número 6 para esta regla.

#### Scenario: Cambiar el tamaño no toca más de un archivo

- **WHEN** se cambia `BOTELLAS_POR_CAJA` de 6 a 3
- **THEN** la regla, los textos derivados y los tests se comportan con cajas de 3
- **AND** ningún archivo fuera de `packages/contratos/src/` necesita editarse

### Requirement: La cuenta es en botellas, no en unidades de venta

El sistema SHALL contar `cantidad × presentacion.botellas` de cada línea, no la
cantidad de unidades de venta.

⚠️ **Enmendada el 2026-09-15 por [ADR 009 §10](../../../../../docs/vault/architecture/decisions/009-venta-por-caja.md).**
La regla sólo alcanza a las botellas que se venden **sueltas**: un producto de
más de una botella trae su propio embalaje, viaja solo y **no cuenta** para la
caja de seis. Los dos escenarios de abajo decían lo contrario y son los que
cambiaron.

#### Scenario: Un producto que viene en su propia caja no cuenta

- **WHEN** el carrito tiene 3 unidades de un producto con `presentacion.botellas = 2`
- **THEN** la cuenta de la caja da **0 botellas sueltas**
- **AND** no hay caja que completar: el pedido se puede cobrar

#### Scenario: Mezcla de presentaciones

- **WHEN** el carrito tiene 2 unidades de un producto de 2 botellas y 2 unidades de uno de 1
- **THEN** el pedido tiene **6 botellas** y **2 sueltas**
- **AND** la caja está incompleta: faltan 4
- **AND** el pedido **no** se puede cobrar

### Requirement: Sólo las líneas vigentes cuentan

El sistema SHALL excluir de la cuenta las líneas cuyo estado sea `agotada` o
`no-disponible`, igual que el total en centavos ya las excluye. Una botella que
no se puede vender MUST NOT llenar una caja.

#### Scenario: Una línea agotada no completa la caja

- **WHEN** el carrito tiene 5 botellas vigentes y 1 de un vino agotado
- **THEN** la cuenta da **5 botellas**
- **AND** el estado dice que falta **1**

### Requirement: El estado de la caja se deriva, no se guarda

El sistema SHALL exponer una función pura que, dado el carrito resuelto,
devuelva `botellas`, `cajasCompletas`, `faltan` y `sobran`. `faltan` y `sobran`
MUST calcularse contra el múltiplo de `BOTELLAS_POR_CAJA` más cercano por
arriba y por abajo respectivamente.

#### Scenario: Carrito incompleto

- **WHEN** el carrito tiene 4 botellas vigentes
- **THEN** `cajasCompletas` es 0, `faltan` es 2 y `sobran` es 4

#### Scenario: Carrito completo

- **WHEN** el carrito tiene 12 botellas vigentes
- **THEN** `cajasCompletas` es 2, `faltan` es 0 y `sobran` es 0

#### Scenario: Carrito pasado de una caja

- **WHEN** el carrito tiene 7 botellas vigentes
- **THEN** `cajasCompletas` es 1, `faltan` es 5 y `sobran` es 1

#### Scenario: Carrito vacío

- **WHEN** el carrito no tiene líneas
- **THEN** `botellas` es 0, `cajasCompletas` es 0, `faltan` es 0 y `sobran` es 0

### Requirement: Un carrito incompleto es un carrito válido

`parsearCarrito` MUST NOT rechazar un carrito porque su cantidad de botellas no
sea múltiplo de `BOTELLAS_POR_CAJA`. La regla es una precondición de **cobro**,
no de validez: un carrito a medio llenar es alguien comprando, y rechazarlo
borraría su `localStorage` en la visita siguiente.

#### Scenario: Un carrito de 4 botellas sobrevive a la recarga

- **WHEN** el navegador guarda un carrito de 4 botellas y se recarga la página
- **THEN** `parsearCarrito` lo acepta
- **AND** las 4 botellas siguen en el carrito

### Requirement: El cobro exige cajas completas

Cuando exista `crearOrden`, el servidor SHALL rechazar todo pedido cuya cuenta
de botellas **sueltas** no sea múltiplo de `BOTELLAS_POR_CAJA`, y MUST
recalcular esa cuenta desde la proyección del servidor. El sistema MUST NOT
creerle a un número enviado por el navegador.

Un pedido de **sólo** productos que vienen en su propia caja tiene cero
botellas sueltas y SHALL poder cobrarse: cada uno viaja solo (ADR 009 §10).

#### Scenario: Un pedido de un solo pack se acepta

- **WHEN** llega un pedido con una unidad de un producto de 2 botellas y nada más
- **THEN** el servidor no lo rechaza por la regla de la caja

#### Scenario: Cuatro sueltas y un pack se rechaza

- **WHEN** llega un pedido de 4 botellas sueltas más una unidad de un producto de 2
- **THEN** el servidor lo rechaza: las 4 sueltas no llenan una caja, aunque el pedido tenga 6 botellas

#### Scenario: Un pedido incompleto se rechaza

- **WHEN** llega un pedido cuyas líneas vigentes suman 5 botellas
- **THEN** el servidor lo rechaza sin cobrar y sin descontar stock

#### Scenario: Un pedido vacío se rechaza

- **WHEN** llega un pedido sin líneas vigentes
- **THEN** el servidor lo rechaza

#### Scenario: La cuenta se recalcula en el servidor

- **WHEN** llega un pedido que declara 6 botellas pero cuyas líneas suman 5 contra la proyección del servidor
- **THEN** el servidor lo rechaza
