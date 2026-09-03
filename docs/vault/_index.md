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

No existe todavía `apps/`, `functions/` ni `firestore.rules`.

**Node 24 corre TypeScript sin transpilar**, así que el paquete tiene **cero
dependencias de test** (ni jest, ni vitest, ni ts-node). La única dependencia
del repo es `typescript`, para `tsc --noEmit`. En una máquina de 7,9 GB eso no
es un detalle de gusto.

Lo próximo es el **paso 2** de
[ARQUITECTURA §12](../../ARQUITECTURA.md#12-orden-de-construcción):
`firestore.rules` e índices, antes de que haya datos.

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
vidriera usa ISR y no lee Firestore por visitante (ADR 004), pero sí al panel
del operador y a las functions.

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

### Lo que quedó abierto

| Qué | Por qué | Quién |
|---|---|---|
| **Los hooks no están vivos todavía** | `.claude/` no existía cuando arrancó la sesión, así que el watcher de settings no lo observa. Hay que abrir `/hooks` una vez, o reiniciar. **Verificado: un Write a `packages/contratos/src/` NO fue bloqueado.** | el usuario |
| **`suite_ts` y `suite_dart` nunca corrieron** | Un push a `main` dispara `alcance=rapido`, que **no corre tests**: las dos salen `skipped`. Las suites de `packages/contratos` jamás se ejecutaron en CI. **Disparador:** antes del próximo cambio de lógica, `gh workflow run ci.yml -f alcance=tests`. Desde 2026-09-03. | el usuario |

---

## Decisiones vigentes

| # | Decisión | ADR |
|---|---|---|
| 001 | Vidriera Next.js en Vercel · panel Flutter en Firebase Hosting · backend Firebase | [001](architecture/decisions/001-stack.md) |
| 002 | La Orden tiene **dos ejes** de estado (pago y entrega), no uno | [002](architecture/decisions/002-estados-de-orden.md) |
| 003 | Proveedor de pagos **diferido**; el contrato del webhook está escrito | [003](architecture/decisions/003-pagos.md) |
| 004 | Frescura por revalidación on-demand · filtrado del catálogo **en memoria** | [004](architecture/decisions/004-frescura-y-lecturas.md) |

---

## Lo que está pendiente y por qué

Cada pendiente lleva **fecha** y **disparador**. §2.9: una nota escrita en el
momento T describe el estado en T, y nadie tiene el trabajo de volver en T+1 —
por eso los "pendiente de deploy" mienten por construcción.

La lista completa está en
[ARQUITECTURA §11](../../ARQUITECTURA.md#11-lo-que-queda-abierto-con-su-disparador).
Los tres que bloquean algo:

| Pendiente | Disparador | Desde |
|---|---|---|
| Proveedor de pagos | Cuando el dueño quiera cobrar online | 2026-09-01 |
| Requisitos legales de venta de alcohol online | Antes de la primera venta real | 2026-09-01 |
| Deploy desde tag en vez de rama | Antes del primer deploy que incluya cobro | 2026-09-01 |

---

## Antes de creerle a este archivo

- **Un job verde no prueba que compiló; el artifact sí.**
- **Un `Deploy: success` no prueba que publicó; la lista de jobs sí.**
- **Antes de creer que una feature existe, grepeá quién la abre**, no si está
  escrita. Pasó cuatro veces en seis meses en el proyecto anterior.
- **Ante cualquier "¿esto está desplegado?", auditá producción**, no este
  archivo.
