# ADR 015 — Las fotos del panel

- **Fecha:** 2026-09-22
- **Estado:** aceptada y **aplicada en el código**. **Functions desplegada y
  `ACTIVE` en producción** (verificado con la API cruda de Cloud Functions,
  cuarto intento); **panel sin desplegar** todavía: ver *Lo que falta*
- **Decide:** que una foto subida desde el panel se procese con **la misma
  tubería que el seed** (`trim(12)` → `resize(1200)` → `webp(82)`), en una
  Cloud Function **callable** y no en un trigger de Storage; y que el panel
  **no intente detectar** si una foto es un packshot de bodega o una foto de
  cámara — ese detector se midió y se refutó
- **Historias:** HU-04.1 · HU-04.3 · HU-04.4 ([EP-04](../../features/panel/EP-04-fotos.md)).
  HU-04.2 queda afuera, con disparador — ver *Lo que NO se construyó*
- **Toca:** [ADR 008](008-catalogo-stock-y-carrito.md) (la vidriera sirve WebP
  sin `next/image`, lo que fija la forma que esta tubería tiene que producir)
- **Hace cumplir:** `functions/test/foto/` (17 tests: `tuberia.test.ts`,
  `validar.test.ts`, `ruta.test.ts`), `packages/contratos/src/foto.ts` como
  única fuente de los tres números, y ARQUITECTURA §5.4 (la regla de la
  extensión) del lado de Dart
- **Planificación:** `openspec/changes/panel-fotos-de-un-vino/`

## Contexto

El panel escribe `imagenes: []` una vez, en el alta, y nada la vuelve a tocar
([ADR 013](013-cargar-un-vino.md)). El hito 1 no es *"que el dueño cargue sus
vinos"*, es *"que cargue su catálogo real"* — y un catálogo donde cada botella
es la silueta gris de `VentanaDeBotella.tsx:45` no es el catálogo real, es el
seed sin las fotos del seed.

El overview del panel marcaba en rojo *"falta una pieza: hay que decidir dónde
se procesa la foto"* y daba por hecho que el problema era el formato. **No lo
es.** La ventana de la vidriera no es un hueco para una imagen: es un recorte
con tres supuestos. `VentanaDeBotella.tsx:11-14` iguala la altura con el
recorte al borde que hizo el seed, no con `object-fit` — *"`object-fit` no
sabe dónde está la botella dentro del cuadro"* —, y `catalogo.css:583` usa
`mix-blend-mode: multiply`, que supone que el fondo es blanco (el del
packshot). Una foto sacada con el teléfono sobre una mesa no cumple ninguno de
los dos supuestos.

## Decisión

### 1. `procesarFoto`: una callable que aplica la tubería del seed, sin reescribirla

El panel sube el crudo a Storage y llama a `procesarFoto(productoId, ruta)`.
La callable baja el archivo, aplica **exactamente** los tres pasos que
`scripts/seed/seed.mjs` ya aplicaba con `sharp` — `trim({ threshold: 12 })` →
`resize({ height: 1200, withoutEnlargement: true })` → `webp({ quality: 82 })`
—, sube `productos/{productoId}/{sha256(webp).slice(0,16)}.webp`, borra el
crudo y devuelve la URL junto con cuánto recortó y las dimensiones finales.

**Los tres números viven una sola vez, en `packages/contratos/src/foto.ts`
(`TUBERIA_DE_FOTO`), pero el código que los usa está duplicado a propósito**:
`contratos` no puede depender de `sharp` — su cero-dependencias es una
decisión del proyecto en una máquina de 7,9 GB —, así que lo compartido son
los números, no la función. Lo que impide que las dos copias diverjan no es la
disciplina: es `functions/test/foto/tuberia.test.ts`, que procesa
`alamos-malbec.jpg` por el seed (como subproceso real, no reimplementando su
lógica) y por `tuberia.ts`, y exige el **mismo SHA-256**. Con control
negativo: cambiarle un número a la tubería pone el test en rojo — verificado
mutando `alto` antes de escribir esta decisión.

**Alternativa descartada:** un paquete `packages/fotos` con `sharp` adentro.
Más limpio en el papel, pero agrega un workspace y un `node_modules` nativo
para compartir tres líneas.

### 2. El clasificador de packshot, REFUTADO POR MEDICIÓN — el hallazgo central de este change

La salida obvia era: detectar si la foto subida es un packshot de bodega o una
foto de cámara, y avisar en el segundo caso. Se midió `trim()` (cuánto
recorta) y la luminosidad de borde sobre los **19 packshots reales** del seed,
contra un **control negativo sintético** (la misma botella compuesta sobre un
fondo de madera):

| | recorta | luminosidad de borde |
|---|---:|---:|
| 19 packshots reales | 15,1 % – 83,3 % | 116,7 – 244,0 |
| Botella sobre una mesa (control negativo) | **0,0 %** | 144,8 |
| `nieto-senetiner-bonarda.png` (packshot legítimo, PNG transparente, recortado al ras) | **0,0 %** | **141,4** |

`trim()` sí separa el control negativo sintético del grueso de los packshots
reales. **Pero `nieto-senetiner-bonarda.png` — un packshot legítimo, ya
publicado en el catálogo — recorta 0,0 % (está recortado al ras desde el
origen) y puntúa PEOR que el control negativo en luminosidad de borde.**
Ningún umbral sobre `trim()` ni sobre el borde separa "packshot" de "foto de
cámara" sin, en el mismo movimiento, marcar como sospechosa una foto que ya
está en producción y es correcta.

**Conclusión: no se construye el detector.** El panel no adivina — dibuja la
foto **exactamente como la va a dibujar la vidriera**: sobre el papel
(`Tokens.papelVentana`, la misma fórmula que `--papel-ventana` de
`tokens.css:48`, verificada fórmula contra fórmula, no asumida), con
`colorBlendMode: BlendMode.multiply`, a la altura real. El operador mira y
decide. Cero dependencias nuevas, cero falsos positivos sobre el catálogo que
ya existe, y es el principio que este repo ya tiene escrito: **lo visual se
juzga mirándolo**.

Un resultado negativo sin el "por qué no" escrito se vuelve a proponer — por
eso este ADR existe con los números adentro, no sólo con la conclusión.

### 3. Es una callable, y NO un trigger `onObjectFinalized`

Un trigger es asincrónico: el panel sube, el trigger corre en otro lado y el
único canal de error es un log que el operador no lee. Eso reconstruye el bug
exacto de PadelPunilla que HU-04.4 existe para no repetir — *spinner, vuelta
al botón, nada* (ARQUITECTURA §5.4, regla 4). Una callable es sincrónica: el
error vuelve a la pantalla con el nombre del archivo que falló. HU-04.4 sale
gratis del transporte, en vez de necesitar una máquina de estados de subida.

**Alternativa descartada:** trigger + un campo de estado en el documento que
el panel escucha. Más piezas para un resultado peor.

**Costo de esta elección:** hay que habilitar `cloudfunctions.googleapis.com`
(estaba apagada — medido: 403 `SERVICE_DISABLED`). Un trigger habría
necesitado además `eventarc`, así que la callable también es la opción barata.

### 4. El `arrayUnion` lo hace el panel, no la callable

La callable corre con el Admin SDK y saltea las reglas por diseño. Si
escribiera `imagenes`, `firestore.rules` dejaría de ser la puerta de ese
campo. La callable queda como una función pura de bytes → bytes, fácil de
testear, sin permisos sobre Firestore; la regla sigue siendo la última
palabra.

## Tres capas de un mismo problema, encontradas EN el deploy y no en el diseño

Documentadas acá porque son el tipo de cosa que se repite si no queda escrito.

**Capa 1 — `functions/tsconfig.json` no resolvía sus propios imports.**
`contratos` ya tenía `allowImportingTsExtensions` y
`rewriteRelativeImportExtensions`; `functions/` no. Medido: Node **no**
resuelve un especificador `./x.js` contra un archivo `x.ts`
(`ERR_MODULE_NOT_FOUND`) — el único que corre nativo es el que termina en
`.ts`. Se alineó `functions/tsconfig.json` con el patrón de `contratos`.

**Capa 2 — el emulador de Functions local no completa el *discovery*.**
`firebase emulators:start` da *"Cannot determine backend specification.
Timeout after 10000"* incluso apuntando a `lib/index.js` ya compilado, aunque
ese mismo archivo, cargado como archivo real (`node prueba.mjs`, no `node
-e`), resuelve en 1,2 s — muy por debajo del timeout de 10 s. **Aislado con
medición: es el *discovery* del emulador en esta máquina, no el código ni la
carga del módulo.** No entra a CI a propósito (`ci.yml:165` no cubre tests de
functions contra emulador todavía). La verificación real de 3.7 pasó al
deploy contra el runtime `nodejs24` real, que es la autoridad de todos modos.

**Capa 3 — `@bouquet/contratos` no resuelve en Cloud Build, la más cara de las
tres.** El primer `firebase deploy --only functions` completó con **exit 0**
y `functions:list` mostraba `procesarFoto` — los dos son el "no le creas al
color" de `CLAUDE.md` en carne propia. La API cruda
(`cloudfunctions.googleapis.com/v2/.../functions/procesarFoto`) decía
`"state": "FAILED"`, `CloudRunServiceNotFound`. El log completo, no el
resumen, tenía la causa: `npm error 404 ... @bouquet%2fcontratos - Not found`.
`@bouquet/contratos` es un symlink de npm workspace que **nunca se publicó a
npm**; Cloud Build sólo empaqueta lo que declara `firebase.json`
(`"source": "functions"`, 19,73 KB, sin `packages/` ni el `node_modules`
hoisteado), así que intenta bajarlo del registro real y da 404.

**Medido, no supuesto: da igual que esté en `dependencies` o en
`devDependencies` — las dos fallan igual.** El paquete subido a Cloud Build no
lleva `package-lock.json` propio (sólo existe en la raíz del workspace, y no
viaja), así que el `npm install` corre sin lockfile, aislado, sin contexto de
workspace — y sin lockfile, `npm install` instala `dependencies` y
`devDependencies` por igual, sin `--omit=dev` implícito. La única `.json` que
no lo intenta resolver es una que no lo nombra en ningún lado.

Se resolvió con `esbuild` (devDependency de `functions/`): `construir` pasó a
`esbuild src/index.ts --bundle --platform=node --format=esm --target=node24
--outfile=lib/index.js` con `firebase-admin`, `firebase-functions` y `sharp`
como `--external` (paquetes reales, Cloud Build sí los resuelve) y
`@bouquet/contratos` **sin** externalizar — esbuild lo empaqueta dentro de
`lib/index.js`, que se verificó (no se supuso) que tiene cero apariciones de
`@bouquet/contratos` y los tres números de `TUBERIA_DE_FOTO` embebidos como
código. Se sacó `@bouquet/contratos` de `package.json` por completo, ni
`dependencies` ni `devDependencies`.

⚠️ **Esto va a volver a aparecer.** `functions/src/index.ts` ya declara que
`crearOrden` y `entroEnPagada` — las próximas dos functions del proyecto —
necesitan la máquina de estados entera de `contratos`, mucho más que tres
números. El bundle con esbuild es la salida que ya funciona; no hace falta
redescubrirla, pero sí volver a verificar que el símbolo que haga falta quede
embebido y que el paquete no vuelva a aparecer en `package.json`.

## Lo que NO se construyó, y por qué

| Qué | Por qué no | Disparador |
|---|---|---|
| **HU-04.2 — reordenar fotos** | Choca con ARQUITECTURA §5.3, que prohíbe reescribir el array entero, y reordenar **es** reescribirlo. Resolverlo pide una transacción que relee y compara contra lo que el operador vio — el mismo patrón que `precioUnitarioVisto` de `crearOrden`. El seed tiene **una** foto por producto: elegir la principal entre una sola es una pantalla que no decide nada | El primer vino con dos fotos |
| **Borrar el archivo crudo de Storage al sacar una foto (HU-04.3)** | Las dos mitades no pesan lo mismo: borrar da 404 en las páginas ya cacheadas en el borde hasta la próxima purga (el tramo 4 de Cloudflare no está construido), mientras que dejarlo cuesta unos cientos de KB de Storage | Cuando los crudos huérfanos pesen |
| **Recorte de fondo con un modelo real** (para la foto de cámara ocasional) | Un modelo ONNX de decenas de MB en el arranque en frío de la function es una superficie que la Decisión 2 de este ADR dice que ni hace falta: el panel muestra y el operador juzga | Que la previsualización resulte insuficiente, mirándola |

## Por qué NO las alternativas

| Alternativa | Por qué no |
|---|---|
| Detectar el packshot con un umbral sobre `trim()` o el borde | **Medido y refutado** (Decisión 2): un packshot legítimo ya en el catálogo puntúa peor que el control negativo sintético. Cualquier umbral da falsos positivos sobre fotos buenas |
| Trigger `onObjectFinalized` en vez de callable | Asincrónico: reconstruye el bug de PadelPunilla que HU-04.4 existe para no repetir. Necesitaría además `eventarc`, que ni siquiera es más barato |
| Procesar la foto en el cliente (Dart), antes de subir | El panel no compila en esta máquina y su único ciclo de feedback es CI; además `sharp`/libvips no tiene equivalente en Dart, y reimplementar `trim()` a mano en el cliente duplicaría lógica real, no sólo números |
| Copiar el símbolo `TUBERIA_DE_FOTO` a mano en un predeploy, en vez de un bundle | Resuelve HOY, pero `crearOrden`/`entroEnPagada` van a necesitar mucho más de `contratos` que tres números — la Capa 3 volvería a aparecer con más superficie |
| Que la callable escriba `imagenes[]` directamente | El Admin SDK saltea las reglas por diseño; `firestore.rules` dejaría de ser la puerta de ese campo (Decisión 4) |

## Presupuesto de lecturas

Cuota: **50.000 lecturas/día**. **Cero lecturas nuevas.**

| Qué | Lecturas | Por qué |
|---|---:|---|
| Subir una foto | **0** | El panel sube a Storage y llama a la callable. La callable no lee Firestore: recibe el `productoId` y devuelve una URL |
| Agregar la URL a `imagenes[]` | **0** | `arrayUnion` es ciego: no lee el documento |
| Quitar una foto | **0** | `arrayRemove`, ídem |
| Ver la previsualización | **0** | Sale del archivo que el operador acaba de elegir, en memoria |
| Ver qué vinos no tienen foto | **0** | `en_la_tienda.dart:121` ya lo calcula sobre el catálogo en memoria (HU-03.1) |

Cargar las 200 fotos del MVP cuesta 200 escrituras, una vez, no lecturas. Lo
que sí agrega es costo de Cloud Functions — no medido en la cuota de
Firestore —: ~200 invocaciones para el catálogo entero y unas pocas por
semana después, muy por debajo de los 2.000.000 de invocaciones sin cargo del
plan.

## Consecuencias

- `functions/` deja de ser un andamio: `index.ts` exportaba `export {}` y
  ningún deploy de functions había ocurrido nunca en el proyecto. Ésta es la
  **primera** Cloud Function de bouquet.
- `cloudfunctions.googleapis.com` queda habilitada — no hace falta
  `eventarc`, porque es callable y no trigger.
- El panel gana la dependencia `firebase_storage` y `cloud_functions`, y una
  feature nueva (`features/fotos/`) con sus cuatro capas.
- ⚠️ **La previsualización copia un color de la vidriera al panel**
  (`Tokens.papelVentana` ↔ `--papel-ventana` de `tokens.css`), que son dos
  sistemas de diseño distintos. Puede desincronizarse; queda anotado como
  constante con nombre y comentario apuntando al token CSS, no escondido en
  un widget.
- Un crudo queda en Storage si la callable falla a mitad de camino. No es
  alcanzable (su nombre es aleatorio y su URL nunca llega a `imagenes[]`) y no
  rompe nada; se limpia con un script el día que los huérfanos pesen.

## Lo que falta

- **4.3 — probar la callable en producción con un usuario real, bloqueado por
  el clasificador.** Mintear un ID token de prueba necesita
  `createCustomToken`, que pide `iam.serviceAccounts.signBlob`; las
  credenciales ADC de usuario no lo tienen sin impersonar una service account,
  y otorgar `roles/iam.serviceAccountTokenCreator` — aunque temporal y
  reversible — es "Permission Grant", categoría que el clasificador frena. El
  comando queda escrito en `tasks.md` 4.3
  (`gcloud iam service-accounts add-iam-policy-binding
  firebase-adminsdk-fbsvc@bouquet-vinos.iam.gserviceaccount.com
  --member="user:aguschazaaa@gmail.com"
  --role="roles/iam.serviceAccountTokenCreator"`, revocado apenas termine la
  verificación). **La verificación funcional real pasa a 10.1**: el dueño
  subiendo una foto de verdad desde el panel.
- **3.7 — probar contra el emulador local, bloqueado por la Capa 2 de arriba.**
  Causa acotada a esta máquina, no al código; el script
  (`functions/test/foto/procesar_foto.emulador.mjs`) queda escrito para cuando
  el emulador local o CI lo permitan.
- **El panel todavía no se desplegó.** Es el Grupo 9 de `tasks.md`: CI
  `alcance=panel` → `publicar.sh preview` → `promover` → `verificar` sobre
  live.
- **10.1 y 10.2 — que el dueño suba una foto real y mire la previsualización.**
  Sigue bloqueado por lo mismo que bloquea a `panel-publicar-un-vino`: los 20
  productos de producción son `muestra: true`.
