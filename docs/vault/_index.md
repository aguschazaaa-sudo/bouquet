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

**Fase: pasos 0 y 1 terminados (2026-09-01). Todavía no hay UI ni backend.**

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

Lo próximo es el **paso 2** de
[ARQUITECTURA §12](../../ARQUITECTURA.md#12-orden-de-construcción):
`firestore.rules` e índices, antes de que haya datos.

### Una segunda landing, en su propia rama (2026-09-04)

**El dueño no quedó convencido de [`escenas.md`](design/escenas.md)**, así que
hay una composición que compite con ella:
[`design/landing-alternativa.md`](design/landing-alternativa.md), **construida y
navegable** en la rama `home-parallax`. ⚠️ **Sin mergear y sin desplegar.**

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
[`voz.md §10.2`](design/voz.md)**, enterrado en un ejemplo.

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
scroll: **13,48 → 13,31:1**, variación de **0,17 puntos**. El control negativo
—la misma foto, sin scrim— varía **3 veces más**. Y con `prefers-reduced-motion`
el `scrollHeight` es **idéntico** (5278 px): no hay pin, así que no existe el
peor defecto de `escenas.md §4.3`.

⚠️ **Los seis vinos son INVENTADOS.** `grep -rn LA_SELECCION_ES_DE_MUESTRA`:
mientras dé `true`, esto no se publica.

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

[`design/parallax.md`](design/parallax.md) — el informe de parallax, con las
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
[ADR 005](architecture/decisions/005-hosting-vidriera.md). Lo caro no es mover
el deploy: **App Hosting no tiene purga on-demand**, y esa era la pieza que
sostenía la frescura del precio de [ADR 004](architecture/decisions/004-frescura-y-lecturas.md).
La repone **Cloudflare, que sí tiene purga por tag en todos los planes**. El
diseño resultante **no usa ISR**: SSR + caché de borde, TTL largo donde hay
purga y TTL corto donde no la hay. **El presupuesto de lecturas no se movió:
~1.700/día, y que no se moviera es la prueba de que el ADR está bien.**

**Y ya existe la dirección visual**, que es lo que `parallax.md` declaraba
faltante: [`design/direccion.md`](design/direccion.md), el **paso 1 de
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

**Y existe la mitad verbal:** [`design/voz.md`](design/voz.md), con su agente
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

**Y ya existe la composición:** [`design/escenas.md`](design/escenas.md), el
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

### Lo que quedó abierto

| Qué | Por qué | Quién |
|---|---|---|
| **Los hooks no están vivos todavía** | `.claude/` no existía cuando arrancó la sesión, así que el watcher de settings no lo observa. Hay que abrir `/hooks` una vez, o reiniciar. **Verificado: un Write a `packages/contratos/src/` NO fue bloqueado.** | el usuario |
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

---

## Antes de creerle a este archivo

- **Un job verde no prueba que compiló; el artifact sí.**
- **Un `Deploy: success` no prueba que publicó; la lista de jobs sí.**
- **Antes de creer que una feature existe, grepeá quién la abre**, no si está
  escrita. Pasó cuatro veces en seis meses en el proyecto anterior.
- **Ante cualquier "¿esto está desplegado?", auditá producción**, no este
  archivo.
