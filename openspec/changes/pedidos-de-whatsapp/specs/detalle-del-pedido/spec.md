## ADDED Requirements

### Requirement: El detalle SHALL mostrar el pedido entero sin preguntarle nada a nadie

El panel MUST mostrar, de un pedido: número, qué lleva, quién lo recibe, a dónde va, el total de lista y en qué estado está, con lo necesario para prepararlo.

#### Scenario: Un pedido cargado
- **WHEN** el operador abre el pedido 7
- **THEN** ve su número, cada ítem con nombre, cantidad y precio de lista, el nombre y el teléfono, la dirección completa con localidad y provincia, el total de lista y el rótulo del estado

### Requirement: Los ítems SHALL mostrarse desde el snapshot, no desde el producto de hoy

Nombre y precio de cada ítem MUST salir de `items[]` de la Orden. NO MUST leerse el producto.

#### Scenario: El vino cambió de precio
- **WHEN** la Orden guardó 1.990.000 y el vino hoy cuesta 2.300.000
- **THEN** el detalle muestra 1.990.000

#### Scenario: Cero lecturas de productos
- **WHEN** se abre el detalle
- **THEN** no se lee ningún documento de `productos`

### Requirement: El detalle SHALL abrirse sin leer si viene de la bandeja, y con una lectura si viene por URL

Abrir un pedido desde la bandeja MUST usar la Orden ya cargada (cero lecturas); abrirlo por URL directa MUST leer ese documento (una lectura). Un pedido que no existe MUST decirlo, sin pantalla en blanco.

#### Scenario: Desde la bandeja
- **WHEN** el operador toca una fila
- **THEN** el detalle aparece sin una lectura nueva

#### Scenario: URL directa
- **WHEN** se abre `/pedidos/<id>` en frío
- **THEN** se lee un documento y se muestra

#### Scenario: Un id que no existe
- **WHEN** se abre `/pedidos/inventado`
- **THEN** el panel dice que no encontró ese pedido y ofrece volver a la bandeja

### Requirement: El estado SHALL salir de la proyección y no decir «cobrado»

El rótulo MUST salir de `proyectarEstadoPublico`, y el detalle MUST NOT decir «cobrado» ni «pagado»: dice «Total de lista» y, para un pedido `por_fuera`, «El cobro se gestiona por fuera».

#### Scenario: Pedido de WhatsApp
- **WHEN** el pago es `por_fuera`
- **THEN** el detalle dice que el cobro se gestiona por fuera y no muestra ningún estado de cobro

### Requirement: Un dato faltante SHALL decirse, no esconderse

Si la Orden no trae un campo esperado (`piso`, `referencia`, `email`), el detalle MUST omitir esa fila; si falta uno **obligatorio** (`items`, `numero`, `estadoEntrega`), MUST decir que el pedido está incompleto en vez de romper.

#### Scenario: Sin piso ni referencia
- **WHEN** `piso` y `referencia` son `null`
- **THEN** esas filas no aparecen

#### Scenario: Documento roto
- **WHEN** falta `items`
- **THEN** el detalle dice que ese pedido está incompleto y no lanza una excepción
