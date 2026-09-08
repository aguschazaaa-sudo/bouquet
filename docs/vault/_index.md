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

**Fase: `main` ya tiene la home elegida (2026-09-08). Backend: todavía nada.**

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

### La composición elegida: la de cuatro escenas, y `main` la tiene (2026-09-08)

**El dueño eligió entre las seis composiciones que llegaron a existir, y ganó la
segunda:** [`landing-alternativa.md`](design/landing-alternativa.md) — cuatro
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

### Una segunda landing, en su propia rama (2026-09-04)

> ⚠️ **Escrito antes de la decisión. Esta es la que ganó**, y desde el
> 2026-09-08 no está en su propia rama: está en `main`. Lo de abajo cuenta de
> dónde salió; el estado de hoy es la entrada de arriba.

**El dueño no quedó convencido de [`escenas.md`](design/escenas.md)**, así que
hay una composición que compite con ella:
[`design/landing-alternativa.md`](design/landing-alternativa.md), **construida y
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
revirtió. Detalle y tabla en [`landing-alternativa.md §5.1`](design/landing-alternativa.md).

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

### Lo que quedó abierto

| Qué | Por qué | Quién |
|---|---|---|
| ⚠️ **La home NO tiene puerta de edad, y es la única pieza legal obligatoria** | [ARQUITECTURA §9.5](../../ARQUITECTURA.md#95-alcohol-y-edad) la exige, y es requisito de **arquitectura**: no se va con la composición que se descarta. Las composiciones 4 y 6 sí la construyeron (`PuertaDeEdad.tsx` + `puerta.css`, en `home-parallax-c` y `-d`); **la que ganó se escribió antes de que ese requisito bajara a código**. ⚠️ No se copia y pega: su diseño es decisión de composición y el de `-d` está dibujado con el cartucho del libro túnel. **Disparador: bloquea el deploy.** Desde 2026-09-08. | el dueño + `tienda` |
| ⚠️ **`/vinos` no existe y la home lo apunta DOS veces** | `EscenaSeleccion.tsx:69` y `EscenaMesa.tsx:60` — **los dos CTA duros de la página**, el de "qué tenés" y el de cierre. Hoy tiran **404**. No se arregla como página suelta: el catálogo es el **paso 5** del orden de construcción. **Disparador: bloquea el deploy.** Una landing cuyos dos botones no llevan a ningún lado es "terminada y sin puerta". Desde 2026-09-08. | el usuario |
| ⚠️ **Los 8 assets están commiteados y no tienen `LICENCIAS.md`** | `ambiente`, `botella`, `cava-h/v`, `mesa-h/v`, `rack-h/v`. La única tabla de licencias verificada que existió es la de los **17 assets de `home-parallax-b`**, y **no cubre a éstos**. De esta misma tanda salió la foto con marca de agua `Unsplash+` tileada, que se descubrió **abriendo el PNG**, no leyendo metadatos. `scripts/assets/traer_landing.py` es la herramienta. **Disparador: antes del deploy.** Desde 2026-09-08. | el dueño |
| **391 KB de `woff2` en la primera pantalla, y son de esta composición** | `parallax.md §8` fija **450 KB** para la primera pantalla en móvil: es el único presupuesto que paga el comprador, y arranca con el **87 % gastado antes de la primera imagen**. Salen de `layout.tsx` (Fraunces con `SOFT`+`WONK`+`opsz`, Newsreader roman e itálica con `opsz`). ⚠️ **Medido el 2026-09-08: el arreglo conocido NO sirve acá.** La composición 6 los bajó a **138 KB** sacando `SOFT` y `opsz`, y ésta usa las dos cosas (`font-variation-settings: 'SOFT' 22` en `sistema.css`, itálica de Newsreader en 4 lugares): sacarlos **cambia el dibujo de la página que se eligió mirando**. La palanca es del dueño. **Disparador: antes del deploy.** Desde 2026-09-08. | el dueño |
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
