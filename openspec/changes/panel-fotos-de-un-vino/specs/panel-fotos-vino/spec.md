## ADDED Requirements

### Requirement: El operador sube fotos de un vino

El panel MUST permitir elegir una o varias imágenes desde la compu o desde el
teléfono —galería o cámara— y sumarlas a un vino. Cada una se sube a Storage,
pasa por `procesarFoto` y su URL entra a `imagenes` con `arrayUnion`.

`arrayUnion` y **nunca** reescribir el array entero
([ARQUITECTURA §5.3](../../../../../ARQUITECTURA.md#53-escrituras-concurrentes-en-arrays)):
dos personas editando el mismo vino a la vez harían que la segunda en guardar
borre la foto de la primera.

#### Scenario: Una foto desde la compu
- **WHEN** el operador elige un archivo y confirma
- **THEN** la foto aparece en la sección de fotos del vino
- **AND** `imagenes` tiene una entrada más, agregada con `arrayUnion`

#### Scenario: Varias de una vez
- **WHEN** el operador elige tres archivos
- **THEN** las tres se procesan y cada una informa su resultado por separado

#### Scenario: Desde el teléfono
- **WHEN** el panel corre en Android y el operador saca una foto con la cámara
- **THEN** el flujo es el mismo que desde la compu

### Requirement: La extensión sale de los bytes del archivo, nunca del path

El panel MUST derivar la extensión del archivo crudo leyendo sus **primeros
bytes** contra una **lista cerrada** —`jpeg`, `png`, `webp`—, y MUST NOT
sacarla del path. El `contentType` que manda MUST ser el que corresponde a esos
bytes, no un `image/jpeg` fijo. La ruta MUST tener **un solo segmento** de
nombre de archivo.

**En web `XFile.path` no es una ruta, es un blob URL.** Sacar la extensión con
`path.split('.').last` devuelve `app/<uuid>` —con una barra adentro—, la barra
convierte el archivo en subcarpeta, `storage.rules` declara un solo segmento,
deja de matchear, cae en el deny-all y Storage devuelve `unauthorized`. Es el
bug que vivió desde el commit inicial en PadelPunilla
([ARQUITECTURA §5.4](../../../../../ARQUITECTURA.md#54-fotos-de-producto-la-regla-de-la-extensión)),
y **se ve como un problema de permisos siendo un problema de string**.

§5.4 regla 1 pide derivarla del `mimeType`. Acá se lee de los bytes, que es
**más estricto, no menos**: en Android el `mimeType` del selector puede venir
`null`, y en ese caso la tentación es caer al path — que es justo lo prohibido.
Cuando el `mimeType` viene, se usa como control cruzado.

#### Scenario: En web, con un blob URL
- **WHEN** el panel corre en web y el selector devuelve un `XFile` cuyo `path` es un blob URL
- **THEN** la ruta de subida tiene exactamente tres segmentos: `productos`, el id y un nombre de archivo
- **AND** la subida NO recibe `unauthorized`

#### Scenario: Un PNG
- **WHEN** el archivo empieza con la firma de PNG
- **THEN** sube con extensión `.png` y `contentType: image/png`

#### Scenario: En Android, sin mimeType
- **WHEN** el selector devuelve `mimeType` nulo
- **THEN** el formato igual se resuelve leyendo los bytes, sin mirar el path

#### Scenario: Un formato fuera de la lista
- **WHEN** los bytes no son `jpeg`, `png` ni `webp`
- **THEN** el panel lo rechaza antes de subir, y lo dice

#### Scenario: Un PDF renombrado
- **WHEN** el archivo se llama `foto.jpg` pero sus bytes son de un PDF
- **THEN** el panel lo rechaza antes de subir, sin gastar la subida ni la callable

### Requirement: La foto se previsualiza como la dibuja la vidriera

Antes y después de subir, el panel MUST mostrar la foto **con la misma
composición que usa la vidriera**: sobre el papel de la ventana, con
`mix-blend-mode: multiply` y a la altura proporcional real.

**El panel no adivina si la foto sirve: la muestra.** Se midió que ningún
umbral sobre el archivo separa un packshot de una foto de cámara —
`nieto-senetiner-bonarda.png`, packshot legítimo, puntúa peor que una botella
fotografiada sobre una mesa—. Un clasificador daría falsas alarmas sobre fotos
buenas que ya están en el catálogo. Lo que sí funciona es mirarla.

#### Scenario: Un packshot
- **WHEN** el operador elige un packshot sobre blanco
- **THEN** la previsualización lo muestra sobre el papel, con el blanco absorbido

#### Scenario: Una foto con fondo
- **WHEN** el operador elige una botella fotografiada sobre una mesa
- **THEN** la previsualización muestra el rectángulo oscuro que va a mostrar la tienda
- **AND** el operador puede subirla igual: la previsualización informa, no bloquea

### Requirement: El panel avisa cuando una foto no se recortó o quedó chica

El panel MUST avisar junto a la foto, con palabras que digan la consecuencia en
la tienda, cuando `procesarFoto` informa que recortó 0 % o que la altura final
quedó por debajo de los 1200.

MUST NOT impedir la subida ni la publicación. Es un aviso, y la decisión es del
operador que está mirando la previsualización.

El caso de la foto chica **ya existe en el catálogo real**: `portillo-malbec.png`
mide 173×438 y `withoutEnlargement` la deja en 436 de alto.

#### Scenario: No recortó nada
- **WHEN** la respuesta dice 0 % de recorte
- **THEN** el panel avisa que la foto tiene fondo y cómo se va a ver
- **AND** la foto queda subida

#### Scenario: Quedó por debajo del alto objetivo
- **WHEN** la altura final es menor a 1200
- **THEN** el panel avisa que se va a ver borrosa en la ficha

#### Scenario: Un packshot normal
- **WHEN** recortó 82,9 % y quedó en 1200 de alto
- **THEN** no hay ningún aviso

### Requirement: Una subida que falla se ve, y dice cuál falló

Toda subida MUST estar envuelta en `try`/`catch` —**nunca** un `try`/`finally`
sin `catch`— y todo fallo MUST llegar a la pantalla nombrando **qué foto**
falló y qué pasó. Con varias fotos a la vez, una que falla MUST NOT impedir que
las otras terminen.

En PadelPunilla la subida falló **meses sin un solo reporte**: la excepción se
perdía como error async no manejado, el spinner giraba y el botón volvía. *Un
fallo invisible no genera reportes, genera la sensación de que "no anda"*
([ARQUITECTURA §5.4](../../../../../ARQUITECTURA.md#54-fotos-de-producto-la-regla-de-la-extensión),
regla 4).

#### Scenario: Se corta la red a mitad de la subida
- **WHEN** la subida a Storage falla
- **THEN** la pantalla muestra el error con el nombre del archivo
- **AND** el botón vuelve a estar disponible para reintentar

#### Scenario: La callable rechaza el archivo
- **WHEN** `procesarFoto` responde `invalid-argument` porque no es una imagen
- **THEN** la pantalla dice el motivo, con el nombre del archivo

#### Scenario: Tres fotos, una falla
- **WHEN** de tres fotos la segunda falla
- **THEN** la primera y la tercera quedan subidas
- **AND** la pantalla nombra sólo la segunda como fallida

### Requirement: El operador quita una foto

El panel MUST permitir sacar una foto de un vino. La URL sale de `imagenes` con
`arrayRemove`.

El archivo **NO** se borra de Storage. Borrarlo daría 404 en las páginas ya
cacheadas en el borde hasta la próxima purga —y el tramo 4 de Cloudflare no
está construido—, mientras que dejarlo cuesta unos cientos de KB.

#### Scenario: Quitar una foto
- **WHEN** el operador saca una foto
- **THEN** desaparece de la sección y de `imagenes`
- **AND** el archivo sigue existiendo en Storage

#### Scenario: Quitar la única foto de un vino publicado
- **WHEN** el vino queda sin fotos
- **THEN** la operación se permite, y el panel avisa que la tienda va a dibujar la silueta
- **AND** el vino sigue publicado: la foto no es requisito para publicar

### Requirement: El panel mide el peso antes de subir

El panel MUST rechazar, **antes de empezar la subida**, todo archivo de 5 MB o
más, y decirlo con el peso del archivo y el tope.

`storage.rules` ya lo rechaza con `pesaMenosDe5MB()`, pero lo hace devolviendo
`unauthorized` — **que parece un problema de permisos y es un problema de
tamaño**, el mismo modo de falla contra el que avisa
[ARQUITECTURA §5.4](../../../../../ARQUITECTURA.md#54-fotos-de-producto-la-regla-de-la-extensión).
Y no es un caso raro: la cámara de un teléfono actual pasa los 5 MB sin
esfuerzo, así que es **el primer error que va a ver quien suba desde el
teléfono**.

#### Scenario: Una foto de 8 MB del teléfono
- **WHEN** el operador elige una foto de 8 MB
- **THEN** el panel lo dice antes de subir, con el peso y el tope
- **AND** NO aparece ningún mensaje de permisos

#### Scenario: Justo por debajo del tope
- **WHEN** la foto pesa 4,9 MB
- **THEN** la subida ocurre normalmente

### Requirement: Un vino no pasa de diez fotos

El panel MUST impedir sumar una foto a un vino que ya tiene diez, y decir por
qué. `imagenesValidas` de `firestore.rules` rechaza la lista de más de diez, así
que sin esta baranda el operador sube el archivo, paga el procesamiento y
recién ahí la escritura falla.

#### Scenario: La foto número once
- **WHEN** el vino tiene diez fotos y el operador elige una más
- **THEN** el panel lo dice **antes** de subir nada

#### Scenario: Diez son válidas
- **WHEN** el vino tiene nueve y el operador suma una
- **THEN** la subida ocurre normalmente
