# Changelog del estado — bouquet

> Lo que salió de [`_index.md`](../_index.md) por el tope de 5 entradas. No se
> borra: se mueve. Un dashboard que no entra en una pantalla dejó de ser un
> dashboard, pero el historial sigue valiendo para entender por qué algo está
> como está.
>
> Orden: **lo más nuevo arriba**.

---

## Salió el 2026-09-17, al entrar el catálogo y las bodegas del panel

Sexta entrada. **Salió ésta y no la de los tres paquetes**, por el mismo
criterio de siempre: aquélla dice dónde vive Firestore y que esa ubicación no
se cambia nunca. Las decisiones de ésta viven enteras en
[ADR 009](../architecture/decisions/009-venta-por-caja.md), y la regla de las
seis botellas sigue citada en el mapa del panel —EP-10 la exceptúa para las
ventas por WhatsApp—, así que no se pierde el hilo.

### El vino se vende de a 6, y hay cajas armadas (2026-09-14)

**Nace la venta por caja.** El carrito tiene que sumar un múltiplo de
`BOTELLAS_POR_CAJA` botellas para poder cobrarse, el aviso se dice **antes de
agregar** —en el listado y en la ficha, sin JavaScript—, y `/vinos` estrena un
carril de **cajas armadas** que el vendedor ofrece. El porqué, en
[ADR 009](../architecture/decisions/009-venta-por-caja.md).

⚠️ **LA REGLA TIENE UN LÍMITE DESDE EL 2026-09-15, y lo puso el dueño:** *"los
vinos que vienen en cajas se venden sueltos, tienen su propio packaging así que
pueden viajar solos: no cuentan para la caja de 6."* La cuenta sigue siendo en
botellas, pero **sólo sobre las sueltas** ([ADR 009
§10](../architecture/decisions/009-venta-por-caja.md)). Cambia tres cosas que antes
eran al revés: un pedido de **una sola caja de 2 se puede cobrar**; 4 sueltas +
un pack son **6 botellas y NO se pueden cobrar**; y una **caja armada** es de
seis botellas sueltas, así que `dos-y-dos` —dos packs + dos botellas— salió del
catálogo de muestra y entró `dos-de-cada`.

⚠️ **La mitad del cambio es el DESPACHO, y ahí había plata.** Si el pack viaja
solo, viaja en **su propio bulto**: seis botellas en tres packs cotizaban
`ceil(6/6) = 1` bulto —se le pide uno al correo y se le entregan tres— y 4
sueltas + 1 pack cotizaban una caja de 8 kg cuando son 2 bultos y **11 kg**.
`bultosDelPedido` recibe ahora la carga separada, y el peso por bulto sale de la
botella medida: `⌈n × 1,118 + 0,6⌉`, que con seis reproduce los 8 kg que ya se
declaraban.

**Y el cotizador simulado cobraba por cantidad de bultos**, con un comentario
arriba que decía *"un correo cobra por escalón de peso"*: funcionaba de
casualidad mientras todos los bultos pesaban 8 kg, y con bultos de 3 kg un pack
salía **igual** que una caja llena. Lo destapó un caso nuevo, no una lectura.

**Verificado el 2026-09-15 sobre `next build` + `next start` contra stage, con
el carrito sembrado en `localStorage` y las dos pantallas MIRADAS:**

| Qué | Cómo |
|---|---|
| La ficha de un pack ya no promete las seis | `curl` a las dos fichas: en la del pack, `Se vende por caja` = **0** y `Viaja sola` = **2**; en la de un vino suelto, al revés (**2** y **0**). Positivo y negativo sobre el mismo par de páginas |
| El listado dice la excepción | `/vinos`: `viajan solas` = **2** (DOM + payload RSC), `Viaja sola` = **0** — el rótulo del pack no se filtró a la cabecera |
| El pedido de un solo pack **se puede comprar** | Carrito de una caja de 2: la barra dice **2**, no hay bloque de caja, y aparece `TERMINAR LA COMPRA`. Antes esa compra no existía |
| 4 sueltas + 1 pack **no** se puede cobrar | Mismo carrito: `4 de 6`, sin botón, y el checkout dice *"Las botellas sueltas viajan de a seis"* |
| El despacho cambió de verdad | El resumen dice **`Viaja en 2 cajas · 11 kg`** (era 1 caja · 8 kg), y con un solo pack **`una caja · 3 kg`** |
| La placa no engordó la ficha | El mostrador pesa **64,97 px** con placa, idéntico en los dos mensajes. Y el `185,53 px (22,0 %)` de un vino suelto reproduce el 186 del §9 |
| La home no se volvió ISR | `○ /` **sin** revalidate, con `/vinos`, `/carrito` y `/pedido` en `1m` de control. El §10 suma **cero** lecturas |
| El carril degrada como se prometió | La build loguea `descartada … 4 entradas para una caja de 6` y el carril sirve **3** cajas contra el documento viejo de stage: la caja desaparece, no miente |
| Tests y tipos | **156** de contratos (eran 143) + **34** de la tienda (eran 30); `tsc` 0 en los dos |
| El seed | Las 4 cajas del catálogo pasan forma y composición, con **dos controles negativos**: la caja vieja se rechaza por forma y una con un pack adentro, por composición |

⚠️ **La regla se dice MUCHO más fuerte desde el 2026-09-15, y lo pidió el
dueño:** *"está muy tenue para ser la regla base de la transacción."* Salía como
un párrafo al cuerpo de la bajada en `/vinos` y como la línea más chica del
mostrador de la ficha —debajo del precio **y** del botón—, mientras `/carrito`
gritaba un total de 2,5 rem que no se podía cobrar y susurraba por qué en 1 rem.
Ahora el número es una **cifra** de 57 px adentro del anillo del cartucho
(`ReglaDeLaCaja`, dos variantes), y en la ficha vive **entre** el monto y el
botón. En el teléfono se cae la invitación y no la regla: el mostrador es
sticky, y con la nota puesta se comía el **26,4 %** de la pantalla contra el
**22 %** sin ella. Sigue sin costar una lectura: es presentación, no datos.

⚠️ **Y había un cuarto lugar que ningún documento contaba: el checkout.** Lo
encontró `cazador-de-puertas`. *"El vino viaja de a seis"* salía por
`.resumen__impedimento` en `tinta-3` —el **piso** de texto legible— en itálica,
debajo de un `Ir a pagar` muerto: lo único que explica por qué el botón no anda,
dicho en el tono más bajo de la paleta. También subió de peso. El detalle y las
alternativas descartadas, en
[ADR 009 §9](../architecture/decisions/009-venta-por-caja.md).

**Una caja armada NO es un producto.** Es una lista de `productoId` que llena el
carrito; no tiene precio propio ni stock propio, porque **no hay descuento**. El
diseño cambió de forma dos veces en el brainstorm y las dos versiones
descartadas están en el ADR — incluida la del `compuesto` con `componentes[]`,
que arrastraba media docena de piezas.

⚠️ **El carrito subió a `version: 2` y guarda `botellas` por línea.** Es la única
excepción a "el carrito no guarda nada del producto", y está razonada:
`presentacion` es inmutable por regla, así que no es un snapshot que envejece.
Sin ese campo el contador de la barra mostraría **3 donde hay 6**. Los carritos
`version: 1` se descartan — se cambió con la tienda sin desplegar, o sea sin un
solo carrito real.

⚠️ **Siete cosas aparecieron midiendo, y tres son transferibles:**

| Instrumento | Cómo mintió |
|---|---|
| Mi script de la API de Rules | Un **403** por falta de quota project se leyó como *"ningún release"*. Una lista vacía por error de lectura confirma cualquier cosa |
| `next build \| head` | El pipe cerrado le manda **SIGPIPE** a la build y la corta: la página quedó pidiendo un CSS que daba **404** y el arreglo "no aparecía" |
| Un test de `carrito.test.ts` | Usaba `version: 1` literal para probar cantidades inválidas. Con la versión nueva lo rechazaba la **versión**, no la cantidad: habría pasado por el motivo equivocado |

Y **el defecto más caro apareció abriendo el PNG**, sexta vez en este proyecto:
**todos los botones de la vidriera tenían cuatro triangulitos grises en las
esquinas**. `<button>` trae `background-color` de sistema y `appearance: auto`, y
`.boton` nunca los reseteaba porque sus dos capas son pseudo-elementos. Le
pasaba al `Agregar` de cada vino **desde que existe**: a 30 px no se nota, a 200
sí. Arreglado en `shared/ui`, medido antes y después.

**Verificado sobre `next build` + `next start` contra stage:**

| Qué | Cómo |
|---|---|
| La home no se volvió ISR | `○ /` **sin revalidate** en la tabla del build, con `/vinos` en `1m` como control. Es la trampa de `unstable_cache` que el ADR 008 documenta |
| Las lecturas | **33** medidas contra stage (20 + 11 + 1 + 1); control sin carril: **32**. +0,5 puntos de cuota en el peor renglón |
| El aviso, sin JavaScript | `/vinos` y las dos fichas dan **2** (DOM + payload RSC); `/oficio` y `/` dan **0**; un slug inventado, **404**. El canario se verificó nuevo con `git grep` en `HEAD` **antes** de usarlo |
| El carril | 4 tarjetas, 1 lugar marcado. Sin el documento sembrado **no se renderiza** |
| Sin overflow | `scrollWidth = clientWidth` a 1440 y 390; la pista scrollea **dentro** de su contenedor (1131 sobre 358) |
| Las reglas | **26** casos contra el emulador (eran 24), con control positivo |
| Tests y tipos | **121** de contratos (eran 65) + **21** de la tienda; `tsc` 0 en los dos; arnés 35/35; 183 enlaces. En CI, sobre el HEAD pusheado: 121 + 21, 0 fallas |
| El seed | Dos corridas, verificado por REST: 4 cajas, control negativo **404** |
| Mirado | 1440 y 390 px emulados, con los datos reales de stage |

**`voz` curó el copy** y de paso encontró una cadena que nadie abría (`vaDeA`):
se borró.

---

## Salió el 2026-09-16, al entrar la puerta del panel

Sexta entrada otra vez, el mismo día. **Salió ésta y no la de los tres
paquetes**, por el mismo criterio: aquélla dice dónde vive Firestore y que esa
ubicación no se cambia nunca. Las decisiones de ésta viven enteras en
[ADR 008](../architecture/decisions/008-catalogo-stock-y-carrito.md), y sus
pendientes —las fotos, el tramo 4, los hallazgos de `revisor-pagos`— siguen en
la tabla de abiertos de `_index.md`.

### El catálogo, la ficha y el carrito, en stage y sin cobrar (2026-09-11)

**Nacen `/vinos`, `/vinos/[slug]` y `/carrito`** sobre 20 vinos argentinos de
muestra en `bouquet-vinos` (stage), con las fotos en Storage. El modelo de stock
quedó hecho para no migrarlo cuando lleguen `crearOrden` y las cajas: `tipo`
inmutable, `stock` sólo del servidor y en unidades de venta, y la caja de 2 como
producto propio. El porqué, en
[ADR 008](../architecture/decisions/008-catalogo-stock-y-carrito.md); los tokens del
papel, en [`tokens.md`](../design/tokens.md), que por fin existe.

La forma la eligió el dueño entre **dos maquetas navegables** con los datos de
stage: ganó **mostrador**, "por mucho". La vidriera se aparta de ella en un solo
punto, y medido: las cifras.

⚠️ **Cuatro cosas que ningún documento sabía, y aparecieron midiendo:**

1. **La Libre Franklin de Google no tiene cifras tabulares.** "1111" y "8888"
   dan 74,41 y 106,89 px con `tabular-nums`, igual que sin. Se pasó a Archivo,
   que da 90,89 y 90,89. El control proporcional al lado es lo que prueba que la
   medición distingue.
2. **El lockfile estaba roto.** La `@google-cloud/firestore` de `firebase-admin`
   pide `@opentelemetry/api` y el lock no la tenía: `npm install` decía "up to
   date" y el cliente de Firestore no cargaba. Se declaró explícita en la tienda.
3. **`--window-size=390` en Chrome headless da un viewport de 504.** Las
   capturas "de teléfono" salían cortadas a la derecha y parecían overflow. Las
   de verdad van por CDP con emulación de dispositivo.
4. **La tienda nunca había importado contratos**, y el primer import no
   compilaba: las extensiones `.ts` que Node exige.

**Verificado sobre `next build` + `next start` contra stage:**

| Qué | Cómo |
|---|---|
| Las rutas | `/vinos`, tres fichas y `/carrito` dan **200**; `/vinos/slug-inventado-de-control` da **404** |
| La caché | `s-maxage=60, stale-while-revalidate=300` y `Cache-Tag: catalogo` (la ficha suma `producto-<slug>`). La home sigue en `s-maxage=31536000` y `/oficio` estática |
| El HTML sin JavaScript | Los vinos de control aparecen; uno inventado da 0 |
| El carrito | Portillo en 9 sobre un tope de 5 queda **guardado en 5**, y el total es **$ 183.500,00**, el mismo número calculado a mano |
| Las reglas | 24 casos contra el emulador, cada requisito con uno aceptado y uno rechazado |
| Tests, tipos, hooks | 65 de contratos + 11 de la tienda; `tsc` 0 en los dos; arnés 35/35; 159 enlaces |
| El seed | Dos corridas, verificadas por REST: 20 productos, una foto por carpeta, control positivo y 404 |
| Mirado | 1440 y 390 px emulados: listado, fichas, caja, agotado, sin foto, el carrito con sus estados feos y vacío. Sin overflow |

⚠️ **Las fotos dan 400: las reglas no están publicadas.** El deploy lo frenó el
clasificador del modo auto tres veces, y lo tiene que correr el dueño (abajo).
**La tienda no se despliega**: al tramo 4 se suman los gates que ya existían.
`revisor-pagos` no encontró nada que bloquee, y dejó ocho puntos para antes de
`crearOrden`.

**Esa misma tarde, la home dejó de mostrar vinos inventados.** Las seis
tarjetas de `La selección` salen del catálogo, horneadas en el build: la home
sigue estática y lee Firestore una vez por deploy, cero por visita
([ADR 008 §7](../architecture/decisions/008-catalogo-stock-y-carrito.md)). Llevan
la foto en una ventana prendida, y ya no dicen precio ni "guarda".

⚠️ **Dos trampas, las dos encontradas midiendo:**

1. **`unstable_cache` le baja el `revalidate` a la página que lo llama.** Con
   `obtenerCatalogo`, la home habría pasado sola a ISR de 60 s. Por eso existe
   `leerCatalogoSinCache`, y un test que falla si la home importa la caché —
   cuya primera versión dio rojo por el comentario que la nombra.
2. **La foto agrandaba su ventana.** Con `height: 84%` adentro de la grilla, el
   alto natural de la foto le ganaba al `aspect-ratio`: en escritorio salían
   cuellos de botella gigantes. **Lo vio el dueño antes de que yo abriera mi
   propia captura, que también lo mostraba.** Ahora la foto va
   `position: absolute`.

| Qué | Cómo |
|---|---|
| Sigue estática | `○ /` en el build y `s-maxage=31536000`; `/vinos` da `1m` como control |
| Lo viejo se fue | 0 "Cuesta del Sauce", 0 `/vinos/muestra-0…`, 0 "Acostada desde marzo" (antes: 2, 6 y 2) |
| Los seis son reales | Los que predijo la regla antes de mirar; sus seis fichas dan **200** y una ruta inventada **404** |
| Sin precio | "19.900" da **0** en la home y **4** en `/vinos` |
| Mirado | 1440 y 390 px emulados, con las fotos reales servidas por intercepción: las seis ventanas miden **0,563** (9:16) en las dos vistas |
| Tests y docs | 19 de la tienda; `tsc` 0; 168 enlaces; `_verdad.md` regenerado |

---

## Salió el 2026-09-16, al entrar el plan del panel

Sexta entrada. **Salió ésta y no la de los tres paquetes**, por el mismo
criterio de la vez anterior: aquélla dice dónde vive Firestore. La decisión de
ésta vive entera en
[ADR 007](../architecture/decisions/007-seccion-el-oficio.md), y su gate —el
contacto provisorio— sigue en la tabla de abiertos de `_index.md`, que es
donde se lo busca antes de desplegar.

### `El oficio`: la sección que cierra dos placeholders con una sola pieza (2026-09-09)

**Nace `/oficio`** —tres tramos, `I Elegir · II Guardar · III Abrir`, de los que
la marca **firma dos**— y con ella se van las dos secciones vacías que la barra
venía nombrando desde `v0.15.0`. `/custodia` **se borró** (nada estaba
desplegado: no hay enlace entrante que preservar) y `/contacto` **se plegó** como
cierre de la página, con la URL vieja redirigiendo **308** a `/oficio#mostrador`.
`Custodia` no desapareció: bajó a nombrar el tramo `II`, que es donde la palabra
rinde. Todo el porqué en [ADR 007](../architecture/decisions/007-seccion-el-oficio.md).

La forma la eligió el dueño **mirando dos maquetas** con el copy real —la
etiqueta única y la carta numerada—, no leyendo una propuesta.

⚠️ **NO SE DESPLIEGA, y es el quinto gate.** `EL_CONTACTO_ES_PROVISORIO` está en
`true`: el WhatsApp publicado es el del desarrollador y el mail todavía no tiene
dominio. Se suma a la puerta de edad, las seis fichas en 404, las licencias de
los assets y los 391 KB de fuentes. La constante **también viaja al HTML** como
`data-contacto-provisorio`, porque `auditor-produccion` audita con `curl` y no
puede grepear un `.ts`.

⚠️ **Dos defectos que ninguna medición mostró, los dos encontrados abriendo el
PNG** — quinta vez en este proyecto:

1. **Los párrafos salían pegados en los dos anchos.** El aire vivía en un
   `p + p` de especificidad (0,1,2) y el `margin: 0` en `.tramo__cuerpo .prosa`,
   (0,2,0): **el margen no pintaba nunca**. Las columnas, los altos, el
   `column-rule` y el `scrollWidth` daban todos bien mientras la prosa era un
   muro.
2. **`break-inside: avoid-column` desbalanceaba las columnas**: con párrafos
   atómicos el balanceador no reparte, y el tramo `I` quedaba **3 líneas de un
   lado y 9 del otro**. Se saca; `orphans`/`widows` en 2 evitan la línea suelta.

⚠️ **Y TRES INSTRUMENTOS DE VERIFICACIÓN MINTIERON EN VERDE.** Es el hallazgo
más transferible de la tarea:

| Instrumento | Cómo miente |
|---|---|
| `grep -i` sobre texto con acentos | Con el locale vacío devuelve **cero en silencio** sobre UTF-8 con tildes; `grep -c` ni imprime número. El control positivo con el dialecto de cata insertado dio **0**. Con `LC_ALL=C.UTF-8` encuentra las tres |
| `call-site-guard` | Grepea `apps/` entero, `node_modules` y `.next` incluidos. Los **sourcemaps embeben el fuente**, así que un símbolo huérfano aparece "usado" en cuanto corrió un build: dio verde con dos exports que no abría nadie. Misma familia que `generar_verdad.mjs` contando comentarios |
| `frontera-features.sh` regla 2 | Sólo mira `from '@/features/`. El mismo import escrito **relativo** no bloquea |
| El propio **gate de deploy**, en su primera versión | `data-x={CONST ? 'true' : undefined}` saca el atributo del DOM pero **no del payload RSC**, que Next serializa en el mismo HTML como `"$undefined"`. Con la constante en `false` el `grep` seguía dando 1: **el gate no distinguía**. Arreglado con un spread condicional y medido en los dos estados — `true` → 2, `false` → 0. Y el comando iba con `grep -c`, que cuenta LÍNEAS y el HTML de Next es una sola |

**Verificado sobre `next build` + `next start`, y mirado renderizado:**

| Qué | Cómo |
|---|---|
| Las rutas | `/oficio` **200**, `/custodia` **404**, `/contacto` **308 → `/oficio#mostrador`**. **Control negativo:** `/ruta-inventada-de-control` da 404 |
| `/oficio` es estática | `next build` la lista con `○`, y `/custodia` ya no aparece |
| El gate llega al HTML | `curl … | grep -c data-contacto-provisorio` = **1**. Control negativo: en la home da **0** |
| Dos columnas en escritorio | A 1440: `column-count` **2** con regla dorada de 1px al 22 %; los tres tramos miden **0,50 · 0,58 · 0,53** de viewport, ninguno se pasa |
| Una sola columna en angosto | A 390: `column-count` **auto**, `column-rule-style` **none**, y `scrollWidth` = `clientWidth` = **390** |
| El numeral sin firma | `III` con `color: transparent` + `-webkit-text-stroke` 1,2px, **adentro** del `@supports`: sin soporte queda macizo, nunca invisible |
| Movimiento reducido | `scrollHeight` **2771 = 2771** con y sin la preferencia, animaciones **16 → 0**, y en la captura los filetes están a **ancho completo** |
| Cero Firestore | Sin `import` de firebase en la feature. **Control positivo:** el mismo grep sí lo encuentra en `src/server/` |
| Los hooks y los enlaces | arnés **35/35** · **143** enlaces en 54 archivos, todos resuelven |
| La voz | 565 palabras: **0** exclamaciones, **0** emoji, **0** `tú`/`usted`, **0** del dialecto de cata — con el control positivo pasando primero |

---

## Salió el 2026-09-15, al entrar el checkout

Sexta entrada. **Salió ésta y no la de los tres paquetes**, por el criterio de
siempre: aquélla dice dónde vive Firestore —`southamerica-east1`, que no se
puede cambiar nunca—, mientras que la decisión de ésta ya vive entera en
[ADR 006](../architecture/decisions/006-estructura-de-la-tienda.md), el hook que
la hace cumplir corre desde entonces, y la barra que describe está en `main`.

Y hay una razón más para moverla hoy: el checkout la **tocó**. `checkout/` no
nació como feature propia —la regla 3 lo impedía— y eso está razonado en
[ADR 010](../architecture/decisions/010-el-checkout.md), que es donde hay que
leerlo ahora.

### La vidriera se ordenó por feature, y ya tiene barra de navegación (2026-09-09)

**`apps/tienda/src` pasó de capas técnicas a `features/` + `shared/`**, con las
cinco reglas contra el cajón de sastre en
[ADR 006](../architecture/decisions/006-estructura-de-la-tienda.md), enlazado desde
`CLAUDE.md`. La regla que se viola en una línea —`shared/` no importa de
`features/`, las features no se importan entre sí— **la mide un hook**,
`frontera-features.sh`, con 5 casos en el arnés, que pasó de 30 a **35**.

**La barra es un cartucho fijo, no una franja al ras.** Reusa `.cartucho-deco`,
que ya existía. Cuatro rutas nuevas —`/vinos`, `/custodia`, `/contacto`,
`/carrito`— con contenido de placeholder, salvo el carrito, que trae el estado
vacío REAL de [`voz.md §9.4`](../design/voz.md) literal.

> ⚠️ **Dos de esas cuatro rutas ya no existen** (2026-09-09): `/custodia` se
> borró y `/contacto` redirige 308 a `/oficio#mostrador` — ver la entrada de
> arriba y [ADR 007](../architecture/decisions/007-seccion-el-oficio.md). La línea
> de acá queda porque cuenta el commit `9865957`, no el estado de hoy. Lo
> encontró `cazador-de-puertas`, que es exactamente para lo que existe.

⚠️ **La mudanza rompió DOS hooks en silencio, y ése es el hallazgo caro.**
`widget-size-guard` medía `src/components/*.tsx` y **dejó de medir nada**;
`no-hardcoded-colors` exceptuaba `src/tokens/*` y habría **bloqueado el propio
archivo de tokens**. El primero es peor: *un hook que no aplica no falla,
**pasa***. Los dos arreglados, con control positivo y negativo directos sobre
los globs nuevos —no sólo con el arnés, que también pasaba con el glob roto—.

**El parallax y la barra fija no pelean, y está verificado, no razonado.**
`parallax.md §3.1` ya lo tenía decidido (*UI, fija, sin parallax*), y
técnicamente no puede romperse: el motor son timelines de scroll de CSS sobre
el scroller nativo, no un `transform` sobre un contenedor —que es lo que
rompería `position: fixed`—. `.grano` (z9) y `.marca-progreso` (z8) ya lo
probaban antes de esta barra.

**Verificado, y las tres cosas que valen salieron de MIRAR:**

| Qué | Cómo |
|---|---|
| Compila y construye | `tsc --noEmit` exit 0 con **control positivo** (`--listFiles` muestra los 8 archivos nuevos); `next build` con las 5 rutas **estáticas** |
| Las rutas existen | 200 en las cuatro; **control negativo**: `/ruta-inventada-de-control` da 404 |
| Los dos CTA muertos revivieron | 3 `href="/vinos"` en la home (2 CTA + barra), contados sobre el HTML servido |
| El mecanismo del asiento | `--asiento` 0 → 1, fondo transparente → opaco, wordmark 0 → 1, medido por CDP en las dos posiciones |
| Los hooks siguen midiendo | arnés 35/35, **más** 4 controles directos sobre los globs que cambié |
| Los enlaces de la doc | 133 enlaces, 49 archivos, todos resuelven |

⚠️ **Tres defectos que ningún número mostró y aparecieron abriendo el PNG**, que
es la tercera vez que pasa en este proyecto: la barra estirada a 1440px **no
leía como cartucho** sino como franja con borde; el fondo asentado al 82 %
**dejaba leer el texto de la página a través de la barra**; y el cartucho de
sección partía el título por ancho. Los tres arreglados y re-capturados. La
barra asentada quedó **opaca**, no en el alfa mínimo que "casi" tapa: es la
misma familia de defecto que la viñeta en z4, y las dos veces anteriores una
verificación numérica había dado verde.

⚠️ **Y el dueño encontró DOS defectos más mirando, otra vez después de que mis
capturas estuvieran bien.** Van cuatro veces en este proyecto, y el patrón ya no
es anecdótico: *lo que verifico yo y lo que se ve son cosas distintas.*

1. **La placa se veía descentrada en el primer píxel de la página.** Yo había
   reservado el hueco del wordmark con `opacity` para evitar un salto de
   layout — argumento correcto para un toggle discreto y **mal aplicado acá**,
   donde el ancho lo interpola el mismo reloj de scroll: no es un salto, es un
   revelado continuo. Ahora colapsa el ancho y la placa queda centrada sobre
   sus cuatro ítems. Medido: `anchoMarca` 0 → 83 px, y la distancia al borde
   izquierdo menos la del derecho da **0 en los dos estados**.
2. ⚠️ **Cuatro triangulitos negros en las esquinas, visibles recién con el zoom
   del navegador al 200 %.** El anillo del cartucho es un octógono pero el
   elemento sigue siendo un RECTÁNGULO: mientras el cartucho fue transparente
   —como nació, sobre la foto de la mesa— no se notaba, y el día que le puse
   `background` el fondo pintó las cuatro esquinas que el anillo deja afuera.
   **El arreglo NO fue en la barra:** `.cartucho-deco` ahora publica la forma
   como `--octogono`, así que el próximo que pinte un cartucho recorta con ella
   y hereda el mismo chaflán. Ninguna de mis capturas al 100 % lo mostraba: a
   9 px el triángulo se pierde.

⚠️ **Y apareció un agujero que el vault contaba mal: la home tiene OCHO
enlaces muertos, no dos.** Los dos CTA a `/vinos` ya están; los otros seis son
las tarjetas, que apuntan a `/vinos/muestra-01…06` y **siguen dando 404**.
Abajo, con disparador.

**Medido en 360×780:** la barra ocupa 48 px (6,2 % de cada pantalla, para
siempre) y la home da **6,26 pantallas** contra el techo de 8. Una barra fija
no suma alto de scroll.

---

## Salió el 2026-09-14, al entrar la venta por caja

Sexta entrada. **Salió ésta y no la de los tres paquetes**, por el mismo motivo
que la vez pasada: aquélla dice dónde vive Firestore —`southamerica-east1`, y
eso no se puede cambiar nunca—, mientras que la decisión de esta entrada ya vive
en [`landing-alternativa.md`](../design/landing-alternativa.md), la página que
describe está en `main` byte por byte, y lo que enseñó de más —el BOM de
`package.json` que rompe `JSON.parse` en silencio— quedó anotado donde se
tropieza con él.

### La composición elegida: la de cuatro escenas, y `main` la tiene (2026-09-08)

**El dueño eligió entre las seis composiciones que llegaron a existir, y ganó la
segunda:** [`landing-alternativa.md`](../design/landing-alternativa.md) — cuatro
escenas, problema → selección → custodia → mesa. **Era la primera que se pudo
mirar corriendo**, y es la que ahora vive en `main`.

**Cómo llegó:** `main` era **ancestro** de `home-parallax`, así que fue un
fast-forward de un comando, no un merge.

⚠️ **Y por eso este archivo NO sabe lo que aprendieron las composiciones 3 a 6**
(del 2026-09-04 al 07, en `home-parallax-b`, `-c` y `-d`). Fue decisión
explícita del dueño: son **dos días** de trabajo y quedan vivos en sus ramas.
Lo que sí bajó son las **cuatro cosas que le faltan a la página que quedó
publicada** — abajo, con disparador. El resto se recupera con
`git show <rama>:<ruta>`.

⚠️ **El fast-forward revivió un bug que ya estaba arreglado**, y conviene que se
note porque es el costo real de volver a un commit viejo: **el BOM UTF-8 de
`package.json`**, que entró en `v0.7.2` y se había quitado en un commit
posterior que `main` ya no incluye. Rompe `JSON.parse`, y el `catch {}` de
`generar_verdad.mjs` se traga el error: la sección 2 entera salía como *"No
verificado: la raíz no declara `workspaces`"*, una **ausencia inventada,
indistinguible de un hallazgo real**. Se quitó de nuevo acá. ⚠️ **El `catch`
silencioso sigue ahí**, así que el próximo BOM vuelve a mentir igual.

**Verificado, no supuesto:**

| Qué | Cómo |
|---|---|
| Compila | `tsc --noEmit --project apps/tienda`, exit 0 |
| Los enlaces resuelven | `verificar_enlaces.mjs`: 121 enlaces, 45 archivos. Control positivo: una corrida previa marcó **6 rotos** |
| El informe no miente | `generar_verdad.mjs --check`, **exit 0** — y de paso destapó que estaba viejo desde `v0.7.0` |
| Las 9 piezas tienen call site | `page.tsx` abre 5, las escenas abren las otras 4 |
| Los 8 assets tienen consumidor | ⚠️ Las rutas se arman en runtime (`/landing/${base}.webp`), así que **el grep literal dio vacío**. Hubo que enumerar las bases: 5, tres con `dosDirecciones` → 8 archivos exactos |

**No se miró renderizada, y esta vez es lo correcto:** es byte por byte la
página que el dueño ya miró y eligió.

---

## Salió el 2026-09-11, al nacer el catálogo

Sexta entrada. **Salió ésta y no la más vieja**: todo lo que enseñó —la ranura de área cero, el `from 0deg` del cónico, el chaflán interior a `0,414 · grosor`— ya vive en [ADR 006](../architecture/decisions/006-estructura-de-la-tienda.md) y en los comentarios de `deco.css`. La más vieja, la de los tres paquetes, sigue arriba porque dice dónde vive Firestore, y eso no se puede cambiar nunca.

### El cartucho de la mesa: filete al triple y trazado en dos brazos (2026-09-09)

**El dueño pidió dos cosas mirando la home:** que el marco de *"Después no te
vas a acordar del vino"* estaba **muy fino**, y que la aparición al scrollear
iba **muy rápida** — con el arreglo ya propuesto adentro del pedido: *dos
inicios, mitad de velocidad, porque se dibuja en dos partes al mismo tiempo.*

**El filete pasó de 1,5 px a 3 px**, y no pisando el default: `.cartucho-deco`
sigue en `--filete-grueso` para las piezas chicas —la barra hasta lo **baja** a
`--filete`— y `.mesa` sube a un token nuevo, `--filete-marco`. Un anillo se lee
en proporción al bloque que encierra, y éste encierra media pantalla.

**El trazado ahora sale de arriba en dos brazos** que se encuentran abajo. Es
un solo gradiente cónico con los topes simétricos, no dos capas: `--cierre`
hacia adelante es el brazo horario y `1turn - --cierre` hacia atrás el
antihorario. `@keyframes` va a **medio giro**, no a uno entero, sobre el mismo
`animation-range` — o sea que la punta del trazo va exactamente a la mitad de
la velocidad angular, que es lo pedido.

⚠️ **Y ahí aparecieron dos defectos de geometría que nadie había medido, los
dos invisibles mientras el filete fue fino.**

1. **`from -90deg` no arrancaba arriba, arrancaba en el borde IZQUIERDO**, con
   el comentario *"barre desde arriba en sentido horario"* al lado. En
   `conic-gradient` el ángulo 0 **ya apunta arriba** —no a las 3, como en un
   `linear-gradient` o en `atan2`—. Con un brazo eso pasa por elección de
   estilo; con dos, los dos salían del mismo costado y se veía roto. Medido en
   un banco aislado a 47°: con `-90deg`, 644 y 643 px en las dos mitades
   izquierdas y **cero** a la derecha; con `0deg`, 625 y 625 arriba y cero
   abajo.
2. ⚠️ **El chaflán superior izquierdo del cartucho estaba PARTIDO, y lo está
   desde que el cartucho existe.** `polygon()` dibuja **un** camino cerrado, no
   dos: poniendo los ocho vértices de afuera y después los ocho de adentro, el
   camino tiene que ir y volver entre los dos anillos, y esos dos puentes caen
   los dos en esa esquina y **se cruzan**. Con `evenodd`, cruzarse invierte el
   relleno. Medido sobre el cartucho publicado: la banda iba 9 → 1 px → **corte
   limpio** → 1 → 9, mientras las otras tres esquinas medían 6 px parejos.

   El arreglo es una **ranura de área cero**: se sale y se vuelve por el mismo
   segmento vertical, arriba al centro. Un segmento recorrido en los dos
   sentidos no encierra nada, así que la paridad de `evenodd` no se entera. Se
   probaron tres órdenes de vértices y sólo ése queda plano:

   | orden de vértices | chaflán sup-izq (el anillo mide 6 px) |
   |---|---|
   | puentes cruzados (lo que había) | min **0,1** · max 4,4 — roto |
   | anillo interior espejado | min 1,1 · max **13,9** — peor |
   | ranura de área cero | **min 5,6 · max 5,6**, y las otras tres igual |

3. Y el vértice interior del chaflán estaba a `--chaflan + --grosor`, que deja
   la diagonal **1,41 veces más gorda** que los lados rectos. Va a
   `+0,414 · --grosor` (que es `√2 − 1`), y ahí sí es un offset paralelo. Con
   1,5 px el error medía 0,6 px; al triple se empezaba a ver.

**Verificado sobre `next build` + `next start`, no sobre `next dev`:**

| Qué | Cómo |
|---|---|
| Los dos brazos son simétricos | A medio trazo, **4.144** px dibujados arriba-izquierda contra **4.158** arriba-derecha, y **cero** en las dos mitades de abajo |
| Y el trazo es la mitad de rápido | `--cierre` barrido a lo largo del scroll: 0° → **180°**, no 0° → 360°, sobre el mismo `animation-range` |
| El filete llegó a la página | `--grosor` computado en `.mesa` = **3px**; espesor pintado del lado recto = **7 px de dispositivo** a dpr 2, parejo en los nueve puntos medidos |
| Las cuatro esquinas están sanas | Corrida horizontal de la banda diagonal: **10 · 10 · 9 · 9**, constante fila por fila. Antes: 9 → 1 → corte |
| La ranura no deja costura | El espesor del lado de arriba en `dx = 0` es **7**, igual que a ±600 px |
| Controles | **Positivo**: el anillo entero aparece en los cuatro cuadrantes. **Negativo**: la captura vacía contra sí misma da **0** px |
| Compila y construye | `tsc --noEmit` exit 0 · `next build` con las 6 rutas estáticas |
| Los hooks y los enlaces | arnés **35/35** · 135 enlaces en 49 archivos, todos resuelven |

⚠️ **La medición por diferencia mintió una vez y hay que saberlo:** el primer
par de capturas dio **315.087 px distintos** en la mitad de abajo, que no era
el anillo sino **la foto terminando de decodificar entre una captura y la
otra**. Un tiro de calentamiento y 2,5 s lo cierran. Sin eso, el control
positivo da un número enorme y verde por el motivo equivocado.

**Sin desplegar, y correctamente:** el deploy sigue bloqueado por la puerta de
edad, las seis fichas en 404 y las licencias de los assets. Lo de acá se miró
renderizado en una build de producción local.

---

## Salió el 2026-09-09, al nacer la sección `El oficio`

Sexta entrada. **Salió ésta y no la más vieja**, y el criterio importa: su
propio encabezado ya decía *"escrito antes de la decisión"* — la composición que
cuenta ganó y vive en `main` desde el 2026-09-08, así que arriba quedaba
contando dos veces la misma historia. Lo que sigue valiendo es de dónde salió
la aritmética del parallax y los seis defectos que se encontraron mirando.

### Una segunda landing, en su propia rama (2026-09-04)

> ⚠️ **Escrito antes de la decisión. Esta es la que ganó**, y desde el
> 2026-09-08 no está en su propia rama: está en `main`. Lo de abajo cuenta de
> dónde salió; el estado de hoy es la entrada de arriba.

**El dueño no quedó convencido de [`escenas.md`](../design/escenas.md)**, así que
hay una composición que compite con ella:
[`design/landing-alternativa.md`](../design/landing-alternativa.md), **construida y
navegable** en la rama `home-parallax`. ~~Sin mergear~~ — **mergeada a `main` el
2026-09-08**. ⚠️ **Sin desplegar.**

Cuatro objeciones, textuales: *mucha ceremonia y poco vino · el arco narrativo ·
muy abstracto · los copys son cortos para desktop*. Lo que sale de ahí:
**cuatro escenas en vez de cinco**, el vino en la **segunda** y son **seis**,
y ~340 palabras contra ~120.

**El arco deja de ser un recorrido de ánimos** —umbral, origen, sorbo, vitrina,
mesa— y pasa a ser la secuencia de preguntas que hace alguien que podría
comprar: el problema que ya vivió, qué hay, por qué nosotros, y qué queda
después.

**La escena que enseña cambió de tema, y ahí está el arreglo de "abstracto".**
`escenas.md` enseñaba el color del menisco de una copa: cierto, pero sobre el
vino, que es justo lo que la marca no puede firmar. Ahora enseña **la custodia**
—acostada, temperatura pareja, sin luz, con el porqué físico de cada una—, que
es lo único que bouquet hizo. Y el texto del héroe no se escribió: **estaba en
[`voz.md §10.2`](../design/voz.md)**, enterrado en un ejemplo.

**`parallax.md`, `direccion.md` y `voz.md` no se tocaron.** Lo único que se
descarta es la composición.

⚠️ **Y ahí apareció el hallazgo más grande: el parallax de los dos documentos
de diseño NO SE VE, y es aritmética.** `escenas.md §5` acertó el **signo**;
los dos documentos están mal en la **magnitud**, por un factor de ~7.

Sobre el rango `cover` el scroll avanza `S = viewport + alto de escena` ≈ 200vh,
y para que un plano vaya a velocidad `v` hace falta `(1 − v)·S`. Para `v = 0.55`
son **90vh**; `parallax.md §4.1` manda **13,5vh**, con lo que `escenas.md §5`
llama *"una escala de 30vh, la fuerza de parallax que el documento eligió"*.
**Esa escala es el error: la amplitud ES la velocidad, no se atenúa.**

Medida la velocidad aparente contra el contenido, que es la unidad que ve el
ojo: **v = 0.91 / 0.94 / 0.98 / 1.02** con los valores del documento, y
separación entre planos de **0,021** contra el mínimo de **0,15** que el propio
`§2.2` fija. Siete veces por debajo de su propio umbral. Corregido:
**0.54 / 0.69 / 0.85 / 1.00 / 1.15**, separación **0,153**.

⚠️ **Lo encontró el dueño mirando, después de que una verificación mía diera
verde.** Esa verificación medía que los `translate` cambiaban y que eran
proporcionales a los tokens — **consistencia interna, no correctitud**. Los
números eran fieles a unos tokens equivocados. Faltaba una unidad externa.

⚠️ **Y el presupuesto de memoria de `parallax.md §2.2` está subestimado por el
mismo motivo:** calculó capas del tamaño del viewport, y una capa del tamaño del
viewport **no puede hacer parallax**. Con sangrado real la capa mide ~180svh.

**Falta la mitad que ninguna aritmética contesta:** scrollearlo con el dedo.
Y ojo con el navegador: **Firefox sigue en `preview`** —detrás de flag— según
`mdn/browser-compat-data`, así que ahí no se ve movimiento por diseño y la
página cae a Tier C.

**Seis defectos que ninguna revisión de código encuentra**, todos hallados
abriendo el PNG de una captura: la foto de la mesa venía con **marca de agua
`Unsplash+`** tileada; `.plano > img` no matcheaba porque el `<img>` es hijo de
`<picture>`, así que las fotos salían a tamaño nativo; el scrim se leía como un
panel rectangular porque sus radios superaban el borde de la caja; el sangrado
parejo de 24vh sobre-ampliaba la dirección de arte horizontal; y la página medía
**9,71 pantallas en móvil** contra el techo de 8. Quedó en **5,88**, y se
arregló **sin sacar vino**: en pantalla angosta la tarjeta gira a fila.

**El scrim está medido, no razonado.** Decodificando el PNG en cinco puntos del
scroll: variación de **0,12 puntos**, contra **0,55** del control negativo —la
misma foto, sin scrim—. Y con `prefers-reduced-motion` el `scrollHeight` es
**idéntico**: no hay pin, así que no existe el peor defecto de `escenas.md §4.3`.

⚠️ **Y el dueño encontró un segundo defecto mirando, otra vez después de una
verificación mía en verde:** *"hay textos que parecen estar detrás de una nube
borgoña"*. Estaban. **`.vinieta` vivía en `z-index: 4`, encima del contenido**, y
oscurecía el panel dorado del CTA de 0,451 a **0,089** de luminancia — cinco
veces—, cambiando además con la posición en la escena. `parallax.md §3.1` ya
prohibía eso en z4: *"área grande, tapar texto"*. La viñeta y la costura bajaron
a z2. La **brecha** entre el color declarado y el pintado se desplomó: CTA duro
del **80 % al 2 %**, datos del vino del 67 % al 4 %.

⚠️ **El error de método es lo más caro y lo más transferible:** para buscar velos
se usó `elementsFromPoint`, que **ignora los elementos con `pointer-events:
none`** — y toda capa decorativa lo lleva. **El detector era incapaz por
construcción de encontrar lo que buscaba**, y devolvió "nada encima" en cada
corrida mientras el velo estaba ahí. Con él ciego se persiguieron seis hipótesis
falsas y se llegó a invertir el CTA para esquivar el síntoma; esa inversión se
revirtió. Detalle y tabla en [`landing-alternativa.md §5.1`](../design/landing-alternativa.md).

⚠️ **Los seis vinos son INVENTADOS.** `grep -rn LA_SELECCION_ES_DE_MUESTRA`:
mientras dé `true`, esto no se publica.

---

## Salió el 2026-09-09, al engrosarse el cartucho

Sexta entrada: entró el trazado de dos brazos y ésta salió por el tope de 5. Lo
que cuenta sigue vigente — es de dónde salieron `openspec/`, `.mcp.json`,
`_verdad.md` y `verificar_release.sh`.

### Las cuatro piezas que se invocaban y no existían (2026-09-02)

Estaban nombradas en los documentos y no en el disco — la feature sin puerta,
al revés: la puerta existía y no había cuarto detrás.

| Pieza | Estado |
|---|---|
| **`openspec/`** | inicializado con `@fission-ai/openspec` **v1.11.0**, `--language es`. Los 6 comandos `/opsx:*` existen. ⚠️ El paquete npm llamado `openspec` a secas es **0.0.0 y sin binario**: no es el real |
| **`.mcp.json`** | en el repo. Arranca `firebase mcp` con el **binario global**, no con `npx -y firebase-tools` — ese `npx` ES la causa del `CONNECT_TIMEOUT` |
| **`_verdad.md`** | generado por `scripts/ci/generar_verdad.mjs`, **corre en CI** y en `npm run verificar` |
| **`verificar_release.sh`** | escrito. Hashea el contenido en vez de mirar el 200, cuenta un job `skipped` como **falla**, y trae los dos controles adentro |

**`_verdad.md` ya pagó en su primera corrida:** detectó que este archivo decía
**24 tests** cuando el runner dice **26**. Esa es, literal, la diferencia entre
intención y comportamiento que el archivo existe para medir.

Y dejó un dato que hay que mirar cuando aparezcan `apps/` y `functions/`:
**19 de 28 símbolos de `packages/contratos` no tienen call site productivo**.
Hoy es correcto —el paquete se escribió primero a propósito— pero **el bug
sería que ese número no baje** cuando existan sus consumidores.

---

## Salió el 2026-09-08, al elegirse la composición

**El dueño eligió la de cuatro escenas** — la segunda de las seis, y la primera
que se había podido mirar corriendo. `main` la tomó por fast-forward. Estas dos
entradas salieron del dashboard por el tope de 5, no por dejar de ser ciertas.

### El repo publicado, y lo que eso destapó (2026-09-03)

**`github.com/aguschazaaa-sudo/bouquet`, público.** Remote `origin`, default
`main`. Verificado comparando `git ls-remote` contra el hash local, no por el
mensaje del push: **`93525f1` de los dos lados**.

**Se cerró un agujero del `.gitignore` antes de publicar.** Cubría
`*-service-account*.json` y `serviceAccountKey*.json`, pero el nombre con el
que la consola de Firebase **descarga de verdad** una clave privada es
`<proyecto>-firebase-adminsdk-<hash>-<hash>.json`, que no matcheaba ninguno.
Medido con `git check-ignore` sobre esa ruta exacta: daba **"se subiría"**. Es
la credencial que ignora `firestore.rules` por diseño. El barrido de las 7
commits del historial —no sólo del HEAD— no encontró nada más.

⚠️ **El primer CI real falló, y la causa era del CI, no del código.**
`_verdad.md` incluía *"En disco hay N carpetas de skill"*, y N es **29** en
esta máquina y **2** en el runner, porque las de terceros no se commitean. Con
`--check` comparando texto exacto, el job `guardas` era **imposible de pasar
regenerando**: el número cambia con el entorno, no con el código. El dato pasó
a stderr y dice *cuáles* faltan, que es accionable. Arreglado en `v0.5.3`.

**El defecto existía desde que se escribió el script.** No lo vio nadie porque
hasta hoy no había remote y el workflow nunca había corrido. Para el resto del
repo: **un workflow que nunca corrió no es un workflow verde, es un workflow
desconocido** — y hay dos en esa situación ahora mismo, abajo.

### La landing, el hosting, y la dirección de marca (2026-09-03)

[`design/parallax.md`](../design/parallax.md) — el informe de parallax, con las
seis decisiones **ya tomadas** por el dueño.

**El sistema de movimiento.** Lo que separa un parallax premium de un capricho
no es el efecto: es de dónde salen los números. **Las velocidades se derivan de
una sola cámara** (`v = 1 − z/D`), no se eligen capa por capa. De ahí sale el
techo de **5 planos** —el rango útil va de 0.4 a 1.15 y la separación mínima
perceptible es 0,15— y el reparto de contenido: **el texto y su scrim viajan
juntos a `v = 1.00`**, porque un texto sobre una foto que se mueve **cambia de
contraste mientras scrolleás** y ninguna herramienta estática lo ve. Técnica:
**scroll-driven animations de CSS** — Chrome 115, Safari 26 (y recién **26.4**
en el compositor), **Firefox todavía detrás de flag**, verificado contra
`browser-compat-data`. Por eso se construye **Tier C primero**: la composición
estática hay que hacerla igual para `prefers-reduced-motion`.

**La landing:** de marca, 5 escenas, *persuade y coquetea* — CTA duro sólo dos
veces, y la puerta de edad es **el telón que se levanta**. Una sola escena toca
el catálogo. **16 planos × 2 direcciones de arte = 32 assets**, especificados
por rol en §10.3 para que la recopilación sea dirigida y cambiar una foto
después cueste un archivo, no un rediseño.

⚠️ **Y el hosting cambió: no va Vercel, va Firebase** — decisión del dueño,
[ADR 005](../architecture/decisions/005-hosting-vidriera.md). Lo caro no es mover
el deploy: **App Hosting no tiene purga on-demand**, y esa era la pieza que
sostenía la frescura del precio de [ADR 004](../architecture/decisions/004-frescura-y-lecturas.md).
La repone **Cloudflare, que sí tiene purga por tag en todos los planes**. El
diseño resultante **no usa ISR**: SSR + caché de borde, TTL largo donde hay
purga y TTL corto donde no la hay. **El presupuesto de lecturas no se movió:
~1.700/día, y que no se moviera es la prueba de que el ADR está bien.**

**Y ya existe la dirección visual**, que es lo que `parallax.md` declaraba
faltante: [`design/direccion.md`](../design/direccion.md), el **paso 1 de
`/disenio`**. Sale de medir el logo, no de opinar sobre él.

**El hallazgo que ordena todo lo demás:** la marca tiene exactamente **dos**
colores —borgoña `#762D2D` y dorado `#D2AE6D`, tomados píxel por píxel del PNG—
y **cada uno sobrevive en un solo fondo**. Dorado sobre claro da **2,10:1** y
borgoña sobre oscuro da **1,92:1**: los dos fallan. No hay aclarado del borgoña
que lo salve —hay que llegar a rosa viejo (`#C76B6B`) para que sea legible sobre
oscuro—. De ahí salen **dos modos repartidos por tarea**: *ceremonia oscura*
(landing, catálogo, ficha) y *transacción de papel* (carrito, checkout,
comprobante). **No es un theme switcher: lo fija la página, no el usuario.**

Ese corte cae **exactamente sobre el mismo límite** que `parallax.md` §1.1 había
trazado para el movimiento, y los dos documentos se escribieron por separado.

Y el Art Decó —del que el dueño dudaba, con razón— entra **sólo como marco**:
un panel borgoña sobre el fondo oscuro llega a **2,05:1** como techo, por debajo
del 3:1 de un borde de UI. **La línea dorada que lo enmarca es lo único que lo
hace visible**, así que el recurso decorativo está haciendo trabajo estructural.
Dark academia aporta el lugar; el Decó, el marco. Nunca al revés.

⚠️ **Falta `design/tokens.md`** — el paso 2. Hasta que exista, `tienda` y
`admin-presentacion` no deberían escribir componentes visuales.

**Y existe la mitad verbal:** [`design/voz.md`](../design/voz.md), con su agente
en `.claude/agents/voz.md` — **son 13 subagentes ahora, 8 escriben y 5
verifican.** `voz` no tiene `Bash`, igual que `vault`: cura texto, no despliega.

**La tesis sale del nombre de la marca.** En enología *aroma* es lo que el vino
trae de la uva y **bouquet es lo que gana mientras está guardado**. O sea: el
nombre nombra la parte del vino que depende de **cómo lo cuidaron**, no de quién
lo hizo. De ahí que **bouquet no hace vino: lo guarda**, y toda la autoridad de
la voz salga de la custodia — que además es lo único que este negocio puede
afirmar sin mentir, porque no produce.

**Y la otra mitad del eslogan cierra la estructura.** *"Sabor eterno"* no
afirma nada del gusto: es una metáfora sobre **la memoria** — el sabor se va, la
experiencia de haberlo tomado dura. Con eso la marca queda con **dos tiempos**,
el *antes* de la custodia (**Cuidador**) y el *después* de lo que quedó
(**Amante**), y **el sorbo —lo único que bouquet no hizo— queda entre paréntesis
sostenido por los dos lados**. Los dos tiempos que la marca posee son de tiempo,
y ninguno es del líquido: ahí se resuelve la tensión del brief sin que ningún
arquetipo tenga que inventar una nota de cata.

Lo sensorial que pide el arquetipo Amante **no se resuelve con notas de cata**:
son la voz del productor, se copian entre bodegas y no son falsables. Se
resuelve describiendo **la escena y no la copa**. Y una nota de cata sólo existe
**firmada** — la misma regla que el glosario §7.4 ya aplicaba al stock.

Los registros son **cava** y **mostrador**, y los decide *el estado del lector,
no la URL*: **donde hay plata, no hay metáfora.** Ese corte cae por **tercera
vez** sobre el mismo límite que `parallax.md` trazó para el movimiento y
`direccion.md` para el color, y los tres se escribieron por separado.

⚠️ **La regla que hace seguro al agente:** cambia **cómo** se dice algo, nunca
**qué** se afirma. Si el original no trae el dato, el curado deja un **hueco
marcado** — plazos, stock, añadas y premios son exactamente por donde entra un
hecho inventado a una tienda.

**Y ya existe la composición:** [`design/escenas.md`](../design/escenas.md), el
**paso 3 de `/disenio`** — qué se muestra en cada una de las cinco escenas, plano
por plano, con su copy y su asset.

**La tesis sale de aplicarle a la luz lo que `parallax.md` ya le había aplicado
al movimiento.** Ese documento fijó que las velocidades se derivan de **una sola
cámara**. Faltaba que la atmósfera necesita lo mismo: **una sola lámpara**, con
tres números por escena, cuya posición **camina de la puerta hasta el lector**.
El scroll no te lleva por cinco lugares: te lleva desde una puerta hasta una
lámpara. De ahí sale el ritmo **lugar · objeto · lugar · objeto · lugar** — las
escenas 2 y 4 son láminas enmarcadas dentro de la cava, y **el marco excusa la
foto de banco**, que era el riesgo más caro del manifiesto de assets.

**Los assets bajaron de 32 a 7.** Resplandores, viñetas, marcos y chaflanes son
CSS; las dos copas de la escena 3 son SVG propio. Eso achica mucho el pendiente
de licencia que bloquea publicar el dominio — y de los 7, dos conviene que sean
**fotos propias**.

⚠️ **Se maquetó antes de especificar, y ahí apareció lo que no se veía leyendo.**
Tres defectos reales, ninguno visible en los documentos: el **scrim viajaba en el
plano equivocado** en dos escenas (el contraste del texto cambiaba mientras
scrolleabas — la violación exacta que `parallax.md §3.2` existe para prohibir);
el **pin se pasaba 12svh** del techo de §4.5; y el **pin sobrevivía a apagar el
movimiento**, así que con `prefers-reduced-motion` se scrolleaban 1,4 pantallas
sin que cambiara nada — parece que la página se colgó, y falla justo la cohorte
que Tier C existe para proteger.

⚠️ **Y los signos de `parallax.md §4.1` están invertidos.** Con el snippet tal
como está escrito, una amplitud negativa hace que el plano lejano se mueva **más**
que el contenido: la profundidad se lee al revés. Lento → **positivo**. Las
magnitudes están bien; era sólo el signo. **`parallax.md` no se editó todavía a
propósito:** se confirma scrolleando con el dedo en un teléfono, no desde el
escritorio. Los dos documentos no pueden tener razón.

Y la escena 4 ya sabe **cómo cambia el vino ofertado sin romper la landing
estática**: un `slug` versionado en el repo, resuelto en **Cloud Build** contra la
proyección publicada y horneado en el HTML. **Una lectura por deploy, cero por
visita.** La defensa contra que se filtre el precio no es CSS — es que el build
**nunca lee el campo**.

⚠️ **Falta `design/tokens.md`.** Sigue siendo el bloqueo: es la fase 0 del plan
de construcción de `escenas.md §7`.

## Salió el 2026-09-04, al entrar la landing alternativa

### La capa `.claude/` (2026-09-02)

**12 subagentes reales** en `.claude/agents/` — 7 escriben, 5 verifican **sin
`Edit` ni `Write`**. Esa resta es el único enforcement real del frontmatter:
`tools:` restringe herramientas, **no rutas**. Las fronteras por ruta las
siguen midiendo los hooks.

**27 skills de terceros**, declaradas en `skills-lock.json` y **no
commiteadas** — `bash scripts/skills_restaurar.sh` las restaura. Las propias
(`commit`, `post-task-doc`) sí se commitean.

`opsx` completo (12 skills) trae dos que PadelPunilla no tenía:
**`openspec-verify-change`**, que es el paso 9 que `WORKFLOWS.md` §4 pedía
agregar, y **`openspec-bulk-archive-change`**, la respuesta a los 33 changes sin
archivar.

Y un **Workflow E** nuevo: el chore que no llega solo a producción. Su paso
definitorio es un `grep`, no un criterio, y su último paso anota **en qué deploy
ajeno viaja de polizón**.
