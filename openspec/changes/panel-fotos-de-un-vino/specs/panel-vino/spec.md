## ADDED Requirements

### Requirement: La página del vino tiene una sección de fotos

La página de un vino MUST tener una sección de fotos con las que ya tiene y la
forma de sumar más, junto a las secciones que ya existen —el vino, la venta y
la tienda.

La sección MUST estar disponible **sólo sobre un vino ya guardado**: la ruta de
Storage y el `arrayUnion` necesitan el `productoId`, que es el slug, y un
borrador sin guardar todavía no lo tiene.

Un producto nace con `imagenes: []` (`documento_del_vino.dart:36`), así que la
sección arranca vacía en todo vino nuevo.

#### Scenario: Un vino guardado
- **WHEN** el operador abre un vino que existe
- **THEN** ve la sección de fotos con las que tiene y el botón de agregar

#### Scenario: Un alta sin guardar
- **WHEN** el operador está cargando un vino nuevo y todavía no lo guardó
- **THEN** la sección de fotos dice que primero hay que guardar el vino

#### Scenario: Un vino sin fotos
- **WHEN** el vino tiene `imagenes` vacío
- **THEN** la sección lo dice y ofrece agregar la primera

### Requirement: El aviso de "sin foto" que ya existe lleva a la solución

El aviso de "sin foto" que HU-03.7 ya muestra antes de publicar MUST llevar al
operador a la sección de fotos. Lo calcula `RevisionParaLaTienda` con
`sinFoto: producto.imagenes.isEmpty` (`en_la_tienda.dart:121`).

Hasta este change la alarma no tenía respuesta posible: el panel decía "este
vino no tiene foto" y no había ninguna forma de darle una.

#### Scenario: Publicar un vino sin foto
- **WHEN** el operador revisa un vino sin fotos para publicarlo
- **THEN** el aviso de "sin foto" lo deja ir a cargar una

#### Scenario: Después de cargar la foto
- **WHEN** el operador suma una foto y vuelve a la revisión
- **THEN** el aviso de "sin foto" ya no está
