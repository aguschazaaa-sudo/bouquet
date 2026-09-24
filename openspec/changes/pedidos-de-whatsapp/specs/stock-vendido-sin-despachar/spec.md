## ADDED Requirements

### Requirement: La hoja de corrección SHALL decir cuántas unidades hay vendidas sin despachar

La hoja de corrección de stock MUST mostrar, para el vino que se corrige, la suma de las unidades de sus ítems en pedidos con `estadoEntrega` `sin_preparar` o `preparando`, y explicar que ya están descontadas del stock pero siguen en la estantería.

Es un aviso y NO una baranda: no impide corregir.

#### Scenario: Hay vendidas sin despachar
- **WHEN** el vino tiene 2 unidades en un pedido `sin_preparar` y 3 en uno `preparando`
- **THEN** la hoja dice que hay 5 vendidas sin despachar y que al contar hay que restarlas

#### Scenario: No hay
- **WHEN** ningún pedido abierto lleva ese vino
- **THEN** la hoja no muestra el aviso

#### Scenario: Otro vino no cuenta
- **WHEN** hay pedidos abiertos que llevan sólo otros vinos
- **THEN** la hoja de este vino no muestra el aviso

#### Scenario: Un pedido despachado no cuenta
- **WHEN** un pedido con ese vino está `despachada` o `entregada`
- **THEN** no suma: esas botellas ya salieron de la estantería

### Requirement: El aviso SHALL decir que puede ser incompleto cuando hay muchos pedidos abiertos

La lectura MUST traer como máximo 50 pedidos; si trae 50, el aviso MUST decir que el número puede ser mayor en lugar de afirmar uno incompleto.

#### Scenario: Más de 50 pedidos abiertos
- **WHEN** la lectura devuelve 50 pedidos
- **THEN** el aviso dice que puede haber más unidades vendidas sin despachar

### Requirement: Un fallo de lectura SHALL decirse

Si no se pueden leer los pedidos, la hoja MUST avisar que no pudo ver si hay pedidos sin despachar, y NO MUST mostrar «no hay».

#### Scenario: Sin permiso o sin conexión
- **WHEN** la lectura falla
- **THEN** la hoja lo dice y sigue permitiendo corregir

### Requirement: La venta SHALL verse en el historial del vino

La lista de movimientos (HU-05.4) MUST mostrar un movimiento de venta como *«Se vendió N …»* con el número de pedido, y no como un «movimiento de stock» sin detalle.

#### Scenario: Una venta en la hoja de movimientos
- **WHEN** el vino tiene un movimiento con `operacion.tipo: 'venta'`, cantidad 2 y pedido 7
- **THEN** la hoja dice que se vendieron 2 por el pedido 7, de cuánto a cuánto quedó el stock
