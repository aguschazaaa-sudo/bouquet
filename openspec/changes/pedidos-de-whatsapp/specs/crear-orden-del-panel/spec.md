## ADDED Requirements

### Requirement: Sólo un admin SHALL poder crear una Orden por la callable del panel

`crearOrdenDelPanel` MUST rechazar con `unauthenticated` a quien no está autenticado y con `permission-denied` a quien no tiene el claim `rol: admin`, antes de leer o escribir nada.

Además, las reglas de Firestore MUST seguir negando `create` sobre `ordenes` a todo cliente:
la única puerta es esta callable.

#### Scenario: Anónimo
- **WHEN** se llama sin sesión
- **THEN** responde `unauthenticated` y no toca Firestore

#### Scenario: Con sesión pero sin claim
- **WHEN** se llama con un usuario sin `rol: admin`
- **THEN** responde `permission-denied`

#### Scenario: Ningún cliente crea una Orden por las reglas
- **WHEN** un admin intenta `setDoc` sobre `ordenes/x` desde el SDK de cliente
- **THEN** las reglas lo rechazan

### Requirement: El origen SHALL ser `whatsapp` y lo fija el servidor

La callable MUST escribir `origen: 'whatsapp'` y `estadoPago: estadoDePagoInicial('whatsapp')`, y MUST rechazar con `invalid-argument` un pedido que traiga un campo `origen` o `estadoPago`.

#### Scenario: El pedido intenta declarar el origen
- **WHEN** el pedido incluye `origen: 'vidriera'`
- **THEN** responde `invalid-argument` y no crea nada

#### Scenario: La Orden nace con los estados correctos
- **WHEN** se crea una Orden
- **THEN** `origen` es `whatsapp`, `estadoPago` es `por_fuera` y `estadoEntrega` es `sin_preparar`

### Requirement: La creación MUST descontar el stock y numerar en una sola transacción

La callable SHALL, en **una** transacción de Firestore, descontar `cantidad` del `stock` de cada producto, asignar `numero` desde `contadores/ordenes` y crear la Orden. Si cualquier parte falla, ninguna se aplica.

#### Scenario: Un pedido de dos vinos
- **WHEN** se pide 2 del vino A (stock 10) y 3 del vino B (stock 5)
- **THEN** A queda en 8, B en 2, y existe una Orden con `numero` igual al contador anterior + 1

#### Scenario: Una línea sin stock aborta todo
- **WHEN** se pide 2 de A (stock 10) y 6 de B (stock 5)
- **THEN** responde `failed-precondition` con `{ codigo: 'sin-stock', productoId: 'B', actual: 5 }` y A sigue en 10

#### Scenario: El stock nunca queda negativo
- **WHEN** se piden exactamente las unidades que hay
- **THEN** el stock queda en 0 y no en un número negativo

#### Scenario: Dos pedidos a la vez sobre el mismo vino
- **WHEN** dos llamadas concurrentes piden 6 cada una de un vino con stock 10
- **THEN** exactamente una tiene éxito y la otra responde `failed-precondition`; el stock final es 4

#### Scenario: Los números no se repiten
- **WHEN** se crean N pedidos en paralelo sobre productos distintos
- **THEN** los N `numero` son distintos y consecutivos

### Requirement: El mismo `idPedido` SHALL ser una sola Orden

`ordenId` MUST ser el `idPedido` del pedido, de modo que crear la Orden sea escribir su propio marcador. Un reintento con el pedido entero igual —líneas, contacto y entrega— SHALL devolver el `numero` que ya existe sin tocar nada; con cualquier dato distinto, `already-exists` con el `numero` de la Orden que ya existe.

#### Scenario: Reintento tras un timeout
- **WHEN** se llama dos veces con el mismo `idPedido` y las mismas líneas
- **THEN** la segunda devuelve el mismo `numero` con `repetido: true`, el stock se descontó una vez y hay una sola Orden

#### Scenario: El mismo id con otras líneas
- **WHEN** se llama con un `idPedido` ya usado y cantidades distintas
- **THEN** responde `already-exists` con `{ codigo: 'otro-pedido', numero }` y no modifica el stock

#### Scenario: El mismo id con otra dirección
- **WHEN** se reintenta con el mismo `idPedido` y las mismas líneas, pero otra calle
- **THEN** responde `already-exists` con el `numero`, y la Orden conserva la calle original

#### Scenario: El mismo id con otro cliente
- **WHEN** se reintenta con el mismo `idPedido`, las mismas líneas y otro nombre
- **THEN** responde `already-exists`, y no se crea una segunda Orden

#### Scenario: El reintento tras vender el resto
- **WHEN** el primer intento tuvo éxito y otro pedido dejó el stock en 0
- **THEN** el reintento del primero devuelve lo que pasó, no `sin-stock`

### Requirement: La callable SHALL rechazar lo que no se puede vender

Dentro de la transacción, la callable MUST rechazar un producto que no existe (`not-found`), que es `compuesto` o tiene stock inválido, o que es de muestra (`muestra == true`), todos con `failed-precondition` salvo el primero. NO MUST exigir que el vino esté publicado.

#### Scenario: Vino de muestra
- **WHEN** una línea es de un producto con `muestra: true`
- **THEN** responde `failed-precondition` y no descuenta nada

#### Scenario: Vino no publicado
- **WHEN** una línea es de un vino con `publicado: false`, `muestra` ausente y stock suficiente
- **THEN** la Orden se crea

#### Scenario: Compuesto
- **WHEN** una línea es de un producto `compuesto`
- **THEN** responde `failed-precondition`

### Requirement: El precio visto SHALL coincidir con el de lista

Cada línea MUST traer `precioUnitarioVisto`; si no es igual al `precio` del producto leído en la transacción, la callable SHALL rechazar con `failed-precondition` y `{ codigo: 'cambio-el-precio', productoId, actual }`.

#### Scenario: El precio cambió mientras el operador cargaba
- **WHEN** el vino costaba 1.990.000 centavos y ahora cuesta 2.100.000
- **THEN** responde `cambio-el-precio` con `actual: 2100000` y no descuenta nada

### Requirement: La Orden SHALL guardar un snapshot de cada ítem

Cada elemento de `items[]` MUST ser `{ productoId, nombre, precioUnitario, cantidad, botellas }` con los valores del producto **al momento de crear**, y `subtotal` y `total` MUST ser la suma de `precioUnitario × cantidad` en centavos enteros, con `envio: null`.

#### Scenario: El producto cambia después
- **WHEN** se crea una Orden y luego el vino cambia de nombre y de precio
- **THEN** la Orden conserva el nombre y el precio de cuando se creó

#### Scenario: Una caja de 2
- **WHEN** la línea es de un producto con `presentacion.botellas: 2`
- **THEN** el ítem guarda `botellas: 2` y el stock baja en unidades de venta, no en botellas

### Requirement: El pedido SHALL validarse entero antes de tocar Firestore

`parsearPedidoDelPanel` en `contratos` MUST rechazar, con el motivo, un pedido sin líneas, con más de 30, con un `productoId` repetido, con una `cantidad` que no sea entero de 1 a `TOPE_DE_STOCK`, con un `idPedido` fuera de `[A-Za-z0-9_-]{16,64}`, o con datos de entrega que `validarDatosDeEntrega` rechace. El teléfono MUST salir normalizado a E.164.

#### Scenario: Línea repetida
- **WHEN** el mismo `productoId` aparece dos veces
- **THEN** el parser rechaza con el motivo, y la callable responde `invalid-argument`

#### Scenario: Teléfono pegado del chat
- **WHEN** el teléfono llega como `0351 15-555-1234`
- **THEN** la Orden guarda `contacto.telefonoE164` en formato `+549…`

#### Scenario: Teléfono inválido
- **WHEN** el teléfono no tiene 10 dígitos nacionales
- **THEN** responde `invalid-argument` y no crea nada

### Requirement: La regla de las seis botellas SHALL NOT aplicarse

La callable MUST aceptar un pedido cuyas botellas sueltas no suman un múltiplo de `BOTELLAS_POR_CAJA`.

#### Scenario: Cuatro botellas
- **WHEN** el pedido lleva 4 botellas sueltas
- **THEN** la Orden se crea

### Requirement: Cada venta SHALL dejar su movimiento en el historial del vino

La transacción MUST escribir, por cada línea, un documento en `productos/{id}/movimientos/venta-{idPedido}` con `operacion: { tipo: 'venta', cantidad, idPedido, numero }`, `antes`, `despues`, `por` y `en`, en la misma transacción que el descuento.

#### Scenario: Un movimiento por línea
- **WHEN** se carga un pedido de dos vinos
- **THEN** cada vino tiene un movimiento con lo que se vendió, el stock antes y después, y quién lo cargó

#### Scenario: Un reintento no lo duplica
- **WHEN** se repite el mismo pedido
- **THEN** cada vino sigue teniendo un solo movimiento de esa venta

#### Scenario: Un rechazo no deja ninguno
- **WHEN** una línea del pedido no tiene stock
- **THEN** ningún vino del pedido tiene un movimiento nuevo

### Requirement: Un vino sin precio SHALL rechazarse con su propio código

La callable MUST rechazar un producto con `precio < 1` con `failed-precondition` y `{ codigo: 'sin-precio', productoId }`, y no con `cambio-el-precio`.

#### Scenario: Un borrador sin precio
- **WHEN** el vino tiene `precio: 0`
- **THEN** responde `sin-precio` y no descuenta nada

### Requirement: El pedido SHALL tener topes que impidan un desborde o una Orden enorme

`parsearPedidoDelPanel` MUST rechazar, con un motivo y sin lanzar, un `precioUnitarioVisto` mayor que `PRECIO_MAXIMO`, un `idPedido` reservado (`__x__`) y un texto libre de la entrega que pase su largo máximo.

#### Scenario: Un precio absurdo
- **WHEN** el precio visto es `1e300`
- **THEN** el parser rechaza con el motivo y la callable responde `invalid-argument`, no `internal`

#### Scenario: Una referencia enorme
- **WHEN** la referencia tiene 900.000 caracteres
- **THEN** el parser la rechaza
