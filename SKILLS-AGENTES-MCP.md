# Skills, agentes y MCP — qué es cada cosa, qué se ejecuta y qué portar

> Cuarto documento del export. Cubre la capa `.claude/` de PadelPunilla: 14
> skills, 12 "agentes", 14 hooks y 2 servidores MCP.
>
> **El hallazgo que ordena todo el documento:** de esas cuatro familias, **sólo
> los hooks y el CI hacen cumplir algo**. Las otras tres describen. Y en este repo
> hay piezas nombradas como si hicieran cumplir, que no.

---

## 1. La escalera de enforcement

Antes del inventario, el marco. Hay **seis** niveles de "regla" en Claude Code, y
se distinguen por una sola pregunta: **¿qué pasa si Claude la ignora?**

| # | Mecanismo | Dónde vive | Si Claude la ignora… | ¿Hace cumplir? |
|---|---|---|---|---|
| 1 | `CLAUDE.md` | raíz del repo | nada | ❌ describe |
| 2 | **Skill** | `.claude/skills/*/SKILL.md` | nada | ❌ describe |
| 3 | **Slash command** | `.claude/commands/**.md` | nada | ❌ describe |
| 4 | **Subagente real** | `.claude/agents/*.md` | **no puede** — el `tools:` del frontmatter le saca la herramienta | ✅ estructural |
| 5 | **Hook** | `settings.json` → script | **exit 2 bloquea la escritura** | ✅ mide el resultado |
| 6 | **CI** | GitHub Actions | **rompe el build** | ✅ y sobrevive a la máquina local |

**PadelPunilla tiene 1, 2, 3, 5 y 6. No tiene 4.** Y ahí está el problema: sus
"agentes" están escritos con la retórica del nivel 4 (`CANNOT touch: */data/`) y
viven en el nivel 3.

> **La regla que se lleva al proyecto nuevo:** cuando escribas una prohibición,
> preguntate en qué nivel la estás poniendo. Si la prohibición importa de verdad,
> el nivel 3 no alcanza.

---

## 2. Los "agentes" no son agentes

### 2.1 El hallazgo

```bash
ls -d .claude/agents/        # → No such file or directory
ls .claude/commands/agents/  # → 12 archivos .md
```

Los 12 `/agents:*` de este repo son **slash commands**: archivos markdown que se
**inyectan como prompt en la conversación principal**. No tienen contexto aislado,
no tienen lista de herramientas restringida, y no hay nada que los distinga de
haber pegado ese texto a mano.

Cada uno declara su alcance con esta forma:

```markdown
# Agent: Presentation Layer
**CAN touch:** */presentation/ — pages, widgets, UI-only code
**CANNOT touch:** */data/, */domain/, test/
```

**Ese `CANNOT touch` es una frase, no un permiso.** El mismo modelo que lee "no
puedo tocar `data/`" tiene la herramienta `Edit` apuntando a todo el repo.

### 2.2 La consecuencia, medida

`/agents:presentation` prohíbe en su texto que un widget hable con Firebase. Y sin
embargo `PerfilPhotoPicker` importa `cloud_firestore` **y** `firebase_storage`
**desde el commit inicial** — porque el hook `layer-boundary.sh`, que es el nivel
5, sólo bloquea que presentación importe `*/data/*`, **no el SDK**.

O sea: la regla existía en el nivel 3 (donde no se aplica) y no existía en el
nivel 5 (donde sí). El resultado es un widget que construye
`FirebaseStorage.instance` inline y **por eso no se puede testear sin
refactorizarlo** — un costo real que salió de una prohibición escrita en el lugar
equivocado.

### 2.3 Qué son buenos igual

No los tires. Como **checklists inyectables** valen: `/agents:presentation` tiene
9.682 bytes de reglas concretas de este proyecto (cuándo `autoDispose`, cómo
partir providers, qué hace `layer-boundary` y por qué). Es documentación
accionable en el momento correcto.

Lo que hay que cambiar es **el nombre y la expectativa**. Un archivo que dice
"Agent" y "CANNOT touch" te hace creer que hay una barrera.

### 2.4 Cómo portarlos bien

Dos opciones, y elegí una a conciencia:

**Opción A — convertirlos en subagentes reales** (`.claude/agents/*.md`), con
frontmatter que restrinja las herramientas:

```markdown
---
name: admin-presentation
description: Presentación del panel admin (Flutter). Widgets, páginas, providers de estado.
tools: Read, Grep, Glob, Edit, Write
model: sonnet
---
Sos el especialista de la capa de presentación del panel admin.
…
```

Ganás aislamiento de contexto y una lista de herramientas real. Perdés el hilo de
la conversación (arrancan en frío) y pagás tokens por el arranque.

**Opción B — dejarlos como slash commands y sacarles la retórica de permiso.**
Renombrar `CANNOT touch` por `Fuera de alcance — si hay que tocarlo, decilo y
cambiá de checklist`. Y **mover cada prohibición que importe a un hook**.

> **Mi recomendación para la tienda de vinos: B para los checklists de capa, A
> para uno solo — el de la vidriera en React.** Razón: en un monorepo con dos
> front-ends, el riesgo real es que un cambio de catálogo toque los dos a la vez
> sin querer. Ese sí merece contexto aislado.

---

## 3. Las 14 skills: qué hace cada una y qué portar

| Skill | Qué hace | ¿Se usó? | Portar |
|---|---|---|---|
| `commit` | Último paso: stage + semver + Conventional Commit | **sí, siempre** | ✅ tal cual |
| `post-task-doc` | Actualiza el vault después de cada tarea | **sí, siempre** | ✅ tal cual |
| `obsidian-context` | Carga el vault antes de tocar código | sí | ✅ adaptada |
| `obsidian-indexer` | **Genera** el vault desde el código | **no se corre** | ⚠️ ver §3.3 |
| `design-review` | Audita UI: responsive, a11y WCAG AA, copy, visual | sí (diagnóstico del panel) | ✅ para el admin |
| `flutter-atomic-guard` | Valida composición hoja→componente→sección→página | ocasional | ✅ |
| `flutter-clean-layer` | Valida fronteras de capa | ocasional | ✅ |
| `review-decouple` | Review enfocado en acoplamiento | **sólo a pedido** | ⚠️ ver §3.4 |
| `brainstorming` | Explora intención antes de implementar | sí (Workflow A) | ✅ |
| `openspec-propose` / `-apply` / `-archive` / `-explore` | El flujo formal | **desbalanceado** | ⚠️ ver `WORKFLOWS.md` |
| `find-skills` | Descubre skills instalables | genérica | ❌ no vendorizar |
| `skill-creator` | Crea/edita/mide skills | genérica | ❌ no vendorizar |

### 3.1 Las dos que valen más que todas las demás juntas

**`commit`** y **`post-task-doc`**. No porque sean sofisticadas —tienen 89 y 56
líneas— sino porque **se ejecutan siempre**. Una skill que corre en cada tarea
moldea el proyecto; una que corre cuando alguien se acuerda, no.

`commit` además carga su propio "por qué" adentro, y eso es lo que la hace
sobrevivir: explica que reemplazó a un watcher que corrompió `.git/index` y costó
5 días de trabajo. **Una regla con su cadáver adjunto no se revierte por
comodidad.**

> **Patrón para el proyecto nuevo:** toda skill que codifique una decisión dolorosa
> lleva una sección "Why this exists (do not regress)" con la fecha y el daño.

### 3.2 `design-review` es la más subestimada

200 líneas que auditan cuatro pilares a la vez: crítica visual, copy,
accesibilidad WCAG 2.1 AA y responsive. Fue lo que produjo el diagnóstico del
panel de admin —y de paso encontró **un agujero de seguridad**: las reglas
permitían que el creador de una Reserva mutara su propio `estado`, o sea que un
jugador podía auto-confirmarse salteando la aprobación del club.

**Que una skill de "revisión de diseño" encuentre un bug de autorización no es
casualidad:** revisar una pantalla en serio obliga a preguntarse quién puede
apretar cada botón.

**En la tienda de vinos** esta es la skill que más rinde, porque el panel de admin
lo usa gente no técnica y la vidriera la usa gente que puede irse.

### 3.3 `obsidian-indexer` existe y no se corre — y ese es el bug

Genera el vault **desde el código**: índices de features, catálogo de widgets,
glosario, mapas de dependencias. Es exactamente el antídoto al modo de falla #2 de
`DIAGNOSTICO.md` (el vault documenta la intención, no el comportamiento).

**Está escrita y nadie la ejecuta.** Por eso el vault dijo cuatro veces que una
feature estaba entregada cuando no tenía puerta.

> **Arreglo para el proyecto nuevo: lo generado no puede depender de que alguien
> invoque una skill.** Corré el indexer **en CI**, escribí la salida a
> `docs/vault/_verdad.md` y subila como artifact. Una skill que hay que acordarse
> de correr tiene la misma tasa de ejecución que una nota mental.

### 3.4 `review-decouple` y el punto ciego que dejó

Detecta dependencias entre features, widgets que saben demasiado, providers
acoplados. Se corre a pedido — y por eso no vio las **tres implementaciones
copiadas** de la misma búsqueda por trigramas, idénticas hasta en una clase
privada interna.

**Duplicación semántica es lo que ningún hook puede medir** (los hooks miran un
archivo por vez) y lo que un review a pedido no alcanza a ver. Es el caso donde
una **skill corrida periódicamente** —no por tarea, sino una vez por semana sobre
el repo entero— es la herramienta correcta.

### 3.5 No vendorices las skills genéricas

`find-skills` (142 líneas) y `skill-creator` (485) son skills **del ecosistema**,
no de este proyecto. Copiadas dentro de `.claude/skills/` quedan congeladas en la
versión del día que se copiaron y no se actualizan nunca.

> **Regla: en `.claude/skills/` del repo va sólo lo que menciona tu dominio, tus
> rutas o tus decisiones.** Todo lo demás va como skill de usuario o de plugin.

Con ese criterio, de las 14 skills de PadelPunilla **9 son legítimamente del
proyecto** y 5 son ecosistema vendorizado (`find-skills`, `skill-creator`,
`brainstorming` y las 4 de OpenSpec — estas últimas discutibles, porque están
adaptadas).

---

## 4. MCP: dos servidores, dos lecciones opuestas

### 4.1 Firebase MCP — configurado, y no conecta

**Está declarado como plugin** (`firebase@firebase` en `~/.claude.json`), **no en
el repo**. No hay `.mcp.json`. Consecuencias:

1. **No es portable.** Un clon del repo en otra máquina no lo trae. Nadie que lea
   `CLAUDE.md` —que dice *"Use Firebase MCP for reading Firebase project state"*—
   puede saber cómo obtenerlo.
2. **Falló dos veces en esta sesión** con `CONNECT_TIMEOUT` a los 30 s.
3. **Ya había costado antes.** El vault registra, en la ronda de localidades:
   *"Pendiente: correr `scripts/auditar_localidades.js` contra producción — **el
   Firebase MCP no conectó durante el change**, así que no hay conteo real
   todavía."* Una verificación quedó abierta porque la herramienta no levantó.

**Y acá está lo bueno:** el proyecto **igual pudo auditar producción**, porque
tiene el camino alternativo escrito (memoria `feedback_verificar_contra_produccion`):

```bash
firebase functions:list
gcloud firestore indexes composite list --format="value(state,fields)"
gcloud scheduler jobs list --location=us-central1
TOKEN=$(gcloud auth print-access-token)
curl -s -H "Authorization: Bearer $TOKEN" \
  "https://firestore.googleapis.com/v1/projects/<proj>/databases/(default)/documents/<col>/<doc>"
```

> **Lección: un MCP es una comodidad, no una dependencia.** Toda capacidad que
> llegue por MCP tiene que tener su equivalente en CLI escrito al lado. Si el
> servidor no levanta y no hay plan B, la tarea se detiene.

### 4.2 GitHub MCP — deshabilitado a propósito, y fue la decisión correcta

`CLAUDE.md` lo dice dos veces: *"For GitHub operations, use the `gh` CLI (no GitHub
MCP)"* y *"GitHub MCP is disabled"*.

**La evidencia de que estuvo bien:** prácticamente todas las lecciones de CI/CD del
export salieron de usar `gh` — y varias **dependen de leer la salida cruda**:

- `gh run view <id> --json conclusion,jobs` para ver que un job estaba `skipped`
  dentro de un run verde.
- `gh run view <id> --log | grep "functions\[<nombre>("` para verificar un deploy
  **por nombre de función**.
- Descubrir que `gh run watch --exit-status` **devuelve 0 en corridas canceladas**.

Ese último hallazgo es del tipo que sólo aparece cuando ves el exit code real. Una
capa que te devuelve "el run terminó bien" te lo esconde.

> **Regla: para lo que verificás, preferí la CLI cruda.** Para lo que explorás, el
> MCP es más cómodo. La verificación necesita ver el error tal como es.

### 4.3 Qué hacer en el proyecto nuevo

1. **`.mcp.json` en el repo**, no configuración por máquina. Lo que no está en el
   repo, el equipo no lo tiene.
2. **Firebase MCP para lectura**, con la confirmación explícita antes de cualquier
   escritura (lo que `CLAUDE.md` ya dice acá y está bien).
3. **`gh` CLI para GitHub**, sin MCP.
4. **Mercado Pago: sin MCP.** ⚠️ **EXTRAPOLADO** — la API de pagos se toca con
   `curl` y con el SDK en las Cloud Functions, y ahí querés ver el JSON exacto que
   devuelve. Es el caso extremo de §4.2: si un cobro sale mal, necesitás el cuerpo
   crudo de la respuesta, no un resumen.
5. **Escribí el plan B de cada MCP** en `CLAUDE.md`, al lado de la línea que lo
   recomienda.

---

## 5. El allowlist de permisos contradice a `CLAUDE.md`

Hallazgo aparte, y es de los que dan vergüenza porque son gratis de arreglar.

`CLAUDE.md` tiene una sección titulada **"PROHIBIDO correr en esta máquina"**:

> `flutter analyze`, `flutter test`, `flutter build` y los tests de `functions/`
> **NO se corren localmente. NUNCA.** […] un `flutter analyze` completo **pasó los
> 20 minutos sin terminar**.

Y `.claude/settings.local.json` tiene, en su lista de permisos **pre-aprobados**:

```json
"Bash(flutter test *)",
"Bash(flutter analyze *)",
"Bash(flutter build *)",
"PowerShell(flutter analyze *)",
"Bash(firebase deploy *)"
```

**Las cuatro primeras autorizan sin preguntar exactamente lo que el proyecto
prohíbe** — o sea que la única barrera real (el prompt de permiso, que le daría al
usuario la chance de decir "no") está desactivada justo para los comandos que
dejan la máquina inutilizable 20 minutos.

Y la quinta, `firebase deploy *`, autoriza a mano lo que el proyecto exige hacer
**sólo por workflow** — incluido `firebase deploy --only hosting`, que está
explícitamente prohibido porque dejó un release atascado el 2026-06-23.

> **Esto es la escalera de enforcement al revés.** El allowlist es nivel 5 (el
> harness lo aplica de verdad) y está configurado en contra de la regla del nivel
> 1. La configuración le gana al documento, siempre.

**Arreglo, 2 minutos:** sacar esas cinco entradas. Los permisos son residuo de
antes de que existiera el CI (abril–mayo); la regla es de agosto. Nadie los
revisó cuando la política cambió.

> **Regla para el proyecto nuevo: cada vez que agregues una prohibición a
> `CLAUDE.md`, grepeá el allowlist.** Una prohibición documentada con su comando
> pre-aprobado es peor que no tener la prohibición, porque genera confianza falsa.

---

## 6. Qué llevarse: la configuración mínima de la tienda de vinos

```
.claude/
  settings.json          # hooks — ver SETUP-PRIMERA-CORRIDA.md §2.9
  settings.local.json    # permisos — AUDITADO contra CLAUDE.md
  agents/                # ← subagentes REALES (el que no existe acá)
    vidriera.md          #   tools restringidas a apps/tienda/
  commands/
    checklists/          # ← los ex-"agentes", renombrados sin retórica de permiso
      admin-presentacion.md
      admin-datos.md
      functions.md
      contratos.md
  skills/
    commit/              # ✅ con su "Why this exists"
    post-task-doc/
    vault-context/
    vault-indexer/       # ✅ pero se corre en CI, no a mano
    design-review/       # ✅ la más subestimada
    review-decouple/     # ✅ semanal sobre el repo entero, no a pedido
.mcp.json                # ← EN EL REPO: firebase (lectura), nada más
```

### Checklist de "la capa .claude está sana"

- [ ] No hay ninguna prohibición importante que viva **sólo** en un prompt.
- [ ] Cada `CANNOT touch` está respaldado por un hook, o no dice "CANNOT".
- [ ] `settings.local.json` **no pre-aprueba** nada que `CLAUDE.md` prohíba.
- [ ] `.mcp.json` está versionado, y cada MCP tiene su plan B en CLI escrito.
- [ ] Toda skill que codifique una decisión dolorosa tiene su "Why this exists".
- [ ] Las skills genéricas del ecosistema **no** están vendorizadas en el repo.
- [ ] Lo que documenta el comportamiento (el indexer) **corre en CI**, no a mano.
