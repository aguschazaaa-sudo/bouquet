## ADDED Requirements

### Requirement: El carrito vive en localStorage y no guarda precios
El carrito MUST guardarse en `localStorage` con la forma
`{ version: 1, idCompra, lineas: [{ productoId, cantidad }] }`, validada con
`parsearCarrito()`. MUST NOT guardar precios ni nombres. Si lo guardado no
valida, el carrito MUST arrancar vacío con un `idCompra` nuevo, sin romper la
página.

#### Scenario: Carrito corrupto
- **WHEN** `localStorage` tiene un carrito con una cantidad negativa
- **THEN** la página carga con el carrito vacío y no tira error

#### Scenario: Sin localStorage
- **WHEN** el navegador bloquea `localStorage`
- **THEN** el carrito funciona en memoria durante la visita

### Requirement: El idCompra se genera en el navegador y persiste
Un carrito nuevo MUST generar un `idCompra` aleatorio y conservarlo mientras el
carrito exista.

#### Scenario: Recargar la página
- **WHEN** el comprador agrega un vino y recarga
- **THEN** el `idCompra` es el mismo que antes de recargar

### Requirement: Agregar respeta el tope
Agregar un vino MUST dejar la cantidad de esa línea en como máximo su `tope`.
Si el pedido lo supera, la cantidad MUST quedar en el tope y la pantalla MUST
decirlo en una línea, sin afirmar cuántas unidades quedan.

#### Scenario: Agregar por encima del tope
- **WHEN** una línea tiene 4 unidades de un vino con tope 5 y el comprador agrega 3
- **THEN** la línea queda en 5 y aparece un aviso de que llegó al máximo

### Requirement: `/carrito` se une con la proyección actual
`/carrito` MUST mostrar cada línea con el precio y el balde de la proyección
actual. Si una cantidad supera el tope, MUST ajustarse **y guardarse** antes de
calcular el total. Una línea agotada o de un producto que ya no está publicado
MUST quedar marcada, MUST NOT sumar al total y MUST poder quitarse.

#### Scenario: El tope bajó desde que se agregó
- **WHEN** una línea tiene 8 unidades y el tope actual es 5
- **THEN** la línea muestra 5, `localStorage` guarda 5 y el total usa 5

#### Scenario: Una línea agotada
- **WHEN** una línea es de un vino que se agotó
- **THEN** aparece marcada "Se agotó", no suma al total y se puede quitar

### Requirement: El total usa la plata de contratos
El total MUST calcularse como la suma de `precio × cantidad` de las líneas
vigentes, con `porCantidad` y `sumar` de `packages/contratos`, y MUST
mostrarse en cifras tabulares.

#### Scenario: Dos líneas
- **WHEN** el carrito tiene 2 × $ 19.900,00 y 1 × $ 76.000,00
- **THEN** el total es $ 115.800,00

### Requirement: El carrito vacío
Un carrito sin líneas vigentes MUST mostrar el texto de `voz.md §9.4`: "No hay
nada acá todavía." y el enlace "Ver los vinos" a `/vinos`.

#### Scenario: Carrito vacío
- **WHEN** se abre `/carrito` sin haber agregado nada
- **THEN** se ve ese texto y el enlace lleva a `/vinos`

### Requirement: Sin botón de terminar la compra
En este cambio, `/carrito` MUST NOT ofrecer ningún control para terminar la
compra: el checkout y `crearOrden` todavía no existen.

#### Scenario: Buscar el botón
- **WHEN** se inspecciona el HTML de `/carrito`
- **THEN** no hay ningún enlace ni botón hacia un checkout

### Requirement: El contador de la barra
La barra MUST mostrar la suma de las cantidades del carrito, leída de
`localStorage`, sin ninguna lectura de Firestore.

#### Scenario: Agregar desde la ficha
- **WHEN** el comprador agrega 2 unidades desde una ficha
- **THEN** el contador de la barra sube en 2 sin recargar la página

### Requirement: El carrito es papel
`/carrito` MUST renderizarse en modo papel (fondo claro, tokens del modo papel)
y MUST NOT usar el dorado como color de texto.

#### Scenario: Color de texto
- **WHEN** se grepea la hoja de estilo del carrito
- **THEN** el token del dorado no aparece en ninguna propiedad `color`
