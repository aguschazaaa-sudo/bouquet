# ADR 020 — Lo que requiere acción, buscar un pedido por número y las notas internas

- **Fecha:** 2026-09-25
- **Estado:** aceptada; **escrita y NO desplegada** (ver *Verificación*, al final)
- **Decide:** cómo la bandeja muestra primero lo que espera algo del operador, cómo
  se encuentra un pedido por su número y cómo se anota
- **Historias:** HU-06.3, HU-06.4 ([EP-06](../../features/panel/EP-06-ver-pedidos.md))
  y HU-07.7 ([EP-07](../../features/panel/EP-07-preparar-y-entregar.md)). **Tercer
  tramo del hito 2**
- **Toca:** [ADR 002](002-estados-de-orden.md) (el conjunto de lo que requiere
  acción sale de su proyección), [ADR 018](018-pedidos-de-whatsapp.md) (la bandeja y
  su presupuesto), [ADR 019](019-preparar-despachar-y-cancelar.md) (`anota()` en las
  reglas, y el supuesto de *"3 fichas por apertura"*)
- **Hace cumplir:** `apps/admin/test/features/pedidos/accion_busqueda_y_notas_test.dart`,
  `apps/admin/test/features/pedidos/textos_y_fechas_test.dart` y
  `scripts/reglas/ordenes.test.mjs` (bloque *ADR 020*)
- **Sin openspec, a pedido del dueño** (2026-09-25): este ADR y las épicas son la
  especificación. El alcance y las tareas se decidieron en la conversación

## Contexto

Desde ADR 019 un pedido se avanza, pero la bandeja abre en *"Por preparar"*: una
entrega fallida queda en otra ficha y **nadie la ve si no la busca**, que es
justo el olvido que HU-06.3 existe para evitar. Contestar *"¿cómo va el 123?"*
obliga a recorrer fichas. Y las notas internas las aceptaban las reglas desde el
día uno (`anota()`), pero no había pantalla.

**Qué quedó afuera del tramo, y por qué:**

| Historia | Por qué no |
|---|---|
| HU-06.5, el aviso push | Es infraestructura entera —APK repartida (H5), FCM, tokens por teléfono con sus reglas, un trigger con marcador— y su caso fuerte es el pedido de la **vidriera**, que todavía no existe: uno de WhatsApp lo cargó alguien que ya lo sabe |
| HU-07.3, el aviso por WhatsApp | Sigue bloqueada: falta el número de la tienda y la ruta `/pedido/<numero>` |
| EP-08, cobros | Espera a `crearOrden` y Mercado Pago |

## Decisión

### 1. *"Requieren acción"* es una ficha más, la primera, y la bandeja abre ahí

La bandeja pasa de elegir un `EstadoEntrega` a elegir una **`VistaDeBandeja`**
(sealed): `RequierenAccion` o `DeUnEstado(estado)`, con igualdad por valor porque
es la clave de la familia del provider. **Abre en *"Requieren acción"***: es lo que
pregunta quien entra.

**La consulta es un `OR` de tramos sacados de la proyección**, no escritos a mano
(`tramosQueRequierenAccion`): un par (pago, entrega) entra si
`proyectarEstadoPublico` cae en `estadosPublicosQueRequierenAccion`. Hoy son cuatro
tramos y ocho disjuntos (el tope de Firestore es 30):

| Entrega | Pagos | Por qué |
|---|---|---|
| `sin_preparar` | `pagada`, `por_fuera` | Hay que prepararlo (el de la vidriera impago, no: *falta cobrar*) |
| `entregada` | `pendiente`, `en_proceso`, `rechazada`, `reembolsada` | *Entregada impaga*. **`por_fuera` no entra** (ADR 018 §3) |
| `fallida` | todos → sin filtro de pago | Hay que reprogramar |
| `cancelada` | `pagada` | Hay que devolver |

Si ADR 002 cambia la tabla o el conjunto, la consulta cambia sola: el test lo
compara contra la proyección del espejo de Dart, y la suite de reglas contra la del
JSON generado.

**Índice nuevo: `(estadoEntrega, estadoPago, creadaEn desc)`.** Cada tramo con
filtro de pago lo necesita para ordenar; el de `fallida` usa el de la bandeja. **No
se confía en el merge** de los dos índices que ya existen: puede que Firestore lo
resuelva, pero eso se ve en producción, y un índice que falta ya rompió la bandeja
una vez (ADR 018). Ordenada y paginada igual que las demás fichas: 25 por página,
*"Ver más"* con `startAfter(creadaEn)`.

### 2. Buscar por número: una igualdad, una lectura, y el detalle sin releer

`where('numero', ==, n).limit(1)`: el índice de un campo que Firestore crea solo; el
`limit` lo exigen las reglas. El texto se lee con `numeroBuscado`, que acepta lo que
se copia de un chat (*"#123"*, *"Pedido 123"*, *"N.º 123"*) y **rechaza lo que no
es inequívoco** (*"12 3"*, *"123abc"*, más de 9 cifras: un teléfono pegado). Busca
al apretar *Buscar* o Enter, nunca por tecla. Si lo encuentra abre el detalle
**con la Orden ya leída** (`extra`): cero lecturas más. Un número que no existe se
dice, no es un error.

### 3. Las notas: una escritura, sin tocar el estado; gana la última

`anotar(id, nota)` escribe `notasOperador` y `actualizadaEn` y **nada más** —lo que
acepta `anota()`—, así que anotar nunca pisa un paso que otra persona dio mientras
se escribía. Una nota vacía **se borra** (`FieldValue.delete()`), no se guarda como
`""`. El tope de 1000 es el de las reglas, contado con `String.length`, que nunca
es menor que lo que cuentan las reglas; con más, el botón no guarda y lo dice (no
se corta en silencio). Se puede anotar en cualquier estado, también en uno
terminal. Después de guardar se relee, como cada cambio del detalle (ADR 019 §6).

⚠️ **Dos personas anotando el mismo pedido a la vez: gana la última**, y la nota de
la primera se pierde. Evitarlo pide una transacción (una lectura más por nota) o un
arreglo de notas con `arrayUnion`, que cambia la forma y las reglas. En una familia,
con un pedido que casi nunca editan dos a la vez, no lo compra el criterio 2 de
*poca burocracia*. Queda con disparador, abajo.

## Por qué NO las alternativas

- **Filtrar en memoria sobre lo ya cargado** — sólo ve la página de la ficha abierta:
  una entrega fallida en otra ficha seguiría invisible, que es el problema.
- **Una consulta por tramo (cuatro)** — cuatro lecturas mínimas por apertura aunque
  estén vacías, y juntar y ordenar en el cliente rompe la paginación.
- **Un campo `requiereAccion` escrito en la Orden** — lo tendría que mantener cada
  escritor (panel, dos callables, el webhook futuro) y las reglas: otra copia de la
  proyección que se desincroniza (ADR 002).
- **Contadores en las fichas** — una consulta más por ficha (ADR 018).
- **Buscar mientras se escribe** — una lectura por tecla.
- **Notas como historial (`arrayUnion`)** — mejor ante escrituras simultáneas, pero
  cambia contratos y reglas por un caso que no pasó.

## Presupuesto de lecturas

Cuota: **50.000 lecturas/día y 20.000 escrituras/día**. Medido por
`presupuesto-lecturas` contra el código (2026-09-25), con los supuestos de ADR 018/019
(3 personas, 20 pedidos/día, 30 aperturas de la bandeja).

| Operación | Lecturas | Escrituras | Al día |
|---|---:|---:|---|
| Abrir *"Requieren acción"* | hasta 25: **un solo `OR` es una sola consulta**, se cobra por documento devuelto, no por disjunto (1 si viene vacía) | — | Reemplaza a *"Por preparar"* como ficha de entrada: **la fórmula de ADR 019 no cambia** (750 / 1.500 / **2.250** con 1 / 2 / 3 fichas por apertura) |
| Buscar por número | **1**, encontrado o no (una consulta vacía cobra 1) | — | 20 búsquedas: **20** |
| …abrir el pedido encontrado | **0**: viaja por `extra` | — | 0 |
| Guardar una nota | **1**: la relectura del detalle | 1 | 20 notas: **20 + 20** |
| El índice nuevo | 0 | 0 (se cobra por documento, no por índice) | 0 |

**Propio de este cambio: ~40 lecturas y ~20 escrituras por día. Acumulado del panel:
~5.934/día, 11,9 % de la cuota**; escrituras ~267/día, 1,3 %.

⚠️ **Dos números son supuestos míos, no del código:** 20 búsquedas y 20 notas por día
(una por pedido). Aun con 100 y 50, el cambio suma 150 lecturas (12,1 %). Y uno que
**probablemente baje** y no está medido: con *"Requieren acción"* como entrada, las
fichas por apertura deberían pasar de 3 a 1 o 2 (−750 a −1.500/día). No se descuenta
hasta una semana de uso real.

**La preview de la vidriera martillada sigue sin entrar** (ADR 019: 109,7 %): lo que hay
que recortar es la preview (ADR 017), no esto.

## Lo que este ADR deja abierto, con su disparador

| Qué | Disparador |
|---|---|
| **Notas simultáneas: gana la última** (§3) | La primera nota que alguien diga que se perdió |
| **Buscar por nombre o teléfono del cliente** — no hay índice ni forma barata (sería un `>=` por prefijo sobre un campo anidado) | Que el dueño lo pida |
| HU-06.5, HU-07.3 y EP-08 | Los de la tabla de *Contexto* |

## Verificación (2026-09-25)

Cada fila dice **cómo**; un job verde no prueba nada.

| Qué | Cómo |
|---|---|
| Las suites | CI `alcance=tests`, corrida `36192553512` sobre `04a149f`, **restadas contra la de ADR 019**: Dart 420 → **432 (+12 exactos)**; emulador 158 → **162 (+4)**. `guardas` cayó ahí por `_verdad.md` sin regenerar (823 → 839 casos), corregido en `8dde89e` |
| ⭐ Que la consulta discrimine | El caso nuevo de `ordenes.test.mjs` siembra **los 36 pares** y corre el `OR` real: trae exactamente los que la proyección marca (control positivo `por_fuera|sin_preparar`, negativo `por_fuera|entregada`), en orden. **Mutado** —sin el tramo de `fallida`— cae ese caso y ningún otro (39/40, local) |
| Las reglas no cambiaron | `firestore.rules` fuera del diff. Los casos nuevos prueban que dejan pasar las tres consultas con su forma real, con `limit` 51 y un comprador rechazados |
| Sin huérfanos | `cazador-de-puertas`: cada símbolo nuevo con call site fuera de su archivo; cadena `enrutador → PantallaDePedidos → BuscadorDePedido · SelectorDeVista` y `→ PaginaDelPedido → DetalleDelPedido → SeccionDeNotas → HojaDeNota`. Controles: uno usado > 0, uno inventado = 0 |
| Hooks | `probar_hooks.sh` 35/35; los 6 del panel sobre los 20 archivos Dart tocados: 0 bloqueos |
| Compila | CI `alcance=panel`, corrida `36192938783` sobre `8dde89e`: el paso *Análisis estático* dice **No issues found**, build web de **35 archivos**, `main.dart.js` `687d027a…`, artifact `panel-web` (id `10888882706`). La lista de jobs, no el color: `suite_emulador` y `suite_ts` **skipped** en esa corrida a propósito (corrieron en la `36192553512`) |

### Lo que NO se verificó

- ⚠️ **NO está desplegado.** El contenedor de la sesión no tiene credenciales de
  Firebase, y el cambio vive en la rama `claude/gracious-wright-5f3ahe`, no en
  `main`. **El orden es índices → panel**: el índice nuevo tiene que estar
  **construido** (correr la consulta, no mirar `READY`) antes de publicar el panel,
  o *"Requieren acción"* —la ficha con la que abre— da `FAILED_PRECONDITION`.
- `flutter analyze` local lo frenó el clasificador (CLAUDE.md lo prohíbe): el
  análisis es el de CI.
- **Nadie lo miró renderizado**, y en producción hay 0 pedidos.
