## ADDED Requirements

### Requirement: El tipo del producto es explícito e inmutable
Todo documento de `productos` MUST nacer con `tipo` igual a `'simple'` o
`'compuesto'`, y las reglas de Firestore MUST rechazar cualquier `update` que
lo cambie. Ningún consumidor SHALL deducir el tipo por la ausencia de otro
campo.

#### Scenario: Alta sin tipo
- **WHEN** el panel crea un producto sin el campo `tipo`
- **THEN** las reglas rechazan la escritura

#### Scenario: Cambio de tipo
- **WHEN** el panel actualiza `tipo` de `'simple'` a `'compuesto'`
- **THEN** las reglas rechazan la escritura

### Requirement: El stock lo escribe sólo el servidor
`stock` MUST vivir en la raíz del documento, ser entero y ≥ 0, y contar
**unidades de venta**. Las reglas MUST rechazar toda escritura de `stock` o de
`muestra` que venga de un cliente, salvo la creación de un simple con
`stock == 0`. Un producto compuesto MUST NOT tener `stock`.

#### Scenario: El panel sobrescribe el stock
- **WHEN** un operador con `rol == 'admin'` actualiza `stock` de un producto
- **THEN** las reglas rechazan la escritura

#### Scenario: Alta de un simple con stock
- **WHEN** el panel crea un producto simple con `stock: 5`
- **THEN** las reglas rechazan la escritura, y con `stock: 0` la aceptan

### Requirement: La presentación es inmutable
`presentacion.botellas` MUST ser un entero ≥ 1 escrito al crear el producto, y
las reglas MUST rechazar cualquier `update` que lo cambie. Una caja de 2 que
comparte botellas con otro producto MUST modelarse como compuesto, no como un
simple con `botellas: 2`.

#### Scenario: Una botella suelta pasa a caja
- **WHEN** el panel actualiza `presentacion.botellas` de 1 a 2
- **THEN** las reglas rechazan la escritura

### Requirement: Los campos obligatorios no se pueden borrar
Todo `update` de `productos` MUST dejar presentes y con su tipo `nombre`
(string no vacío), `precio` (entero ≥ 0), `publicado` (bool), `imagenes`
(lista), `fichaVino.color` y `fichaVino.organico`. Las reglas MUST cerrar el
documento con `keys().hasOnly([...])` y comparar los mapas anidados de forma
explícita.

#### Scenario: Update que borra el precio
- **WHEN** el panel manda un `update` que elimina `precio`
- **THEN** las reglas rechazan la escritura

#### Scenario: Campo desconocido
- **WHEN** el panel crea un producto con un campo que no está en la lista
- **THEN** las reglas rechazan la escritura

### Requirement: Los varietales salen de una lista cerrada
`fichaVino.varietales` MUST ser una lista no vacía cuyos elementos pertenezcan
a la lista `VARIETALES` de `packages/contratos`. Las reglas MUST hacerlo
cumplir con `hasOnly`, y un chequeo de CI MUST fallar si la lista de las reglas
difiere de la de `contratos`.

#### Scenario: Varietal escrito de otra forma
- **WHEN** el panel guarda `varietales: ['Cab. Sauv.']`
- **THEN** las reglas rechazan la escritura

#### Scenario: Las dos listas se desincronizan
- **WHEN** se agrega un varietal a `contratos` y no a `firestore.rules`
- **THEN** el chequeo de CI sale con código distinto de 0

### Requirement: Cepa o corte se deduce de los varietales
Un producto con un solo varietal SHALL considerarse **cepa**, y uno con dos o
más, **corte**. Ningún documento SHALL guardar ese dato por separado.

#### Scenario: Un corte
- **WHEN** un producto tiene `varietales: ['Malbec', 'Cabernet Sauvignon']`
- **THEN** la proyección lo marca como corte

### Requirement: El balde de stock se calcula en botellas
`balde(producto)` MUST devolver `agotado` si `stock <= 0`, `quedan-pocas` si
`stock × presentacion.botellas <= 6`, y `disponible` en otro caso.

#### Scenario: Caja de 2 con tres cajas
- **WHEN** un producto con `botellas: 2` tiene `stock: 3`
- **THEN** el balde es `quedan-pocas`

#### Scenario: Sin stock
- **WHEN** un producto tiene `stock: 0`
- **THEN** el balde es `agotado`

### Requirement: El tope por pedido
`tope(producto)` MUST devolver `max(0, min(stock, 12))` unidades de venta.

#### Scenario: Stock alto
- **WHEN** un producto tiene `stock: 48`
- **THEN** el tope es 12

#### Scenario: Stock negativo por un error de datos
- **WHEN** un producto tiene `stock: -2`
- **THEN** el tope es 0

### Requirement: La proyección pública no lleva el stock
`proyectarProducto()` MUST devolver un `ProductoPublicado` sin `stock` y sin
unidades vendidas. Un documento que no valida MUST quedar excluido de la
proyección sin impedir que se arme el resto, y dos productos con el mismo slug
MUST quedar excluidos los dos.

#### Scenario: Un documento roto
- **WHEN** un producto publicado no tiene `precio`
- **THEN** la proyección se arma igual, sin ese producto, y el error queda en el log

#### Scenario: Slug duplicado
- **WHEN** dos productos publicados tienen el mismo `slug`
- **THEN** ninguno de los dos aparece en la proyección

### Requirement: Un solo parser del carrito
`parsearCarrito()` de `packages/contratos` MUST ser el único lugar que valida un
carrito, y lo MUST usar tanto el navegador como `crearOrden`. MUST rechazar
líneas con `productoId` repetido, cantidades que no sean enteras ≥ 1 y
versiones desconocidas, sin corregirlas.

#### Scenario: Cantidad negativa
- **WHEN** un carrito trae una línea con `cantidad: -5`
- **THEN** `parsearCarrito()` lo rechaza

#### Scenario: Línea duplicada
- **WHEN** un carrito trae dos líneas con el mismo `productoId`
- **THEN** `parsearCarrito()` lo rechaza

### Requirement: El pedido de compra lleva la clave de idempotencia y el precio visto
`packages/contratos` MUST definir `PedidoDeCompra` con `idCompra` y, por línea,
`productoId`, `cantidad` y `precioUnitarioVisto` en centavos. Es el contrato que
va a validar `crearOrden` en la próxima sesión.

#### Scenario: El tipo existe antes que su consumidor
- **WHEN** se compila `packages/contratos`
- **THEN** `PedidoDeCompra` se exporta con esos campos y `tsc --noEmit` sale con 0

### Requirement: La popularidad es un documento recalculado y cerrado
`metricas/popularidad` MUST ser un único documento con `simulada`,
`calculadaEn` y `unidades` por `productoId`. Las reglas MUST negar toda
escritura de clientes y permitir la lectura sólo a admin. La vidriera MUST
recibir el puesto de cada vino, nunca las unidades.

#### Scenario: Un cliente intenta escribir la métrica
- **WHEN** un navegador intenta escribir `metricas/popularidad`
- **THEN** las reglas rechazan la escritura
