## ADDED Requirements

### Requirement: Las puertas desde Catálogo
Catálogo MUST ofrecer cargar un vino nuevo, y cada renglón de la lista MUST
abrir la corrección de ese vino. El alta y la corrección MUST tener su propia
URL (`/catalogo/nuevo` y `/catalogo/vinos/<id>`), y una URL con un id que
no existe MUST decirlo en vez de mostrar un formulario vacío.

#### Scenario: Cargar desde Catálogo
- **WHEN** el operador toca "Cargar un vino" en Catálogo
- **THEN** se abre el formulario vacío en `/catalogo/nuevo`

#### Scenario: Corregir desde el renglón
- **WHEN** el operador toca el renglón de un vino
- **THEN** se abre el formulario con los datos de ese vino en `/catalogo/vinos/<id>`

#### Scenario: Un id que no existe
- **WHEN** se abre `/catalogo/vinos/un-id-inventado`
- **THEN** el panel dice que ese vino no existe y ofrece volver a Catálogo

#### Scenario: Entrar por la URL sin sesión
- **WHEN** alguien sin sesión abre `/catalogo/nuevo`
- **THEN** va a la pantalla de entrada, y después de entrar vuelve a esa URL

### Requirement: Un vino nace con una forma fija (HU-03.2)
El alta MUST escribir el producto por **una única factory** que fija
`tipo: 'simple'`, `publicado: false`, `stock: 0` e `imagenes: []`. Ningún
campo de esos SHALL depender de lo que se haya tocado en el formulario.

#### Scenario: Un alta cualquiera
- **WHEN** el operador guarda un vino nuevo
- **THEN** el documento tiene `publicado: false`, `stock: 0`, `tipo: 'simple'` e `imagenes: []`

#### Scenario: El vino nuevo aparece en Catálogo
- **WHEN** el alta termina bien
- **THEN** el vino aparece en Catálogo marcado como que no está en la tienda, sin recargar la página

### Requirement: Lo obligatorio se pide antes de guardar (HU-03.2)
El formulario MUST exigir nombre, bodega, al menos un varietal, color, región,
volumen mayor que cero y precio mayor que cero. La añada y la graduación MUST
poder quedar vacías. Mientras falte algo, guardar MUST NOT estar disponible, y
el formulario MUST decir qué falta: **al lado del campo** en cuanto ese campo
se tocó, y en una línea junto al botón para los que todavía no se tocaron. Un
alta vacía MUST NOT arrancar con todos los campos en rojo.

#### Scenario: Falta el precio
- **WHEN** el operador completa todo menos el precio
- **THEN** no puede guardar, y junto al botón dice que falta el precio

#### Scenario: Un precio mal escrito
- **WHEN** el operador escribe "doce" en el precio
- **THEN** el campo del precio dice que no parece un precio

#### Scenario: Un vino guardado roto
- **WHEN** se abre para corregir un vino al que le falta la región
- **THEN** el campo de la región lo dice desde el principio, sin tocarlo

#### Scenario: Sin añada
- **WHEN** el operador deja la añada vacía
- **THEN** el vino se guarda sin añada

#### Scenario: Un nombre sin letras ni números
- **WHEN** el nombre es "---"
- **THEN** no se puede guardar, porque no tiene una dirección posible en la tienda

### Requirement: La bodega se elige de la lista
La bodega MUST elegirse entre las que existen en `bodegas`, y MUST NOT
escribirse como texto libre. Si la bodega no está, el formulario MUST ofrecer
cargarla sin salir del alta, y la bodega recién cargada MUST quedar elegida.

#### Scenario: La bodega no está
- **WHEN** el operador carga una bodega nueva desde el formulario del vino
- **THEN** vuelve al formulario con esa bodega ya elegida y sin perder lo que había escrito

### Requirement: Los varietales salen de la lista cerrada
El formulario MUST ofrecer sólo los varietales de `VARIETALES`, en el mismo
orden, y MUST permitir elegir más de uno. La lista del panel MUST ser la misma
que la de `contratos`, y un chequeo de CI MUST fallar si difieren.

#### Scenario: Un corte
- **WHEN** el operador elige Malbec y Cabernet Franc
- **THEN** el vino se guarda con los dos varietales

#### Scenario: La lista del panel se desincroniza
- **WHEN** se agrega un varietal a `contratos` y no al panel
- **THEN** `auditar_varietales.mjs` sale con código distinto de 0

### Requirement: El precio se escribe en pesos y se guarda exacto
El precio MUST escribirse en pesos con el formato argentino —punto de miles,
coma decimal— y MUST guardarse como **entero en centavos** sin pasar por un
número con coma flotante. Más de dos decimales MUST rechazarse. Un texto que
se puede leer de dos formas (`12.50`) MUST rechazarse con una explicación, no
interpretarse. El formulario MUST mostrar cómo se va a ver el precio en la
tienda, con el mismo formato que la vidriera.

#### Scenario: Con separador de miles
- **WHEN** el operador escribe "12.500"
- **THEN** se guarda `precio: 1250000`

#### Scenario: Con centavos
- **WHEN** el operador escribe "12.500,50"
- **THEN** se guarda `precio: 1250050`

#### Scenario: Ambiguo
- **WHEN** el operador escribe "12.50"
- **THEN** el campo pregunta si quiso decir 12,50 o 12.500 —un cero que se perdió—, y no se puede guardar

#### Scenario: La vista previa
- **WHEN** el operador escribe "12500"
- **THEN** el formulario muestra "$ 12.500,00", con el espacio duro que usa la vidriera

### Requirement: La graduación se escribe en grados y se guarda en décimas
La graduación MUST escribirse en grados, con coma o punto decimal y a lo sumo
un decimal, y MUST guardarse como entero en décimas. MUST rechazarse fuera de
[5; 25] grados. Vacía MUST NOT escribirse.

#### Scenario: Con decimal
- **WHEN** el operador escribe "13,5"
- **THEN** se guarda `fichaVino.graduacion: 135`

#### Scenario: Se confundió de unidad
- **WHEN** el operador escribe "135"
- **THEN** el campo lo rechaza por fuera de rango

#### Scenario: Dos decimales
- **WHEN** el operador escribe "13,55"
- **THEN** el campo lo rechaza: la etiqueta de un vino declara a lo sumo un decimal

### Requirement: La dirección del vino se deriva del nombre y no se repite
La dirección —el slug— MUST derivarse del nombre con `aSlug` y MUST verse
mientras se escribe. Si ya la tiene otro vino que **no** es de muestra, guardar
MUST NOT estar disponible y el formulario MUST decir cuál. Si la tiene un vino
de muestra, el formulario MUST avisarlo y MUST dejar guardar. Si otra persona
la toma entre que se abrió el formulario y se guardó, el alta MUST fallar con
un mensaje y MUST NOT sobrescribir nada.

#### Scenario: Otro vino ya tiene esa dirección
- **WHEN** el operador escribe el nombre de un vino real que ya existe
- **THEN** el formulario dice cuál es y no deja guardar

#### Scenario: Un vino de muestra tiene esa dirección
- **WHEN** el nombre coincide con el de un vino de muestra
- **THEN** el formulario avisa que choca con uno de muestra y deja guardar

#### Scenario: Dos personas cargan el mismo vino a la vez
- **WHEN** la segunda guarda después de que la primera ya guardó
- **THEN** la segunda ve que ya existe, y el documento de la primera queda intacto

### Requirement: Las botellas por unidad se eligen una vez (HU-03.3)
Las botellas por unidad de venta MUST elegirse al crear, con 1 por defecto. La
pantalla MUST decir **antes de guardar** que no se pueden cambiar después.
Cuando son más de una, MUST explicar que el stock se va a contar en cajas y que
la caja viaja sola, y MUST pedir confirmación antes de guardar.

#### Scenario: Una botella suelta
- **WHEN** el operador guarda un vino con 1 botella por unidad
- **THEN** se guarda sin pedir confirmación, con `presentacion.botellas: 1`

#### Scenario: Una caja de 3
- **WHEN** el operador guarda un producto con 3 botellas por unidad
- **THEN** el panel pide confirmar que es una caja de 3 que no se va a poder cambiar, y guarda sólo si confirma

#### Scenario: No confirma
- **WHEN** el operador cancela la confirmación
- **THEN** no se guarda nada y el formulario sigue como estaba

### Requirement: Corregir un vino (HU-03.4)
La corrección MUST abrir el mismo formulario con los datos del vino. El tipo,
las botellas por unidad y la dirección MUST verse fijos, con el motivo. La
escritura MUST mandar **sólo los campos que cambiaron**, y si no cambió nada,
guardar MUST NOT estar disponible.

#### Scenario: Corregir la región
- **WHEN** el operador cambia sólo la región y guarda
- **THEN** el `update` lleva sólo `fichaVino.region`

#### Scenario: Cambiar el nombre no mueve la dirección
- **WHEN** el operador corrige el nombre de un vino
- **THEN** la dirección sigue siendo la misma

#### Scenario: Nada cambió
- **WHEN** el operador abre un vino y no toca nada
- **THEN** el botón de guardar está apagado

### Requirement: Los varietales se corrigen sin reescribir la lista
Corregir los varietales MUST hacerse con `arrayUnion` para los agregados y
`arrayRemove` para los quitados, en ese orden y en una sola escritura atómica.
MUST NOT reescribirse la lista entera (ARQUITECTURA §5.3).

#### Scenario: Dos personas corrigen varietales distintos
- **WHEN** una agrega Merlot y otra, a la vez, quita Syrah del mismo vino
- **THEN** el vino queda con Merlot y sin Syrah

#### Scenario: Cambiar el único varietal
- **WHEN** el operador reemplaza Malbec por Syrah
- **THEN** la escritura se acepta y el vino queda con Syrah

### Requirement: El precio se corrige sólo fuera de la tienda
En la corrección, el precio MUST poder cambiarse mientras el vino tiene
`publicado: false`. Con `publicado: true` MUST verse fijo, diciendo que el
precio de un vino que está en la tienda todavía no se cambia desde acá.

#### Scenario: Un vino sin publicar
- **WHEN** el operador corrige el precio de un vino que no está en la tienda
- **THEN** se guarda el precio nuevo

#### Scenario: Un vino en la tienda
- **WHEN** el operador abre un vino publicado
- **THEN** el precio se ve y no se puede editar

### Requirement: Un fallo al guardar se ve
Si una escritura falla, el formulario MUST decir por qué en términos del
operador —sin permiso, sin conexión, ya existe—, MUST conservar lo escrito y
MUST volver a dejar guardar. MUST NOT quedar un botón girando ni volver al
estado inicial en silencio.

#### Scenario: Las reglas rechazan
- **WHEN** la escritura vuelve con `permission-denied`
- **THEN** el formulario lo dice, y todo lo escrito sigue ahí

### Requirement: Abrir el formulario no lee Firestore
Abrir el formulario MUST costar **cero** lecturas: las bodegas, las regiones
sugeridas, las direcciones ocupadas y el vino a corregir MUST salir del
catálogo que ya está en memoria.

#### Scenario: Abrir un vino para corregirlo
- **WHEN** el operador abre la corrección de un vino desde Catálogo
- **THEN** el formulario se llena sin una lectura nueva de Firestore

#### Scenario: Sugerir la región
- **WHEN** el operador empieza a escribir "Mendo"
- **THEN** el formulario sugiere las regiones que ya usan otros vinos que contienen ese texto
