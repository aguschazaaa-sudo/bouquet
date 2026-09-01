# Setup: la primera corrida de Claude en el proyecto nuevo

> **Objetivo.** Que el día 1 del repo de la tienda de vinos arranque con la
> maquinaria que a PadelPunilla le costó seis meses armar, **sin heredar lo que
> ahí no funcionó** (ver `DIAGNOSTICO.md`).
>
> **Tiempo estimado:** 2-3 horas de setup antes de escribir la primera línea de
> producto. Suena mucho. En PadelPunilla, no tener esto costó ~5 días de trabajo
> perdido por un hook mal hecho, un release atascado, y tres features escritas que
> nadie podía usar.
>
> **Orden.** Los pasos están ordenados por dependencia. El paso 0 es el único que
> **no** se puede hacer después.

---

## Paso 0 — Antes de abrir Claude: tres decisiones que no se toman a mitad de camino

### 0.1 La forma del repo

La decisión de §1.1 de `LECCIONES.md` (vidriera en React, panel en Flutter)
implica un repo con dos front-ends. Definilo **antes**, porque todos los hooks y
los workflows se escriben contra estas rutas:

```
apps/
  admin/          # Flutter — panel de administración (web + Android)
  tienda/         # Next.js — vidriera pública, SSR/ISR
functions/        # Cloud Functions (TypeScript)
packages/
  contratos/      # tipos compartidos + máquina de estados de Orden (TS)
docs/
  vault/          # documentación viva
scripts/
  hooks/          # los hooks de Claude
  ci/             # verificadores
.github/workflows/
```

**El punto no negociable:** `packages/contratos/` tiene **una sola definición** de
los estados de una Orden y de las transiciones válidas. Las Cloud Functions la
importan directo; el admin en Flutter la espeja en un `enum` con **un test que
compara contra un JSON generado desde el TS**. Sin ese test, los dos lados se
desincronizan en la tercera semana y nadie se entera hasta que un webhook escribe
un estado que la app no sabe dibujar.

> **Por qué acá y no después:** en PadelPunilla los estados de Reserva quedaron
> repartidos entre Dart y TS, y la condición correcta para "entró en confirmada"
> hubo que **descubrirla** auditando 5 rutas distintas, meses después de que el
> primer trigger estuviera mal.

### 0.2 El nombre del remote

```bash
git remote -v   # que diga lo que creés que dice
```

**Evidencia de por qué esto está en el paso 0:** en PadelPunilla el remote se
llama `github`, y `origin` apunta a un repo que **no existe (404)**. `git push`
anda; `git push origin` falla. Eso confundió sesiones enteras.

Elegí `origin`, verificá que resuelve, y no tengas dos.

### 0.3 Qué NO se va a re-discutir

Escribilas ahora, en `CLAUDE.md`, sección "Decisiones tomadas". Si no están
escritas, Claude te las va a re-proponer cada dos semanas y vos vas a re-evaluarlas
cada vez:

- Estado en el admin: **Riverpod** (o lo que elijas) — no BLoC, no GetX.
- Backend: **Firebase**.
- Vidriera: **Next.js** (o Flutter, si decidís pagar el prerender).
- Pagos: **Mercado Pago** (o Ualá) — y **el webhook es idempotente por marcador**.
- Estructura **feature-first**, no por capas en la raíz.
- Composición **bottom-up**: del widget hoja a la página, nunca al revés.

---

## Paso 1 — `CLAUDE.md`

Este archivo se lee al inicio de **cada** sesión. Es el lugar más caro del repo en
tokens y el más valioso en efecto. Reglas para escribirlo:

- **Imperativo y corto.** "YOU MUST", tablas, listas. No prosa explicativa.
- **Todo lo que sea prohibición, decilo con su razón medida.** "No corras
  `flutter test` acá" se ignora; "no corras `flutter test` acá: medido, un solo
  archivo no completó en 7 minutos con 7,9 GB de RAM" no.
- **Termina en deploy, no en commit** (§3.1 de `LECCIONES.md`).

Plantilla mínima, adaptada a la tienda:

```markdown
# CLAUDE.md

## MANDATORY CHECKLIST — cada tarea

1. Leer `docs/vault/_index.md` antes de tocar código.
2. Después de cada tarea: actualizar `docs/vault/`.
3. Commit vía la skill `commit` (Claude decide el semver y el mensaje).
4. **Deploy** — un cambio commiteado NO es un cambio entregado.
5. Vault post-deploy: mover lo que salió de "pendiente" a "desplegado".

## PROHIBIDO correr en esta máquina
`flutter analyze` · `flutter test` · `flutter build` · `npx jest` de functions.
Causa medida: 7,9 GB de RAM totales, 0,4 GB libres. Todo va a paginación.
Un build local muere con `0xC0000005` (ACCESS_VIOLATION) del generador de
snapshots — no es un error del proyecto.

**Sí se corre local:** `dart format` · `tsc --noEmit` · `npm run dev` ·
`firebase emulators:start`.

## CI — elegí el alcance más chico que conteste la pregunta
| Pregunta | Comando | Costo |
|---|---|---|
| ¿Compila? ¿Pasan los lints? | `gh workflow run ci.yml -f alcance=rapido` | ~4 min |
| ¿Pasa la suite? | `gh workflow run ci.yml -f alcance=tests` | ~14 min |
| Todo menos builds | `gh workflow run ci.yml -f alcance=completo` | ~20 min |

Un push a `master` ya dispara `rapido` solo. NO encimes otra corrida.
⚠️ `rapido` NO corre tests. Si el cambio es lógica y no UI, dispará `tests`
a mano antes de tocar producción.

## Deploy — orden no negociable: reglas → functions → tienda/admin
| Tocaste | Objetivo |
|---|---|
| Sólo `apps/admin/` | `-f objetivo=admin` |
| `functions/` | `-f objetivo=functions` |
| `firestore.rules` / índices | `-f objetivo=reglas` |
| `apps/tienda/` | `-f objetivo=tienda` |

⚠️ El deploy de front **reconstruye desde el HEAD pusheado**: arrastra TODO lo
mergeado, no sólo tu cambio. Antes de publicar, preguntate qué más se mergeó.

## Verificación — no le creas al color
- Un job verde NO prueba que compiló; el artifact sí.
- Un `Deploy: success` NO prueba que publicó; la lista de jobs sí.
- `gh run watch` devuelve 0 en corridas CANCELADAS.
- Verificá por **hash de contenido** + **canario nuevo** + **control positivo**.

## Convenciones de lenguaje
Dominio en español: `Vino`, `Bodega`, `Varietal`, `Orden`, `Cliente`, `Despacho`.
Infraestructura en inglés: providers, repositories, services, widgets, hooks.

## Decisiones tomadas (no re-proponer)
[…las del paso 0.3…]
```

---

## Paso 2 — Los hooks

Los hooks son la única parte del sistema que **mide** en vez de describir. Portá
estos cuatro, **con las correcciones aplicadas**.

> **Nota importante:** el `PreToolUse` de PadelPunilla está roto — lee la bandera
> en la raíz del repo y su propio mensaje manda a escribirla en `.claude/`, así que
> una vez desbloqueado **no vuelve a frenar nunca**. La versión de abajo ya tiene
> la ruta unificada. Ver `DIAGNOSTICO.md` §"No funciona".

### 2.1 `scripts/hooks/_leer_ruta.sh` — helper compartido

Los 4 hooks de PadelPunilla repiten el mismo bloque de Python para sacar el
`file_path` del JSON del hook. Sacalo a un helper desde el principio:

```bash
#!/bin/bash
# _leer_ruta.sh — devuelve el file_path del input del hook, normalizado a /
leer_ruta() {
  local input="$1"
  local p
  p=$(echo "$input" | python3 -c "
import json, sys
try:
    print(json.load(sys.stdin).get('tool_input', {}).get('file_path', ''))
except Exception:
    print('')
" 2>/dev/null)
  echo "${p//\\//}"
}
```

### 2.2 HARD — `widget-size-guard.sh` (portar tal cual, adaptando rutas)

Bloquea archivos de presentación de más de 200 líneas. **Es el hook que más veces
tuvo razón** en PadelPunilla.

```bash
if [[ "$RUTA" == */apps/admin/lib/* && "$RUTA" == */presentation/*.dart ]]; then
  LINES=$(wc -l < "$RUTA" 2>/dev/null || echo 0)
  if [ "$LINES" -gt 200 ]; then
    echo "BLOCK: $RUTA tiene $LINES líneas (max 200). Partí el widget."
    exit 2
  fi
fi
```

**Excluí `test/` a propósito:** partir un suite de tests en dos para bajar de 200
líneas no arregla nada, sólo esconde la cobertura en más archivos.

### 2.3 HARD — `layer-boundary.sh` (portar **y ampliar**)

El de PadelPunilla bloquea tres cosas. Agregale la cuarta, que es el agujero real
que dejó pasar un widget hablando con Firestore desde el commit inicial:

```bash
# 1. domain no importa Firebase ni Flutter
if [[ "$RUTA" == */domain/*.dart ]] && \
   grep -qE "import.*cloud_firestore|import.*firebase_|import.*package:flutter/" "$RUTA"; then
  echo "BLOCK: domain debe ser Dart puro."; exit 2
fi

# 2. data no importa presentation
# 3. presentation no importa data

# 4. ← NUEVO: presentation no toca el SDK de Firebase directo
if [[ "$RUTA" == */presentation/*.dart ]] && \
   grep -qE "import.*package:(cloud_firestore|firebase_storage|firebase_auth|cloud_functions)" "$RUTA"; then
  echo "BLOCK: $RUTA usa el SDK de Firebase directo. Va por un repositorio."
  exit 2
fi
```

### 2.4 HARD — `no-hardcoded-colors.sh` (portar tal cual)

Cero tolerancia: `Color(0x…)`, `Color.fromARGB/fromRGBO/…`, `Colors.*`, todos
bloqueados fuera de los archivos del tema. **Sin excepciones para colores
"neutros"** — la excepción del gris es por donde se rompe un sistema de temas.

Excluí `*.g.dart`, `*.freezed.dart` y la carpeta del tema.

**Para la tienda en React**, el equivalente es bloquear hex literales fuera de los
tokens de diseño:

```bash
if [[ "$RUTA" == */apps/tienda/* && "$RUTA" != */tokens/* ]] && \
   grep -qE "#[0-9a-fA-F]{3,8}\b" "$RUTA"; then
  echo "BLOCK: color hardcodeado. Usá los tokens de apps/tienda/src/tokens/."
  exit 2
fi
```

### 2.5 HARD — `one-widget-per-file.sh` (portar tal cual)

Un widget público por archivo. Es lo que hace posible la composición bottom-up: si
un archivo puede tener tres widgets, "partir" un widget grande se hace con métodos
privados y no se parte nada.

### 2.6 NUEVO — `call-site-guard.sh` (SOFT, y es el que yo agregaría primero)

Ataca directo el modo de falla más caro de PadelPunilla: **la feature escrita que
nadie puede abrir** (§6 de `LECCIONES.md`, pasó **cuatro veces**).

```bash
#!/bin/bash
# call-site-guard.sh — SOFT: avisa si una clase nueva no la referencia nadie.
# Sale 0 SIEMPRE: es una advertencia, no un bloqueo (una clase recién creada
# legítimamente no tiene consumidores todavía).

[[ "$RUTA" == *.dart || "$RUTA" == *.tsx ]] || exit 0

BASE=$(basename "$RUTA")
# Clases públicas declaradas en el archivo
CLASES=$(grep -oE "^(class|abstract class) [A-Z][A-Za-z0-9_]*" "$RUTA" 2>/dev/null \
         | awk '{print $NF}')

for C in $CLASES; do
  HITS=$(grep -rn "\b$C\b" apps/ packages/ 2>/dev/null | grep -v "/$BASE:" | wc -l)
  if [ "$HITS" -eq 0 ]; then
    echo "AVISO: $C no la referencia nadie fuera de su propio archivo."
    echo "       ¿Tiene puerta? Si es una pantalla, ¿está en el router?"
  fi
done
exit 0
```

> **Por qué SOFT y no HARD:** el orden bottom-up hace que un widget hoja
> legítimamente no tenga consumidores durante los 10 minutos que tarda en
> escribirse el que lo compone. Un bloqueo ahí haría el flujo imposible. El aviso,
> en cambio, aparece justo cuando **cerrás la tarea sin haberlo cableado**.

### 2.7 SOFT — recordatorios

- `doc-reminder.sh` — avisa si cambió código sin cambiar `docs/vault/`.
- `commit-reminder.sh` — avisa si el árbol está sucio al terminar el turno.
  **Read-only. Exit 0. NUNCA escribe git.** Ver §9.1 de `LECCIONES.md`: escribir
  git desde un hook corrompió `.git/index` y costó 5 días de trabajo.

### 2.8 El gate del vault, **con la ruta unificada**

```bash
#!/bin/bash
# vault-precheck.sh — HARD (PreToolUse): frena la primera escritura de código
# hasta que se confirme que se leyó el vault.
#
# ⚠️ UNA SOLA RUTA. En PadelPunilla el PreToolUse leía la raíz y el Stop borraba
# la de .claude/ — o sea que el gate se desbloqueaba una vez y no frenaba nunca más.

FLAG="${CLAUDE_PROJECT_DIR:-.}/.claude/.vault-session-ok"   # ← misma ruta que borra el Stop

if [[ "$RUTA" == */apps/*/lib/* || "$RUTA" == */apps/tienda/src/* || "$RUTA" == */functions/src/* ]]; then
  if [ ! -f "$FLAG" ]; then
    cat << 'EOF'
CHECKPOINT — escritura de código bloqueada.

Antes de escribir código:
  1. Leé docs/vault/_index.md
  2. Leé el overview de la feature que vas a tocar

Para confirmar y desbloquear, escribí cualquier contenido en:
  .claude/.vault-session-ok
EOF
    exit 2
  fi
fi
exit 0
```

Y en el Stop hook, borrá **exactamente esa misma ruta**. Agregá las dos al
`.gitignore` sólo si querés, pero **usá una sola en el código**.

**Verificá que el gate funciona antes de confiar en él:**

```bash
rm -f .claude/.vault-session-ok
# pedile a Claude que edite un archivo de apps/admin/lib/ → tiene que bloquear
```

### 2.9 `.claude/settings.json`

```json
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Edit|Write",
        "hooks": [{ "type": "command", "command": "bash scripts/hooks/vault-precheck.sh" }] }
    ],
    "PostToolUse": [
      { "matcher": "Edit|Write",
        "hooks": [
          { "type": "command", "command": "bash scripts/hooks/widget-size-guard.sh" },
          { "type": "command", "command": "bash scripts/hooks/layer-boundary.sh" },
          { "type": "command", "command": "bash scripts/hooks/one-widget-per-file.sh" },
          { "type": "command", "command": "bash scripts/hooks/no-hardcoded-colors.sh" },
          { "type": "command", "command": "bash scripts/hooks/call-site-guard.sh" },
          { "type": "command", "command": "bash scripts/hooks/doc-reminder.sh" }
        ] }
    ],
    "Stop": [
      { "hooks": [
          { "type": "command", "command": "bash scripts/hooks/post-task-reminder.sh" },
          { "type": "command", "command": "bash scripts/hooks/commit-reminder.sh" }
        ] }
    ]
  }
}
```

---

## Paso 3 — La documentación viva (el "vault")

PadelPunilla usa un vault de Obsidian en `docs/vault/`. **La idea es correcta y la
ejecución envejeció mal** (ver `DIAGNOSTICO.md`). Portá la idea con tres reglas que
allá no existían.

### 3.1 La estructura

```
docs/vault/
  _index.md                    # dashboard: estado ACTUAL. Tope: 5 entradas.
  changelog/_log.md            # historial completo, append-only
  architecture/
    decisions/00N-*.md         # ADRs — una decisión por archivo
    patterns.md                # reglas verificadas empíricamente
  features/{feature}/overview.md
  domain/glossary.md           # Vino, Bodega, Varietal, Orden, Despacho…
```

### 3.2 Regla nueva 1: `_index.md` tiene tope

**Máximo 5 entradas.** La sexta se mueve al changelog. En PadelPunilla `_index.md`
creció hasta ser un log de ~15 entradas de 20 líneas cada una, y **Claude lo lee
entero en cada sesión**. Un dashboard que no cabe en una pantalla dejó de ser un
dashboard.

### 3.3 Regla nueva 2: separá "intención" de "comportamiento"

Este es **el** arreglo al modo de falla más caro. El vault escrito a mano documenta
lo que quisiste hacer; siempre. Necesitás un segundo documento **generado**:

```
docs/vault/_verdad.md      # GENERADO — no editar a mano
```

Un script (`scripts/vault/generar_verdad.mjs`) que derive del código:

- **Rutas registradas** en el router — y cuáles páginas existen pero no están.
- **Cloud Functions exportadas** desde `functions/src/index.ts`.
- **Providers/hooks sin ningún consumidor.**
- **Clases sin call site fuera de su archivo** (lo mismo que el hook, pero como
  reporte completo en vez de aviso por archivo).
- **Colecciones de Firestore leídas o escritas** vs. las declaradas en
  `firestore.rules` (esto habría cazado la colección fantasma `follows` el primer
  día).

Corrélo en CI y subilo como artifact. **La diferencia entre `_index.md` y
`_verdad.md` es exactamente la deuda del proyecto.**

### 3.4 Regla nueva 3: las secciones "pendiente" llevan fecha y se auditan

Toda línea que diga "pendiente de deploy" lleva la fecha en que se escribió. Y
antes de creerle a cualquiera, corré la auditoría contra producción (§2.9 de
`LECCIONES.md`). En PadelPunilla tres pendientes estuvieron hechos durante **dos
meses** sin que nadie tachara la nota.

---

## Paso 4 — CI desde el día uno

**El error que no hay que cometer:** montar el CI cuando ya hay código. Un CI nuevo
encuentra **bugs viejos**, y encontrarlos con 200 archivos es tolerable; con 1105,
te comés una semana.

### 4.1 La forma del workflow

Un solo `ci.yml` con `workflow_dispatch` + input `alcance`:

```yaml
on:
  push:
    branches: [master]
    paths-ignore: ['docs/**', '**/*.md']
  pull_request:
  schedule: [{ cron: '0 6 * * 1' }]     # lunes: detecta que algo se pudrió solo
  workflow_dispatch:
    inputs:
      alcance:
        type: choice
        options: [rapido, tests, completo, todo-con-builds]
        default: rapido

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true
```

**Alcances según el evento, sin que nadie los pida:** `push → rapido` ·
`pull request → completo` · `lunes → completo` · **builds nunca automáticos**.

> ⚠️ **Trampa heredada, decidila ahora:** con `cancel-in-progress: true` sin
> discriminar por evento, un `workflow_dispatch` **cancela la corrida del push**.
> En PadelPunilla eso mató un análisis automático y `gh run watch` devolvió 0
> igual. O agregás `${{ github.event_name }}` al grupo, o lo dejás y **lo
> documentás en `CLAUDE.md`**. Lo que no sirve es que sorprenda.

### 4.2 El veredicto de tests, separado de los shards

Ningún shard emite veredicto. Los shards corren, toleran rojos y suben su reporte;
**un job aparte exige los N reportes** y compara contra el baseline. Sin esa
cuenta, **un shard muerto en silencio pasa por suite verde**.

`scripts/ci/check_test_baseline.mjs`:

- Compara contra `.github/known_test_failures.txt` **por nombre de test**, no por
  cantidad.
- **Un error de carga o compilación nunca se tolera**, aunque esté listado.
- Denuncia las entradas obsoletas (un test listado que dejó de fallar).
- Imprime un "baseline sugerido con los nombres exactos de hoy", listo para pegar.

> **Y una regla de higiene que PadelPunilla no tuvo:** el archivo de baseline lleva
> **fecha y motivo** por línea, y cualquier entrada de más de 30 días es un ítem de
> deuda que se revisa. Allá 7 tests quedaron tolerados durante meses; dos eran un
> `RenderFlex overflowed by 24 pixels` que nunca se arregló.

### 4.3 Verificadores propios que valen la pena desde el principio

- `scripts/ci/auditar_indices.mjs` — **corre** cada forma de query del catálogo
  contra el emulador y sale con exit 1 si falta un índice. Ver §4.2 de
  `LECCIONES.md`: un índice `READY` puede no servir.
- `scripts/ci/auditar_estados.mjs` — compara el `enum` de estados de Orden en Dart
  contra el de TypeScript.
- `node --check` sobre los scripts de build. ⚠️ **`node --check` valida sintaxis,
  no referencias** — hacé además un `require()` de cada módulo.

---

## Paso 5 — El workflow de deploy

### 5.1 Las cuatro reglas que se llevan tal cual

1. **Orden `reglas → functions → front`**, impuesto con `needs:`, no con
   disciplina.
2. **Promové, no republiques.** Build → canal de preview → verificar → clonar a
   producción. Publicar los **bytes ya verificados**, sin recompilar.
3. **`concurrency` SIN `cancel-in-progress`** en deploy (grupo distinto al de CI).
   Cortar un deploy por la mitad es peor que esperar.
4. **El workflow imprime en su resumen qué falta**: "actualizá el vault", "el
   binario no lo mueve ningún deploy".

### 5.2 La aprobación: que exista, o que no se mencione

Si vas a poner `environment: production`, **configurá Required reviewers de
verdad** en Settings → Environments. Verificalo:

```bash
gh api repos/<owner>/<repo>/environments
# protection_rules: []  ← no gatea NADA
```

Si no vas a ponerlos, **sacá la palabra "aprobación" de toda la documentación**.
Ver §3.4 de `LECCIONES.md`: lo peligroso no es la falta de la red, es creer que hay
una red que no está.

### 5.3 El script de verificación post-deploy

Escribilo el día que escribas el workflow, no la primera vez que dudes:

```bash
#!/bin/bash
# verificar_release.sh <url> <canario-nuevo> <canario-que-desaparece> <control>
CB="?cb=$(uuidgen)"            # saltear cache del CDN

BUNDLE=$(curl -s "$1/bundle.js$CB")
echo "bytes:  $(echo "$BUNDLE" | wc -c)"
echo "sha256: $(echo "$BUNDLE" | sha256sum | cut -c1-16)"
echo "canario nuevo ($2):     $(echo "$BUNDLE" | grep -c "$2")   # esperado: >0"
echo "canario que se va ($3): $(echo "$BUNDLE" | grep -c "$3")   # esperado: menos que antes"
echo "control fijo ($4):      $(echo "$BUNDLE" | grep -c "$4")   # esperado: igual que antes"

# Control negativo: una ruta inventada NO puede devolver lo mismo que una real
echo "ruta inventada: $(curl -s -o /dev/null -w '%{http_code}' "$1/ruta-que-no-existe-jamas")"
```

**Tres cosas que ese script encapsula y que se olvidan siempre:** el cache-buster,
el canario que **desaparece** (no sólo el que aparece), y el control negativo.

---

## Paso 6 — La primera conversación con Claude

### 6.1 Qué decirle, literal

> Vamos a arrancar la tienda de vinos. Antes de escribir código:
>
> 1. Leé `CLAUDE.md` y `docs/vault/_index.md`.
> 2. **No corras** `flutter analyze`, `flutter test`, `flutter build` ni `npx jest`
>    — la máquina tiene 7,9 GB de RAM y no terminan. Sí podés correr
>    `dart format` y `tsc --noEmit`.
> 3. Antes de proponer cualquier cosa que agregue lecturas a Firestore,
>    **cuantificá el costo** y encuadralo contra la cuota gratuita de 50k/día.
> 4. Cuando digas que algo funciona, decime **cómo lo verificaste**. Un job verde
>    no cuenta.

### 6.2 Las tres cosas que Claude va a hacer mal si no se las decís

1. **Va a construir de arriba hacia abajo.** Va a escribir `CatalogoPage` de 400
   líneas y después "partirla" con métodos privados. El hook de 200 líneas lo
   frena; el `one-widget-per-file` frena el otro camino. **Pero decíselo igual**:
   "empezá por el widget hoja".
2. **Va a decir "listo" cuando compila.** En PadelPunilla la frase recurrente en
   las notas es *"lo único que falta: NO se vio renderizado"*. Compilar, pasar
   tests y desplegarse son tres cosas distintas de que **alguien lo haya mirado**.
3. **Va a creerle a la documentación.** Si el vault dice "feature completa", lo va
   a dar por hecho. Por eso existe `_verdad.md` (paso 3.3) y el `call-site-guard`.

### 6.3 Guardá la memoria desde el primer día

Cada vez que algo cueste una iteración —un índice que no servía, un webhook que
llegó dos veces, un hook que bloqueó por una razón que no era obvia— pedile a
Claude que lo guarde como memoria con esta forma:

```
La regla, en una línea.
**Por qué:** qué pasó de verdad, con el número o el comando.
**Cómo aplicarlo:** qué hacer distinto la próxima vez.
```

**Ese formato es el que hizo que este documento exista.** Una nota que dice "hubo
un problema con los índices" no sirve; una que dice "el índice estaba `READY` con
los campos exactos y no servía porque el rango iba antes que una igualdad" te
ahorra el día entero la próxima vez.

---

## Checklist de "el setup está listo"

- [ ] `git remote -v` dice lo que creés, y hay **uno solo**.
- [ ] `CLAUDE.md` existe, termina en **deploy** y no en commit.
- [ ] Los hooks HARD están cableados y **verificaste que bloquean** (probá con un
      archivo de 210 líneas a propósito).
- [ ] El gate del vault usa **una sola ruta** en el PreToolUse y en el Stop, y
      probaste que vuelve a bloquear después de un Stop.
- [ ] Ningún hook escribe git.
- [ ] `ci.yml` corre con `alcance=rapido` en push y **no** dispara builds solo.
- [ ] Hay un job de **veredicto** separado que exige los N reportes de shards.
- [ ] `deploy.yml` impone `reglas → functions → front` con `needs:`.
- [ ] `verificar_release.sh` existe y tiene canario nuevo + canario que
      desaparece + control negativo.
- [ ] `packages/contratos/` tiene la máquina de estados de Orden, y hay un test
      que compara el `enum` de Dart contra ella.
- [ ] El webhook de pagos es **idempotente por marcador en la misma transacción**
      que el efecto, y consulta la API del proveedor en vez de confiar en el
      cuerpo.
