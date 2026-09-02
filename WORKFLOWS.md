# Workflows — los tres que existen, lo que produjeron de verdad, y el que yo escribiría

> Quinto documento del export. Cubre el proceso: Workflow A (formal, vía
> OpenSpec), B (cambio menor) y C (exploración), más lo que muestran los números
> después de cinco meses.
>
> **Resumen en una línea:** el diseño de los workflows es bueno y la disciplina
> llegó tarde — hay **33 changes sin archivar contra 8 archivados**, y 6 de esos 8
> archivos son de agosto en adelante. El problema no es el proceso: es que nadie
> barrió lo que se acumuló antes de que el proceso se cerrara.

---

## 1. Los tres workflows, como están escritos

### Workflow A — feature nueva (formal, pasa por OpenSpec)

```
1. Leer vault           → obsidian-context
2. Brainstorm           → /brainstorm
3. Plan                 → /writing-plans
4. Proponer             → /opsx:propose
5. Implementar por capa → /opsx:apply
   a. Data              → /agents:data + /agents:firebase
   b. Domain            → /agents:domain
   c. Presentación      → /agents:presentation + /agents:widget-atomic
                          + /agents:riverpod + /agents:routing
   c2. Copy/UX          → /agents:brand-voice
   d. Tests             → /agents:test
6. Review               → /agents:review
7. Documentar           → /agents:docs
8. Archivar             → /opsx:archive
9. Commit               → /commit
10. Deploy              → deploy.yml
11. Vault post-deploy   → mover de "pendiente" a "desplegado"
```

### Workflow B — cambio menor (fix, ajuste, refactor)

```
1. Leer vault → 2. Implementar con el agente de la capa → 3. Hooks validan
→ 4. post-task-doc → 5. /commit → 6. Deploy → 7. Vault post-deploy
```

### Workflow C — exploración

```
1. Leer vault → 2. /opsx:explore → 3. cuando esté claro, pasar a A o B
```

**Lo que está bien de este diseño, y hay que copiarlo:**

- **La separación A/B es la decisión correcta.** Obligar a un fix de UI a pasar por
  una propuesta formal mata el flujo; dejar una feature nueva sin spec produce
  features sin puerta. Tener dos velocidades declaradas evita las dos cosas.
- **Los pasos 10 y 11 existen.** No siempre existieron — ver §3.3.
- **El paso 5 está ordenado por capa**, de abajo hacia arriba. Eso es lo que hace
  que la composición bottom-up sea el camino natural y no un acto de voluntad.

---

## 2. Lo que produjo de verdad: los números

Medido hoy sobre `openspec/`:

```
ARCHIVADOS:                     8
COMPLETOS SIN ARCHIVAR:         9   (tasks.md al 100 %, carpeta viva)
ABIERTOS:                      24
                              ───
TOTAL DE CHANGES EN 5 MESES:   41
```

### 2.1 Los 9 completos sin archivar

```
0/29   cancha-disponibilidad-precios      0/41   perfil-card-hero
0/28   explorar-swap-jugadores            0/72   reservas
0/44   mi-club-hub                        0/38   suscripciones-pagos-correctitud
0/25   mis-reservas                       0/21   turnos-fijos-remediacion
0/41   onboarding-jugador-perfil
```

Cero tareas pendientes, y siguen en `changes/` en vez de `changes/archive/`. **El
paso 8 se saltea.**

### 2.2 Los 24 abiertos, y la sorpresa que traen

```
 2/56  agenda-acciones-por-estado     11/77  home-feed-inicio
 3/53  auth-flow                       3/64  jornada-operativa
13/75  borrar-cuenta                   2/21  landing-bandas-cinematicas
10/65  busqueda-fuzzy-jugadores       17/17  mejorar-crear-club      ← 0 hechas
 4/37  cierres-cancha-club             6/53  mi-club-v2
68/100 clubes-cover-y-galeria         10/97  notificaciones-push-generalizadas
11/43  confianza-conexion-politica     3/43  notificaciones-remediacion
 8/47  confianza-en-la-agenda         46/91  redistribuir-colores-semanticos
 5/71  crear-club                      4/49  social-seguir-jugadores
 2/58  explorar-identity-cards         5/44  suscripciones-mercadopago
                                       2/35  turno-fijo-nombre
                                      64/64  turnos-fijos            ← 0 hechas
                                      22/22  ver-club                ← 0 hechas
```

**Mirá los tres marcados.** `ver-club`, `turnos-fijos` y `mejorar-crear-club`
tienen **cero tareas tildadas** — y las tres features **están en producción hoy**.
`ver_club` recibió una ronda entera hace tres días (`resumen-disponibilidad`);
turnos fijos tiene seis memorias propias y tres crons corriendo.

> **O sea que el checkbox tampoco refleja la realidad.** Se implementó por fuera del
> flujo formal y nadie volvió a tildar.

Y `turno-fijo-nombre` está en `2/35` cuando la funcionalidad **se desplegó el
2026-08-24** — la ronda que descubrió que le faltaba la puerta.

### 2.3 La lectura correcta de estos números

Es tentador concluir "el Workflow A no funciona". **No es eso, y la fecha lo
demuestra.** Los 8 archivados son:

```
2026-05-07  sistema-confianza
2026-06-03  reducir-exposicion-datos-sensibles
2026-08-05  agenda-multicancha
2026-08-05  turno-fijo-titular-externo
2026-08-07  agenda-operacion-club
2026-08-08  club-publico-paridad
2026-08-20  slug-club-compartible
2026-09-01  compartir-estado-disponibilidad
```

**Seis de ocho son de agosto en adelante.** La disciplina de archivar **sí se
adquirió** — y coincide en el tiempo con dos cosas: el CI entrando en servicio
(2026-08-19) y la corrección del proceso que agregó los pasos de deploy
(2026-08-20).

**El diagnóstico real:** el proceso se cerró en agosto y **nadie barrió el
backlog de abril–junio**. 33 carpetas donde conviven cuatro estados distintos que
el directorio no distingue:

| Estado real | Cuántos | Ejemplo |
|---|---:|---|
| Terminado, sin archivar | 9 | `reservas` (72/72) |
| Enviado a producción, sin tildar | ≥3 | `ver-club` (0/22) |
| Genuinamente a medias | ~10 | `clubes-cover-y-galeria` (68/100 pendientes) |
| Abandonado / superado | ? | `mi-club-v2` vs `mi-club-hub` |

> **Y esto es el MISMO modo de falla que las secciones "pendiente de deploy" del
> vault**, señalado en `DIAGNOSTICO.md` #4: un estado escrito en el momento T,
> y nadie con el trabajo de volver en T+1. No es descuido de una persona — es lo
> que produce cualquier sistema donde el estado se escribe a mano y no se deriva.

---

## 3. Los tres defectos de proceso, y cómo se arreglaron (o no)

### 3.1 El paso de archivar no tiene quién lo dispare

`opsx:archive` es el paso 8 de 11. Está **antes** del commit, así que quien llega
al final de la tarea ya "terminó" en su cabeza cuando le toca.

**Arreglo para el proyecto nuevo:** que el archivado sea **una consecuencia del
deploy**, no un paso previo. Un change cuyo código está en producción **es**, por
definición, un change archivable. Un script en CI que compare las tareas tildadas
contra el último deploy exitoso y proponga el archivado cierra el lazo sin
depender de la memoria de nadie.

Mínimo viable, si eso es mucho: un hook `Stop` que **cuente** carpetas con
`tasks.md` al 100 % en `changes/` y lo diga. Cinco líneas, mismo espíritu que
`commit-reminder.sh`, y **read-only**.

### 3.2 El CD estuvo desconectado del proceso durante cinco meses

Hasta el 2026-08-20 los Workflows A y B **terminaban en "Commit"**. Desplegar
dependía de que alguien se acordara de pedirlo.

> **La cita del post-mortem, que vale más que cualquier consejo mío:** *"Las
> secciones 'pendiente de deploy' que se acumulan en el vault no son un descuido:
> son la consecuencia estructural de eso. Si el último paso escrito es 'commit',
> el sistema produce commits sin deploys, de forma fiable."*

Se corrigió agregando los pasos 10 y 11, una tabla de "qué objetivo según qué
tocaste", y sacándole a la skill `commit` la frase de que era el paso final.

**En el proyecto nuevo esto arranca corregido** (está en el `CLAUDE.md` plantilla
de `SETUP-PRIMERA-CORRIDA.md`). Pero la lección de fondo se generaliza:

> **Un proceso produce exactamente lo que dice su último paso.** Si el workflow
> termina en "test", vas a tener código testeado sin desplegar. Si termina en
> "deploy", vas a tener código desplegado sin verificar. Escribí el último paso
> pensando en qué querés que se acumule.

### 3.3 El trigger por tag nunca se disparó

`deploy.yml` tiene `push: tags: ['v*']` y publica un preview con el nombre de la
versión. **Al 2026-08-20 el repo tenía cero tags** y hoy sigue igual.

La causa es una desconexión entre dos piezas del mismo repo: la skill `commit`
decide un `vX.Y.Z` por commit y lo escribe **en el asunto**, no como tag.

**Se decidió NO conectarlos**, y la decisión es correcta: se bumpea versión en
*cada* commit, así que taggear todos serían decenas de canales de preview y un
build de ~20 min por commit — justo lo que la política de cuota evita.

> **Pero deja una capacidad muerta en el repo**, que es su propio costo: un
> trigger que nunca corrió no tiene evidencia de funcionar (§9.6 de
> `LECCIONES.md`). El día que alguien taggee, va a descubrir si anda.

**En el proyecto nuevo:** o lo sacás, o lo usás. Si desplegás **desde tag** en vez
de desde `master` —que es lo que recomiendo en `DIAGNOSTICO.md` #7— el trigger deja
de ser decorativo y encima arregla el problema de que el deploy arrastre UI de
polizón.

---

## 4. Los workflows que yo escribiría para la tienda de vinos

Cinco, no tres. Los tres de acá, corregidos, más dos nuevos.

### Workflow A — feature nueva (formal)

```
1. Leer vault           → vault-context
2. Brainstorm           → /brainstorming
3. Proponer             → /opsx:propose
   ⚠️ El ADR de la propuesta declara el PRESUPUESTO DE LECTURAS de la feature
4. Implementar por capa → /opsx:apply
   a. contratos/        → si toca estados de Orden o tipos compartidos
   b. functions/        → backend primero, SIEMPRE
   c. data → domain → presentación (admin) o componentes → páginas (tienda)
   d. copy              → /checklists:voz
   e. tests
5. Review               → /checklists:review
6. Documentar           → post-task-doc
7. Commit               → /commit
8. DEPLOY               → reglas → functions → front
9. VERIFICAR            → ./scripts/verificar_release.sh  (no el color del job)
10. Archivar            → /opsx:archive   ← ÚLTIMO, después de verificar
11. Vault post-deploy
```

**Los tres cambios contra el original:**

- **Archivar pasó del puesto 8 al 10**, después de verificar. Un change no está
  cerrado cuando el código está escrito: está cerrado cuando está **en producción y
  comprobado**.
- **`functions/` va antes que el front**, dentro del mismo change. Es el orden de
  deploy metido en el orden de implementación, para que no puedan divergir.
- **El paso 9 es explícito.** En PadelPunilla verificar es cultura; acá es un paso
  numerado con un script.

### Workflow B — cambio menor

```
1. Leer vault → 2. Implementar → 3. Hooks → 4. post-task-doc
→ 5. /commit → 6. Deploy → 7. Verificar → 8. Vault post-deploy
```

Igual que el de PadelPunilla más el paso 7.

### Workflow C — exploración

Tal cual. Es el que menos deuda genera porque no produce artefactos.

### Workflow D — **cambios que tocan plata** ⚠️ EXTRAPOLADO

PadelPunilla no tiene este workflow porque difirió los pagos a propósito. Es el
hueco más grande al portar el proceso, y una tienda no puede no tenerlo.

```
1. Leer vault + el ADR del contrato de webhook
2. Proponer (formal SIEMPRE — nunca Workflow B sobre plata)
3. Implementar contra el SANDBOX de Mercado Pago
4. Tests de integración con --runInBand, incluyendo:
   · webhook duplicado (llega dos veces) → un solo efecto
   · webhook fuera de orden (pagado después de cancelado)
   · firma inválida → rechazo
   · payment_id que la API no reconoce
5. Review — con foco en idempotencia, no en estilo
6. Deploy a functions PRIMERO, y esperar
7. Verificar con una compra real de monto mínimo
8. Recién ahí, la UI que ofrece pagar
9. Archivar
```

**Las dos reglas duras del Workflow D**, las dos derivadas de lecciones reales de
este repo:

1. **La UI que ofrece pagar sale DESPUÉS de que su backend esté verificado.**
   PadelPunilla ya publicó un botón "Borrar mi cuenta" llamando a una Cloud
   Function que no existía, porque el deploy de front arrastra todo lo mergeado.
   El mismo mecanismo, con un botón de pago, es plata.
2. **Ningún cambio de plata pasa por Workflow B.** No importa lo chico que
   parezca: la ronda que "sólo cambiaba un rótulo" en este repo terminó
   descubriendo que un estado tenía cinco rutas de entrada y dos de ellas nacían
   finales.

### Workflow E — mantenimiento (el cambio que no llega solo a producción)

Es el hueco entre el Workflow B y la fila *"cambio sólo de documentación —
ninguno, commit y listo"* de §5. Hoy ahí no hay ningún guardia: todo lo que
alguien decide que "no amerita deploy" cae en una casilla sin reglas.

Entran: un test, un hook, un script de `scripts/`, un `.github/workflow`, un
ADR, un refactor **sin cambio de comportamiento observable**.

```
1. Leer vault
2. Implementar
3. Hooks validan
4. PROBAR que no llega a producción      ← el paso que define el workflow
5. post-task-doc
6. /commit
7. Registrar el POLIZÓN
```

**El paso 4 es un tripwire, no una opinión.** El diff no puede tocar nada que se
empaquete:

```bash
git diff --name-only main... \
  | grep -vE '^(scripts/|docs/|\.github/|\.claude/|\.gitignore$|\.gitattributes$|skills-lock\.json$|.*\.md$)'
```

Si eso devuelve **cualquier cosa**, pará. Hay exactamente dos salidas, y ninguna
es "me parece que era chiquito":

1. **Es un Workflow B.** Le corresponde deploy y verificación.
2. **Es un archivo de configuración que de verdad no se empaqueta.** Entonces
   lo **nombrás en la línea del polizón** y agregás el patrón acá arriba, para
   que la próxima vez el tripwire ya lo sepa.

⚠️ **El tripwire es deliberadamente paranoico y la lista blanca es
deliberadamente corta.** La primera vez que se corrió, sobre el propio change
que agregó este workflow, saltó con `.gitignore` y `skills-lock.json` — y estuvo
**bien** que saltara: la lista se completa por evidencia, no por adivinanza.

**`package.json` es el caso con filo, y hay que partirlo en dos.** La skill
`commit` bumpea la versión en **cada** commit, así que si el archivo entero
disparara el tripwire, el tripwire saltaría siempre — y **un guardia que grita
en todos los casos deja de ser un guardia.** Ese es el mismo mecanismo que
volvió teatro a los checkboxes de `tasks.md`.

| Qué cambió en `package.json` | Veredicto |
|---|---|
| Sólo el `"version"` | sigue siendo **E** |
| `dependencies` o `scripts` | es **B**, sin discusión |

Un cambio de dependencia llega a producción aunque el archivo parezca
configuración. La comprobación:

```bash
git diff main... -- package.json | grep -E '^[+-]' | grep -v '"version"'
```

Si eso devuelve algo, no era un bump: era un cambio de dependencias.

#### El paso 7, que es la razón de ser de este workflow

**Un cambio de Workflow E no se queda quieto: viaja de polizón en el próximo
deploy que haga otro.**

Esto no es una hipótesis, es el mecanismo que ya está escrito en `CLAUDE.md`:
*el deploy de front reconstruye desde el HEAD pusheado y arrastra TODO lo
mergeado, no sólo tu cambio*. Así fue como PadelPunilla publicó un botón
"Borrar mi cuenta" que llamaba a una Cloud Function inexistente — nadie
desplegó ese botón, el botón **viajó**.

Entonces "este cambio no requiere deploy" es falso. Lo verdadero es: **este
cambio se publica sin verificación, dentro del deploy de otra persona.**

Por eso el paso 7 escribe una línea en `docs/vault/_pendiente_deploy.md`:

```
2026-09-02 · a1b2c3d · E · scripts/hooks/nuevo-guard.sh
  → viaja en el próximo deploy de: ninguno (no se empaqueta)
```

Y quien vaya a desplegar **lee ese archivo primero** y se pregunta qué más está
por salir con lo suyo. Esa pregunta —*¿qué MÁS se mergeó?*— es literalmente la
que `CLAUDE.md` exige antes de publicar. El Workflow E existe para que tenga
respuesta escrita en vez de depender de la memoria de alguien.

**La trampa a evitar:** que E se vuelva el carril por donde se cuela lo que da
pereza verificar. La defensa es el paso 4, que es mecánico. Si el `grep`
devuelve algo, no hay conversación.

---

## 5. Cuándo usar cuál

| Situación | Workflow |
|---|---|
| Feature nueva, flujo de negocio nuevo | **A** |
| Cualquier cosa que toque cobros, stock o precios | **D** |
| Bug fix, refactor, ajuste de UI, cambio de copy | **B** |
| No tengo claro qué hacer | **C** |
| Test, hook, script, CI, ADR, refactor sin cambio observable | **E** |
| Cambio sólo de documentación | **E** — es el caso más simple de E, no "ninguno" |

**La pregunta que decide entre B y E** es mecánica, no de criterio: *¿el diff
toca algo que se empaqueta?* Si sí, es B. El `grep` del paso 4 de E la contesta
sin discusión, y por eso la división aguanta la presión de un viernes.

**La pregunta que decide entre A y B**, y que en PadelPunilla no está escrita pero
se aplica de hecho: *¿este cambio agrega una capacidad que un usuario puede
ejercer?* Si sí, es A — porque una capacidad nueva necesita que alguien se
pregunte **por dónde se llega**, y ese es exactamente el paso que faltó las cuatro
veces que apareció una feature sin puerta.

---

## 6. Quién hace cada paso — agentes y skills

Los agentes viven en `.claude/agents/` y son **subagentes reales**: el `tools:`
del frontmatter es nivel 4 de la escalera de enforcement, no retórica. Las
skills de terceros se declaran en `skills-lock.json` y se restauran con
`bash scripts/skills_restaurar.sh`.

### La única cosa que el `tools:` hace cumplir de verdad

**Restringe herramientas, no rutas.** Un agente con `Edit` puede escribir en
cualquier parte del repo, diga lo que diga su texto. Entonces:

| Lo que sí es estructural | Lo que sigue siendo un prompt |
|---|---|
| Un revisor **sin `Edit`/`Write`** no puede escribir. Punto. | "Este agente sólo toca `presentation/`" |
| Un agente **sin `Bash`** no puede desplegar ni commitear. | "No importes Firebase acá" |
| Lo que `permissions.deny` bloquea, lo bloquea para todos. | Cualquier `CANNOT touch` por ruta |

Por eso los cinco verificadores **no tienen `Edit` ni `Write`**, y las fronteras
por ruta las siguen midiendo los hooks. Es exactamente la corrección que
`SKILLS-AGENTES-MCP.md` §2 reclama: los "agentes" de PadelPunilla decían
`CANNOT touch: */data/` desde el nivel 3, y un widget importó
`cloud_firestore` desde el commit inicial.

### Escritores (`Edit`, `Write`, `Bash`)

| Agente | Territorio | Entra en |
|---|---|---|
| `contratos` | `packages/contratos` — estados, dinero, puertos | A·4a, D·2 |
| `functions` | `functions/` — triggers, webhooks, idempotencia | A·4b, D·3 |
| `reglas` | `firestore.rules`, storage, índices | A·4, D·3 |
| `tienda` | `apps/tienda` — vidriera Next.js | A·4c, B·2 |
| `admin-datos` | `apps/admin` `data/` + `domain/` | A·4c, B·2 |
| `admin-presentacion` | `apps/admin` `presentation/` | A·4c, B·2 |
| `vault` | `docs/` — sin `Bash`, no puede desplegar | A·6, B·4, E·5 |

### Verificadores (sin `Edit` ni `Write` — no pueden escribir código)

| Agente | Qué contesta | Entra en |
|---|---|---|
| `cazador-de-puertas` | ¿alguien puede **abrir** lo que escribimos? | A·5, B·3, **antes de cerrar cualquier tarea** |
| `presupuesto-lecturas` | ¿cuántas lecturas/día contra las 50.000? | A·3 (**campo obligatorio del ADR**) |
| `revisor-pagos` | ¿idempotente, y la UI sale después del backend? | **D·5, obligatorio** |
| `auditor-produccion` | ¿qué está corriendo **de verdad** en producción? | A·9, B·7, D·7 |
| `revisor-acoplamiento` | ¿hay la misma idea escrita dos veces? | **semanal, sobre el repo entero** |

### Skills por workflow

| Paso | Skill |
|---|---|
| A·2 explorar / C | `openspec-explore` |
| A·3 proponer | `openspec-propose`, `openspec-new-change`, `openspec-ff-change` |
| A·4 implementar | `openspec-apply-change`, `openspec-continue-change`, `openspec-update-change` |
| A·9 verificar | **`openspec-verify-change`** |
| A·10 archivar | `openspec-archive-change`, `openspec-bulk-archive-change` |
| reglas e índices | `firebase-security-rules-auditor`, `firebase-firestore` |
| **D — plata** | `mp-integrate`, `mp-webhooks` (oficiales de Mercado Pago) |
| visual, antes del código | `/disenio` → `brand-guidelines`, `theme-factory`, `canvas-design` |
| vidriera | `frontend-design`, `web-design-guidelines`, `vercel-composition-patterns`, `vercel-react-best-practices`, `vercel-react-view-transitions`, `vercel-optimize` |
| panel | `flutter-premium-ui` |
| copy | `writing-guidelines` |
| pruebas de UI | `webapp-testing` |

**Dos cosas que valen señalar de esta tabla.**

`openspec-verify-change` **no existía en el flujo de PadelPunilla** — su
Workflow A iba de implementar a archivar sin un paso de verificación. El
upstream la trae, y encaja exactamente en el paso 9 que §4 pedía agregar.

`openspec-bulk-archive-change` es la respuesta directa a §2: **33 changes sin
archivar contra 8 archivados**. Archivar de a uno es lo que hizo que nadie
barriera el backlog de abril–junio.

---

## 7. Dos reglas de higiene que este repo aprendió tarde

### 6.1 Barré el backlog antes de que sea un cementerio

33 carpetas donde no se distingue lo terminado de lo abandonado no es un backlog:
es ruido que le cuesta tokens a cada sesión y confianza a cada lectura.

**Regla: una vez por mes, clasificá.** Terminado → archivar. Abandonado →
borrar, con una línea en el changelog diciendo por qué. A medias → o se retoma o
se cierra. **Ningún estado ambiguo sobrevive un mes.**

Con `openspec/changes/` es literalmente un script de 20 líneas: contá `- [ ]` vs
`- [x]` en cada `tasks.md` y clasificá. El que está en este documento tardó un
minuto en escribirse y contestó una pregunta que llevaba cinco meses abierta.

### 6.2 El estado se deriva, no se escribe

Es la misma conclusión de `DIAGNOSTICO.md` (el `_verdad.md` generado) aplicada al
proceso. Todo lo que este repo escribió a mano sobre su propio estado envejeció
mal:

- las secciones "pendiente de deploy" del vault,
- los checkboxes de `tasks.md`,
- el conteo de tests del `_index.md` (decía 1929 cuando iban 2003),
- las features marcadas "completa" que no tenían puerta.

Y todo lo que se derivó del código o de producción resultó cierto: el hash del
bundle, `firebase functions:list`, el conteo de tareas de arriba, `grep` del call
site.

> **Si una afirmación sobre el estado del proyecto se puede calcular, calculala.
> Si se escribe a mano, ponele fecha y asumí que vence.**

---

## Checklist de "el proceso está sano"

- [ ] Los workflows terminan en **verificar**, no en commit ni en deploy.
- [ ] Archivar es el **último** paso, después de que el código esté en producción.
- [ ] Ningún cambio que toque plata puede ir por el workflow corto.
- [ ] La frontera entre B y E se decide con un `grep`, no con criterio.
- [ ] Todo cambio de Workflow E dejó anotado **en qué deploy ajeno viaja**.
- [ ] `functions/` se implementa y despliega **antes** que la UI que lo llama,
      dentro del mismo change.
- [ ] Hay un script que clasifica el backlog, y se corre una vez por mes.
- [ ] Los triggers declarados en los workflows **se dispararon alguna vez**. Si
      hace 5 meses que no, o se usa o se saca.
- [ ] Todo lo que el proceso afirma sobre su propio estado, o se calcula, o tiene
      fecha de escritura.
