# bouquet — estado actual

> **Este archivo es un dashboard, no un log.** Tope: **5 entradas**. La sexta se
> mueve a `changelog/_log.md`.
>
> `DIAGNOSTICO.md` §3: en PadelPunilla este archivo creció a ~15 entradas de 20
> líneas y Claude lo leía **entero en cada sesión** — el archivo más caro del
> repo en tokens, y las entradas 6 a 15 casi nunca cambiaban una decisión. Un
> dashboard que no entra en una pantalla dejó de ser un dashboard.
>
> **Y este archivo documenta la INTENCIÓN.** El comportamiento real sale de
> `_verdad.md`, que se genera desde el código. **La diferencia entre los dos es
> la deuda del proyecto, medida.**

---

## Dónde está el proyecto

**Fase: la vidriera está entera hasta el botón de pagar (2026-09-15). Todavía
no se cobra nada.** `/vinos`, la ficha, `/carrito` y ahora `/pedido` leen 20
vinos de muestra de `bouquet-vinos`. El checkout pide los datos y cotiza el
envío **con un cotizador simulado**; falta `crearOrden`, la preferencia de
Mercado Pago y su webhook.

**Las reglas de Firestore y Storage YA ESTÁN PUBLICADAS** (2026-09-14), medido
por la API de Rules con quota project: dos releases. **Las fotos dan 200
`image/webp`**, así que las ventanas del catálogo y de la home dejaron de estar
vacías.

Existe: `git init` en `main`, `CLAUDE.md`, los 10 hooks con su arnés de 30
casos, `ci.yml`, los ADRs 001-004, y **`packages/contratos`** — la máquina de
estados de Orden, la proyección de los 30 pares, el dinero en centavos, los
tests y el contrato generado.

**El conteo de tests salió de acá a propósito.** Decía **24** y el runner
dice **26** — lo detectó `_verdad.md` en su primera corrida, que es
exactamente para lo que existe. Un número que se puede calcular no se
escribe a mano: está en
[`_verdad.md`](_verdad.md), generado desde el código.

~~No existe todavía `apps/`, `functions/` ni `firestore.rules`.~~ Existen
desde el 2026-09-03 — ver abajo. La línea quedó contradiciendo a su propio
archivo dos entradas más abajo, que es el modo de falla que este dashboard
existe para no tener.

**Node 24 corre TypeScript sin transpilar**, así que el paquete tiene **cero
dependencias de test** (ni jest, ni vitest, ni ts-node). La única dependencia
del repo es `typescript`, para `tsc --noEmit`. En una máquina de 7,9 GB eso no
es un detalle de gusto.

Lo próximo es `crearOrden` y el cobro, con los nueve hallazgos que dejó
`revisor-pagos` en
[ADR 008](architecture/decisions/008-catalogo-stock-y-carrito.md). Y antes del
deploy público con el catálogo real, el tramo 4: Cloudflare con purga por tag.

**El panel tiene plan desde el 2026-09-16, y ese mismo día tuvo puerta**:
EP-01 entera. Se entra con mail o con Google, quien no tiene permiso lo ve
dicho, y las cuentas las da un script.

**Catálogo dejó de estar vacío el 2026-09-17**: se ven todos los vinos
—publicados y no—, se buscan escribiendo, y las bodegas se cargan, se corrigen
y se borran con una baranda que no deja despublicar sin querer. Son **EP-02
entera y HU-03.1**. ~~Pedidos sigue vacío y lo dice: es el hito 2.~~ **Desde el 2026-09-24 se cargan y se ven
pedidos de WhatsApp**, primer tramo del hito 2; **desde el 2026-09-25 se avanzan y se
cancelan** (EP-07, primera entrada de abajo).

~~**Cargar un vino está escrito desde el 2026-09-18 y todavía NO desplegado**~~
**Desplegado el 2026-09-21**: HU-03.2 a HU-03.4, reglas (`0310466f`) y panel
(commit `d871218`). Lo próximo del hito 1 era **publicar** —HU-03.5 a 03.7,
**construidas el 2026-09-22** (entrada de arriba)—; lo que sigue pendiente es
el deploy del panel y que alguien cargue y publique un vino real.

**Y desde el 2026-09-17 está PUBLICADO en
[`bouquet-vinos.web.app`](https://bouquet-vinos.web.app)**, con `noindex` y con
la API key acotada por referrer. **El dueño ya entró con Google y tiene el
permiso**: es la única cuenta de Auth. Falta la lista de mails del resto de la
familia — el permiso lo da el script, no una pantalla.

### EP-07: los pedidos se preparan, se despachan y se cancelan devolviendo el stock (2026-09-25)

**Escrito; sin desplegar ni verificar** (ver abajo). Sin openspec, a pedido del dueño:
[ADR 019](architecture/decisions/019-preparar-despachar-y-cancelar.md) es la
especificación. **HU-07.1, 07.2, 07.4, 07.5 y 07.6**, el segundo tramo del hito 2:
cierra lo que ADR 018 dejó como *"lo primero que sigue"* — un pedido ya sale de
`sin_preparar`, y **uno mal cargado se cancela y su stock vuelve**.

**Dos caminos.** Preparar, despachar (correo + seguimiento opcional), entregar y la
entrega fallida (con motivo) los escribe el panel **directo**, y **las reglas validan
la transición** contra el estado de ahora, con cero lecturas: era el hallazgo 3 del
mapa. **Cancelar es `cancelarOrden`, la cuarta Cloud Function**: devuelve el stock con
el snapshot de `botellas` en la misma transacción que marca la Orden, que es su propio
marcador. **Ningún cliente puede escribir `cancelada`**, aunque la tabla la permita.

**Tres decisiones mías, en el ADR:** cancelar **nunca se traba por una línea** (un vino
borrado o recreado en otra presentación queda en `sinReponer`, escrito en la Orden y en
rojo en el detalle); **no aplica el tope** de stock al devolver; y las listas de
correos y motivos. La confirmación de *entregado* **es la declaración legal**: *"Sí, lo
recibió un mayor de 18"*.

**La tabla de transiciones vive ahora en tres lugares** (contratos, Dart, reglas), y la
tercera copia la sincroniza un test: la suite de reglas lee los pares del JSON generado.
Y **las suites de emulador pasan a CI** (job `suite_emulador`): hasta hoy las que prueban
plata se corrían sólo a mano, y esta máquina no tiene RAM para levantar el emulador.

### Pedidos de WhatsApp: se cargan y se ven, pero todavía no se pueden avanzar (2026-09-24)

**Desplegado —reglas, índices, `crearOrdenDelPanel` y panel— y verificado por bytes y por
API cruda (v0.36.3, commit `6efec1c`). Nadie lo usó y nadie miró el panel renderizado.**
Change [`pedidos-de-whatsapp`](../../openspec/changes/pedidos-de-whatsapp/proposal.md), con la
decisión y su presupuesto de lecturas en
[ADR 018](architecture/decisions/018-pedidos-de-whatsapp.md). **HU-10.1, HU-06.1 y HU-06.2**:
el primer tramo del hito 2. Cargar un pedido que llegó por WhatsApp descuenta el stock, le da
un número y lo deja en una bandeja por estado de entrega, con su detalle.

**`crearOrdenDelPanel` es la tercera Cloud Function y la primera que CREA una Orden.** Descuenta
el stock, reserva el número y escribe la Orden en una transacción, donde **el documento es su
propio marcador de idempotencia**. **El origen lo fija el servidor**, no el pedido. El pago de un
pedido de WhatsApp es un valor nuevo, **`por_fuera`** (terminal, no dispara `entroEnPagada`, no
cae en *entregada impaga*): la proyección pasó de 30 a 36 pares (**decisión mía**, ADR 018 §3).

**`revisor-pagos` corrió antes del commit: 14 hallazgos, 1 ALTO.** El ALTO era el bloqueante que
[ADR 016](architecture/decisions/016-mover-el-stock.md) había dejado escrito: contar el depósito y
corregir **pisa lo vendido sin despachar**. Y dos que ninguna prueba mía veía: **un reintento con
la dirección corregida devolvía «éxito» sin guardar el cambio**, y **la regla `update` dejaba a un
admin borrar `estadoEntrega`**, con lo que la orden desaparecía de toda bandeja. Los 14, uno por
uno, en el ADR.

**Y verificar destapó tres cosas más, cada una con una prueba que la habría dejado pasar:**

| Qué | Cómo se vio |
|---|---|
| ⚠️ **La bandeja estaba rota en producción**: los índices de `ordenes` estaban *declarados* y nunca *desplegados* | Correr las seis consultas contra la API: `FAILED_PRECONDITION` en todas. Con los índices desplegados corren, y el control negativo sigue fallando. **Un índice declarado no prueba nada** |
| Las rutas `nuevo` y `:id` eran **hijas** de `/pedidos`, así que se apilaban sobre una bandeja que seguía viva | `presupuesto-lecturas`: abrir por URL directa la armaba abajo (25 lecturas de más) y volver tras cargar mostraba la lista vieja, sin el pedido nuevo. Ahora son hermanas |
| **El aviso de la hoja de corrección mandaba a restar de más** | Al leer ese informe caí en que **el panel todavía no puede marcar un despacho**: un pedido cuyas botellas ya salieron sigue «abierto». El texto ahora da el dato y las dos salidas |

⚠️ **Lo que este tramo NO resuelve, y es lo primero que sigue:**

- **Sin EP-07 los pedidos no salen de `sin_preparar`.** Se cargan y se ven, pero no se pueden
  despachar ni cancelar. La bandeja cuesta 25 lecturas por apertura desde el segundo día, el aviso de
  stock no es fiable y **un pedido mal cargado o duplicado no se puede sacar**: puede costar vino.
- **Nadie llamó a la callable como usuario real** (mintear un token lo frena el clasificador) **ni miró
  el panel**: la máquina tenía ~700 MB libres y el servidor de análisis ya se había caído. La primera
  carga real la va a probar el dueño.
- **Con la preview de la vidriera martillada, la cuota no entra**, y ya no entraba: este cambio la pasa
  por ~2 puntos. Lo que hay que recortar es la preview.

Verificación completa —qué se corrió, cómo, y qué no— en la sección final del ADR.

### HU-05.4: los movimientos de stock se leen — y el hito 1 queda escrito entero (2026-09-24)

**Escrita; el deploy y su verificación van abajo.** Sin openspec, a pedido del dueño:
[ADR 016 §6](architecture/decisions/016-mover-el-stock.md) es la especificación. Un botón
*"Ver los últimos movimientos"* en la sección de stock abre una hoja con los últimos 20:
qué se hizo, de cuánto a cuánto (con la unidad), quién y cuándo. **Con esto las 24 historias
del hito 1 están escritas.** Ninguna está cerrada: falta lo que sólo puede hacer el dueño.

**Toca `firestore.rules`**: el deploy es reglas → panel. `read` de `movimientos` pasa de
cerrado a `get` de admin y `list` de admin **con `limit` ≤ 50**; `write` sigue cerrado.
Se construyó **antes de su disparador**, para cerrar el hito.

**Workflow D: `revisor-pagos` corrió ANTES de commitear**: ningún ALTO ni MEDIO, cinco BAJO.
Corregidos cuatro: el parser podía **ocultar la lista entera** con un solo documento roto
(`NaN`, o un `en` que no fuera Timestamp) y la pantalla habría culpado a la conexión; el
*"de 8 a 10"* de un vino de caja no decía que son **cajas** (60 botellas, no 10); dos pruebas
que faltaban (la consulta real `orderBy('en').limit(20)` y que un `collectionGroup` siga
rechazado); y una línea del ADR que decía *"nada lee movimientos"*. El quinto sigue abierto,
con su porqué: `seed.mjs` reescribe `stock` y `borrar.mjs` deja huérfana la subcolección, así
que sólo en los vinos de muestra la historia puede no explicar el número.

| Qué | Cómo |
|---|---|
| Las reglas | Emulador: **60 casos** (+3). Un `get` y un `list` con `limit` pasan (control positivo); sin `limit`, con 51, un comprador, un anónimo y un `collectionGroup` rechazan. **Mutando** la exigencia de `limit`, fallan exactamente los 2 casos que la prueban |
| El panel | `dart test` de `stock/`: **45 casos**; `dart analyze lib test`: **No issues found**. Incluye el movimiento REAL de producción (`reponer 32`, `0 → 32`) |
| Sin huérfanos | 9 símbolos grepeados con call site fuera de su archivo; control negativo: 0. Ruta: `enrutador` → `PaginaDelVino` → `SeccionDelStock` → `HojaDeMovimientos` |
| Presupuesto | **≤ 20 lecturas por apertura de la hoja, 0 con la hoja cerrada**; 20 aperturas al día = 400, el **0,8 %** de la cuota |

**Dice `Vos` u `Otra persona`, no un nombre**: el movimiento guarda un uid. Mostrar nombres
tocaría `moverStock`; queda con disparador en el ADR.

**Sin probar:** la lectura de Firestore real desde el panel (`RepositorioDeMovimientosFirestore`
no tiene prueba propia; el parser y los textos sí).

### La foto principal: HU-04.2 recortada, y el estado del hito 1 medido (2026-09-24)

**Desplegada y verificada por bytes el 2026-09-24 (v0.32.0, commit `1ab7bb0`); nadie la
miró renderizada.** Change
[`panel-foto-principal`](../../openspec/changes/panel-foto-principal/proposal.md),
con el porqué en [ADR 015 §7](architecture/decisions/015-fotos-del-panel.md). Cada
foto que no es la primera tiene **"Usar como principal"**, un toque y sin
confirmación. **Se elige la principal y NO se ordenan las demás**: la vidriera lee
sólo `imagenes[0]` (`VentanaDeBotella.tsx:30`, `seleccion.ts:49`).

⚠️ **Se construyó ANTES de su disparador, a propósito.** El disparador era *"el primer
vino con dos fotos"* y se midió que no pasó: **0 de 22 productos**. Se tomó igual
porque, hoy, cambiar la principal obliga a sacar la foto y volver a subirla.

**El hito 1, medido en producción el 2026-09-24** (no leído de este archivo):
24 de 24 historias escritas (HU-04.2 recortada; HU-05.4 se escribió después, ver arriba). **0 cerradas**: ningún
change se archivó. **0 vinos reales**: de 22 productos, 20 son `muestra: true`, uno es
`vino-de-prueba` (32 de stock, 1 foto, publicado) y otro `ve`, una prueba del dueño.
Falta que el dueño cargue su catálogo, y eso no lo hace ningún código.

| Qué | Cómo |
|---|---|
| La regla | `conPrincipal`, pura: 10 casos con `dart test`. **Mutada** con `.reversed`: falla 1 y se revirtió. Es una mutación **débil**: sólo la agarra el caso de tres fotos |
| Compila | `dart analyze lib test`: **No issues found** |
| Sin huérfanos | 10 símbolos grepeados, cada uno con call site fuera de su archivo; control negativo con uno inventado: 0. Ruta: `enrutador` → `PaginaDelVino` → `FormularioDelVino` → `SeccionDeFotos` |
| Hooks | `probar_hooks.sh` 35/35 |
| Presupuesto | 1 lectura por cambio + 1 por sesión abierta: ~150/día, **0,3 %** |
| CI | `alcance=panel`, corrida `36043832300`: `suite_dart` **244 → 254, +10 exactos** (`suite_ts` `skipped`: no se tocó lógica de `functions`) |
| El deploy | Canal → **canario discriminante** (`Usar como principal`: live 0 → 1; `permiso para subir fotos`: 1 → 0; control positivo en 1; inventado en 0) → `promover` → los 4 hashes iguales, `noindex`, `commit publicado: 1ab7bb0` |
| Que arranca | Chrome por CDP sobre live: `/entrar`, Flutter montado, **0 errores de consola**, texto leído con control positivo y negativo |

**Sin probar, y ahora ya en producción:** la transacción contra Firestore. Los tests del panel son de dominio puro
y no hay emulador en la suite del panel: lo que corre es `conPrincipal`, no
`runTransaction`. La concurrencia (otra persona sube una foto en el medio) queda
verificada por razonamiento sobre el contrato del SDK, **no por una prueba**.

### La vidriera tiene una preview cerrada, y `moverStock` ya se usó de verdad (2026-09-23)

**Desplegada y verificada**: <https://bouquet-tienda--bouquet-vinos.us-east4.hosted.app>,
en App Hosting, región `us-east4`, sin dominio, con `noindex` y `maxInstances: 1`.
El porqué está en [ADR 017](architecture/decisions/017-preview-cerrada.md). Sin
openspec, a pedido del dueño.

⚠️ **NO es la publicación de la tienda, y los gates de deploy siguen abiertos**:
no hay puerta de edad (por eso no puede ser pública), el contacto es el WhatsApp
del desarrollador, el checkout no cobra y el dominio y el tramo 4 no existen.
**"Cerrada" no significa protegida con contraseña**: quien tenga la URL la ve.

**Lo que costó, y no se repite** (ADR 017 §3): el buildpack de App Hosting toma
como raíz de la aplicación el `rootDir` y busca **ahí** el lockfile, no más
arriba, así que **un workspace de npm no se despliega**: el build muere a los 18
segundos con `fah/missing-lock-file` aunque el lockfile viaje en el zip. Se
resolvió **desplegando una copia autocontenida** (`scripts/tienda/preparar_despliegue.mjs`):
la tienda como app común, `contratos` adentro, y el lockfile **sembrado con el de
la raíz** para que lo que se despliega sea lo que se probó. La documentación de
Firebase no lo dice; se leyó el código del buildpack.

**Lo que salió de verificar** (con control negativo cada uno):

| Qué | Cómo |
|---|---|
| El rollout | API cruda: `-003` `SUCCEEDED` con el 100 %, `-001` y `-002` `FAILED`. El CLI dijo "complete" |
| `noindex` | En las cinco páginas, dos 404 y un asset |
| El catálogo | Firestore: 21 publicados, **los 21 nombres están en `/vinos`**. Se ve, renderizado por Chrome real en escritorio y en teléfono (390 px), con 0 fotos rotas |
| **`moverStock` en producción** | **Alguien repuso 32 en `vino-de-prueba` a las 00:04 UTC** (21:04 en Argentina): `0 → 32`, con su marcador y el uid de quien lo hizo, **un solo movimiento, sin duplicados**. Es lo que no se pudo verificar antes |
| Una foto real | El mismo vino tiene una foto subida desde el panel: 200 `image/webp` `immutable`, y se ve recortada sobre el papel en la ficha |

⚠️ **Y verificar destapó que la receta del gate del checkout era un falso
negativo**: `curl /pedido | grep data-checkout-simulado` da **0 con el gate
cerrado**, porque el atributo lo dibuja `ElResumen`, que sólo existe con ítems
en el carrito. Corregida en el código, en [ADR 010](architecture/decisions/010-el-checkout.md)
y en la fila del gate; la comprobación válida está en
`bash scripts/tienda/preview.sh verificar`.

⚠️ **El techo de lecturas es el riesgo de esta preview**: alguien que la martille
las 24 h lleva la cuota **compartida con el panel** al ~98 % (1.440
reconstrucciones × ~34 lecturas). La apaga
`firebase apphosting:backends:delete bouquet-tienda --project bouquet-vinos --force`.
Vigilarla el día que se comparta la URL.

> ⚠️ **"EP-05: mover el stock, desplegado y verificado por bytes — falta que el dueño lo use (2026-09-23)" se movió a
> [`changelog/_log.md`](changelog/_log.md#ep-05-mover-el-stock-desplegado-y-verificado-por-bytes-falta-que-el-dueño-lo-use-2026-09-23)
> el 2026-09-25**, al construirse EP-07 y llegar el dashboard a 6 entradas. El porqué
> de cada decisión sigue en [ADR 016](architecture/decisions/016-mover-el-stock.md). Lo
> que sigue vigente y no vive en otro lado: **`moverStock` se verificó en producción por
> uso real** (`0 → 32` en `vino-de-prueba`, un solo movimiento) y **sigue faltando que
> el dueño mire la pantalla y diga si le sirve**.

> ⚠️ **"EP-04: las fotos del panel, desplegadas — y el dueño encontró que la callable no se puede llamar (2026-09-22)" se movió a
> [`changelog/_log.md`](changelog/_log.md#ep-04-las-fotos-del-panel-desplegadas-y-el-dueño-encontró-que-la-callable-no-se-puede-llamar-2026-09-22)
> el 2026-09-24**, al construirse los pedidos de WhatsApp y llegar el dashboard a 6
> entradas. El porqué de cada decisión de EP-04 sigue en
> [ADR 015](architecture/decisions/015-fotos-del-panel.md). Lo que sigue vigente y no
> vive en otro lado: **el clasificador de packshot se midió y se REFUTÓ** (ningún
> umbral sobre el archivo distingue una foto de cámara de un packshot legítimo), así
> que el panel dibuja la foto como la va a dibujar la vidriera y deja que el operador
> mire; y **el `ACTIVE` de la API de Cloud Functions no prueba que una callable sea
> alcanzable desde el navegador**: faltaba `allUsers` como invoker y el preflight daba
> 403 sin un solo header de CORS.

> ⚠️ **"EP-03 queda cerrada: publicar, cambiar el precio y verse en la tienda" (2026-09-22) se movió a
> [`changelog/_log.md`](changelog/_log.md#ep-03-queda-cerrada-publicar-cambiar-el-precio-y-verse-en-la-tienda-2026-09-22)
> el 2026-09-24**, al construirse HU-05.4 y llegar el dashboard a 6 entradas. El porqué está en
> [ADR 014](architecture/decisions/014-publicar-un-vino.md). Lo que sigue vigente y no vive en otro
> lado: **falta que alguien publique un vino REAL y lo mire en la tienda** (los 20 son `muestra: true`),
> y eso bloquea archivar `panel-publicar-un-vino`.

> ⚠️ **"El producto se endureció, y la ficha lleva descripción" (2026-09-21) se movió a
> [`changelog/_log.md`](changelog/_log.md#el-producto-se-endureció-y-la-ficha-lleva-descripción-2026-09-21)
> el 2026-09-24**, al construirse la foto principal y llegar el dashboard a 6 entradas. El
> porqué está en [ADR 014](architecture/decisions/014-publicar-un-vino.md). Lo que sigue
> vigente y no vive en otro lado: **las reglas se midieron contra el emulador** (`matches()`
> compara la cadena entera, `size()` cuenta caracteres) y **en producción hay 0 vinos reales**:
> los 20 del seed son `muestra: true`.

> ⚠️ **"Cargar un vino: escrito, probado contra el emulador" (2026-09-18) se movió a
> [`changelog/_log.md`](changelog/_log.md#cargar-un-vino-escrito-probado-contra-el-emulador-sin-desplegar-2026-09-18)
> el 2026-09-23**, al desplegarse la preview de la vidriera y llegar el dashboard a
> 6 entradas. El porqué está en [ADR 013](architecture/decisions/013-cargar-un-vino.md).
> Lo que sigue vigente y no vive en otro lado: **las reglas se probaron contra el
> emulador, no se supusieron** (`matches()` compara la cadena entera; `size()` cuenta
> caracteres, no bytes), y la suite de reglas tenía una trampa que la regla nueva
> destapó (todas las altas usaban el mismo id, y los `assertFails` pasaban por el slug).

> ⚠️ **"El catálogo se ve y las bodegas se cargan" (2026-09-17) se movió a
> [`changelog/_log.md`](changelog/_log.md#el-catálogo-se-ve-y-las-bodegas-se-cargan-2026-09-17)
> el 2026-09-23**, al escribirse EP-05 y llegar el dashboard a 6 entradas. El
> porqué de cada decisión de EP-02 sigue en
> [ADR 012](architecture/decisions/012-el-catalogo-del-panel.md). Lo que sigue
> vigente de ella y no vive en otro lado: **`dart analyze` SÍ corre en esta
> máquina** (`flutter analyze` no), y **dart2js escapa los no-ASCII**, así que
> un canario con tilde da CERO en `main.dart.js` aunque el deploy haya llegado.

> ⚠️ **"El panel tiene puerta" (2026-09-16) se movió a
> [`changelog/_log.md`](changelog/_log.md#el-panel-tiene-puerta-entrar-sin-acceso-y-la-estructura-2026-09-16)
> el 2026-09-22**, al construirse EP-04 y llegar el dashboard a 6 entradas. El
> porqué de cada decisión de EP-01 sigue en
> [ADR 011](architecture/decisions/011-entrar-al-panel.md), incluido el NO
> REVERTIR de §6.

### Lo que quedó abierto

| Qué | Por qué | Quién |
|---|---|---|
| ~~⚠️ **La callable `procesarFoto` NO es alcanzable desde el navegador: el preflight da 403, y el panel lo muestra como error de CORS**~~ **RESUELTO el 2026-09-23, por el dueño** | Lo vio usando el panel; medido después con `curl` crudo el 2026-09-22, y el `ACTIVE` de la API de Cloud Functions **no lo veía**. `OPTIONS` con `Origin` y `Access-Control-Request-Method: POST` devolvía **403 Forbidden** de `Google Frontend`, **sin un solo header `Access-Control-Allow-*`**. **Control negativo:** una function inventada daba **404**. **El control que aisló la causa:** un `POST` anónimo devolvía **el mismo 403 HTML**, no el JSON `UNAUTHENTICATED` de la callable — el código nunca corría, lo frenaba IAM antes. Faltaba `allUsers` como `roles/run.invoker`. **No era el bucket** (medido aparte). El clasificador de permisos frenó el otorgamiento dos veces el 2026-09-23 —la segunda con autorización explícita en la conversación—, así que lo corrió **el dueño a mano**. **Verificado con los mismos tres controles:** el preflight ahora da **204** con los headers de CORS, el negativo **sigue en 404**, y el `POST` anónimo ahora da **401 JSON real** (`UNAUTHENTICATED`) en vez del HTML de IAM. Detalle completo en [ADR 015](architecture/decisions/015-fotos-del-panel.md#lo-que-falta). | el dueño + `functions` |
| ✅ **Escrito el 2026-09-23: el formulario del vino usa el espacio de escritorio con dos columnas** (`DisposicionDelFormulario`, ADR 015 §6) — reemplaza el `ConstrainedBox(maxWidth: 640)` fijo. Debajo de 900 px sigue apilado en una columna, igual que antes (celular, y Android). **Desplegado el 2026-09-23** (v0.29.0, bytes verificados con canario), **pero nadie lo miró renderizado.** | Lo vio el dueño mirándolo — CLAUDE.md: compilar, pasar tests y desplegarse son tres cosas distintas de que **alguien lo haya mirado renderizado**, y eso sigue pendiente acá. **Disparador:** que el dueño lo mire renderizado, en escritorio y en Android. Desde 2026-09-22. | el dueño + `admin-presentacion` |
| ✅ **Escrito el 2026-09-23: cargar un vino, sumarle una foto y publicarlo pasan a ser UN gesto** (ADR 015 §5) — se revirtió, sólo para `imagenes` y `publicado`, la exclusión de `AltaDeVino`/`documentoNuevo` que forzaba los tres viajes separados; `stock` y `tipo` siguen sin salir del alta, sin tocar. `SeccionDeFotos` sube con el slug todavía sin guardar (`agregarAlDocumento: false`, sin `arrayUnion` hasta confirmar); `PieDelFormulario` suma el tilde **"Publicar apenas se cargue"**, con default `true`. Medido antes de escribir: ni `procesarFoto`, ni `storage.rules`, ni `firestore.rules` pedían el documento guardado — sólo lo pedía el panel. **Desplegado el 2026-09-23** (v0.29.0, CI verde con la suite de Dart), **todavía sin verificar con el dueño cargando un vino de verdad.** El default `true` del tilde es una decisión de producto, no sólo técnica: queda para que el dueño la confirme o la cambie. | El dueño lo dijo con las palabras del que lo usa: *"no tiene sentido primero cargar el vino, para después subir la foto, para después activar"*. **Disparador:** que el dueño cargue un vino real, con foto, en un solo gesto — y confirme o cambie el default `true` del tilde. Desde 2026-09-22. | el dueño + `admin-presentacion` + `admin-datos` |
| **Falta la lista de mails de la familia** | El **dueño ya entra**: entró con Google el 2026-09-17 y `acceso.mjs dar` le puso el claim —verificado leyendo su registro, `{"rol":"admin"}`, y el listador pasó de 0 a 1—. Es la única cuenta de Auth. Para cada uno de los demás: `node scripts/acceso/acceso.mjs dar <mail>`, y que entre con Google o toque *"¿No tenés contraseña?"*. **El orden importa poco:** si entran antes de tener permiso, caen en `/sin-acceso` y con el botón *"Ya me dieron acceso"* pasan sin volver a escribir nada. **Disparador:** cuando el dueño pase los mails. Desde 2026-09-16. | el dueño |
| ~~**Entrar con Google no está verificado en live por una persona**~~ **VERIFICADO el 2026-09-17: lo hizo el dueño** | Entró con Google en live, se le creó la cuenta —`providers: google.com`, mail verificado, sin claims— y cayó en `/sin-acceso`, que es exactamente lo que el diseño dice que pase. ⚠️ **Queda un hueco chico:** eso fue **antes** de acotar la API key, así que el flujo de Google **con la restricción puesta** no está probado. Lo que sí está probado con la restricción es una llamada real a Auth desde el navegador en live y en el canal. `firebaseapp.com` está en la lista justo porque por ahí pasa el handler de Google, pero eso es un razonamiento, no una medición. **Disparador:** la próxima vez que alguien entre con Google —basta con que el dueño salga y vuelva a entrar—. Desde 2026-09-17. | el dueño |
| ~~**La API key web del panel no está restringida**~~ **RESUELTO el 2026-09-17**, y lo corrió el dueño porque el clasificador del modo auto frena tocar la key (*"Modify Shared Resources"*) | La key es pública por diseño —viaja adentro de `main.dart.js`, así que guardarla como secret no cambia nada: el navegador la necesita en claro—, pero estaba sin acotar: `browserKeyRestrictions` **vacío** y 27 servicios habilitados, `identitytoolkit` entre ellos. Ahora acepta tres hosts: el panel, `firebaseapp.com` —por donde pasa el handler de Google— y el canal `panel`. **Verificado con las dos mitades, y el antes medido:** un `POST` a `accounts:signInWithPassword` con `Referer` inventado daba **400 `INVALID_LOGIN_CREDENTIALS`** (la atendía) y ahora da **403 blocked**, mientras los tres hosts permitidos siguen dando 400, o sea que llegan. Y de punta a punta con un navegador real pidiendo el correo de contraseña desde live y desde el canal: los dos contestan el aviso, sin nada de bloqueo en consola. ⚠️ **La trampa que sólo apareció con el tercer control: un comodín en medio de una etiqueta (`bouquet-vinos--*.web.app`) la API lo ACEPTA y no matchea nada** — se guarda sin protestar y el canal seguía dando 403. Va el host literal. **Ojo con lo que esto NO es:** el `Referer` lo falsifica cualquiera con `curl -H`, así que corta abuso casual y robo de cuota, no a alguien decidido; contra el registro anticipado lo que protege es la negativa del script (ADR 011), y apagar el alta pública está descartado ahí mismo. **Deja una obligación:** un canal con otro nombre no va a poder entrar hasta que su host esté en la lista — anotado en `publicar.sh`. | el dueño |
| **Ningún change de openspec se archivó nunca** | `openspec/specs/` está **vacío** y hay **4** changes en `openspec/changes/` (`panel-entrar`, `cajas-de-seis`, `catalogo-y-carrito`, `seccion-el-oficio`), todos implementados. Sin línea base publicada, un change nuevo no tiene contra qué diferenciarse. `opsx` trae `openspec-bulk-archive-change` justo para esto, pero las skills de terceros no se commitean (`bash scripts/skills_restaurar.sh`). Archivar sólo uno inventaría una línea base que los otros tres no tienen, así que van los cuatro juntos. **Disparador:** la próxima sesión que empiece con las skills restauradas. Desde 2026-09-17. | el usuario |
| **Los tests del script de accesos no corren en CI** | Corren contra el emulador de Auth. ~~Igual que los de reglas, que tampoco están en CI~~: **los de reglas y los de las transacciones sí corren en CI desde el 2026-09-25** (job `suite_emulador`, [ADR 019 §8](architecture/decisions/019-preparar-despachar-y-cancelar.md)); éste quedó afuera porque pide el emulador de Auth. Hoy se corren a mano: `firebase emulators:exec --only auth --project demo-bouquet "node --test scripts/acceso/acceso.test.mjs"`. **Disparador:** el mismo que los de reglas, la sesión de `crearOrden`. Desde 2026-09-16. | el usuario |
| ~~⚠️ **Seis preguntas del dueño cambian el backlog del panel**~~ **RESPONDIDAS el 2026-09-16, en dos rondas** | Queda **un dato**: el **número de WhatsApp de la tienda**, que el dueño todavía no tiene y va a pasar. El botón de aviso del panel se activa sólo para quien lo tenga (HU-07.3), y es el mismo número que bloquea `/oficio` (quinto gate, más abajo). El detalle, en [`features/panel/overview.md`](features/panel/overview.md). **Disparador:** cuando el dueño lo pase, y antes de escribir los requerimientos de HU-07.3. Desde 2026-09-16. | el dueño |
| ~~⚠️ **Las reglas nuevas NO están publicadas en `bouquet-vinos`**~~ **RESUELTO el 2026-09-14:** desplegadas con `firebase deploy --only firestore:rules,storage`. Verificado **con la API de Rules**, no con el mensaje del CLI: dos releases con la marca de tiempo del deploy, y el ruleset publicado contiene `cajasSugeridas` (control negativo: una colección inventada da 0). **Las fotos dan 200 `image/webp`.** ⚠️ Al medirlo, la API devolvió **403** por falta de quota project y mi primer script lo leyó como *"ningún release"* — el modo de falla exacto contra el que avisa `CLAUDE.md`. | el dueño |
| ⚠️ **SEXTO GATE: `/pedido` está armado y NO COBRA** | `EL_CHECKOUT_NO_COBRA = true` en `features/carrito/checkout/textos.ts`, y viaja al HTML como `data-checkout-simulado`, así que se chequea con `grep` en el repo **y** con `bash scripts/tienda/preview.sh verificar` en lo desplegado (⚠️ **no** con `curl /pedido | grep`: da 0 con el gate cerrado, ver [ADR 010](architecture/decisions/010-el-checkout.md)). Se apaga **sólo** cuando existan las tres cosas: `crearOrden`, la preferencia de Mercado Pago y su webhook verificando firma. CLAUDE.md: *un "Pagar" que llegue antes que su webhook es una venta que se cobra y no se registra*. **Disparador: bloquea el deploy.** Desde 2026-09-15. | el dueño + `functions` |
| ⚠️ **`cajasSugeridas/publicas` de stage quedó VIEJO, y se ve** | El documento sembrado todavía tiene `dos-y-dos` —dos packs de 2 + dos botellas—, que desde [ADR 009 §10](architecture/decisions/009-venta-por-caja.md) no es una caja: el código la descarta y el carril de `/vinos` sirve **3** tarjetas en vez de 4, con el motivo logueado en la build. `dos-de-cada` no existe hasta que corra `node scripts/seed/seed.mjs`. **Disparador:** antes de mirar el carril de stage, y antes del primer deploy. Desde 2026-09-15. | el dueño + `tienda` |
| ⚠️ **El peso y las medidas de una caja de 2 NO están medidos** | El peso sale de `⌈n × 1,118 + 0,6⌉` —la botella la pesó el dueño; el 0,6 del embalaje está **calibrado** para reproducir los 8 kg de la caja de seis, no medido— y el ancho es una proporción de esa caja. Una caja de regalo puede ser más ancha y más chata. **Disparador:** cuando haya una en la mano, y antes de las tarifas reales. Desde 2026-09-15. | el dueño |
| ⚠️ **El glosario quedó DESACTUALIZADO en `Zona` y `Envío`** | Dice que una dirección fuera de toda zona *"no puede comprar"* y que se le avisa antes del carrito, y que el MVP es *"sólo envío a domicilio"*. Con envío a todo el país **eso ya no es cierto**: nadie queda afuera, `Zona` pasa a ser *hasta dónde repartimos nosotros*, y el texto de [`voz.md §9.3`](design/voz.md) queda sin pantalla. No se editó en este cambio a propósito: tocar el glosario adentro de una tarea de feature esconde la decisión adentro del diff de otra cosa. **Disparador:** antes de `crearOrden`, que es quien va a guardar el `Envío`. Desde 2026-09-15. | `vault` |
| **Los precios del cotizador son INVENTADOS** (y los otros dos números ya no) | (a) El **peso** dejó de ser de catálogo: el dueño pesó una botella el 2026-09-15 —**1,118 kg**, o sea 6,666 kg las seis y ~7 kg con caja y relleno—, y se declara **8 del lado seguro**; lo que queda por mirar es **dónde caen los escalones de peso del correo**, porque de eso depende si ese margen cuesta algo. (b) Los **códigos postales de Punilla** dejaron de ser peligrosos al apagarse el reparto propio: hoy sólo prellenan una localidad que el comprador corrige. (c) Los **precios** siguen siendo puro invento y no hay forma de arreglarlos sin tarifas. **Disparador: las tarifas reales del proveedor, antes del primer cobro.** Desde 2026-09-15. | el dueño + `tienda` |
| **El reparto propio en Punilla está APAGADO, y el camino está escrito entero** | `REPARTIMOS_NOSOTROS = false` en `server/envios.ts`, por decisión del dueño (*"de momento no lo vamos a hacer nosotros"*). Prenderlo es una línea, pero **antes** hay que verificar los códigos postales uno por uno con control negativo: con el reparto prendido, un CP mal puesto no falla ruidosamente. **Disparador:** cuando el dueño decida repartir él. Desde 2026-09-15. | el dueño |
| ⚠️ **Nadie confirmó que se pueda despachar alcohol, ni cuánto cobra Mercado Pago** | Ningún correo prohíbe el vino por escrito **y ninguno lo permite por escrito**: es zona gris y se resuelve preguntándole a Envíopack por contacto comercial, no leyendo más documentación. Y la comisión de Mercado Pago no se pudo verificar: las páginas oficiales de costos devuelven **403** y las fuentes de terceros se contradicen entre 2,99 % y 6,99 % + IVA — hay que mirarlo en el panel de la cuenta real. Los dos están en [`proveedores/`](architecture/proveedores/). **Disparador:** antes de contratar y antes de fijar precios. Desde 2026-09-15. | el dueño |
| **El umbral de envío sin cargo no existe, y el lugar donde va ya está** | El dueño lo dejó abierto: *"no sé desde qué monto me conviene"*. Cuando haya tarifas reales, el renglón es el de la entrega más un empujón arriba del total (*"te faltan $X para que el envío salga sin cargo"*). La cuenta ya soporta `precio: 0` y lo dice con palabras, no con un cero. **Disparador:** cuando existan las tarifas del proveedor. Desde 2026-09-15. | el dueño |
| **El comprobante vive en una URL que todavía no existe** | [ADR 010](architecture/decisions/010-el-checkout.md) §6 decide que el comprobante **no va por mail**: va a `/pedido/<numero>` y el link viaja por WhatsApp. Esa ruta no está escrita — hoy no hay número de orden que mostrar. **Disparador:** la sesión de `crearOrden`. Desde 2026-09-15. | `tienda` |
| ⚠️ **`server-only-guard` ofrece una salida que su propia regla no permite** | Su mensaje dice *"Para tipos usá `import type`"*, pero su expresión regular (`import\s+.*['\"]@/server/`) **también bloquea un `import type`**. No molestó en el checkout —la Server Action llega por props, que es mejor—, pero el hook promete algo que no cumple, y eso es exactamente lo que `CLAUDE.md` llama un verde que dice algo falso. Arreglarlo pide un caso nuevo en `probar_hooks.sh`, con su par positivo y negativo. **Disparador:** la próxima vez que alguien necesite un tipo de `server/` en un componente cliente. Desde 2026-09-15. | el usuario |
| **En teléfono, el total del checkout queda abajo de todo el formulario** | La maqueta *el remito* tenía una barra fija con el total y el botón; no se construyó porque hoy el botón está apagado y una barra fija con un botón que no se puede apretar es ruido pegado a la pantalla. **Disparador:** el día que se apague `EL_CHECKOUT_NO_COBRA`. Desde 2026-09-15. | `tienda` |
| ⚠️ **El catálogo real no se despliega sin el tramo 4** | Hasta que Cloudflare cachee con purga por tag, las lecturas escalan con las visitas: con 200 vinos, 115 % de la cuota a 250 visitas/día (ADR 008). Y el tramo 4 tiene que invalidar también la caché de Next, que sirve una página vencida hasta 360 s. Y decidir si la home entra a la purga: hoy envejece hasta el próximo deploy (ADR 008 §7). **Disparador: antes del deploy público.** Desde 2026-09-11. | `functions` + `tienda` |
| **NUEVE hallazgos de `revisor-pagos` para antes de `crearOrden`** | Recrear un producto se saltea la inmutabilidad; precio 0; compuesto sin componentes; `PedidoDeCompra` sin validador; carrito sin tope de líneas; la caché de Next contra la purga; los tests de reglas fuera de CI; reglas y validador que no dicen lo mismo. **El noveno (2026-09-14):** rechazar todo pedido que no sume un múltiplo de `BOTELLAS_POR_CAJA` botellas, recalculado en el servidor ([ADR 009](architecture/decisions/009-venta-por-caja.md)). La tabla está en ADR 008. **Disparador: la sesión de `crearOrden`.** Desde 2026-09-11. | `functions` + `reglas` |
| **El carril de cajas no se miró en un teléfono de verdad** | Se miró a 390 px **emulados** por CDP, que es lo que esta máquina puede: el Chrome headless no baja de 504 px sin emulación. La pista scrollea de lado dentro de su contenedor y eso se juzga con el dedo, no con `scrollWidth`. **Disparador:** la próxima vez que el dueño abra `/vinos` en su teléfono. Desde 2026-09-14. | el dueño |
| ⚠️ **El canal de contacto de `/oficio` es PROVISORIO — quinto gate de deploy** | `EL_CONTACTO_ES_PROVISORIO = true` en `features/oficio/oficio.ts`: el WhatsApp publicado (`+54 9 3548 60-0375`) es el **del desarrollador** y `hola@bouquet.com.ar` no resuelve porque no hay dominio. La constante viaja al HTML como `data-contacto-provisorio`, así que se chequea con `grep` en el repo **y** con `curl` en producción. **Disparador: bloquea el deploy.** Cuando el dueño entregue el WhatsApp real y el dominio: bajar la constante, volver a correr las rutas y el `grep -c` del HTML, y recién ahí desplegar `tienda` — preguntándose antes **qué más se mergeó**, porque el deploy de front reconstruye desde el HEAD pusheado. Desde 2026-09-09. | el dueño + `tienda` |
| ⚠️ **El numeral hueco del tramo `III` lo tiene que mirar el dueño** | Es la tesis de la página dicha con tipografía —"firmamos dos"— y el riesgo lo marcó él: que se lea como que algo se rompió en vez de como una decisión. Yo lo miré renderizado y se lee como decisión (contorno parejo, más el filete al 50 % y el nombre atenuado acompañando), pero la palabra es suya. **Plan B ya escrito** en el design: numeral macizo, nombre en cursiva y filete al 50 %. **Disparador:** abrir `/oficio` y mirarlo. Desde 2026-09-09. | el dueño |
| ⚠️ **La vidriera NO tiene sitemap, ninguna ruta** | Lo destapó `cazador-de-puertas` cerrando `/oficio`: no existe `sitemap.ts`, `sitemap.xml` ni `robots.ts` en todo el repo, así que hoy la única cobertura de descubribilidad es la barra de navegación. No se escribió acá a propósito: un `sitemap.ts` necesita una URL base y **todavía no hay dominio**, así que saldría apuntando a un host inventado. **Disparador: el día que exista dominio** — el mismo día que se puede medir la purga de Cloudflare y que se resuelve el mail del mostrador. Desde 2026-09-09. | el dueño + `tienda` |
| ⚠️ **`frontera-features.sh` no ve los imports RELATIVOS entre features** | Su regla 2 grepea sólo `from '@/features/`. El **mismo** import escrito `from '../landing/seleccion'` **pasa**, medido con los dos controles uno al lado del otro. ADR 006 regla 3 queda a medias: la mide un hook que se esquiva con una ruta relativa. No se tocó en este cambio para no meter una modificación de enforcement adentro de una tarea de feature. **Disparador:** antes de la próxima feature nueva de la vidriera, o el día que alguien escriba un import relativo entre features. Desde 2026-09-09. | el usuario |
| ⚠️ **`call-site-guard` cuenta los sourcemaps del build como call sites** | Grepea `apps/ packages/ functions/ scripts/` enteros, y ahí adentro están `node_modules` y `.next`. Los `*.js.map` **embeben el fuente**, así que un símbolo que no abre nadie aparece "usado" en cuanto corrió un `next build`: dio verde con dos exports huérfanos que un grep acotado a `src/` sí encontró. Es la misma familia que `generar_verdad.mjs` contando comentarios. Y es O(símbolos × repo): sobre un archivo con 8 exports tarda **más de dos minutos**, así que como PostToolUse frena la escritura. **Disparador:** la próxima vez que el hook tarde o que un huérfano pase. Desde 2026-09-09. | el usuario |
| ⚠️ **La home NO tiene puerta de edad, y es la única pieza legal obligatoria** | [ARQUITECTURA §9.5](../../ARQUITECTURA.md#95-alcohol-y-edad) la exige, y es requisito de **arquitectura**: no se va con la composición que se descarta. Las composiciones 4 y 6 sí la construyeron (`PuertaDeEdad.tsx` + `puerta.css`, en `home-parallax-c` y `-d`); **la que ganó se escribió antes de que ese requisito bajara a código**. ⚠️ No se copia y pega: su diseño es decisión de composición y el de `-d` está dibujado con el cartucho del libro túnel. **Disparador: bloquea el deploy.** Desde 2026-09-08. | el dueño + `tienda` |
| **La selección de la home la elige una regla, no el dueño** | `elegirSeleccion` toma seis por ventas, sin agotados ni cajas y con los tres colores. La escena dice "los elegimos de a uno", y eso pide un dato que el modelo no tiene: que el dueño marque cuáles, con su campo en contratos, reglas y panel. **Disparador:** cuando el dueño cargue su catálogo real. Desde 2026-09-11. | el dueño + `contratos` |
| ~~**Las SEIS tarjetas de la home apuntan a fichas que no existen**~~ **Resuelto el 2026-09-11:** salen del catálogo y sus seis fichas dan 200 (ADR 008 §7). | ~~`/vinos` no existe y la home lo apunta dos veces~~ — **resuelto el 2026-09-09**: `/vinos` existe y los dos CTA duros dan 200. Pero contando los `href` del HTML servido aparecieron **seis más**: `/vinos/muestra-01` … `-06`, las tarjetas de `EscenaSeleccion`, todas **404**. El vault decía "dos" y eran **ocho**. No se arreglan con un placeholder: son la ficha, paso 5 de ARQUITECTURA §12, y hacer que `/vinos/<cualquier-cosa>` devuelva 200 es peor que un 404. **Actualizado el 2026-09-11:** `/vinos/[slug]` ya existe, y un slug que no está da 404, que es lo correcto; lo que falta es que las tarjetas apunten a slugs reales. Y sus datos son inventados mientras `LA_SELECCION_ES_DE_MUESTRA` siga en `true`. **Disparador: bloquea el deploy.** Desde 2026-09-09. | el dueño + `tienda` |
| ⚠️ **Los 8 assets están commiteados y no tienen `LICENCIAS.md`** | `ambiente`, `botella`, `cava-h/v`, `mesa-h/v`, `rack-h/v`. La única tabla de licencias verificada que existió es la de los **17 assets de `home-parallax-b`**, y **no cubre a éstos**. De esta misma tanda salió la foto con marca de agua `Unsplash+` tileada, que se descubrió **abriendo el PNG**, no leyendo metadatos. `scripts/assets/traer_landing.py` es la herramienta. **Disparador: antes del deploy.** Desde 2026-09-08. | el dueño |
| **391 KB de `woff2` en la primera pantalla, y son de esta composición** | `parallax.md §8` fija **450 KB** para la primera pantalla en móvil: es el único presupuesto que paga el comprador, y arranca con el **87 % gastado antes de la primera imagen**. Salen de `layout.tsx` (Fraunces con `SOFT`+`WONK`+`opsz`, Newsreader roman e itálica con `opsz`). ⚠️ **Medido el 2026-09-08: el arreglo conocido NO sirve acá.** La composición 6 los bajó a **138 KB** sacando `SOFT` y `opsz`, y ésta usa las dos cosas (`font-variation-settings: 'SOFT' 22` en `sistema.css`, itálica de Newsreader en 4 lugares): sacarlos **cambia el dibujo de la página que se eligió mirando**. La palanca es del dueño. **Disparador: antes del deploy.** Desde 2026-09-08. | el dueño |
| **Los hooks no están vivos todavía** | `.claude/` no existía cuando arrancó la sesión, así que el watcher de settings no lo observa. Hay que abrir `/hooks` una vez, o reiniciar. ~~**Verificado: un Write a `packages/contratos/src/` NO fue bloqueado.**~~ **Resuelto el 2026-09-11:** `vault-precheck` frenó dos escrituras en la sesión del catálogo, así que los hooks corren. | el usuario |
| **`suite_ts` y `suite_dart` nunca corrieron** | Un push a `main` dispara `alcance=rapido`, que **no corre tests**: las dos salen `skipped`. Las suites de `packages/contratos` jamás se ejecutaron en CI. **Disparador:** antes del próximo cambio de lógica, `gh workflow run ci.yml -f alcance=tests`. Desde 2026-09-03. | el usuario |
| **Los signos de `parallax.md §4.1` contradicen a `escenas.md §5`** | La aritmética dice que un plano lento lleva amplitud **positiva**; el snippet del informe la escribe negativa. **Los dos no pueden tener razón, y no lo midió nadie.** No se editó ningún documento a propósito. **Disparador:** scrollear la maqueta con el dedo en un teléfono. Desde 2026-09-03. | el usuario |
| **Hay dos landings y sólo se mergea una** | [`escenas.md`](design/escenas.md) y [`landing-alternativa.md`](design/landing-alternativa.md) resuelven la misma pantalla de dos formas incompatibles. La segunda está construida en `home-parallax`; la primera no está construida. **Disparador:** mirar la rama y elegir. La que pierda se archiva en `changelog/`. Desde 2026-09-04. | el usuario |
| **`generar_verdad.mjs` cuenta comentarios como call sites** | Busca con `new RegExp('\b' + nombre + '\b')` sobre el fuente entero, comentarios incluidos. La palabra `CERO` en un comentario bajó los símbolos "sin puerta" de 16 a 15 **sin que nadie abriera nada**. Se esquivó reformulando el comentario, que es un parche. **Disparador:** la próxima vez que ese número se mueva sin causa. Desde 2026-09-04. | — |
| **El contraste del filete del cartucho no está medido** | `direccion.md §2.1` calcula dorado **puro** sobre tinta en 8,80:1, pero el filete se dibuja al 72 % y al 28 %. Si el píxel renderizado da < 3:1, el cartucho deja de cumplir la función estructural que lo justifica y `escenas.md §2.3` se cae. **Disparador:** junto con `tokens.md`. Desde 2026-09-03. | — |

---

## Decisiones vigentes

| # | Decisión | ADR |
|---|---|---|
| 001 | Vidriera Next.js · panel Flutter en Firebase Hosting · backend Firebase | [001](architecture/decisions/001-stack.md) |
| 002 | La Orden tiene **dos ejes** de estado (pago y entrega), no uno | [002](architecture/decisions/002-estados-de-orden.md) |
| 003 | Proveedor de pagos **diferido**; el contrato del webhook está escrito | [003](architecture/decisions/003-pagos.md) |
| 004 | Frescura por invalidación on-demand · filtrado del catálogo **en memoria** | [004](architecture/decisions/004-frescura-y-lecturas.md) |
| 005 | La vidriera va a **Firebase App Hosting detrás de Cloudflare**; la frescura la da la **purga por tag**, no el ISR | [005](architecture/decisions/005-hosting-vidriera.md) |
| 006 | La vidriera se ordena por **feature**, y `shared/` tiene **cinco reglas** contra el cajón de sastre | [006](architecture/decisions/006-estructura-de-la-tienda.md) |
| 007 | La sección se llama **El oficio**, cubre tres tramos, y el contacto es su cierre | [007](architecture/decisions/007-seccion-el-oficio.md) |
| 008 | El **stock** lo escribe sólo el servidor, en unidades de venta; la vidriera lee **una proyección** por minuto, y el carrito vive en `localStorage` | [008](architecture/decisions/008-catalogo-stock-y-carrito.md) |
| 009 | La botella **suelta** se vende sólo de a 6 — lo que viene en su propia caja **viaja solo** y no cuenta (§10); una caja que ofrece el vendedor **no es un producto**, es un carrito pre-armado | [009](architecture/decisions/009-venta-por-caja.md) |
| 010 | El **código postal** decide cómo viaja el pedido —nadie queda fuera de zona—; se cobra con **Mercado Pago Checkout Pro** y el comprobante **no va por mail** | [010](architecture/decisions/010-el-checkout.md) |
| 011 | Al panel se entra con mail o Google; **las cuentas las crea un script, sin contraseña**, que se niega a habilitar una cuenta sin el mail verificado; el permiso viaja en el token, y se publica **lo que compiló CI** | [011](architecture/decisions/011-entrar-al-panel.md) |
| 018 | Un pedido de WhatsApp se carga por **una callable del panel** que fija el origen; su cobro es **`por_fuera`** (terminal); el documento es su propio marcador; **cada venta deja su movimiento** | [018](architecture/decisions/018-pedidos-de-whatsapp.md) |

---

## Lo que está pendiente y por qué

Cada pendiente lleva **fecha** y **disparador**. §2.9: una nota escrita en el
momento T describe el estado en T, y nadie tiene el trabajo de volver en T+1 —
por eso los "pendiente de deploy" mienten por construcción.

La lista completa está en
[ARQUITECTURA §11](../../ARQUITECTURA.md#11-lo-que-queda-abierto-con-su-disparador).
Los que bloquean algo:

| Pendiente | Disparador | Desde |
|---|---|---|
| Proveedor de pagos | Cuando el dueño quiera cobrar online | 2026-09-01 |
| Requisitos legales de venta de alcohol online | Antes de la primera venta real | 2026-09-01 |
| Deploy desde tag en vez de rama | Antes del primer deploy que incluya cobro | 2026-09-01 |
| **Medir la purga de Cloudflare** — [ADR 005](architecture/decisions/005-hosting-vidriera.md) la razona, no la midió | El día que exista dominio | 2026-09-03 |
| **Licencia de las imágenes de la landing** | Antes de publicar el dominio | 2026-09-03 |
| ⚠️ **La venta por caja Y AHORA EL CHECKOUT viajan de POLIZÓN**: están commiteados y **no desplegados**. Seis gates siguen abiertos — el sexto es `EL_CHECKOUT_NO_COBRA`, arriba — más puerta de edad, contacto provisorio, licencias de assets, 391 KB de fuentes y el tramo 4 de Cloudflare. El día que se despliegue `tienda` **se publica también esto**, porque el deploy de front reconstruye desde el HEAD pusheado, no desde el cambio de ese día. Antes de publicar: correr el seed de `cajasSugeridas/publicas` en el proyecto que corresponda —sin ese documento el carril no se renderiza, que es el modo de falla silencioso— y verificar con `curl` el aviso y el carril, con control positivo y negativo | El primer deploy de `tienda`, sea por el motivo que sea | 2026-09-14 |
| **HU-04.2 — ordenar las fotos que NO son la principal.** Elegir la principal se construyó el 2026-09-24 ([ADR 015 §7](architecture/decisions/015-fotos-del-panel.md)); la vidriera lee sólo `imagenes[0]`, así que ordenar el resto no cambia nada visible | El día que la ficha muestre más de una foto | 2026-09-22 |
| **El recorte de fondo de una foto de cámara**, con un modelo real — el clasificador por umbral se midió y se refutó (ADR 015 §2) | Que la previsualización resulte insuficiente, mirándola | 2026-09-22 |
| **Los crudos huérfanos en Storage** si `procesarFoto` falla a mitad de camino: no son alcanzables y no rompen nada. Entre el 2026-09-22 y el 2026-09-23 se produjo uno en CADA intento de subida, mientras el preflight de la callable daba 403 — **RESUELTO el CORS el 2026-09-23** ([ADR 015](architecture/decisions/015-fotos-del-panel.md)), vuelve a ser el caso raro original | Cuando pesen, y hay que barrer los que deje un fallo a mitad de camino | 2026-09-22 |
| ⚠️ **El color del papel de la previsualización está copiado entre el panel (Dart, `Tokens.papelVentana`) y la vidriera (CSS, `--papel-ventana`)** — puede desincronizarse, sin nada automático que lo detecte | La próxima vez que alguien toque uno de los dos sistemas de diseño | 2026-09-22 |
| **4.3 — probar `procesarFoto` en producción con un usuario real, bloqueado por el clasificador — pero el 2026-09-23 alguien subió una foto desde el panel a `vino-de-prueba` y se sirve (200 `image/webp`), así que la callable anda en producción; queda la parte de 10.1 de mirarla en la tienda con un vino de verdad** (otorgar `iam.serviceAccountTokenCreator`, aunque temporal y reversible, es "Permission Grant") | Que el usuario autorice el rol temporal, o que el dueño suba una foto real (10.1) — lo que pase primero | 2026-09-22 |
| ⚠️ **`corregir` pisa lo vendido y todavía no despachado** ([ADR 016](architecture/decisions/016-mover-el-stock.md), hallazgo 1): con 2 botellas vendidas sin despachar, el panel muestra 8, el operador cuenta 10 en la estantería y `visto` coincide — quedan 10 y se venden 2 que no existen. Hoy no se puede disparar (no hay órdenes). **Bloquea `crearOrden`**: la hoja tiene que mostrar *"N vendidas sin despachar"* | **Disparador: bloquea el deploy de `crearOrden`.** | 2026-09-23 |
| ⚠️ **Tramo 4 y `moverStock`**: cada movimiento va a disparar la purga de la vidriera, y si cambia el balde de un vino publicado son **232 lecturas** —no las ~20 de ARQUITECTURA §6.3—; con 200 vinos publicados, hasta el 93 % de la cuota. **Cargar el stock ANTES de publicar lo evita** ([ADR 016](architecture/decisions/016-mover-el-stock.md)) | Cuando se escriba el tramo 4 | 2026-09-23 |
| **Las suites de emulador y de reglas no corren en CI, y hoy son tres**: `moverStock` (19 casos), `crearOrdenDelPanel` (27) y las reglas de `productos` y `ordenes` (83) (hallazgo 8; agrava el 7 de ADR 008). Una de ellas protege plata. ⚠️ **Se corren EN SERIE**: comparten emulador y con dos en paralelo fallaron 8 casos ajenos. **Disparador:** la sesión de `crearOrden` de la vidriera. Desde 2026-09-23. | el usuario |
| **El tope de 5.000 unidades por vino** es una decisión mía, no del dueño ([ADR 016](architecture/decisions/016-mover-el-stock.md) §1) | Que el dueño lo confirme, o el primer vino real que se le acerque | 2026-09-23 |
| **`/favicon.ico` da 404 en la vidriera** (único error de consola de la preview): la tienda no tiene favicon | Antes de publicar de verdad | 2026-09-23 |
| ⚠️ **La cuenta de servicio de la preview tiene `firebase.sdkAdminServiceAgent`**, que incluye escritura y el CLI re-otorga en cada deploy ([ADR 017](architecture/decisions/017-preview-cerrada.md) §6). La vidriera sólo lee | **Antes de publicar de verdad**: una cuenta dedicada con `roles/datastore.viewer` | 2026-09-23 |
| **Basic auth en la preview**, que cierra de verdad el hueco de que no hay puerta de edad | Si la URL se va a compartir fuera de la familia | 2026-09-23 |
| ⚠️ **EP-07: despachar y cancelar un pedido.** Sin ella los pedidos se acumulan en `sin_preparar` (ADR 018 §10): la bandeja cuesta 25 lecturas por apertura desde el segundo día, el aviso de stock de la hoja de corrección no es fiable, y un pedido mal cargado no sale. **Lo que sigue** | **Bloquea que el hito 2 sirva.** Empezar por HU-07.6 (cancelar, Workflow D) y HU-07.1/07.2 | 2026-09-24 |
| **Nadie llamó a `crearOrdenDelPanel` como usuario real** ni miró el panel renderizado (ADR 018, *Lo que NO se verificó*) | La primera carga real del dueño; y que la mire con sus ojos, en escritorio y en el teléfono | 2026-09-24 |
| **¿Un pedido de WhatsApp puede ser de un vino que la tienda no muestra?** Se decidió que sí (ADR 018 §5) y el selector lo marca *«no está en la tienda»*; contradice ADR 014, donde despublicar es sacar de la venta | Que el dueño lo confirme o lo cambie (es una línea) | 2026-09-24 |
| **`productoIds[]` en la Orden**, para contar exactas las vendidas sin despachar. Sin despacho, los 50 pedidos del tope se llenan en una semana | Más de 50 pedidos abiertos, o un conteo que el aviso no explique. La salida de fondo es EP-07 | 2026-09-24 |
| **Cada venta escribe `productos.stock`**: con el tramo 4, una venta que cambie el balde de un vino publicado costará 232 lecturas | Cuando se escriba el tramo 4 | 2026-09-24 |

---

## Antes de creerle a este archivo

- **Un job verde no prueba que compiló; el artifact sí.**
- **Un `Deploy: success` no prueba que publicó; la lista de jobs sí.**
- **Antes de creer que una feature existe, grepeá quién la abre**, no si está
  escrita. Pasó cuatro veces en seis meses en el proyecto anterior.
- **Ante cualquier "¿esto está desplegado?", auditá producción**, no este
  archivo.
