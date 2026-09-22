## ADDED Requirements

### Requirement: La callable aplica exactamente la tubería del seed

`procesarFoto` MUST transformar la imagen con **los mismos tres pasos y los
mismos parámetros** que `scripts/seed/seed.mjs`:

```
.trim({ threshold: 12 })
.resize({ height: 1200, withoutEnlargement: true })
.webp({ quality: 82 })
```

Los números MUST estar en un solo lugar del repo y ser leídos por los dos
consumidores, o una copia va a divergir de la otra sin que nadie lo note. La
foto que sale de la callable y la que sale del seed, sobre el mismo archivo de
entrada, MUST ser **byte a byte iguales**.

El motivo no es la prolijidad: la ventana de la vidriera depende del recorte.
`VentanaDeBotella.tsx` iguala la altura con el recorte al borde de la botella,
no con CSS, y `mix-blend-mode: multiply` supone el blanco del packshot.

#### Scenario: La misma foto por los dos caminos
- **WHEN** se procesa `alamos-malbec.jpg` con el seed y con la callable
- **THEN** los dos WebP tienen el mismo SHA-256

#### Scenario: Una foto más chica que el objetivo no se agranda
- **WHEN** entra `portillo-malbec.png`, de 173×438
- **THEN** la salida mide menos de 1200 de alto, porque `withoutEnlargement` lo impide
- **AND** la callable informa el alto real para que el panel pueda avisarlo

### Requirement: La callable sólo la puede llamar un admin

`procesarFoto` MUST rechazar con `permission-denied` toda invocación cuyo token
no traiga el claim `rol: admin`.

**Una callable es un endpoint HTTPS público.** Las reglas de Firestore y de
Storage no la protegen: corre con el Admin SDK y las saltea por diseño. Si no
chequea el claim, cualquiera con la URL escribe en el bucket del proyecto.

#### Scenario: Sin autenticar
- **WHEN** se invoca sin token
- **THEN** responde `unauthenticated` y no toca Storage

#### Scenario: Autenticado sin el claim
- **WHEN** se invoca con un usuario logueado pero sin `rol: admin`
- **THEN** responde `permission-denied` y no toca Storage

#### Scenario: Admin
- **WHEN** se invoca con un token que trae `rol: admin`
- **THEN** procesa la foto

### Requirement: La callable valida la ruta que le pasan

`procesarFoto` recibe la ruta del archivo crudo. MUST rechazar toda ruta que no
sea exactamente `productos/{productoId}/{archivo}` —**un solo segmento** de
nombre de archivo— con el `productoId` **igual al que vino en el argumento**.

Quien llama elige la ruta, así que sin esta validación un admin con un panel
con bugs —o una llamada a mano— puede hacer que la function lea y borre
cualquier objeto del bucket.

#### Scenario: Ruta de otro producto
- **WHEN** se invoca con `productoId: "malbec-a"` y la ruta `productos/malbec-b/x.jpg`
- **THEN** responde `invalid-argument` y no toca Storage

#### Scenario: Ruta con segmentos de más
- **WHEN** la ruta es `productos/malbec-a/2026/01/x.jpg`
- **THEN** responde `invalid-argument`

#### Scenario: Ruta fuera de productos
- **WHEN** la ruta es `otra-cosa/x.jpg`
- **THEN** responde `invalid-argument`

### Requirement: El nombre del archivo final sale del contenido

El archivo resultante MUST llamarse `productos/{productoId}/{hash}.webp`, donde
`hash` son los primeros 16 caracteres del SHA-256 **del WebP ya procesado** —
igual que el seed. El nombre original del archivo MUST NOT influir en la ruta
final.

Esto hace la operación **idempotente**: subir dos veces la misma foto produce
la misma URL, así que el `arrayUnion` del panel no duplica una entrada.

#### Scenario: La misma foto dos veces
- **WHEN** un operador sube el mismo archivo dos veces al mismo vino
- **THEN** las dos veces devuelve la misma URL
- **AND** `imagenes` queda con **una** entrada, porque `arrayUnion` no duplica

#### Scenario: Un nombre de archivo hostil
- **WHEN** el archivo crudo se llama `../../otra.jpg` o `foto con espacios.JPEG`
- **THEN** la ruta final igual es `productos/{productoId}/{hash}.webp`

### Requirement: La callable rechaza lo que no es una imagen que sirva

`procesarFoto` MUST rechazar, sin escribir nada, un archivo que no sea `jpeg`,
`png` o `webp` según lo que **lee del contenido** —nunca según la extensión ni
el `contentType` declarado—, y MUST rechazar uno que pese 5 MB o más, el mismo
tope que `storage.rules`.

#### Scenario: Un PDF con nombre de foto
- **WHEN** entra un PDF llamado `foto.jpg`
- **THEN** responde `invalid-argument` con el motivo, y no escribe el WebP

#### Scenario: Un formato que la vidriera no sabe servir
- **WHEN** entra un HEIC o un TIFF
- **THEN** responde `invalid-argument` nombrando el formato que encontró

#### Scenario: Más grande que el tope
- **WHEN** el archivo crudo pesa 5 MB o más
- **THEN** responde `invalid-argument`

### Requirement: La callable informa cuánto recortó

La respuesta MUST incluir el porcentaje de área que sacó `trim()`, y el ancho y
el alto finales.

**No es un veredicto, es un dato.** Se midió que ningún umbral separa un
packshot de una foto de cámara: los 19 packshots del seed recortan entre 15,1 %
y 83,3 %, una botella sobre una mesa recorta 0,0 %, y
`nieto-senetiner-bonarda.png` —packshot legítimo de bodega— también recorta
poco. El número va a la pantalla para acompañar lo que el operador ve, no para
decidir por él.

#### Scenario: Un packshot con margen
- **WHEN** entra `alamos-malbec.jpg`
- **THEN** la respuesta dice que recortó ~82,9 %

#### Scenario: Una foto sin borde uniforme
- **WHEN** entra una foto de una botella sobre una mesa
- **THEN** la respuesta dice que recortó 0,0 %
- **AND** la foto **igual se procesa y se sube**: el dato no bloquea

### Requirement: El archivo crudo no sobrevive a una subida exitosa

Después de escribir el WebP, `procesarFoto` MUST borrar el archivo crudo que
recibió. Si la transformación falla, el crudo MUST quedar donde está y la
respuesta MUST decir qué pasó.

Un crudo que queda es basura de unos MB que nadie referencia —`imagenes[]`
nunca recibió su URL—, y borrarlo tras un fallo perdería el único archivo que
el operador subió.

#### Scenario: Subida exitosa
- **WHEN** la callable termina bien
- **THEN** en `productos/{productoId}/` queda el `.webp` y no queda el crudo

#### Scenario: La transformación falla
- **WHEN** `sharp` no puede leer el archivo
- **THEN** el crudo sigue en Storage
- **AND** la respuesta nombra el motivo
