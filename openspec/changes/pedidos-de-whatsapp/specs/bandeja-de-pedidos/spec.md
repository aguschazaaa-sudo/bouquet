## ADDED Requirements

### Requirement: La bandeja SHALL mostrar los pedidos por estado de entrega, los más nuevos arriba

El panel MUST ofrecer una bandeja que filtra por `estadoEntrega` y ordena por `creadaEn` descendente, con `limit(25)` y sin escuchar cambios en vivo: una lectura por apertura o por «Actualizar», nunca un `snapshots()` abierto.

#### Scenario: Ver lo que falta preparar
- **WHEN** el operador abre la bandeja en «Por preparar»
- **THEN** ve los pedidos con `estadoEntrega == sin_preparar`, el de `creadaEn` más reciente primero

#### Scenario: Una página
- **WHEN** hay 40 pedidos en un estado
- **THEN** la primera página trae 25 y ofrece «Ver más»

#### Scenario: Estado vacío
- **WHEN** no hay ningún pedido en el estado elegido
- **THEN** la bandeja lo dice con una frase, sin lista vacía muda

### Requirement: La consulta SHALL correrse contra el índice declarado

La consulta `estadoEntrega == X` ordenada por `creadaEn desc` MUST resolverse con el índice de `firestore.indexes.json`, y se verifica **corriéndola** contra producción, no mirando que el índice esté `READY`.

#### Scenario: La consulta real
- **WHEN** se corre la consulta contra Firestore con un usuario admin
- **THEN** devuelve documentos o una lista vacía, no `FAILED_PRECONDITION: requires an index`

### Requirement: Las reglas SHALL exigir un límite en la lista de pedidos

`list` sobre `ordenes` MUST requerir `request.query.limit <= 50` y `get` MUST seguir permitido a un admin. Un `list` sin límite, o con 51, MUST rechazarse.

#### Scenario: Con límite
- **WHEN** un admin lista con `limit(25)`
- **THEN** funciona; con `limit(50)` también

#### Scenario: Sin límite o pasado
- **WHEN** un admin lista sin `limit`, o con `limit(51)`
- **THEN** las reglas lo rechazan

#### Scenario: Un comprador y un anónimo
- **WHEN** alguien sin el claim intenta leer o listar `ordenes`
- **THEN** las reglas lo rechazan

### Requirement: Lo que requiere acción SHALL destacarse

Cada fila MUST llevar su rótulo de operador salido de `proyectarEstadoPublico`, y las de un estado público en `estadosPublicosQueRequierenAccion` MUST distinguirse visualmente de las demás.

#### Scenario: Un pedido de WhatsApp por preparar
- **WHEN** el par es `(por_fuera, sin_preparar)`
- **THEN** la fila dice «Cobro por fuera - falta preparar» y se destaca

#### Scenario: Ningún rótulo armado a mano
- **WHEN** se busca en `presentation/` un rótulo construido mirando `estadoPago` y `estadoEntrega` por separado
- **THEN** no existe: todo pasa por `proyectarEstadoPublico`

### Requirement: Cada fila SHALL identificar el pedido por su número

La fila MUST mostrar el `numero` (no el `ordenId`), el nombre de quien recibe, el total de lista y hace cuánto se creó.

#### Scenario: El id no se muestra
- **WHEN** se renderiza cualquier fila
- **THEN** el `ordenId` no aparece en el texto visible
