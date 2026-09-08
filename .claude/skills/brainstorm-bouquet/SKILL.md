---
name: brainstorm-bouquet
description: El encaje de la skill `brainstorming` (obra/superpowers) en el sistema de spec de bouquet — clasifica en los cinco workflows A/B/C/D/E en vez de los tres caminos de upstream, y aterriza en `openspec/changes/`, no en `docs/superpowers/specs/`. Leer SIEMPRE junto con `brainstorming`, antes de cualquier trabajo creativo.
---

# brainstorm-bouquet

## Por qué existe esto (NO REVERTIR)

`brainstorming` es del ecosistema, está declarada en `skills-lock.json` con su
hash y **se actualiza sola**. Este archivo es la parte que es *nuestra*: por eso
vive committeado al lado, y no adentro de aquélla.

`SKILLS-AGENTES-MCP.md` §3.5 fija la regla —*"en `.claude/skills/` del repo va
sólo lo que menciona tu dominio, tus rutas o tus decisiones"*— y nombra a
`brainstorming` como una de las 5 skills que PadelPunilla vendorizó y quedaron
congeladas en la versión del día que se copiaron.

**Editar el `SKILL.md` de upstream para adaptarlo pierde dos veces:**

1. Se pierde en cualquier clon — `.claude/skills/*` está gitignoreado.
2. Lo pisa el próximo `skills update` — su hash está en el lock.

Se midió antes de escribir esto, no se supuso.

⚠️ **`WORKFLOWS.md` §4 invocaba `/brainstorming` en el paso A·2 desde `v0.3.0`
y la skill no existía.** Se instaló el 2026-09-07. Es la misma clase de agujero
que cerró `9f93aab` ("las cuatro piezas que los documentos invocaban y no
existían"): había una quinta, y era ésta.

## Este archivo GANA sobre el texto de upstream

Cuando los dos digan cosas distintas, **gana éste**. Es la misma regla por la
que el ADR 005 le gana a `parallax.md §11`: una decisión del proyecto vive en el
documento del proyecto, no en un informe de terceros.

| Upstream dice | Acá vale |
|---|---|
| Escribir el diseño en `docs/superpowers/specs/YYYY-MM-DD-<topic>-design.md` | **`openspec/changes/<id>/`**, vía `/opsx:propose`. Ese directorio no existe en este repo y no se crea |
| *"the ONLY skill you invoke after brainstorming is writing-plans"* | **`/opsx:propose`.** `writing-plans` estaba en el paso A·3 del workflow de PadelPunilla (`WORKFLOWS.md` §1) y **§4 lo sacó a propósito**: el plan es `tasks.md`, y lo genera opsx |
| Tres caminos: spike / bounded / architectural | **Cinco workflows: A, B, C, D, E** — ver abajo |
| *"Commit the design document to git"* | La skill **`/commit`**: stage explícito, semver en el asunto, sin `--no-verify`, **no taggear** |
| El estado terminal es el plan o la implementación | El estado terminal es **verificar producción**. Archivar es el paso **10**, después de verificar |
| *"TDD applies"* en el camino bounded | `flutter test`, `flutter analyze` y `npx jest` están **prohibidos en esta máquina** (7,9 GB). El CI corre por alcance |
| *"Explore project context — files, docs, recent commits"* | **Leer `docs/vault/_index.md` y el ADR de lo que vas a tocar.** El hook `vault-precheck` lo bloquea si no |
| Ofrecer el visual companion (server node en el browser) | **`/disenio`**, que ya existe y define tokens y dirección. Ver "Lo visual" abajo |
| Artefactos en inglés | **Español.** `openspec/config.yaml`: *"All artifacts must be written in es"*. Dominio en español, infraestructura en inglés |

Lo que **no** se toca de upstream, porque es lo bueno: el `<HARD-GATE>`, el
trinquete de una sola vía, la tabla de banderas rojas y el anti-patrón *"esto es
demasiado simple para necesitar aprobación"*. La ceremonia escala con la tarea;
**la aprobación nunca**.

## Los cinco workflows, no los tres caminos

Clasificá y **decí la clasificación en voz alta** antes de la primera pregunta,
para que el dueño pueda corregirte. La definición completa de cada uno está en
[`WORKFLOWS.md`](../../../WORKFLOWS.md) §4 y §5.

| Upstream | Acá | Qué produce |
|---|---|---|
| **Spike** | **C — exploración** → `/opsx:explore` | Una respuesta, no código. Cero artefactos, y por eso es el que menos deuda genera |
| **Bounded** | **B — cambio menor**, o **E** si el tripwire no toca nada empaquetado | Sin documento de plan. Termina en deploy y **verificación** |
| **Architectural** | **A — feature nueva** → `/opsx:propose` | Los artefactos de opsx: `proposal.md`, `specs/`, `design.md`, `tasks.md` |
| *(no existe)* | **D — toca plata** | Formal SIEMPRE |
| *(no existe)* | **E — no llega solo a producción** | Un polizón anotado |

### El override que upstream no puede tomar: la plata

El trinquete de upstream sube de camino cuando aparece complejidad oculta. **No
conoce el eje del dinero**, así que llamaría "bounded" a un cambio de rótulo de
precio.

> **Si el cambio toca cobros, stock o precios es D, sin importar cómo clasificó.**
> `WORKFLOWS.md` §4: *"Ningún cambio de plata pasa por Workflow B. No importa lo
> chico que parezca."* La ronda que "sólo cambiaba un rótulo" terminó
> descubriendo que un estado tenía cinco rutas de entrada y dos nacían finales.

En D, `revisor-pagos` es **obligatorio**, y la UI que ofrece pagar sale **después**
de que su backend esté verificado. Un "Pagar" que llegue antes que su webhook es
una venta que se cobra y no se registra.

### La frontera B/E se decide con un `grep`, no con criterio

Upstream no tiene el concepto de un cambio que **viaja de polizón** en el deploy
de otro. Acá lo tiene, porque el deploy de front reconstruye desde el HEAD
pusheado y arrastra todo lo mergeado.

```bash
git diff --name-only main... \
  | grep -vE '^(scripts/|docs/|\.github/|\.claude/|\.gitignore$|\.gitattributes$|skills-lock\.json$|.*\.md$)'
```

Si devuelve **cualquier cosa**, es **B** y le corresponde deploy y verificación.
Si no devuelve nada, es **E** y hay que anotar el polizón. La pregunta es
mecánica: *¿el diff toca algo que se empaqueta?* Y por eso aguanta la presión de
un viernes.

⚠️ `package.json` es el caso con filo: sólo el `"version"` sigue siendo E;
`dependencies` o `scripts` es B, sin discusión.

## Campo obligatorio que upstream no pide: el presupuesto de lecturas

`CLAUDE.md`: *"Antes de proponer algo que agregue lecturas a Firestore,
cuantificá el costo"* contra la cuota de **50.000/día**. Es un **campo
obligatorio del ADR**, no una nota al pie.

En el paso A·3, corré el agente **`presupuesto-lecturas`** antes de cerrar la
propuesta. No puede escribir código: sólo contesta cuántas lecturas cuesta.

Encuadre vigente: [ARQUITECTURA §6.3](../../../ARQUITECTURA.md#63-el-presupuesto-completo).

## Lo visual: `/disenio`, no el companion del browser

Antes de escribir componentes visuales corré **`/disenio`** — la dirección y los
tokens salen antes que el primer widget, no después del décimo. Y antes de que
un texto llegue a una pantalla que ve un comprador, pasalo por **`voz`**.

El visual companion de upstream levanta un server node y abre una pestaña. En
una máquina de 7,9 GB y 4 núcleos eso compite con el editor (1,15 GB) y con
Chrome (761 MB). **Si hace falta ver algo, maquetalo y miralo**: los defectos que
importaron en este repo aparecieron abriendo el PNG de una captura, no leyendo
el código.

## Antes de cerrar

Upstream no tiene el concepto de **puerta**. Acá es la falla más repetida del
proyecto anterior — cuatro features declaradas completas que nadie podía abrir,
una decía *"59/59 completa"*.

- **`cazador-de-puertas`** antes de cerrar cualquier tarea. Lo que nadie
  referencia no está entregado, está escrito.
- **`post-task-doc`**: decisión → ADR; estado → `_index.md`, tope 5; pendiente
  → con fecha y disparador.
- **`/commit`**, leyendo el diff en conversación.
- Y después **deploy** (reglas → functions → front) y **verificar**, que es
  donde termina el workflow. Recién ahí, `/opsx:archive`.

> **Un proceso produce exactamente lo que dice su último paso.** Si termina en
> "commit", produce commits sin deploys, de forma fiable. Por eso el último paso
> de acá no es el diseño aprobado: es producción verificada.
