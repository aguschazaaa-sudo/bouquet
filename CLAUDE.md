# CLAUDE.md — bouquet

Tienda de vinos. Vidriera Next.js · panel Flutter · backend Firebase.
Diseño completo en [ARQUITECTURA.md](ARQUITECTURA.md).

---

## CHECKLIST OBLIGATORIO — cada tarea

1. Leer `docs/vault/_index.md` y el ADR de lo que vas a tocar.
2. Escribir el código. Composición **bottom-up**: del componente hoja a la
   página, nunca al revés.
3. **Grepear quién abre lo que escribiste.** Si nadie lo referencia, no está
   entregado, está escrito.
4. Actualizar `docs/vault/`. Decisión → ADR. Estado → `_index.md` (tope 5).
5. Commit, en conversación, leyendo el diff.
6. **Deploy.** Un cambio commiteado NO es un cambio entregado.
7. Verificar producción y decir **cómo** lo verificaste.

**El último paso escrito es lo que el sistema produce.** Si el workflow termina
en "commit", el sistema produce commits sin deploys — de forma fiable.

---

## PROHIBIDO correr en esta máquina

`flutter analyze` · `flutter test` · `flutter build` · `npx jest` de functions

**Causa medida:** 7,9 GB de RAM totales, 4 núcleos. Todo va a paginación.
En este mismo hardware, `flutter analyze` no terminó en 20 minutos y un solo
archivo de test no completó en 7. Un build local muere con `0xC0000005`
(ACCESS_VIOLATION) del generador de snapshots — **no es un error del proyecto**.

Quién se come la RAM: el analysis server de Dart **1,4 GB** (y no hace falta
para compilar), el editor 1,15 GB, Chrome 761 MB, el daemon de Gradle 596 MB
**que queda vivo después de un build fallido**.

⚠️ Cerrar el editor mata la sesión de Claude Code: corre como extensión adentro.

### Sí se corre local (segundos)

| Comando | Qué atrapa |
|---|---|
| `dart format` | Parseo. Si formatea, el archivo compila sintácticamente |
| `npx tsc --noEmit` | Imports faltantes y exports duplicados |
| `node --check` | Sintaxis de un `.mjs` — **no** referencias |
| `bash scripts/hooks/probar_hooks.sh` | Que los hooks sigan midiendo |
| `node scripts/ci/verificar_enlaces.mjs .` | Enlaces de la documentación |
| `npm run dev` (tienda) | Ciclo real de segundos |
| `firebase emulators:start` | Reglas y triggers |

---

## CI — elegí el alcance más chico que conteste la pregunta

| Pregunta | Comando |
|---|---|
| ¿Los hooks y los enlaces siguen bien? | `gh workflow run ci.yml -f alcance=rapido` |
| ¿Pasan las suites? | `gh workflow run ci.yml -f alcance=tests` |
| Todo menos builds | `gh workflow run ci.yml -f alcance=completo` |

- Un push a `main` ya dispara `rapido` solo. **NO encimes otra corrida.**
- ⚠️ `rapido` **NO corre tests**. Si el cambio es **lógica y no UI**, disparalo
  a mano antes de tocar producción — aunque el push haya dejado verde.
- **Builds nunca automáticos.** Son la mitad del costo. iOS cuesta ×10.
- Si ya hay una corrida, **leela**. Re-disparar cuesta lo mismo que la primera.

---

## Deploy — orden no negociable: reglas → functions → front

| Tocaste | Objetivo |
|---|---|
| `firestore.rules` / índices | `reglas` |
| `functions/` | `functions` |
| `apps/tienda/` | `tienda` |
| `apps/admin/` | `admin` |

⚠️ **El deploy de front reconstruye desde el HEAD pusheado: arrastra TODO lo
mergeado, no sólo tu cambio.** Antes de publicar, preguntate qué **más** se
mergeó. En PadelPunilla eso puso en producción un botón que llamaba a una Cloud
Function inexistente. Acá es plata: un "Pagar" que llegue antes que su webhook
es una venta que se cobra y no se registra.

**Promové, no republiques.** Publicá los bytes ya verificados. Y no pushees
entre verificar y promover, o lo que revisaste no es lo que quedó publicado.

---

## Verificación — no le creas al color

| No prueba nada | Lo que sí prueba |
|---|---|
| Un job verde | El artifact |
| `Deploy: success` | La lista de jobs (`skipped` cuenta) |
| `gh run watch` exit 0 | Devuelve **0 en corridas CANCELADAS** |
| Un HTTP 200 | El hash del contenido |
| Que un índice esté `READY` | **Correr la query** |
| Que la clase exista | **Grepear quién la abre** |
| Que la suite "pasó" | La resta contra la corrida anterior |

**Toda verificación necesita un control positivo** — algo que sabés que tiene
que aparecer. Sin él, una lista vacía por error de lectura confirma cualquier
cosa. Y un **control negativo**: pedile al servidor una ruta inventada.

**El canario tiene que ser nuevo y discriminante:** uno que aparece y otro que
desaparece. Chequeá que el string sea nuevo **antes** de usarlo.

---

## Los hooks

Miden de verdad. **Si uno bloquea, abrí el `.sh` y leé su regla** — no te
quedes quieto, que es exactamente lo que no lo destraba.

| Hook | Bloquea |
|---|---|
| `vault-precheck` | Escribir código sin haber leído el vault |
| `widget-size-guard` | Presentación > 200 líneas |
| `layer-boundary` | domain con Firebase · presentation con `data/` o con el SDK |
| `server-only-guard` | `firebase-admin` fuera de `apps/tienda/src/server/` |
| `one-widget-per-file` | Más de un widget público por archivo |
| `no-hardcoded-colors` | `Colors.*`, `Color(0x…)`, hex fuera de tokens |
| `call-site-guard` | *(SOFT)* Avisa si nadie referencia lo que escribiste |

**Ningún hook escribe git, nunca.** Un watcher de auto-commit corrompió
`.git/index` y costó ~5 días de trabajo sin commitear.

`bash scripts/hooks/probar_hooks.sh` verifica que sigan midiendo: 30 casos con
control positivo y negativo cada uno.

---

## Convenciones

**Dominio en español, infraestructura en inglés.** `Producto`, `Bodega`,
`Varietal`, `Orden`, `Envío`, `Zona`, `Despacho` — pero `repository`,
`provider`, `service`, `widget`, `hook`. Glosario en
[docs/vault/domain/glossary.md](docs/vault/domain/glossary.md).

**Antes de proponer algo que agregue lecturas a Firestore, cuantificá el costo**
y encuadralo contra la cuota de **50.000/día**. Es un campo obligatorio del ADR,
no una nota al pie. Presupuesto vigente:
[ARQUITECTURA §6.3](ARQUITECTURA.md#63-el-presupuesto-completo).

---

## Decisiones tomadas — NO re-proponer

| | |
|---|---|
| Vidriera | **Next.js** en Vercel. Flutter web es invisible y el renderer HTML se eliminó en 3.29 |
| Panel | **Flutter** (web + Android) en Firebase Hosting |
| Backend | **Firebase** |
| Estado en el panel | **Riverpod** — no BLoC, no GetX |
| Estructura | **Feature-first**, no por capas en la raíz |
| Composición | **Bottom-up**, del widget hoja a la página |
| Estados de Orden | **Dos ejes** (pago y entrega) + proyección. No un string lineal |
| Triggers | **`onDocumentWritten` + `entroEn*`**. Nunca `onDocumentUpdated` |
| Idempotencia | **Marcador en la misma transacción** que el efecto |
| Carrito | **`localStorage`**. No hay colección `carritos` |
| Catálogo | Filtrado **en memoria**. Cero índices compuestos |
| Frescura | **ISR + revalidación por trigger**. La vidriera no lee por visitante |
| Precio | **Entero en centavos**. `items[]` guarda snapshot, no referencia |
| Pagos | **Diferido** — el eje existe y se usa a mano desde el día 1 |

Los ADRs con el "por qué no" adentro están en
[docs/vault/architecture/decisions/](docs/vault/architecture/decisions/).

---

## Tres cosas que hago mal si no me las decís

1. **Construyo de arriba hacia abajo.** Empezá por el componente hoja.
2. **Digo "listo" cuando compila.** Compilar, pasar tests y desplegarse son tres
   cosas distintas de que **alguien lo haya mirado renderizado**.
3. **Le creo a la documentación.** Si el vault dice "completa", grepeá igual.
