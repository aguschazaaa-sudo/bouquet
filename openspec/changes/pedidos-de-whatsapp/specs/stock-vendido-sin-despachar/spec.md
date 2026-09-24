## ADDED Requirements

### Requirement: La hoja de corrección SHALL decir cuántas unidades hay en pedidos que no figuran como despachados

La hoja de corrección de stock MUST mostrar, para el vino que se corrige, la suma de las unidades de sus ítems en pedidos con `estadoEntrega` `sin_preparar` o `preparando`, decir que ya están descontadas del stock, y dar **las dos salidas**: si siguen en la estantería se restan de lo que se cuenta, y si ya salieron no.

Es condicional a propósito: mientras el panel no pueda marcar un despacho (EP-07), un pedido cuyas botellas ya salieron sigue figurando abierto, y ordenar «restale esas» haría restar de más. Es un aviso y NO una baranda: no impide corregir.

#### Scenario: Hay pedidos abiertos con ese vino
- **WHEN** el vino tiene 2 unidades en un pedido `sin_preparar` y 3 en uno `preparando`
- **THEN** la hoja dice que hay 5 en pedidos que todavía no figuran como despachados, que ya están descontadas, y que si siguen en la estantería hay que restarlas y si ya salieron no

#### Scenario: El aviso no da una orden a secas
- **WHEN** se lee el texto del aviso
- **THEN** menciona tanto el caso de que sigan en la estantería como el de que ya hayan salido

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

### Requirement: Los pedidos abiertos SHALL leerse una vez y compartirse entre los vinos

El panel MUST leer los pedidos abiertos una sola vez y sacar de esa lectura lo de cada vino, y NO MUST releerlos por cada hoja que se abre: contar el depósito abre la hoja de muchos vinos seguidos. Lo leído SHALL conservarse un tiempo corto y sólo si la lectura salió bien.

#### Scenario: Dos hojas seguidas
- **WHEN** el operador abre la hoja de corrección de dos vinos distintos en menos de dos minutos
- **THEN** se hace una sola lectura de pedidos

#### Scenario: Un error no se cachea
- **WHEN** la lectura falla y el operador vuelve a abrir la hoja
- **THEN** se reintenta la lectura

#### Scenario: Un vino que ningún pedido lleva
- **WHEN** ningún pedido abierto lleva el vino de la segunda hoja
- **THEN** esa hoja no muestra el aviso, sin haber leído nada más
