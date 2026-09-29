# ADR 025 — El tablero del panel: el día al entrar, y lo que más se vende medido

- **Fecha:** 2026-09-29
- **Estado:** aceptada; **desplegada y verificada el 2026-09-29** —functions y panel (`e95e653`)—. El job corrió una vez a mano. Nadie miró el *Resumen* renderizado: ver *Verificación*, al final
- **Decide:** qué ve el dueño al entrar al panel, cómo se cuentan los pedidos
  del día sin leerlos, y quién mide la popularidad que hasta hoy era inventada
- **Historias:** HU-11.2 y HU-11.3 ([EP-11](../../features/panel/EP-11-parametros-y-tablero.md)).
  **Primer tramo de EP-11**; el segundo es HU-11.1, el envío sin cargo (ADR 026)
- **Toca:** [ADR 008](008-catalogo-stock-y-carrito.md) (`metricas/popularidad`
  se recalcula entero y nunca se acumula), [ADR 018 §7](018-pedidos-de-whatsapp.md)
  (`ordenes` se lista con `limit <= 50`), [ADR 020](020-accion-busqueda-y-notas.md)
  (los tramos de la consulta salen de la proyección), [ADR 012](012-el-catalogo-del-panel.md)
  (la carga del catálogo, una vez por sesión)
- **Hace cumplir:** `packages/contratos/test/popularidad.test.ts`,
  `functions/test/metricas/calcular.emulador.mjs` (**entra a CI**), el bloque
  *ADR 025* de `scripts/reglas/ordenes.test.mjs` y
  `apps/admin/test/features/resumen/resumen_test.dart`
- **Sin openspec, a pedido del dueño** (2026-09-29): este ADR y la épica son la
  especificación

## Contexto

EP-11 dejó escritas dos cosas que este ADR no discute:

- **HU-11.2:** *"al entrar, cuántos pedidos hay por preparar, cuántos pagos siguen
  en proceso y qué se agotó"*. Con el presupuesto ya pensado: los conteos de
  agregación cobran **una lectura cada 1.000 documentos contados**, y lo agotado
  sale del catálogo en memoria.
- **HU-11.3:** *"mostrar un ranking sobre datos que no se miden es mentirle a quien
  lo lee. Hasta el job, esta pantalla no existe"*. `metricas/popularidad` lo
  escribía **sólo el seed**, con `simulada: true`.

El disparador de las dos era otro (*"que la lista no alcance"* y *"que exista el
job"*). Las construye el pedido del dueño, y la segunda **construyendo el job
primero**.

## Decisión

### 1. `calcularPopularidad`: un job diario que recalcula el documento entero

El primer job programado del proyecto (`onSchedule`, `every day 05:00`,
`America/Argentina/Cordoba`). Lee las Órdenes con `creadaEn` en
`[ahora − 90 días, ahora)`, suma las unidades de venta de cada vino con
`contarPopularidad` (contratos) y **reescribe** `metricas/popularidad` con `set`
entero: `{ simulada: false, calculadaEn, desde, ventanaDias, ventas, unidades }`.

Es el patrón que ADR 008 dejó escrito para cuando existiera el job: **idempotente
por construcción**, sin marcador.

- `ahora` es la hora **programada** (`scheduleTime`), no el reloj: un reintento
  de la misma corrida mira las mismas Órdenes aunque arranque una hora después.
  Por eso la ventana tiene tope arriba.
- `contarPopularidad` es pura y ordena las claves: dos corridas escriben el mismo
  mapa, byte a byte (lo mide el emulador).
- **Sin transacción**: una Orden que cambia mientras se lee entra con el estado
  que tenía, y la corrida de mañana la cuenta bien.

### 2. Qué es una venta, y en qué ventana

**Cuenta** una Orden con pago `pagada` o `por_fuera` y entrega que **no** es
`cancelada`. Afuera: `pendiente` y `en_proceso` (todavía no es venta),
`rechazada`, `reembolsada`, y una cancelada aunque esté pagada
(`cancelada_con_pago` es plata por devolver). Una entrega `fallida` **sí** cuenta:
el vino está vendido y se reprograma. La lista entera de los 10 pares está en el
test.

Se suman **unidades de venta** (`cantidad`), no botellas: es la unidad con la que
`armarCatalogo` ya ordena la vidriera.

**90 días** es decisión mía: una temporada. Con menos, en un negocio chico una
sola compra grande decide el ranking; con más, un vino que dejó de venderse sigue
arriba meses. El documento lleva `ventanaDias` escrito y el panel lo lee de ahí:
**sin espejo en Dart** que se desincronice.

Una Orden con **una** línea ilegible se descarta **entera** —contar la mitad de un
pedido es inventar uno que nadie hizo— y el job la loguea como `ilegibles`.

### 3. El panel se entra por *Resumen*

Una sección nueva, **primera en la navegación y a donde se entra** (`/` y el
regreso de `/entrar` van a `/resumen`; antes iban a Catálogo). HU-11.2 dice *"al
entrar"*.

**Hoy** —tres cifras, cada una con a dónde ir—:

| Cifra | Cómo se cuenta | Lleva a |
|---|---|---|
| **Por preparar** | `count()` de los pares cuya proyección es `pagada` o `por_preparar` —los dos rótulos *"falta preparar"*—, sacados de la proyección como los de *"Requieren acción"*. Hoy: `sin_preparar` con `pagada` o `por_fuera` | Pedidos, que abre en *"Requieren acción"* |
| **Pagos en proceso** | `count()` de `estadoPago == en_proceso` | — (la bandeja no filtra por pago) |
| **Agotados** | Los **publicados** con `balde == agotado`, del catálogo en memoria, y sus nombres | Catálogo con *"Por reponer"* puesto |

**El conteo lleva `limit(50)`, y no es un gusto:** un `count()` pasa por la misma
regla que la lista, y `ordenes` sólo se lista con `limit <= 50` (ADR 018 §7). Sin
`limit` las reglas lo rechazan —medido en el emulador, con su control—. En el tope
la pantalla dice **"50 o más"**. Sin `orderBy` y sólo con igualdades: no pide
índice compuesto.

**No se pudo contar** se dice con palabras, nunca como un cero: *"no hay pedidos"*
y *"no pude contarlos"* mandan a hacer cosas opuestas.

**Lo que más se vende** —hasta 10 puestos, con el nombre de hoy sacado del
catálogo— se muestra **sólo si el documento dice `simulada: false`**. El del
seed, o uno que no dice nada, se lee como *"todavía no hay ventas medidas"*. Uno
que dice ser medido y no se puede leer es *Ilegible*, no *"sin ventas"*.

### 4. El seed ya no puede pisar la medición

`seed.mjs` **frena entero** si encuentra un documento suyo sin `muestra: true`, y
`borrar.mjs` lo saltea: el documento del job no lleva esa marca. No hizo falta
tocarlos. **Consecuencia:** después de la primera corrida el seed no vuelve a
correr contra `bouquet-vinos`, igual que después del primer guardado de cajas del
panel (ADR 024).

## Por qué NO las alternativas

| Alternativa | Por qué no |
|---|---|
| Un contador que suma en un trigger por venta | Se infla con cada reintento (los triggers son at-least-once): es exactamente lo que ADR 008 descartó |
| Recalcular en cada apertura del panel | Leería la ventana entera por apertura: 450 lecturas cada vez con 5 ventas por día |
| Contar leyendo la bandeja | 25 lecturas por apertura y un número que se corta en 25; `count()` cuesta una |
| Mostrar el ranking simulado con un cartel | Es el ranking que EP-11 prohíbe, con un cartel que nadie lee |
| Un espejo en Dart de la ventana de 90 | Viaja en el documento; un espejo se desincroniza |
| Dejar Catálogo como entrada | HU-11.2 dice *"al entrar"*; con el resumen tres toques más allá, nadie arranca el día mirándolo |

## Presupuesto de lecturas

| Quién | Cuánto | Cuándo |
|---|---|---|
| El job | **Una por Orden de la ventana**: ~450 con 5 ventas por día (**0,9 %**), ~1.800 con 20 (**3,6 %**). Más una escritura | Una vez por día |
| El panel, al abrir *Resumen* | **+3**: dos `count()` (una lectura cada uno hasta 1.000 contados) y un documento | Por apertura (`autoDispose`: *"al entrar"* es recontar). 20 aperturas por día = **60, 0,12 %** |
| El catálogo del panel | **0 nuevas** | Se entraba por Catálogo, que ya lo cargaba una vez por sesión (ADR 012) |
| La vidriera | **0 nuevas** | Ya leía `metricas/popularidad` (P + B + 2) |

⚠️ **El renglón que crece es el del job**, y crece con las ventas, que es un buen
problema. Si pasa del 5 %, la palanca es achicar la ventana o guardar un
acumulado por día.

## Lo que este ADR deja abierto, con su disparador

| Qué | Disparador |
|---|---|
| **La vidriera deja de ofrecer *"más vendidos"*** en cuanto corra el job, hasta que haya ventas reales en la ventana: el simulado se reemplaza por uno medido, y `armarCatalogo` no ofrece el orden sin ventas. Es lo correcto, y se va a notar en la preview | La primera corrida |
| **90 días, 10 puestos y las 5 de la mañana** son decisiones mías | Que el dueño lo mire y quiera otra cosa: son una línea cada una |
| **La cifra de pagos en proceso no lleva a ningún lado**: la bandeja no filtra por pago | Si el dueño la toca esperando ir a algún lado |
| **El ranking del panel puede no coincidir con los puestos de la vidriera**: el panel ordena todo lo vendido, la vidriera sólo lo publicado | Si confunde a alguien |

## Verificación (2026-09-29)

| Qué | Cómo |
|---|---|
| Las suites | CI `36593373052` (`tests`) sobre la rama descartable `ci/ep11-t1`, restada contra ADR 024: contratos 284 → **293 (+9)**, emulador 209 → **221 (+12 = 7 del job + 5 de reglas)**, Dart 509 → **522 (+13)**; functions 76 sin cambios; el bundle carga **8 functions**. Después se sacó `esPopularidadMedida` —sin un solo llamador fuera de los tests—: contratos queda en **292** |
| Compila | CI `36594073461` (`completo`): `flutter analyze` **No issues found!** |
| Quién lo abre | `secciones` → `enrutador` → `PantallaDelResumen` → `SeccionDelDia` → `CifraDelDia` / `SeccionLoQueMasSeVende` → `RenglonDeVenta`; `destino` manda `/` y `/entrar` a `/resumen`. Cada símbolo nuevo con su llamada (grep directo; control inventado 0) |
| El job en producción | `calcularPopularidad` `ACTIVE`; job de Cloud Scheduler `ENABLED`, `every day 05:00`, `America/Argentina/Cordoba` (el deploy **habilitó la API de Cloud Scheduler**, que estaba apagada). Las otras 7 functions conservan su `updateTime` |
| Lo que escribió | Corrido a mano (`gcloud scheduler jobs run`): `metricas/popularidad` pasó de `simulada: true`, `muestra: true`, 20 vinos (2026-09-14) a `simulada: false`, `ventanaDias: 90`, `ventas: 0`, `unidades: {}` —en producción hay **0 pedidos**—, sin `muestra` |
| ⚠️ Lo que encontró la corrida a mano | `calculadaEn` quedó en **2026-09-30T08:00Z**: una corrida manual manda como `scheduleTime` la **próxima** hora programada, no la de ahora. No rompe nada —la ventana se corre un día, y con cero pedidos da igual—; el panel dice *"calculado recién"* hasta mañana, y la corrida programada de las 5 escribe **el mismo documento** (misma hora programada). Si hace falta correrlo a mano con la hora real, el arreglo es `min(scheduleTime, reloj)` en `calcular_popularidad.ts` |
| Los conteos, en producción | Las dos consultas del *Resumen*, con su forma real y `limit(50)`, corren por la API **sin pedir índice** (dan 0: no hay pedidos). Control negativo: igualdad + `orderBy` por otro campo da `FAILED_PRECONDITION`. Control positivo: el mismo `count()` sobre productos publicados da **21** |
| La vidriera | `/vinos` de la preview (`build-2026-09-29-002`) ya **no ofrece** `popularidad`; `precio-asc` y `nombre` siguen |
| Panel | Build `36608815308` (*No issues found*) → canal → canario discriminante (5 cadenas nuevas 0 → ≥1, `COMMIT` `dacfb58` → `e95e653`, inventada 0 → 0) → live con los 4 hashes del artifact, `noindex` |
