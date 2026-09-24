## ADDED Requirements

### Requirement: El operador SHALL poder cargar un pedido de WhatsApp desde el panel

El panel MUST ofrecer una pantalla para cargar un pedido: elegir vinos de la lista que ya está en memoria con su cantidad, escribir los datos de quien recibe y confirmar. Tiene que tardar menos que anotarlo en un papel: **una pantalla, sin pasos intermedios**.

#### Scenario: Cargar un pedido completo
- **WHEN** el operador elige un vino, pone cantidad 2, completa nombre, teléfono, calle, número, código postal, localidad y provincia, y confirma
- **THEN** el panel llama a `crearOrdenDelPanel` y muestra el número de la Orden creada

#### Scenario: Se llega desde la bandeja
- **WHEN** el operador está en la bandeja de pedidos
- **THEN** ve el acceso «Cargar un pedido» y lo abre con un toque

### Requirement: Los vinos SHALL elegirse de la lista en memoria, sin lecturas nuevas

El selector MUST usar el catálogo que el panel ya cargó (HU-03.1) y NO MUST leer Firestore al abrirse. Un vino de muestra o sin stock MUST mostrarse como no elegible con el motivo dicho.

#### Scenario: El selector no lee
- **WHEN** el operador abre la pantalla con el catálogo ya cargado
- **THEN** no se hace ninguna lectura de `productos`

#### Scenario: Un vino de muestra
- **WHEN** el vino tiene `muestra: true`
- **THEN** aparece deshabilitado con el motivo «de muestra: no existe»

#### Scenario: Un vino sin stock
- **WHEN** el vino tiene stock 0
- **THEN** aparece deshabilitado con el motivo «sin stock: cargalo primero en Stock»

### Requirement: La cantidad SHALL no poder pasar el stock que se ve

Cada línea MUST limitar su cantidad al stock que el panel tiene en pantalla, y MUST mostrar el total de lista de todo el pedido, dicho como total de lista y no como «cobrado».

#### Scenario: Pasarse
- **WHEN** el operador intenta poner 11 de un vino con stock 10
- **THEN** la cantidad no pasa de 10 y el panel lo dice

#### Scenario: El total no dice cobrado
- **WHEN** hay líneas cargadas
- **THEN** el total se rotula «Total de lista» y ningún texto de la pantalla dice «cobrado» ni «pagado»

### Requirement: El teléfono SHALL pegarse tal como vino del chat

El campo de teléfono MUST aceptar el número con espacios, guiones, el `15` o el `+54 9`, y MUST mostrar cómo quedó normalizado antes de confirmar. Un número que no se puede normalizar MUST marcarse en el campo.

#### Scenario: Con 15
- **WHEN** el operador pega `351 15 555 1234`
- **THEN** el panel muestra `+54 9 351 555 1234` y permite confirmar

#### Scenario: Incompleto
- **WHEN** el número tiene 8 dígitos
- **THEN** el campo se marca y el botón de confirmar queda deshabilitado

### Requirement: Un reintento SHALL NOT duplicar el pedido

El `idPedido` MUST generarse al abrir la pantalla y NO MUST regenerarse nunca, ni tras un error, ni al cambiar cantidades: un timeout con la transacción ya commiteada seguido de otro toque es el mismo pedido.

#### Scenario: Error ambiguo y reintento
- **WHEN** la llamada falla por timeout, el operador cambia una cantidad y confirma de nuevo
- **THEN** la segunda llamada usa el mismo `idPedido`

#### Scenario: Doble toque
- **WHEN** el operador toca «Confirmar» dos veces seguidas
- **THEN** sólo hay una llamada en curso y el segundo toque no hace nada

### Requirement: Cada rechazo del servidor SHALL decirse con qué hacer

El panel MUST traducir `sin-stock`, `cambio-el-precio`, `already-exists`, `permission-denied` y los errores de red a un texto con la acción a seguir, nombrando el vino cuando el código lo trae. Un texto de error MUST NOT ser el mensaje crudo del servidor.

#### Scenario: Se acabó el stock en el medio
- **WHEN** el servidor responde `sin-stock` para un vino con `actual: 3`
- **THEN** el panel dice qué vino y cuántas quedan, y deja corregir la cantidad sin perder lo demás

#### Scenario: Cambió el precio
- **WHEN** el servidor responde `cambio-el-precio`
- **THEN** el panel actualiza el precio de esa línea y pide confirmar de nuevo

### Requirement: Un pedido que ya existe SHALL mandar a abrirlo, no a cargar otro

Cuando el servidor responde `already-exists` con un `numero`, el panel MUST decir que ese pedido ya está cargado con ese número y ofrecer abrirlo, y NO MUST ofrecer cargar otro: otro sería un pedido duplicado.

#### Scenario: Reintento con algo cambiado
- **WHEN** el reintento vuelve con `already-exists` y `numero: 7`
- **THEN** el panel dice que el pedido 7 ya estaba cargado y ofrece abrirlo, sin dejar el botón de confirmar activo

### Requirement: El selector SHALL marcar los vinos que la tienda no muestra

Un vino elegible que no está publicado MUST mostrarse con la marca *«no está en la tienda»*: se puede vender igual, pero el operador tiene que saberlo.

#### Scenario: Un vino despublicado
- **WHEN** el vino tiene `publicado: false` y stock
- **THEN** aparece elegible con la marca, y elegirlo funciona

### Requirement: Una carga exitosa SHALL dejar el pedido a la vista

Al terminar, el panel MUST mostrar el número de la Orden y llevar a su detalle.

#### Scenario: Éxito
- **WHEN** la callable devuelve el `numero` 7
- **THEN** el panel lleva al detalle del pedido 7
