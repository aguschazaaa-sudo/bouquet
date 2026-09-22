## Why

El panel carga vinos que **no pueden tener foto**. `imagenes` se escribe una
sola vez en la vida de un producto, vacía, y nada la vuelve a tocar:

```
$ grep -rn "imagenes" apps/admin/lib --include=*.dart
data/documento_del_vino.dart:36:    'imagenes': <String>[],
domain/escrituras_del_vino.dart:10:/// ⚠️ No lleva `publicado`, `stock`, `tipo` ni `imagenes`, a proposito.
...el resto son LECTURAS
```

Y el panel **ya se lo dice al dueño**: `en_la_tienda.dart:121` calcula
`sinFoto: producto.imagenes.isEmpty` y HU-03.7 lo muestra antes de publicar.
**La alarma está construida desde el 2026-09-22 y no hay forma de apagarla.**

El hito 1 no es *"que el dueño cargue sus vinos"*, es *"que cargue su catálogo
real"*. Un catálogo donde cada botella es la silueta gris de
`VentanaDeBotella.tsx:45` no es el catálogo real: es el seed sin las fotos del
seed.

Historias: **HU-04.1 · HU-04.3 · HU-04.4** de
[EP-04](../../../docs/vault/features/panel/EP-04-fotos.md). HU-04.2 queda
afuera, con disparador — ver abajo.

## Lo que encontró esta sesión, y ningún documento del proyecto tenía

El overview marcaba en rojo *"falta una pieza: hay que decidir dónde se procesa
la foto"*, y daba por hecho que el problema era el formato. **El formato es la
mitad fácil.**

**La ventana de la vidriera no es un hueco para una imagen: es un recorte con
tres supuestos.** `VentanaDeBotella.tsx:11-14` lo dice — *"La altura la iguala
el recorte que hizo el seed al borde de la botella, no el CSS: `object-fit` no
sabe dónde está la botella dentro del cuadro"* — y `catalogo.css:583` agrega
`mix-blend-mode: multiply`, que existe para que el blanco del packshot se
absorba en el papel.

Una foto sacada con el teléfono no cumple ninguno de los tres:

| Pieza | Packshot | Foto sobre una mesa |
|---|---|---|
| `trim({threshold: 12})` | recorta el blanco; la botella queda al borde | **no hay borde uniforme: no recorta nada.** Vuelve el defecto que `seed.mjs:51` documenta — *"sin recortar el fondo una botella ocupa el 81 % del alto y otra el 100 %"* |
| `mix-blend-mode: multiply` | el blanco (1,0) no altera el papel | la madera (≈0,3) × papel = **un rectángulo oscuro pegado sobre la ventana** |

### El clasificador quedó REFUTADO por medición, y por eso no se construye

La salida obvia era detectar el packshot y avisar. Se midió, con control
positivo (los 19 packshots del seed) y negativo (la misma botella compuesta
sobre un fondo de madera):

| | recorta | borde |
|---|---:|---:|
| 19 packshots reales | 15,1 % – 83,3 % | 116,7 – 244,0 |
| Botella sobre una mesa | **0,0 %** | 144,8 |
| Packshot recortado al ras | **0,0 %** | 141,4 |

`trim()` separa el control negativo sintético. **Pero
`nieto-senetiner-bonarda.png` —un packshot legítimo, PNG transparente de la
bodega, 1205×4016 recortado al ras— puntúa PEOR que el control negativo en los
dos indicadores.** Un umbral acá no protege de fotos malas: da falsas alarmas
sobre fotos buenas que ya están en el catálogo.

**Ningún umbral sobre el archivo distingue un packshot de una foto de cámara.**
Así que el panel no adivina: **dibuja la foto como la va a dibujar la
vidriera** —sobre el papel, con `multiply`, a la altura real— y el operador
mira. Cero dependencias, cero falsos positivos, y es el principio que este
repo ya tiene escrito: lo visual se juzga mirándolo.

## What Changes

- **`procesarFoto`, la primera Cloud Function del proyecto (HU-04.1).** El
  panel sube el archivo crudo a Storage y llama a la callable; la callable
  aplica **la tubería del seed, sin reescribirla** —`trim({threshold: 12})` →
  `resize({height: 1200, withoutEnlargement: true})` → `webp({quality: 82})`—,
  sube `productos/{productoId}/{hash}.webp`, borra el crudo y devuelve la URL
  con cuánto recortó y las dimensiones finales.
- **Es una callable y NO un trigger `onObjectFinalized`, y el motivo es
  HU-04.4.** Una callable es sincrónica: el error vuelve a la pantalla con el
  nombre de la foto que falló. Un trigger dejaría al operador mirando un
  spinner que vuelve al botón — **el bug exacto de PadelPunilla que HU-04.4
  existe para no repetir** (ARQUITECTURA §5.4, regla 4).
- **El panel gana la sección de fotos en la página del vino**, con la
  previsualización sobre el papel y la advertencia cuando la foto no se recortó.
  La advertencia **no bloquea**: informa.
- **Quitar una foto (HU-04.3)** con `arrayRemove`.
- **Las cuatro reglas de ARQUITECTURA §5.4 aplican a la subida del crudo**: la
  extensión sale del `mimeType` y **nunca** del path —en web `XFile.path` es un
  blob URL con una barra adentro—, un solo segmento de nombre de archivo, el
  `contentType` real, y `try/catch`.

### Las dos decisiones de alcance que este change toma

**1. HU-04.2 (reordenar) NO entra, con disparador: el primer vino con dos
fotos.** Es la historia que choca con
[ARQUITECTURA §5.3](../../../ARQUITECTURA.md#53-escrituras-concurrentes-en-arrays),
que prohíbe reescribir el array entero — y reordenar **es** reescribirlo.
Resolverlo cuesta una transacción que relee y compara contra lo que el operador
vio. Pero **el seed tiene exactamente una foto por producto** y elegir la
principal entre una sola es una pantalla que no decide nada. Cuando entre, el
patrón ya existe en el proyecto y tiene nombre: el mismo `precioUnitarioVisto`
de `crearOrden` y de HU-05.2.

**2. HU-04.3 saca la foto de `imagenes[]` pero NO borra el archivo de
Storage.** EP-04 lo dejaba abierto. Se cierra así porque las dos mitades no
pesan lo mismo: borrar el archivo da **404 en las páginas ya cacheadas en el
borde** hasta la próxima purga —y el tramo 4 de Cloudflare no está construido—,
mientras que dejarlo cuesta unos cientos de KB de Storage. Queda anotado con su
disparador: si los huérfanos alguna vez pesan, un script los limpia.

### Lo que este cambio NO hace

- **No toca `firestore.rules`.** Medido: `imagenes` ya está en el `hasAll` y en
  el `hasOnly` de `productoValido`, y `imagenesValidas` acepta hasta 10 entradas
  `https://` —el endurecimiento lo hizo `panel-publicar-un-vino`—. **Al revés
  de EP-02 y EP-03, esta épica no lleva deploy de reglas.** El orden de deploy
  es **functions → panel**.
- **No toca `storage.rules`.** `productos/{productoId}/{archivo}` con
  `esAdmin() && esImagen() && pesaMenosDe5MB()` ya cubre la subida del crudo.
- **No toca la vidriera.** Consume `imagenes[0]` y no se entera de dónde salió.
- **No quita las fotos de muestra.** Los 20 productos de producción tienen
  `muestra: true`; sus fotos las puso el seed y siguen donde están.
- **No agrega recorte de fondo.** Para la foto de cámara ocasional, este change
  la muestra como se va a ver y deja decidir. Quitar el fondo es un modelo
  ONNX de decenas de MB en el arranque en frío de la function: tiene disparador
  propio, y es que la previsualización resulte insuficiente **mirándola**.

## Presupuesto de lecturas

Campo obligatorio (`CLAUDE.md`). Cuota: **50.000 lecturas/día**.

| Qué | Lecturas | Por qué |
|---|---:|---|
| Subir una foto | **0** | El panel sube a Storage y llama a la callable. La callable **no lee Firestore**: recibe el `productoId` y devuelve una URL |
| Agregar la URL a `imagenes[]` | **0** | `arrayUnion` es ciego: no lee el documento |
| Quitar una foto | **0** | `arrayRemove`, ídem |
| Ver la previsualización | **0** | Sale del archivo que el operador acaba de elegir, en memoria |
| Ver qué vinos no tienen foto | **0** | `en_la_tienda.dart:121` ya lo calcula sobre el catálogo en memoria (HU-03.1) |

**EP-04 no agrega una sola lectura de Firestore.** Cargar las 200 fotos del
MVP cuesta 200 escrituras, una vez.

**Lo que sí agrega es costo de Cloud Functions**, que no se mide en la cuota de
Firestore: ~200 invocaciones para el catálogo entero y unas pocas por semana
después. Muy por debajo de los 2.000.000 de invocaciones sin cargo del plan.

## Capabilities

### New Capabilities

- `panel-fotos-vino`: subir fotos de un vino desde la compu o el teléfono,
  quitarlas, ver cada una como la va a dibujar la vidriera, y ver el error con
  el nombre de la foto cuando una subida falla (HU-04.1, HU-04.3, HU-04.4).
- `procesar-foto`: la callable del servidor que recorta al borde, redimensiona
  y codifica a WebP con **los mismos parámetros que el seed**, y devuelve la
  URL final junto con cuánto recortó.

### Modified Capabilities

- `panel-vino`: la página del vino gana la sección de fotos. La define
  `panel-cargar-un-vino`, **todavía sin archivar**, así que no existe en
  `openspec/specs/` y el delta va como `ADDED`.

## Impact

- **`functions/`: deja de ser un andamio.** `index.ts` exporta hoy `export {}`
  y ningún deploy de functions ocurrió nunca. Suma la dependencia `sharp`
  (misma versión que el seed: **0.35.4 / libvips 8.18.6**) y los primeros tests
  de `functions/test/`.
  ⚠️ **`sharp` trae binarios por plataforma.** Acá se instala `win32-x64`; la
  function necesita `linux-x64`. Lo resuelve el `npm ci` de Cloud Build, que
  corre en Linux — **se verifica en el deploy, no se supone**.
- **Una API de Google Cloud que hay que habilitar: `cloudfunctions`.** Medido
  el 2026-09-22: `functions:list` devuelve **403 `SERVICE_DISABLED`**.
  `eventarc` **no** hace falta, porque es callable y no trigger. El proyecto ya
  está en Blaze —`firebaseapphosting`, `run`, `cloudbuild`, `artifactregistry`
  y `secretmanager` están habilitadas—, así que **no hay cambio de plan**.
- **`apps/admin`:** dos dependencias nuevas —`firebase_storage` y el selector
  de archivos, que es de donde sale la trampa del blob URL de §5.4—, la feature
  `fotos/` con sus capas, y la sección nueva en la página del vino.
- **`packages/contratos`:** sin cambios. Las fotos no tienen máquina de estados.
- **Deploy: functions → panel.** Sin reglas, sin tienda.
- **Workflow A.** No toca cobros, stock ni precios: `revisor-pagos` no es
  obligatorio.
- **La decisión va a ADR 015**, con la medición del clasificador refutado
  adentro: es el tipo de resultado negativo que se vuelve a proponer si no
  queda escrito por qué no.
