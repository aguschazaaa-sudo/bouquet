# Diagnóstico del sistema de trabajo de PadelPunilla

> Qué funciona, qué no está funcionando y qué le agregaría. Todo con la evidencia
> al lado — si no puedo señalar el caso concreto, no está en la lista.
>
> Esto es lo que decide **qué se porta y qué no** al proyecto nuevo.

---

## Lo que funciona

### 1. Los hooks HARD miden de verdad, y hay que creerles

**Evidencia.** El límite de 200 líneas bloqueó `edit_slug_sheet.dart` con **208** y
lo dejó pasar con **197**. El de fronteras de capa bloqueó un provider por importar
`data/`, correctamente. Y en la ronda de fotos del club, los 9 archivos nuevos
quedaron todos bajo 200 líneas **sin que ninguno bloqueara** — o sea que el gate ya
está internalizado.

**Por qué importa más de lo que parece.** Hasta el 2026-08-17 la memoria del
proyecto decía que estos hooks *no podían correr en esta máquina* y que su bloqueo
era **ruido a ignorar**. Eso es el peor de los dos errores posibles: se ignora una
violación real y se commitea código que el gate estaba frenando a propósito. La
corrección fue explícita y sigue vigente.

**Portar:** sí, los cuatro. Son la parte del sistema con mejor relación
costo/beneficio de todo el repo.

### 2. `no-hardcoded-colors` con cero excepciones

Bloquea `Color(0x…)`, `Color.fromARGB/…` y **`Colors.*` sin excepciones**, incluso
para grises. Es una regla incómoda y por eso funciona: la excepción del "gris
neutro" es exactamente por donde se rompe un sistema de temas.

Un dato que lo justifica: el proyecto tiene tema claro y oscuro (`ThemeMode.system`)
y una nota entera sobre contraste medido. Nada de eso sobrevive si hay 40
`Colors.grey` sueltos.

**Portar:** sí, y escribir el equivalente para la tienda en React.

### 3. El baseline de tests **por nombre**, no por cantidad

`check_test_baseline.mjs` falla sólo ante fallos **nuevos**, comparando por nombre
de test contra `.github/known_test_failures.txt`. Dos reglas que lo salvan de ser
una alfombra: **un error de carga o compilación nunca se tolera** aunque esté
listado, y las entradas obsoletas se denuncian.

**Por qué es la decisión correcta:** un gate siempre rojo deja de mirarse. Con
1566 tests y 7 rojos preexistentes, la alternativa era un CI que nadie lee.

**Y el job de veredicto separado de los shards** es la mitad menos obvia y más
importante: los 3 shards terminan verdes con rojos adentro; el veredicto **exige los
3 reportes**, porque sin esa cuenta un shard muerto en silencio pasa por suite
verde.

**Portar:** sí, con la mejora de fecha+motivo por línea (ver "Qué agregaría" #5).

### 4. La disciplina de verificación

Es lo mejor que produjo el proyecto y no está en ningún hook: está en la cultura de
las notas. Hash de contenido + canario nuevo + canario que desaparece + control
positivo + control negativo. El ejemplo canónico: `Confirmando` de 0 → 1 y
`Pendiente` de 11 → 10, con dos controles fijos en 1.

Esta disciplina **encontró** cosas: que un deploy verde no había publicado nada,
que un hosting arrastró UI de polizón, que un índice `READY` no servía, que un
"pendiente" del vault estaba hecho hacía dos meses.

**Portar:** sí, y **codificarla en un script** (`verificar_release.sh`) en vez de
dejarla como costumbre. Una costumbre no sobrevive al primer día apurado.

### 5. Los alcances de CI y la disciplina de cuota

Cuatro alcances (`rapido` / `tests` / `completo` / `todo-con-builds`) con una tabla
de "qué pregunta contesta cada uno". Bajó el costo por push de ~21 min a ~4 min.
`paths-ignore` sobre `docs/**` y `**/*.md` significa que documentar es gratis — y
eso es lo que hace que la documentación se escriba.

**Portar:** sí, tal cual.

### 6. `hosting:clone` en vez de republicar

Promover los bytes ya verificados, sin recompilar. Es la decisión que evita la
clase entera de bugs "verifiqué una cosa y publiqué otra".

**Portar:** sí. (Con la advertencia de §3.3 de `LECCIONES.md`: el workflow igual
reconstruye antes de clonar, así que "no pushear entre verificar y promover" sigue
siendo una regla humana.)

### 7. La skill `commit` reemplazando al watcher

Claude lee el diff, decide el bump semver, escribe el mensaje, commitea — **en
conversación**, como último paso. El hook `Stop` sólo **avisa** si el árbol está
sucio y **nunca escribe git**.

Es la corrección directa del desastre del 2026-06-14 (ver "Lo que no funciona" #1
de la historia: 5 días de trabajo sin commitear por un `.git/index` corrupto).

**Portar:** sí, y la regla de oro con él: **nunca escribir git desde un hook o un
proceso de fondo**.

### 8. Feature-first + empaquetado + bottom-up

Las tres reglas estructurales aguantaron 1105 archivos y ~333 widgets sin
convertirse en un pantano. La regla de empaquetado (más de 3 pasos lógicos → cada
paso su archivo, y el orquestador **sin lógica**) es la que hace que las Cloud
Functions sigan siendo legibles con 20 funciones en producción.

**Portar:** sí.

### 9. Los ADRs

11 ADRs, uno por decisión, con el "por qué no" adentro. Son la parte del vault que
**no** envejeció mal, porque una decisión tomada sigue siendo una decisión tomada
aunque el código cambie.

**Portar:** sí, y son lo primero que escribiría en el repo nuevo.

---

## Lo que NO está funcionando

### 1. El gate del vault es un no-op — **verificado en vivo hoy**

El más caro del sistema y el único que no mide nada.

```
scripts/hooks/vault-precheck.sh    lee    ${CLAUDE_PROJECT_DIR}/.vault-session-ok      ← raíz
scripts/hooks/post-task-reminder.sh borra ${CLAUDE_PROJECT_DIR}/.claude/.vault-session-ok
```

Y el propio mensaje del hook manda a escribir la ruta **que no desbloquea nada**.

**Lo medí en esta misma sesión, no lo cito de la memoria.** Al empezar,
`.claude/.vault-session-ok` existía; después de un `Stop`, quedó así:

```
.vault-session-ok         → 109 B, Sep 1 19:01   (raíz — la que el gate LEE)
.claude/.vault-session-ok → no existe            (la que el Stop BORRÓ)
```

Como el de la raíz nunca se borra, **el gate se desbloqueó una vez en algún momento
y no volvió a frenar nunca**. El `.gitignore` lista las dos rutas (líneas 52 y 54),
o sea que la duda ya existía cuando se escribió.

**Consecuencia real:** el paso 1 del checklist obligatorio de `CLAUDE.md` —leer el
vault antes de tocar `lib/`— **no está enforced**. Depende enteramente de que Claude
se acuerde.

**Arreglo:** una sola ruta en los dos extremos. Está en `SETUP-PRIMERA-CORRIDA.md`
§2.8.

### 2. El vault documenta la intención, no el comportamiento — **cuatro veces**

No son accidentes: es un modo de falla sistemático de la documentación escrita a
mano.

| Caso | Lo que el vault decía | Lo que era |
|---|---|---|
| Fotos del club | feature entregada, con un widget listado | cadena completa de 3 capas **sin un solo call site**; el widget listado nunca se escribió |
| Lista de bloqueados | *"fila con nombre/avatar"* | mostraba **uids crudos de 28 caracteres** |
| `ConfianzaPage` | feature *"59/59 completa"* | página huérfana, **sin ruta ni navegación** |
| Nombre del turno fijo | implementado y desplegado | sin puerta: el menú que lo abría **sólo se dibuja con 3+ turnos fijos** |

**El diagnóstico correcto es estructural, no de disciplina:** el vault se escribe
cuando se **propone** o se **implementa** el código, y nadie vuelve a mirarlo
cuando la última pieza no se cablea. Pedirle a alguien que "documente mejor" no
arregla esto.

**Arreglo:** un `_verdad.md` **generado** (§3.3 del setup) + el `call-site-guard`
(§2.6). Ninguno de los dos existe hoy.

### 3. `_index.md` dejó de ser un dashboard

Es un log. Cada ronda agrega un callout de ~20 líneas al tope y nada se saca. Hoy
tiene ~15 entradas y Claude lo lee **entero en cada sesión** — es el archivo más
caro del repo en tokens, y las entradas 6 a 15 casi nunca cambian una decisión.

La ironía: existe una skill (`obsidian-indexer`) que regenera el vault desde el
código, y **no se corre**.

**Arreglo:** tope de 5 entradas, lo demás al changelog. Automatizable.

### 4. Los "pendiente de deploy" mienten por construcción

Ya está como lección (§2.9 de `LECCIONES.md`), pero como diagnóstico del sistema es
peor: **no es un error de alguien, es lo que el diseño produce.** Una nota escrita
en el momento T describe el estado en T; nadie tiene el trabajo de volver en T+1.

**Arreglo:** las notas de estado llevan fecha, y el estado real sale de auditar
producción. Idealmente el `_verdad.md` incluye un diff contra `firebase
functions:list`.

### 5. "Aprobación antes de producción" es una red que no existe

`environment: production` sin `protection_rules`. Documentado en dos lugares como si
gateara. **Lo peligroso no es la falta, es la creencia.**

**Arreglo:** una de dos, y es decisión del usuario — reviewers de verdad, o sacar la
palabra de la documentación. **Sigue sin decidirse desde el 2026-08-20.**

### 6. El objetivo de deploy no aísla la UI, y ya costó un bug en producción

`hosting-live` reconstruye desde el HEAD pusheado: publica **toda la UI mergeada**.
El aislamiento por `objetivo` protege reglas y functions; a `lib/` no lo protege
nadie.

**Salió a producción un botón "Borrar mi cuenta" llamando a una Cloud Function que
no existía**, en el flujo que Google Play exige.

**Arreglo:** no hay uno técnico limpio con este diseño de workflow. La mitigación es
humana y ya está escrita ("preguntate qué más se mergeó"). Un arreglo real sería
desplegar desde un tag en vez de desde `master`.

### 7. La cuarentena de tests se volvió permanente

7 fallos tolerados desde agosto. Dos de ellos son **un solo bug**: un `RenderFlex
overflowed by 24 pixels` en un archivo que no se toca desde el 2026-06-06, causado
por un cambio de métricas de texto entre versiones de Flutter. Nunca se arregló.

**El baseline hizo su trabajo** (evitó un gate siempre rojo) **y esa es exactamente
la razón por la que el bug sigue vivo**: dejó de doler.

**Arreglo:** fecha + motivo por entrada, y revisión de las de más de 30 días.

### 8. Hay reglas escritas que ningún hook mide

El agujero concreto: `layer-boundary.sh` bloquea que presentación importe `data/`,
**pero no bloquea el SDK de Firebase directo en un widget**. Por eso
`PerfilPhotoPicker` convive con `cloud_firestore` + `firebase_storage` **desde el
commit inicial**, pese a que el agente `/agents:presentation` lo prohíbe en su
texto.

**Regla general que sale de acá:** lo que está en un prompt es una intención; lo
que está en un hook es una regla. **Portá la lista de prohibiciones de los agentes a
hooks, o aceptá que son sugerencias.**

### 9. El sistema no detecta duplicación semántica

**Tres implementaciones copiadas** de la misma búsqueda por trigramas, idénticas
hasta en una clase privada. Mejorar una no mejoraba la app. Y las tres ignoraban un
índice de prefijos que el backend **sí generaba** — una búsqueda de 2 letras habría
funcionado ese mismo día.

Ningún hook, agente ni skill lo vio. `review-decouple` existe pero se corre a
pedido.

### 10. El ciclo de feedback pasa por la nube y dura entre 4 y 14 minutos

Consecuencia de los 7,9 GB de RAM. No es culpa del sistema de trabajo, pero **lo
condiciona todo**: es lo que hace que "un job verde" sea tentador como evidencia,
que re-disparar CI duela, y que el proyecto necesite toda la disciplina de
verificación del punto 4 de "Lo que funciona".

**Es el problema más caro del proyecto y el único cuya solución no es software.**
16 GB de RAM cambiarían más que cualquier hook de esta lista.

---

## Qué le agregaría

Ordenado por relación valor/esfuerzo, no por importancia teórica.

### 1. `call-site-guard` — el hook que ataca el modo de falla #2

SOFT, avisa cuando una clase pública no la referencia nadie fuera de su archivo.
Habría cazado **las cuatro** features sin puerta. ~20 líneas de bash. Está escrito
en `SETUP-PRIMERA-CORRIDA.md` §2.6.

**Es lo primero que agregaría, en los dos repos.**

### 2. `_verdad.md` generado desde el código

El complemento del vault escrito. Deriva del código: rutas registradas vs. páginas
existentes, funciones exportadas, providers sin consumidor, clases sin call site,
colecciones leídas vs. declaradas en las reglas.

**La diferencia entre `_index.md` y `_verdad.md` es la deuda del proyecto,
medida.** Y habría cazado la colección fantasma `follows` el primer día —el string
aparecía **una sola vez en todo el repo** y el read denegado moría en un `?? {}`.

La infraestructura ya existe a medias (`obsidian-indexer`); falta correrla en CI y
tratarla como artefacto, no como skill a pedido.

### 3. Cerrar el agujero de `layer-boundary`

Agregar la regla que bloquea el SDK de Firebase en `presentation/`. Cuatro líneas.
Va a romper archivos existentes — eso **es** el punto.

### 4. Presupuesto de lecturas declarado en el ADR

La lección de costo (§4.1 de `LECCIONES.md`) es sofisticada y vive sólo como
memoria. Convertirla en un campo obligatorio del template de ADR: *"esta feature
agrega N lecturas por apertura de pantalla; contra la cuota de 50k/día son X
aperturas"*.

En una tienda con catálogo esto es más importante que en PadelPunilla, no menos.

### 5. Fecha y motivo en el baseline de tests

Una línea por entrada: `<test> | 2026-08-20 | overflow 24px en explorar_header`.
Cualquier entrada de más de 30 días es deuda que se revisa. Evita que la cuarentena
se vuelva permanente (problema #7).

### 6. Un `verificar_release.sh` versionado

La disciplina de verificación es lo mejor del proyecto **y vive en la cabeza**.
Cada ronda la reconstruye a mano en el scratchpad. Un script en el repo, con
cache-buster, canario nuevo, canario que desaparece y control negativo, la vuelve
barata. Está escrito en `SETUP-PRIMERA-CORRIDA.md` §5.3.

### 7. Deploy desde tag, no desde `master`

Arregla el problema #6 de raíz: si el deploy sale de un tag, el contenido es
exactamente el que se decidió publicar, y "qué más se mergeó" deja de ser una
pregunta.

Tiene costo: el trigger por tag de PadelPunilla nunca se disparó (cero tags en el
repo) porque la skill `commit` escribe `vX.Y.Z` en el asunto y no crea el tag. Y
taggear **cada** commit serían decenas de builds de 20 min. La versión razonable es
taggear **sólo lo que se va a desplegar**.

### 8. Para el proyecto nuevo: el contrato de webhook, escrito el día 1

No es una mejora al sistema de PadelPunilla —allá los pagos se difirieron
explícitamente— sino el hueco más grande al portarlo. Un documento de una página en
`docs/vault/architecture/decisions/` con:

- Idempotencia por marcador, **en la misma transacción** que el efecto.
- La fuente de verdad es la consulta a la API con el `payment_id`, **no el cuerpo
  del webhook**.
- Verificación de firma.
- Qué pasa con una notificación fuera de orden (`pagado` que llega después de
  `cancelado`).
- Los estados de Orden que pueden **nacer** finales, y por qué el trigger es
  `onDocumentWritten`.

### 9. Decidir la aprobación de producción

Cinco minutos de trabajo y sigue abierto hace dos semanas. **Reviewers de verdad, o
sacar la palabra.**

### 10. Más RAM

No es una recomendación de software, pero es la que más cambia. Cada lección de
"cómo verificar sin correr nada localmente" de este documento existe porque un
`flutter analyze` no termina en 20 minutos. La mitad de la disciplina del proyecto
es una adaptación a una restricción de hardware.

---

## Resumen en una tabla

| | Portar tal cual | Portar corregido | No portar | Agregar |
|---|---|---|---|---|
| **Hooks** | size-guard, one-widget, no-colors | layer-boundary (+SDK), vault-precheck (ruta única) | — | call-site-guard |
| **CI** | alcances, paths-ignore, veredicto separado | baseline (+fecha/motivo) | — | auditar_indices, auditar_estados |
| **Deploy** | orden reglas→functions→front, clone | "aprobación" (decidirla) | — | verificar_release.sh, deploy por tag |
| **Docs** | ADRs, changelog | `_index.md` (con tope) | "pendiente de deploy" a mano | `_verdad.md` generado |
| **Proceso** | skill commit, feature-first, empaquetado | — | auto-commit por hook (nunca) | contrato de webhook |
