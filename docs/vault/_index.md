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

**El panel tiene plan desde el 2026-09-16**, y su primer hito —cargar el
catálogo real— no espera a `crearOrden`.

### El panel tiene plan: 11 épicas, 49 historias, ninguna construida (2026-09-16)

**Nace el backlog de la app de gestión** en
[`features/panel/`](features/panel/overview.md): épicas que agrupan historias
de usuario, cada una con lo que **ya está decidido** y la restringe, enlazado a
su ADR. Son dos capas de tres: los **requerimientos** se escriben historia por
historia, en el change de `/opsx:propose` que la tome. El documento **no tiene
casillas** a propósito: el estado de una historia sale de un `grep` de su ID en
`openspec/changes/`.

**Tres hitos:** cargar el catálogo real —que **no** espera a `crearOrden`—,
atender pedidos —que sí, y cuyos requerimientos se escriben con el spec de
`crearOrden`— y curar la vidriera.

⚠️ **Planificar encontró siete cosas que ningún documento sabía.** Las tres que
más pesan:

1. **Una foto subida desde el panel llega cruda**, y la vidriera espera WebP
   recortado: hoy ese recorte lo hace sólo el seed, con `sharp`.
2. **Las reglas de `ordenes` no validan la transición de `estadoEntrega`**, y
   no dejan guardar ni el seguimiento ni el motivo de una entrega fallida.
3. **La reposición de stock y `crearOrden` escriben el mismo campo**: se
   diseñan juntas.

| Qué | Cómo |
|---|---|
| El mapa dice la verdad | **49** encabezados `HU-` en las épicas contra los 49 de la tabla, épica por épica; **0** IDs repetidos (control positivo del `uniq -d` al lado) y **0** referencias a historias que no existen |
| Los enlaces | **374** resuelven, anclas incluidas. **Control negativo:** un ancla inventada en ARQUITECTURA la rechaza el verificador, y la real con tilde pasa |

Son documentos: no se despliega nada.

### El checkout existe, y no cobra (2026-09-15)

**Nace `/pedido` — terminar la compra.** Quién lo recibe, a dónde va, cuánto
sale el envío y un botón `Ir a pagar` que **está apagado a propósito**:
`crearOrden` no existe, no hay preferencia de Mercado Pago y no hay webhook. El
porqué de cada decisión, en [ADR 010](architecture/decisions/010-el-checkout.md).
`/carrito` estrena su puerta: el botón sale **sólo con la caja cerrada**.

La forma la eligió el dueño **mirando dos maquetas navegables** con los vinos de
stage — *el remito* y *el mostrador*. Ganó el remito.

**Cuatro decisiones del dueño, y las cuatro cambian la pantalla:** envío a todo
el país más reparto propio en Punilla · **no hay retiro** · Mercado Pago desde
el día 0 · el envío **se suma** al precio.

⚠️ **Una de ellas borró una pantalla entera.** El glosario dice que una
dirección fuera de toda zona *"no puede comprar"* y `voz.md §9.3` tiene el texto
escrito. Con envío nacional **nadie queda fuera de zona**: `Zona` pasa a
significar *hasta dónde repartimos nosotros*. El glosario quedó desactualizado
(abajo, con disparador).

⚠️ **Y Mercado Pago borró otra: la de elegir cómo pagar.** Con Checkout Pro eso
pasa en la pantalla de ellos. Lo que sí aparecen son **tres finales y no dos**,
porque un pago puede volver `approved`, `rejected` **o** `in_process` — y ése ya
tenía su estado en la máquina (`en_proceso`, ADR 002).

⚠️ **El reparto propio nació apagado.** `REPARTIMOS_NOSOTROS = false`: hoy
**todo sale por correo**, Punilla incluida, porque el dueño decidió que *"de
momento no lo vamos a hacer nosotros"*. La modalidad `propio` queda escrita sin
uso y se prende con una línea. De paso **desactiva el peor de los números
inventados**: con el reparto prendido, un código postal mal puesto en la tabla
mandaba al reparto propio un pedido que había que despachar —no falla, sale más
barato y no llega—; apagado, lo peor que hace es prellenar mal una localidad.

**El puerto `ProveedorDeEnvio` nace en contratos con una sola implementación:
`CotizadorSimulado`, en `server/`, con números inventados y la forma real.** El
día del proveedor se reemplaza el cuerpo y la pantalla no se entera. La
investigación de los dos proveedores quedó escrita: **no es "Envíos Pack", es
[Envíopack](architecture/proveedores/enviopack.md)** (hay otra empresa con
nombre casi igual que hace paquetería a Cuba), y
[Mercado Pago](architecture/proveedores/mercado-pago.md) **ya no tiene
sandbox**: nunca usar `sandbox_init_point`.

⚠️ **SEIS defectos aparecieron mirando el PNG, y ninguno lo agarraba el diff**
—séptima vez en este proyecto—:

| Qué se vio | Por qué pasaba |
|---|---|
| **El botón salía sin texto**: un bloque borgoña vacío | `.boton` necesita su label en un `<span>` con z-index propio, o el relleno `::after` lo pinta encima. **Está escrito con una advertencia adentro de `boton.css`** y aun así lo repetí |
| **El botón apagado se veía encendido** | `.papel .boton::after` y `.boton[disabled]::after` empatan en especificidad y `papel.css` se importa después: ganaba el acento. La regla del apagado tuvo que mudarse a `papel.css` |
| **El precio salía ANTES del nombre** en cada opción de envío | `grid-row: 1` deja la columna al auto-placement. Las cuatro posiciones ahora son explícitas |
| **La localidad de un código postal anterior quedaba pegada** | Un pedido a 1425 seguía diciendo "Villa Giardino": la dirección mezclaba dos lugares |
| **"Cordoba", sin tilde**, en el selector de provincia | El paquete escribe sus comentarios sin acentos y se me contagió a una cadena **que lee un comprador** |
| **`9999` cotizaba como si existiera** | Con el cotizador simulado, cualquier número de 4 cifras era válido: el estado *"ese código postal no nos suena"* era **UI que nadie podía abrir**. Se le puso el rango argentino (1000–9431) para que se pueda disparar y probar |

**Verificado sobre `next build` + `next start` contra stage, con el carrito
sembrado en `localStorage`:**

| Qué | Cómo |
|---|---|
| Las rutas | `/pedido` da **200**; una ruta inventada, **404** |
| La home no se volvió ISR | `○ /` sin revalidate en la tabla del build, con `/vinos` y `/pedido` en `1m` como control |
| Punilla | `5176` → **una** opción (reparto propio), provincia `X` y localidad puestas solas |
| El resto del país | `1425` → **dos** opciones; a sucursal siempre más barata |
| Las cajas | 12 botellas cuestan **más** que 6 y **menos** que el doble, con test |
| El estado feo | `9999` → el aviso, **0** opciones, y el total vuelve a *falta la dirección* |
| El gate | `data-checkout-simulado` aparece **1** vez y el botón sale `disabled` |
| Teléfono | 390 px **emulados**: `scrollWidth = clientWidth = 390`, sin overflow |
| Tests y tipos | **143** de contratos (eran 121) + **30** de la tienda (eran 21); `tsc` 0 en los dos; arnés 35/35; 213 enlaces |
| Mirado | 1440 y 390 px, con los datos reales de stage |

### El vino se vende de a 6, y hay cajas armadas (2026-09-14)

**Nace la venta por caja.** El carrito tiene que sumar un múltiplo de
`BOTELLAS_POR_CAJA` botellas para poder cobrarse, el aviso se dice **antes de
agregar** —en el listado y en la ficha, sin JavaScript—, y `/vinos` estrena un
carril de **cajas armadas** que el vendedor ofrece. El porqué, en
[ADR 009](architecture/decisions/009-venta-por-caja.md).

⚠️ **LA REGLA TIENE UN LÍMITE DESDE EL 2026-09-15, y lo puso el dueño:** *"los
vinos que vienen en cajas se venden sueltos, tienen su propio packaging así que
pueden viajar solos: no cuentan para la caja de 6."* La cuenta sigue siendo en
botellas, pero **sólo sobre las sueltas** ([ADR 009
§10](architecture/decisions/009-venta-por-caja.md)). Cambia tres cosas que antes
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
[ADR 009 §9](architecture/decisions/009-venta-por-caja.md).

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

### El catálogo, la ficha y el carrito, en stage y sin cobrar (2026-09-11)

**Nacen `/vinos`, `/vinos/[slug]` y `/carrito`** sobre 20 vinos argentinos de
muestra en `bouquet-vinos` (stage), con las fotos en Storage. El modelo de stock
quedó hecho para no migrarlo cuando lleguen `crearOrden` y las cajas: `tipo`
inmutable, `stock` sólo del servidor y en unidades de venta, y la caja de 2 como
producto propio. El porqué, en
[ADR 008](architecture/decisions/008-catalogo-stock-y-carrito.md); los tokens del
papel, en [`tokens.md`](design/tokens.md), que por fin existe.

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
([ADR 008 §7](architecture/decisions/008-catalogo-stock-y-carrito.md)). Llevan
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

### Los tres paquetes del monorepo — CONFIGURACIÓN, no features (2026-09-03)

Existen y **compilan**: `apps/tienda` (Next.js), `apps/admin` (Flutter) y
`functions` (Cloud Functions, `nodejs24`). Más `firestore.rules`,
`storage.rules`, `firestore.indexes.json`, `firebase.json` y `.firebaserc`.

⚠️ **Es andamio a propósito.** No hay componentes, rutas, repositories ni
lógica de negocio. En la primera pasada se escribieron y **se borraron**: eran
las features de los pasos 4, 5 y 6 de
[ARQUITECTURA §12](../../ARQUITECTURA.md#12-orden-de-construcción), y su
momento es después de `/disenio` y por Workflow A. Lo único que sobrevive
además de la config es el **cableado del contrato**: el espejo del enum en
Dart (que `auditar_estados.mjs` verifica) y la frontera `apps/tienda/src/server/`.

**Proyecto Firebase: `bouquet-vinos`.** Firestore en **`southamerica-east1`**
(São Paulo) — verificado con `gcloud firestore databases list`, no con la
salida del comando de creación. **Esa ubicación no se puede cambiar nunca.**
Se eligió por latencia hacia Argentina; no afecta al comprador, porque la
vidriera cachea en el borde y no lee Firestore por visitante (ADR 004), pero sí
al panel del operador y a las functions.

**Runtime `nodejs24`**, que es el máximo que soporta Cloud Functions y calza
exacto con el Node local — leído del `firebase-tools` instalado, no supuesto.

### Lo que quedó abierto

| Qué | Por qué | Quién |
|---|---|---|
| ⚠️ **Seis preguntas del dueño cambian el backlog del panel** | Quién usa el panel, si entran ventas por fuera de la tienda, cómo se entra, por dónde enterarse de un pedido nuevo, si se despacha un pedido impago y cómo sale el aviso de despacho. Están en [`features/panel/overview.md`](features/panel/overview.md). La 2 decide si una épica entera (EP-10) sube al hito 2. **Disparador:** antes de escribir los requerimientos del hito 1, que dependen de la 1 y la 3. Desde 2026-09-16. | el dueño |
| ~~⚠️ **Las reglas nuevas NO están publicadas en `bouquet-vinos`**~~ **RESUELTO el 2026-09-14:** desplegadas con `firebase deploy --only firestore:rules,storage`. Verificado **con la API de Rules**, no con el mensaje del CLI: dos releases con la marca de tiempo del deploy, y el ruleset publicado contiene `cajasSugeridas` (control negativo: una colección inventada da 0). **Las fotos dan 200 `image/webp`.** ⚠️ Al medirlo, la API devolvió **403** por falta de quota project y mi primer script lo leyó como *"ningún release"* — el modo de falla exacto contra el que avisa `CLAUDE.md`. | el dueño |
| ⚠️ **SEXTO GATE: `/pedido` está armado y NO COBRA** | `EL_CHECKOUT_NO_COBRA = true` en `features/carrito/checkout/textos.ts`, y viaja al HTML como `data-checkout-simulado`, así que se chequea con `grep` en el repo **y** con `curl` en producción. Se apaga **sólo** cuando existan las tres cosas: `crearOrden`, la preferencia de Mercado Pago y su webhook verificando firma. CLAUDE.md: *un "Pagar" que llegue antes que su webhook es una venta que se cobra y no se registra*. **Disparador: bloquea el deploy.** Desde 2026-09-15. | el dueño + `functions` |
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

---

## Lo que está pendiente y por qué

Cada pendiente lleva **fecha** y **disparador**. §2.9: una nota escrita en el
momento T describe el estado en T, y nadie tiene el trabajo de volver en T+1 —
por eso los "pendiente de deploy" mienten por construcción.

La lista completa está en
[ARQUITECTURA §11](../../ARQUITECTURA.md#11-lo-que-queda-abierto-con-su-disparador).
Los cuatro que bloquean algo:

| Pendiente | Disparador | Desde |
|---|---|---|
| Proveedor de pagos | Cuando el dueño quiera cobrar online | 2026-09-01 |
| Requisitos legales de venta de alcohol online | Antes de la primera venta real | 2026-09-01 |
| Deploy desde tag en vez de rama | Antes del primer deploy que incluya cobro | 2026-09-01 |
| **Medir la purga de Cloudflare** — [ADR 005](architecture/decisions/005-hosting-vidriera.md) la razona, no la midió | El día que exista dominio | 2026-09-03 |
| **Licencia de las imágenes de la landing** | Antes de publicar el dominio | 2026-09-03 |
| ⚠️ **La venta por caja Y AHORA EL CHECKOUT viajan de POLIZÓN**: están commiteados y **no desplegados**. Seis gates siguen abiertos — el sexto es `EL_CHECKOUT_NO_COBRA`, arriba — más puerta de edad, contacto provisorio, licencias de assets, 391 KB de fuentes y el tramo 4 de Cloudflare. El día que se despliegue `tienda` **se publica también esto**, porque el deploy de front reconstruye desde el HEAD pusheado, no desde el cambio de ese día. Antes de publicar: correr el seed de `cajasSugeridas/publicas` en el proyecto que corresponda —sin ese documento el carril no se renderiza, que es el modo de falla silencioso— y verificar con `curl` el aviso y el carril, con control positivo y negativo | El primer deploy de `tienda`, sea por el motivo que sea | 2026-09-14 |

---

## Antes de creerle a este archivo

- **Un job verde no prueba que compiló; el artifact sí.**
- **Un `Deploy: success` no prueba que publicó; la lista de jobs sí.**
- **Antes de creer que una feature existe, grepeá quién la abre**, no si está
  escrita. Pasó cuatro veces en seis meses en el proyecto anterior.
- **Ante cualquier "¿esto está desplegado?", auditá producción**, no este
  archivo.
