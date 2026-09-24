# ADR 015 — Las fotos del panel

- **Fecha:** 2026-09-22
- **Estado:** aceptada y **aplicada en el código**. **Functions desplegada y
  `ACTIVE` en producción** (verificado con la API cruda de Cloud Functions,
  cuarto intento) y **el panel también se desplegó el 2026-09-22**. **CORS
  RESUELTO el 2026-09-23:** el clasificador de permisos frenó el
  otorgamiento dos veces —la segunda con autorización explícita en la
  conversación—, así que lo corrió el dueño a mano. **Verificado con los
  tres controles, no con el `etag` verde de la respuesta:** el preflight
  `OPTIONS` pasó de 403 sin headers a **204 No Content** con
  `access-control-allow-origin`, `-methods: POST` y `-headers: content-type`;
  el control negativo (function inventada) **sigue en 404**, así que la
  medición no cambió de criterio; y un `POST` anónimo pasó del HTML 403 de
  IAM a un **401 JSON real de la callable**
  (`{"error":{"message":"hace falta estar autenticado","status":"UNAUTHENTICATED"}}`)
  — la prueba de que el código ahora corre. **También el 2026-09-23:** §5 y
  §6 —los dos defectos de uso que el dueño encontró el mismo día— fueron
  **desplegados el 2026-09-23 (v0.29.0)**, con los bytes que compiló CI y un
  canario discriminante en live; **nadie los miró renderizado todavía**
- **Decide:** que una foto subida desde el panel se procese con **la misma
  tubería que el seed** (`trim(12)` → `resize(1200)` → `webp(82)`), en una
  Cloud Function **callable** y no en un trigger de Storage; y que el panel
  **no intente detectar** si una foto es un packshot de bodega o una foto de
  cámara — ese detector se midió y se refutó
- **Historias:** HU-04.1 · HU-04.3 · HU-04.4 ([EP-04](../../features/panel/EP-04-fotos.md)).
  **HU-04.2, recortada a *elegir la principal*, se construyó el 2026-09-24** (§7);
  ordenar las demás sigue afuera, con disparador — ver *Lo que NO se construyó*
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
se procesa la foto"* y daba por hecho que el problema e|---|---:|---:|
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

### 5. Cargar, subir la foto y publicar son UN gesto, no tres (2026-09-23)

El dueño usó el panel el 2026-09-22 y encontró que cargar un vino con su foto
y publicarlo eran tres viajes separados por el diseño original de §1/§4: la
ruta de Storage y el `arrayUnion` que persiste `imagenes[]` necesitan el id
del producto, y el documento no existe hasta guardar. Asentado sin reparar en
`_index.md` → *Lo que quedó abierto* (2026-09-22); acá se repara.

**Medido antes de tocar nada, para no reparar lo que no está roto:**

- `functions/src/foto/procesar_foto.ts` **nunca tocó Firestore.** Valida auth,
  el claim `rol: admin`, que la ruta sea `productos/{productoId}/{archivo}`,
  el peso y el formato — todo contra Storage y el argumento, cero lecturas ni
  escrituras de Firestore. El `arrayUnion` posterior lo hacía el panel
  (Decisión 4), no la callable.
- `storage.rules:43-46` sólo exige `esAdmin() && esImagen() && pesaMenosDe5MB()`
  sobre `productos/{productoId}/{archivo}` — ningún `firestore.get()`, nada
  que pida que el documento exista.
- `firestore.rules` — `productoValido(d)` (la función que valida create Y
  update por igual) ya acepta `imagenes` con URLs y `publicado` en cualquier
  valor booleano al **crear**: nada ahí asumía que un alta llegaba con
  `imagenes: []` y `publicado: false` fijos, eso lo imponía sólo
  `documentoNuevo` del lado del panel.
- ADR 008 §2: `stock` | sólo el servidor | **"El panel crea con `0`"** — no
  `null`. Publicar con `stock: 0` no inventa unidades: la tienda lo muestra
  "agotado" hasta la reposición, que sigue siendo, sin cambios, la única
  puerta de `stock` (`RepositorioDeProductosFirestore.crear` la sigue fijando
  en `0` siempre).

**Conclusión: nada en Storage, en las reglas ni en el stock exigía el orden de
tres pasos — lo exigía únicamente que `AltaDeVino`/`documentoNuevo` excluían
`imagenes` y `publicado`, a propósito, desde antes de que este ADR existiera.**
Se revierte esa exclusión para esos dos campos (`escrituras_del_vino.dart`,
`documento_del_vino.dart`) — **`stock` y `tipo` siguen fuera del alta, sin
tocar.**

**Lo que cambia:**

- `SeccionDeFotos` deja de exigir que el vino esté guardado: alcanza con que
  el nombre dé una dirección (`revision.slug`). Sube a
  `productos/{slug}/...` con ese slug **todavía no persistido**, y
  `RepositorioDeFotos.subir(..., agregarAlDocumento: false)` se salta el
  `arrayUnion` porque no hay documento — la URL queda en memoria
  (`BorradorDeVino.imagenes`) hasta que se confirma el alta.
- `PieDelFormulario` suma un tilde, **"Publicar apenas se cargue"**, con
  **default `true`** en un alta nueva: es una decisión de producto, no sólo
  técnica — el dueño ya hacía las tres cosas cada vez, así que la opción
  frecuente es ahora la que no hay que buscar. Se puede destildar antes de
  guardar.
- `RepositorioDeProductosFirestore.crear` no cambia: sigue siendo una única
  transacción. Lo único distinto es qué valores le da `documentoNuevo` a
  `imagenes`/`publicado` — atómico con el resto del alta, no un segundo viaje.

**Lo que NO cambia, a propósito:** una corrección (vino ya guardado) sigue
subiendo fotos con `arrayUnion` inmediato — ahí el documento ya existe y no
hay nada que diferir. El switch "Poner en la tienda" (`interruptor_de_tienda`)
sigue siendo el único camino para publicar/despublicar un vino que ya existe.

### 6. El espacio del formulario (2026-09-23)

El dueño también midió una columna fija de 640 px con el resto de la pantalla
vacío en una ventana de escritorio (`formulario_del_vino.dart`, antes de esta
sesión). `DisposicionDelFormulario` reemplaza el `ConstrainedBox` fijo: debajo
de 900 px de ancho disponible se sigue apilando en una columna (celular, y el
panel corre en Android); a partir de 900 los datos/venta van a la izquierda y
las fotos a la derecha, dentro de un ancho máximo de 1100. No es una dirección
de diseño nueva (no pasó por `/disenio`): es la misma paleta y los mismos
componentes, sólo reacomodados — sigue siendo un layout, no un sistema de
diseño nuevo.

### 7. Elegir la foto principal (HU-04.2, recortada — 2026-09-24)

**Se recortó la historia.** HU-04.2 pide *elegir la primera y ordenar las demás*. La
vidriera lee **sólo `imagenes[0]`** (`VentanaDeBotella.tsx:30`, `seleccion.ts:49`), así
que el orden de la segunda en adelante no le cambia nada a un comprador. Se hace
la primera mitad; **ordenar las demás queda con disparador: el día que la ficha
muestre más de una foto.**

**Se construyó antes del disparador que esta tabla le puso** (*"el primer vino con dos
fotos"*): se midió el 2026-09-24 y son **0 de 22**. La razón es que hoy la única forma de
cambiar la principal es sacar la foto y volver a subirla, y con el catálogo real
por cargarse eso es lo primero que se va a necesitar.

**La decisión: una transacción de cliente que relee.** `RepositorioDeFotos.hacerPrincipal`
lee el documento, aplica `conPrincipal` (pura, en `domain/foto_principal.dart`) **sobre lo
leído**, y escribe con `tx.update` sólo si cambió. Es la única escritura del panel que
reescribe `imagenes` entero, y choca con ARQUITECTURA §5.3; lo que esa regla protege —que
no se pierda la foto que subió otra persona— lo cuida que la lista escrita sea **una
permutación de la que se leyó en ese intento**. El SDK reintenta con lectura fresca si el
documento cambió antes del commit.

| Alternativa | Por qué no |
|---|---|
| Un campo `principal` aparte | Dos fuentes para la misma pregunta (§5.2) y cuatro lugares que tocar; y un `principal` que apunta a una foto ya sacada es un estado nuevo |
| `arrayRemove` + `arrayUnion` en un batch, sin leer | Las fotos que se re-agregan salen de la pantalla, que puede estar vieja: si otra persona sacó `A`, el `arrayUnion(A)` **la resucita** |
| Una callable | Un deploy de `functions` y un arranque en frío para una escritura que las reglas ya permiten |
| Escribir la lista de la pantalla | Es lo que §5.3 prohíbe |

**Sin reglas nuevas.** `imagenesValidas` ya acepta la lista reescrita. Lo que **no** exigen
es que sea una permutación de la anterior: esa invariante vive en `conPrincipal` y en sus
tests, no en las reglas (compararlas pediría desenrollar diez posiciones por lado).

**La excepción sale afuera de la transacción**: el handler devuelve `cambiada` / `yaEra` /
`yaNoEsta` y `hacerPrincipal` arma el `FalloDeFotos` después, porque en web una excepción
propia que cruza el puente de promesas de JS puede llegar envuelta. `yaEra` no escribe.

**Dos textos de error dejaron de decir "subir"** (`sinPermiso`, `desconocido`): ahora
sirven a tres operaciones y "no tenés permiso para subir fotos" era falso al elegir la
principal.

**Presupuesto de lecturas:** 1 por cambio (la de la transacción) **más 1 por cada sesión
abierta**, porque `productosProvider` es un `snapshots()`. Con 50 cambios por día y dos
sesiones: **~150/día, el 0,3 % de los 50.000**. La página no lee nada nuevo.

⚠️ **Con el tramo 4, cambiar la principal de un vino publicado va a disparar una purga**
(igual que `moverStock`, ADR 016). Conviene elegirla **antes de publicar**.

**Lo que NO está probado:** los tests del panel son de dominio puro; no hay una prueba de
`runTransaction` contra un emulador. `conPrincipal` está probada, la concurrencia no.

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
| **HU-04.2 — ordenar las fotos que no son la principal** (elegir la principal **sí** se construyó, §7) | Choca con ARQUITECTURA §5.3, que prohíbe reescribir el array entero, y reordenar **es** reescribirlo. Resolverlo pide una transacción que relee y compara contra lo que el operador vio — el mismo patrón que `precioUnitarioVisto` de `crearOrden`. El seed tiene **una** foto por producto: elegir la principal entre una sola es una pantalla que no decide nada. La vidriera lee sólo `imagenes[0]`: ordenar la segunda en adelante no cambia nada visible | El día que la ficha muestre más de una foto |
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

- ~~⚠️ **La callable no es alcanzable desde el navegador: el preflight da 403,
  y el panel lo muestra como un error de CORS.**~~ **RESUELTO el 2026-09-23,
  por el dueño.** Lo encontró usando el panel el 2026-09-22; medido después
  con `curl` crudo. `OPTIONS` con `Origin` y `Access-Control-Request-Method:
  POST` sobre `https://us-central1-bouquet-vinos.cloudfunctions.net/procesarFoto`
  devolvía **403 de `Google Frontend`, sin un solo header
  `Access-Control-Allow-*`**. **Control negativo:** el mismo `OPTIONS` contra
  una function inventada daba **404**, así que el 403 era de esta function y
  no del frontend contra cualquier `OPTIONS`. **El control que aisló la
  causa:** un `POST` anónimo devolvía **el mismo 403 HTML** en vez del JSON
  `UNAUTHENTICATED` que devolvería la callable — **el código nunca
  corría**: lo frenaba IAM antes. Faltaba `allUsers` como `roles/run.invoker`
  en el servicio de Cloud Run de `procesarfoto`. **No era el bucket** (medido
  aparte: el endpoint de subida y una descarga con `Origin` contestaban
  `Access-Control-Allow-Origin: *` aunque el bucket no tuviera política CORS).
  El clasificador de permisos de Claude Code frenó el otorgamiento dos veces
  el 2026-09-23 —la segunda con autorización explícita en la conversación—,
  así que lo corrió **el dueño, a mano**:
  `gcloud run services add-iam-policy-binding procesarfoto
  --project=bouquet-vinos --region=us-central1 --member="allUsers"
  --role="roles/run.invoker"`. **Verificado con los mismos tres controles, no
  con el `etag` verde de la respuesta:** el preflight ahora da **204 No
  Content** con `access-control-allow-origin`,
  `access-control-allow-methods: POST` y
  `access-control-allow-headers: content-type`; el control negativo **sigue
  en 404** (la medición no cambió de criterio); y el `POST` anónimo ahora da
  **401 JSON real de la callable**
  (`{"error":{"message":"hace falta estar autenticado","status":"UNAUTHENTICATED"}}`),
  no el HTML de IAM — el código corre. **Sigue habiendo un crudo huérfano por
  cada subida que falla a mitad de camino** (eso no lo arregla el CORS, es
  Decisión 4/Consecuencias de este mismo ADR), pero ya no en CADA intento.
- ✅ **Escrito el 2026-09-23** (§5, abajo): los dos defectos de uso de arriba.
  **Desplegado el 2026-09-23** (v0.29.0). Lo que falta es lo que ninguna
  medición reemplaza: que el dueño cargue un vino real, con foto, en un solo
  gesto, y lo mire.

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
