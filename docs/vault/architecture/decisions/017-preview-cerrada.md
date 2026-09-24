# ADR 017 — La preview cerrada de la vidriera

- **Fecha:** 2026-09-23
- **Estado:** aceptada, **desplegada y verificada** el 2026-09-23 (rollout
  `build-2026-09-24-003`, `SUCCEEDED`, 100 % del tráfico; los dos anteriores
  fallaron, ver §3). URL: <https://bouquet-tienda--bouquet-vinos.us-east4.hosted.app>
- **Decide:** dónde y cómo se **mira** la vidriera con el catálogo real, sin
  publicarla. **No es la publicación de la tienda**: los gates de deploy siguen
  cerrados
- **Toca:** [ADR 005](005-hosting-vidriera.md) (elige la región y el modo de
  deploy de App Hosting; el ADR no tocaba cómo se despliega) y
  [ADR 010](010-el-checkout.md) (corrige la receta para verificar el gate del
  checkout, §6)
- **Hace cumplir:** `bash scripts/tienda/preview.sh verificar` (estado real del
  rollout, `noindex` en cada respuesta, catálogo contra Firestore, gates
  cerrados — con control negativo cada uno)
- **Sin openspec**, a pedido del dueño (2026-09-23)

## Contexto

Con EP-05 el hito 1 quedó escrito, y lo que falta para cerrarlo es **uso real**:
que alguien cargue un vino, le suba la foto, lo publique y lo **mire en la
tienda** (10.1 y 10.7 de los changes del panel). Pero la vidriera no está
desplegada en ningún lado, y **no puede publicarse**: le faltan la puerta de
edad (la única pieza legal obligatoria de una tienda de alcohol, ARQUITECTURA
§9.5), el WhatsApp y el dominio reales, el checkout cobra en falso, y no existe
el tramo 4 de Cloudflare. Correrla en `localhost` sirve para mí y no para el
dueño.

## Decisión

### 1. Qué es, y qué NO

Un backend de **Firebase App Hosting** con la vidriera tal como está, para
**mirarla**. *Cerrada* quiere decir **sin dominio, sin indexar y con la URL sin
difundir**. **No está protegida con contraseña**: cualquiera que tenga la URL la
ve. Los gates de deploy **siguen abiertos** y esta preview no los cierra:

| Gate | Estado en la preview |
|---|---|
| Puerta de edad | **No existe.** Es lo que hace que esto no pueda ser público |
| Contacto | Provisorio: el WhatsApp es el del desarrollador (`EL_CONTACTO_ES_PROVISORIO`) |
| Checkout | Armado y **no cobra** (`EL_CHECKOUT_NO_COBRA`); el botón está deshabilitado |
| Datos | 20 vinos de muestra + los que el dueño cargó |

### 2. App Hosting sin GitHub, en `us-east4`

`firebase apphosting:backends:create --backend bouquet-tienda --primary-region
us-east4 --non-interactive` crea el backend **sin repositorio vinculado**, y
`firebase deploy --only apphosting` sube el código local (`alwaysDeployFromSource`).
Sin OAuth de GitHub —que pide un navegador— y **sin el problema de "el deploy de
front reconstruye desde el HEAD pusheado y arrastra todo lo mergeado"**: se
publica una copia armada a propósito.

**`us-east4`**, una de las dos que [ADR 005 §1](005-hosting-vidriera.md) admite
(la otra es `us-central1`) y la más cercana a São Paulo, donde está Firestore.
**La región de un backend no se cambia**: si se elige otra, se borra y se recrea.

### 3. La copia autocontenida — por qué existe esto (NO REVERTIR)

`scripts/tienda/preparar_despliegue.mjs` arma `.deploy/tienda/` (gitignoreado, se
regenera siempre): la app, `contratos` **adentro** como `file:./vendor/contratos`,
y un `package-lock.json` propio. Se despliega **desde esa carpeta**.

**El cadáver.** Dos rollouts perdidos el 2026-09-23 (del segundo hay log y dice
la causa; del primero **no hay log** —§6— y falló, casi seguro, por lo mismo: la
configuración era idéntica. **Es una inferencia, no una medición**). El buildpack
de Next de App
Hosting (`google.nodejs.firebasenextjs`) toma como **"raíz de la aplicación" el
`rootDir`** —acá `/workspace/apps/tienda`— y busca **ahí** el lockfile, **no más
arriba**. El nuestro está en la raíz del monorepo, como corresponde a un
workspace de npm, así que el build muere a los 18 segundos con
`fah/missing-lock-file` **aunque el lockfile viaje en el zip** (se verificó
bajando el zip y listándolo: 170 archivos, `package-lock.json` incluido).
Se leyó el código del buildpack (`ReadNodeDependencies`) para no adivinar. La
documentación de monorepos de Firebase **no dice nada** de esto.

**El diseño:** la tienda pasa a ser una app de Next común —el caso que App
Hosting soporta— y `@bouquet/contratos` entra como dependencia local, igual que
`procesarFoto` lleva `contratos` adentro de su bundle
([ADR 015](015-fotos-del-panel.md)). El lockfile **parte del de la raíz**: un
`npm install` en frío resolvería `@opentelemetry/api ^1.9.1` y todo lo
transitivo a lo que salga hoy, y lo que se despliega dejaría de ser lo que se
probó. El script **falla** si `next`, `react`, `react-dom`, `firebase-admin` o
`@opentelemetry/api` cambiaron de versión respecto del lock de la raíz, si el
lock trae un workspace ajeno, o si `npm ci --dry-run` —la comprobación que hace
la nube— no pasa. **Se midió que ese control discrimina**: con una dependencia
que el lock no tiene, `npm ci` sale con 1.

⚠️ npm **no borra** del lock los workspaces que dejaron de existir: los marca
`"extraneous": true` y los deja. El script los poda; sin eso el lock queda
inconsistente y se entera uno a los 18 segundos de un build.

### 4. `noindex` por variable de entorno

`next.config.ts` agrega `X-Robots-Tag: noindex, nofollow, noarchive` a **toda**
ruta **sólo si `PREVIEW_CERRADA=1`**, que vive en el `apphosting.yaml` de la
carpeta. **No es fijo** porque el día que se publique la tienda de verdad, salir
con `noindex` la dejaría afuera de Google **sin un solo error**. Se lee **al
build** (los headers se compilan al manifiesto de rutas), así que la variable va
con disponibilidad `BUILD` **y** `RUNTIME`. Se midió en las dos direcciones: con
la variable, 1 regla; sin ella o con `=0`, 0.

### 5. Un tope de costo y de lecturas: `maxInstances: 1`

`minInstances: 0` (no se paga en reposo) y **`maxInstances: 1`**. El máximo por
defecto es 100: un bot que encuentre la URL levanta cien instancias y paga el
dueño. Y **el tope de instancias es también el tope de lecturas** (ver
*Presupuesto*), porque la caché de datos de Next vive por instancia.

### 6. La cuenta de servicio, y qué roles tiene

El CLI crea `firebase-app-hosting-compute@` y le da **cuatro roles**, incluido
`firebase.sdkAdminServiceAgent`, que es **más ancho de lo que una tienda que sólo
lee necesita** (incluye escritura). **Se re-otorgan en cada `firebase deploy`**
(`prepare.js`), así que achicarlos a mano no dura. La vidriera sólo lee
(`productos`, `bodegas`, `metricas`, `cajasSugeridas`); la escritura de plata va
por Cloud Functions, que tienen su propia cuenta. **Antes de publicar de verdad
hay que decidir una cuenta dedicada con `roles/datastore.viewer`.**

⚠️ **Y los roles tardan en propagarse.** El primer rollout se lanzó **21
segundos** después de otorgarlos (el audit log lo fecha: `SetIamPolicy` a las
00:15:56, build a las 00:16:17) y **no escribió un solo log de texto**, solo las
entradas de auditoría. El segundo, minutos después, sí escribió 301 líneas. Un
build que "no dice nada" no es un build sin error: esperar unos minutos y leer
`gcloud logging read 'resource.labels.build_id="<id>"'` (no `gcloud builds log`,
que vuelve vacío: los logs de App Hosting van a Cloud Logging).

## Por qué NO las alternativas

| Alternativa | Por qué no |
|---|---|
| `rootDir: apps/tienda` sobre el monorepo | **Se probó y falló dos veces** (§3) |
| `rootDir` en la raíz con `buildCommand`/`runCommand` a medida | No se probó. El buildpack de Next se apaga si no encuentra `next` en el `package.json` de la raíz, y el adaptador que arma el bundle es lo que hace funcionar el resto: se pelea contra el framework |
| Un backend vinculado a GitHub | Pide OAuth en un navegador, y despliega desde el `HEAD` pusheado arrastrando lo mergeado (CLAUDE.md) |
| Ver la vidriera en `localhost` | Sirve para quien tiene el repo, no para el dueño |
| Protegerla con contraseña (basic auth) | Descartado **por ahora**, no rechazado: cierra de verdad el hueco de que no hay puerta de edad, pero es código nuevo en la tienda. Es la primera cosa a agregar si la URL se va a compartir |
| Vercel | No es el stack decidido ([ADR 001](001-stack.md), [005](005-hosting-vidriera.md)) |

## Presupuesto de lecturas

Campo obligatorio, contra los 50.000/día. **Es la misma cuota que usa el panel**
(4,6 % de catálogo + 3 lecturas por movimiento de stock, [ADR 016](016-mover-el-stock.md)).

Una reconstrucción del catálogo lee **P + B + 1**: hoy 21 publicados + ~12
bodegas + 1 = **~34**. El build **prerenderiza** `/vinos` y `/carrito`, así que un
deploy suma unas 100 ([ADR 008](008-catalogo-stock-y-carrito.md): una visita a
listado, ficha y carrito en el mismo minuto es **una** reconstrucción).

| Escenario | Lecturas/día | % de la cuota |
|---|---:|---:|
| Uso normal de una preview (unas decenas de visitas) | < 1.000 | < 2 % |
| **Techo, con `maxInstances: 1`:** alguien la martilla las 24 h, una reconstrucción por minuto | 1.440 × 34 ≈ **49.000** | **~98 %** |
| Sin el tope (100 instancias, cada una con su caché) | sin cota | — |

⚠️ **El techo es el riesgo real de esta preview**: un scraper constante la lleva
al 98 % de una cuota que **comparte con el panel**, y el panel es lo que el dueño
usa a diario. **Mitigaciones:** la URL no está indexada ni difundida; el tope de
una instancia; y `firebase apphosting:backends:delete bouquet-tienda --project
bouquet-vinos --force` la apaga entera. **Vigilar el uso el día que se comparta.**

## Verificación (2026-09-23)

| Qué | Cómo |
|---|---|
| El rollout | **API cruda** de App Hosting: `build-2026-09-24-003` `SUCCEEDED`, 100 % del tráfico; los `-001` y `-002` figuran `FAILED`. El CLI decía "complete" |
| `noindex` | En **8 respuestas**: las cinco páginas, dos 404 y un asset. `/contacto` redirige con 308 |
| Que el catálogo es el real | Firestore: 22 productos, 21 publicados, **los 21 nombres aparecen en `/vinos`**; la ficha de un vino real da 200 con su foto |
| La foto | 200 `image/webp` `immutable`, la salida de `procesarFoto`, referenciada por la ficha |
| Renderizado | Chrome real por CDP, escritorio (1280) y teléfono (390, por `Emulation.setDeviceMetricsOverride`): sin desborde horizontal, **0 fotos rotas**, capturas miradas |
| Los gates | El checkout que no cobra, en los **chunks de JS** (1 archivo; control negativo 0), y el contacto provisorio en `/oficio` |
| Que el verificador discrimina | Apuntado a un backend inexistente, sale con 1. **Tenía un bug propio**: con `pipefail`, el `grep -l` del control negativo sale con 1 cuando no encuentra nada —que es lo que tiene que pasar— y `set -e` lo mataba **en silencio** |

### Dos hallazgos que salieron de verificar

- **La receta del gate del checkout era un falso negativo** (§ ADR 010): `curl
  /pedido | grep data-checkout-simulado` da **0 con el gate cerrado**, porque el
  atributo lo dibuja `ElResumen`, que sólo existe con ítems en el carrito. Se
  corrigió en el código, en el ADR 010 y en el dashboard.
- **`moverStock` ya se usó en producción.** A las 00:04 UTC (21:04 en Argentina)
  alguien repuso **32** en `vino-de-prueba`: `antes 0 → despues 32`, con su
  marcador y el uid de quien lo hizo; **un solo movimiento, sin duplicados**. Eso
  cierra lo que [ADR 016](016-mover-el-stock.md) no pudo verificar (el Admin SDK
  contra el Firestore real y el permiso de la cuenta de servicio).

## Lo que queda abierto

- **La puerta de edad, el contacto real, el dominio, el tramo 4 y las licencias**
  son los gates de la **publicación**, no de esta preview. Siguen como estaban.
- **`/favicon.ico` da 404** (único error de consola): la tienda no tiene favicon.
- **Los roles anchos de la cuenta de servicio** (§6), antes de publicar de
  verdad.
- **Basic auth**, si la URL se comparte fuera de la familia (§ alternativas).
- **Cómo se actualiza:** `bash scripts/tienda/preview.sh desplegar` y después
  `verificar`. Cada rollout cuesta unos 5 minutos de Cloud Build.
