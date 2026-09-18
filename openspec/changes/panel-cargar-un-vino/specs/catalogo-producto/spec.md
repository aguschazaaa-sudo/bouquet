## ADDED Requirements

### Requirement: El id de un producto nuevo es su slug
Las reglas de Firestore MUST rechazar la creación de un documento de
`productos` cuyo `slug` no sea igual al id del documento. Así la unicidad del
slug la garantiza la base, sin `get()` en las reglas ni una colección de
reservas.

#### Scenario: Alta con el id igual al slug
- **WHEN** el panel crea `productos/trumpeter-malbec` con `slug: 'trumpeter-malbec'`
- **THEN** las reglas aceptan la escritura

#### Scenario: Alta con otro id
- **WHEN** el panel crea `productos/abc123` con `slug: 'trumpeter-malbec'`
- **THEN** las reglas rechazan la escritura

### Requirement: El slug no cambia
Las reglas MUST rechazar todo `update` de `productos` que cambie el `slug`.
Vale también para los documentos anteriores a esta regla, cuyo id no es su
slug (los de muestra: `muestra-<slug>`).

#### Scenario: Cambiar el slug
- **WHEN** el panel actualiza el `slug` de un producto
- **THEN** las reglas rechazan la escritura

#### Scenario: Corregir un vino de muestra
- **WHEN** el panel corrige el nombre de `muestra-trumpeter-malbec` sin tocar su slug
- **THEN** las reglas aceptan la escritura

### Requirement: La graduación es opcional y va en décimas
`fichaVino.graduacion` MUST ser opcional. Si está, MUST ser `null` o un entero
entre 50 y 250 que cuenta **décimas de grado** (135 es 13,5 %). Las reglas y
`validarProducto` de `packages/contratos` MUST aceptar y rechazar lo mismo.

El piso de 50 (5 %) no describe a los vinos: **atrapa la confusión de unidad**.
Un `14` escrito pensando en 14 % valdría 1,4 %, y con el piso se rechaza, igual
que `13.5` (no es entero) y `1350` (fuera de rango).

#### Scenario: Con graduación
- **WHEN** el panel crea un vino con `fichaVino.graduacion: 135`
- **THEN** las reglas aceptan la escritura y `validarProducto` lo valida

#### Scenario: Graduación con decimales
- **WHEN** el panel crea un vino con `fichaVino.graduacion: 13.5`
- **THEN** las reglas rechazan la escritura y `validarProducto` también

#### Scenario: Fuera de rango
- **WHEN** el panel crea un vino con `fichaVino.graduacion: 1350`
- **THEN** las reglas rechazan la escritura

#### Scenario: La unidad equivocada
- **WHEN** un script escribe `fichaVino.graduacion: 14` pensando en 14 %
- **THEN** las reglas rechazan la escritura y `validarProducto` también

#### Scenario: Un vino anterior, sin el campo
- **WHEN** se corrige un vino que no tiene `graduacion`
- **THEN** las reglas aceptan la escritura
