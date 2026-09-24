# ADR 016 — Mover el stock: reponer y corregir

- **Fecha:** 2026-09-23
- **Estado:** aceptada y **desplegada el 2026-09-23**, en el orden reglas →
  `moverStock` → panel (`aff14bb`), verificada con la API cruda y con los tres
  controles sobre `moverStock` y `procesarFoto`. **Y `moverStock` ya se usó de
  verdad** (2026-09-24 00:04 UTC, `0 → 32`, un solo movimiento, ver
  *Verificación*). Falta que el dueño lo mire y diga si le sirve
- **Decide:** cómo se escribe `stock` desde el panel, dado que las reglas de
  Firestore le prohíben escribirlo ([ADR 008](008-catalogo-stock-y-carrito.md)
  §1): una callable `moverStock` con dos operaciones, `reponer` y `corregir`,
  idempotente, con la baranda `visto` contra el valor absoluto que pisa ventas
- **Historias:** HU-05.1 · HU-05.2 · HU-05.3 ([EP-05](../../features/panel/EP-05-stock.md)).
  **HU-05.4** (ver los movimientos de un producto) queda afuera, con su
  disparador — pero el dato que necesita ya se guarda (§3)
- **Toca:** [ADR 008](008-catalogo-stock-y-carrito.md) (cumple lo que dejó
  escrito: *"la reposición llega por una callable del servidor"*) y
  [ADR 015](015-fotos-del-panel.md) (la guarda de admin de `procesarFoto` pasa
  a `functions/src/auth.ts`, compartida)
- **Hace cumplir:** `packages/contratos/test/stock.test.ts`,
  `functions/test/stock/mover.emulador.mjs` (19 casos contra el emulador de
  Firestore, **a mano**: no corren en CI, ver *Lo que queda abierto*),
  `scripts/reglas/productos.test.mjs` (3 casos nuevos), y los tests de Dart de
  `apps/admin/test/features/stock/` y `test/core/contratos/stock_test.dart`
- **Sin openspec, a pedido del dueño** (2026-09-23): este ADR y el `EP-05`
  del mapa son la especificación. Las tareas vivieron en la conversación

## Contexto

`stock` lo escribe **sólo el servidor**. Las reglas ven el documento
resultante y no la operación, así que no distinguen un `increment(10)` de un
valor absoluto calculado sobre un dato viejo, y por eso el panel no lo escribe
en absoluto. Sin esta pieza, todo vino nace con stock 0, la vidriera lo muestra
*"Se agotó"* para siempre, y el hito 1 —*"que el dueño cargue su catálogo
real"*— queda a medias: se puede cargar y publicar un vino que nadie puede
comprar.

Es la **primera Cloud Function que escribe plata**. Por eso Workflow D:
`revisor-pagos` corrió sobre el backend **antes** de commitear (§ *Lo que
encontró `revisor-pagos`*), y el panel que la llama sale **después** de que el
backend esté verificado en producción.

## Decisión

### 1. Una callable, dos operaciones

`moverStock(productoId, idMovimiento, operacion)`, con `operacion` una de:

| Operación | Qué hace | Por qué es de plata |
|---|---|---|
| `reponer { cantidad }` | **Suma.** Entra mercadería; no importa cuánto había | Conmutativa: dos reposiciones a la vez dan la suma exacta |
| `corregir { visto, valor, motivo }` | **Fija** el stock en `valor` después de contar el depósito | Un absoluto **pisa las ventas del medio**. Por eso lleva `visto` |

**`visto` es el `precioUnitarioVisto` de `crearOrden`, para el stock**: el
número que el operador tenía en pantalla al contar. Si el stock ya no es ése,
la callable rechaza con `failed-precondition` y devuelve `{ codigo:
'cambio-el-stock', actual }` — el panel muestra el número de ahora, **vacía el
campo y pide contar de nuevo**. Reintentar el mismo valor a ciegas es
exactamente lo que el rechazo evita.

`motivo` es una lista cerrada de tres (`conteo`, `rotura`, `otro`) que se elige
con **un toque**, no se escribe: poca burocracia
([overview del panel](../../features/panel/overview.md), criterio 4), y un
motivo escrito a mano no se puede contar después.

**Corregir al mismo valor que ya había se rechaza en el parser**: no es una
corrección, y dejaría un registro que no explica nada.

**Un tope de 5.000 unidades** (`TOPE_DE_STOCK`), después de cualquier
movimiento. Es una baranda anti dedo-gordo —un cero de más en una reposición
es el error probable— y **una decisión mía, que el dueño puede cambiar**: el
catálogo real es de decenas de unidades por vino. Vive en `contratos`, no en
las reglas (`stock` no pasa por ellas). `visto` no tiene tope propio: si un dato
anterior a la baranda lo pasó, el operador tiene que poder bajarlo.

### 2. La transacción (`functions/src/stock/mover.ts`)

Una sola, en este orden, y **el orden importa**:

1. Lee el producto **y el marcador** — las dos lecturas, antes de cualquier
   escritura (Firestore no lee después de escribir).
2. **Si el marcador existe**: es un reintento. Misma operación → devuelve lo
   que pasó la primera vez (`repetido: true`), aunque el stock ya sea otro.
   Otra operación con el mismo id → `already-exists`. **Se mira antes que el
   tipo del producto**, para que un reintento legítimo no falle porque el
   producto cambió en el medio (hallazgo 6).
3. Rechaza un compuesto (no tiene stock propio, [ADR 009](009-venta-por-caja.md)
   §10) y un stock que no es un entero ≥ 0: **un stock roto no se
   "arregla", alguien lo tiene que mirar**.
4. Aplica la cuenta (`aplicarOperacion`, en `contratos`) sobre el stock que
   **acaba de leer**, no el que el panel tenía.
5. Escribe `stock` **y** el marcador en la misma transacción, con `create`
   (un `set` pisaría un marcador ajeno). `maxAttempts: 10`, porque
   `crearOrden` va a competir por el mismo documento.

**Escribe sólo `stock`.** Un campo de más rompe el `hasOnly` de las reglas y el
panel deja de poder editar ese vino, en silencio. Lo prueba un caso del
emulador (el producto queda con las mismas claves) y uno de las reglas (después
de un movimiento del servidor, el panel sigue pudiendo editar).

**Los vinos de muestra se pueden mover, a propósito**: es lo que permite
probar en producción sin tocar un vino real. `crearOrden` los rechaza
([ADR 008](008-catalogo-stock-y-carrito.md)); esta callable no.

### 3. El marcador es también el registro

`productos/{id}/movimientos/{idMovimiento}` guarda `operacion`, `antes`,
`despues`, `por` (el uid) y `en` (hora **del servidor**). Es el marcador de
idempotencia y, de yapa, **el dato que HU-05.4 va a leer**: se guarda ahora
porque agregarlo después no se puede hacer hacia atrás.

Las reglas lo cierran a los clientes (`allow read, write: if false`), por el
mismo motivo que `ordenes/marcadores`: si el panel pudiera **crear** uno,
marcaría un movimiento como hecho sin que ocurra; si pudiera **borrarlo**, lo
dejaría ocurrir dos veces. Las dos cosas son stock. El bloque es redundante con
el `deny` por defecto **a propósito**: hace legible la intención, y una
colección nueva sin su bloque parece un olvido.

### 4. La guarda de admin, en un solo lugar

`functions/src/auth.ts` (`exigirAdmin`) reemplaza las dos guardas de
`procesarFoto` y sirve a `moverStock`. Devuelve el `uid`: una callable que
escribe plata tiene que dejar dicho **quién**. Las reglas de Firestore y de
Storage **no protegen una callable**, así que es la única puerta.

### 5. El panel

- **`SeccionDelStock`** en la ficha de un vino, entre la sección de la tienda
  y el formulario: el stock **exacto** en su unidad (`4 cajas de 6 · 24
  botellas`, no sólo botellas), la palabra del balde (*"Se agotó"*, *"Quedan
  pocas"*) y dos botones. No aparece al cargar un vino nuevo, que nace en 0.
- **Dos hojas** con el patrón de `HojaDePrecio`. **Reponer no pide confirmar**
  —se equivoca uno y se corrige, y el *"Va a quedar en N"* se ve antes de
  apretar— y **corregir tampoco**: la baranda es `visto`, y la vista previa
  dice la diferencia con su signo (*"Pasa de 10 a 7 (−3)"*).
- **Las hojas no leen el stock en vivo**: usan el que el operador tenía al
  abrirlas, que es exactamente lo que `visto` significa. Si cambió, el
  servidor lo rechaza y la hoja muestra el número de ahora. Así el feature
  `stock` no depende de `catalogo` (que es quien lo embebe).
- **`idMovimiento`: UNO por hoja, y no se regenera nunca** (§ hallazgo 2).
- **HU-05.3**: un filtro **"Por reponer (N)"** en el catálogo —agotados
  primero, después los que menos botellas tienen, con desempate por nombre
  porque `List.sort` de Dart no es estable— y una línea de stock en cada
  renglón. Un vacío con el filtro puesto se dice como lo que es, una buena
  noticia (*"No hay nada por reponer"*), no como un error.
- El espejo en Dart (`core/contratos/stock.dart`) se verifica contra 16
  fixtures **calculadas** por el TypeScript (`generated/contratos.json`), no
  contra sí mismo. `textoDelBalde` se movió a `core/contratos/catalogo_publico.dart`
  porque lo usan dos features que no pueden importarse.

### Por qué existe esto (NO REVERTIR): un `idMovimiento` por hoja

La primera versión de las hojas generaba un id nuevo cada vez que cambiaba la
cantidad, para que "otra operación" no chocara con el marcador de la anterior.
Parecía prolijo y **suma dos veces justo cuando el operador más duda**: repone
6, la respuesta se pierde con la transacción ya commiteada (10→16), cambia a
12, y con un id nuevo la callable lo aplica — 28 en vez de 22. Lo encontró
`revisor-pagos` el 2026-09-23, **antes de que se desplegara nada**, leyendo el
panel que consume la callable y no sólo la callable.

La regla que queda es más simple que la que la reemplazó: **un id por hoja**.
Tras un error ambiguo reusarlo es *obligatorio*; tras un rechazo definitivo no
quedó marcador y reusarlo no hace daño; y con otra operación la callable
contesta `already-exists`, que el panel dice como *"Ese movimiento ya se había
registrado: mirá el stock antes de volver a intentar"*. Volver a hacerlo "más
inteligente" reabre el bug.

## Por qué NO las alternativas

| Alternativa | Por qué no |
|---|---|
| Dos callables (`reponer` y `corregir`) | El doble de superficie de IAM y de CORS —cada una necesita su permiso público y sus tres `curl`— para el mismo núcleo transaccional |
| El panel escribe una "solicitud" y un trigger la aplica | Asíncrono: el error no llega a la pantalla que lo causó (la lección de HU-04.4), y abre una colección escribible desde el cliente |
| Que las reglas dejen al panel hacer `increment` | La regla ve el documento resultante, no la operación ([ADR 008](008-catalogo-stock-y-carrito.md)) |
| Regenerar el `idMovimiento` cuando cambia la cantidad | **Suma dos veces** tras un error ambiguo. Fue lo que la primera versión de las hojas hizo, y el hallazgo 2 lo encontró |
| Confirmar cada corrección con un diálogo | Poca burocracia: se confirma lo que no tiene vuelta atrás, y una corrección tiene otra corrección |
| Un campo de texto para el motivo | No se puede contar después, y el registro existe para explicar diferencias |

## Presupuesto de lecturas

Campo obligatorio. Cuantificado por el agente `presupuesto-lecturas` y
**verificado leyendo el código**, no supuesto.

| | Lecturas | Escrituras (cuota 20.000) |
|---|---:|---:|
| Un movimiento normal (2 en la transacción + 1 del listener del panel) | **3** | 2 |
| Un reintento idempotente (el marcador ya existe) | 2 | 0 |
| Un rechazo (cambió el stock, tope, compuesto…) | 2 | 0 |
| Peor caso: 10 intentos por contención | 21 | 2 |

| Movimientos/día | Normal | % de la cuota de 50.000 | Base + EP-05 |
|---:|---:|---:|---:|
| 10 | 30 | 0,06 % | 7,6 % |
| 100 | 300 | 0,6 % | 8,2 % |
| 500 | 1.500 | 3 % | 10,6 % |

**HU-05.3 cuesta cero:** el filtro y su contador salen del `catalogoProvider`
en memoria, y las hojas reciben el stock por parámetro. No hay listeners
nuevos. **Nada lee `movimientos`**: no el panel, no la vidriera, no el seed; y
`collection('productos')` no trae subcolecciones. No escala con las visitas.

⚠️ **Dos riesgos del futuro que este ADR deja escritos** (los midió el agente):

1. **Tramo 4.** Cuando exista el trigger que purga la vidriera por tag, **cada
   movimiento va a dispararlo**, y si cambia el balde de un vino publicado la
   vidriera reconstruye: **232 lecturas** (P+B+2), no las ~20 por edición que
   cuenta ARQUITECTURA §6.3. La primera reposición de cada vino —que nace en 0—
   pasa justo de *agotado* a *disponible*. Con 200 vinos publicados y una visita
   entre carga y carga, hasta **46.400 lecturas: el 93 %**. **Cargar el stock
   antes de publicar lo evita**, y por eso "Publicar apenas se cargue" con
   stock 0 (ADR 015 §5) merece mirarse cuando se escriba el tramo 4.
2. **`movimientos` crece sin límite.** No se borra nunca. A 500 por día son
   ~182.000 documentos al año. Hoy cuesta 0; para **HU-05.4** hay que leerlo
   con `orderBy('en').limit(20)` (20 lecturas por apertura, índice simple
   automático), **nunca sin `limit`**. `scripts/seed/borrar.mjs` borra el
   producto y deja la subcolección huérfana.

## Lo que encontró `revisor-pagos` (2026-09-23)

Corrió **antes** de commitear, con el backend escrito. Probó contra el emulador,
no sólo leyendo. **Ninguno de los ocho es un camino por el que el backend aplique
un movimiento dos veces.**

| # | Sev. | Qué | Qué se hizo |
|---|---|---|---|
| 1 | MEDIO → **ALTO con `crearOrden`** | `corregir` **pisa lo vendido y todavía no despachado**: con 2 botellas vendidas y sin despachar, el panel muestra 8, el operador cuenta 10 en la estantería, `visto` coincide, y quedan 10 — se venden 2 que no existen | **No se puede disparar todavía** (no hay órdenes). **Bloquea `crearOrden`**: la hoja de corrección tiene que mostrar *"N vendidas sin despachar"*. Va a *Lo que queda para `crearOrden`* |
| 2 | MEDIO | **Mi panel regeneraba el `idMovimiento` al cambiar la cantidad**, también tras un error ambiguo: repone 6, timeout con la transacción ya commiteada (10→16), cambia a 12, id nuevo, queda 28 en vez de 22 | **Corregido**: un id por hoja, nunca se regenera. Tras un error ambiguo reusarlo es *obligatorio*; tras un rechazo definitivo no hay marcador y reusarlo no hace daño; con otra operación, la callable contesta `already-exists` → *"Mirá el stock antes de volver a intentar"* |
| 3 | MEDIO | `moverStock` es nueva: el CLI intenta dar `allUsers` como invoker y es **el mismo paso que falló con `procesarFoto`** — preflight 403. Y desplegar todo redespliega `procesarFoto` | `--only functions:moverStock`, y los **tres controles sobre las dos**. Si da 403, el dueño corre `add-iam-policy-binding` |
| 4 | BAJO | `valor: -0` pasa el parser y Firestore lo guarda como `doubleValue`: `stock is int` falla y **el panel ya no puede editar ese vino**. Sólo con un cuerpo escrito a mano | **Corregido**: `Object.is(x, -0)` en el parser, con test |
| 5 | BAJO | Un stock negativo no se puede reparar desde el panel | **A propósito**: es un dato roto. Lo que tiene que evitar es `crearOrden`, adentro de su transacción |
| 6 | BAJO | El marcador se miraba después del tipo del producto | **Corregido**: se mira antes. Test agregado |
| 7 | BAJO | Un token revocado sirve hasta una hora (`verifyIdToken` sin `checkRevoked`) | La misma ventana que las reglas: no es un agujero nuevo. Anotado |
| 8 | BAJO | Los 19 casos del emulador y el bloque de reglas **no corren en CI** | Agrava el hallazgo 7 de ADR 008. Va a *Lo que queda abierto* |

**Y lo que revisó y no rompe:** la firma de la operación (ordena las claves;
Firestore devuelve los mapas ordenados); 5 llamadas simultáneas con el mismo id
son UN movimiento; un `HttpsError` adentro de la transacción no se reintenta;
si se pierde la respuesta de un commit el SDK reintenta, encuentra el marcador
y devuelve `repetido`; `visto` sin tope nunca coincide con nada raro; y
`movimientos` queda cerrado dos veces.

## Lo que queda para `crearOrden`

`crearOrden` va a escribir **este mismo campo** en su propia transacción.
Firestore serializa las dos sobre el documento, así que no hay sobreventa por
esta vía. Lo que tiene que respetar:

1. **Escribir en el producto sólo `stock`, entero, nunca `-0`** — o se rompe el
   `hasOnly`.
2. **Asegurar `stock ≥ 0` adentro de su transacción.** `moverStock` no repara
   negativos.
3. **Guardar su marcador fuera de `productos/*/movimientos`**: `moverStock`
   trata cualquier documento ahí como propio.
4. **Resolver el hallazgo 1 antes de salir.**
5. **Rechazar `muestra == true`**: `moverStock` los deja mover.
6. Una cancelación que deje el stock por encima del tope no es problema:
   `corregir` lo puede bajar.

## Verificación

Se actualiza a medida que ocurre. **Hoy:**

| Qué | Cómo | Estado |
|---|---|---|
| El contrato | `contratos`: 205 tests; el JSON fresco (`auditar_estados`); las 16 fixtures se calculan con el parser y la cuenta de hoy | ✅ |
| La transacción | 19 casos contra el emulador de Firestore, con concurrencia real (12 reposiciones a la vez suman exacto; 2 correcciones con el mismo `visto`, gana una). **Mutada**: sin la rama del marcador y sin la baranda de `visto`, fallan 7 casos, exactamente los de idempotencia y de `visto` | ✅ |
| Las reglas | 57 casos; **mutando** `movimientos` a `esAdmin()`, falla exactamente el caso que lo prueba | ✅ |
| Revisión de plata | `revisor-pagos`, 8 hallazgos, ver arriba | ✅ |
| Reglas | API de Rules: ruleset `0c73d24a` idéntico al archivo local; `movimientos` en 1 y una colección inventada en 0 | ✅ |
| `moverStock` | API de Cloud Functions: `ACTIVE`, GEN_2, callable; `allUsers` como invoker (lo puso el CLI); preflight **204**, `POST` anónimo **401 JSON**, función inventada **404** — sobre `moverStock` **y** `procesarFoto` (intacta) | ✅ |
| El panel | CI `panel` (`suite_dart` 197→244) y `tests` (`suite_ts` 185→205); canal → canario (6 cadenas nuevas: 0 en live, ≥1 en el canal) → promover → 4 hashes iguales. Live sirve `aff14bb` | ✅ |
| Que la app arranca | CDP sobre live: `/entrar`, Flutter montado, 0 errores de consola | ✅ |
| **Llamarla como usuario real** | **No la pude llamar yo** (mintear un token lo frena el clasificador). **Alguien la usó**: a las 00:04 UTC del 2026-09-24 repuso 32 en `vino-de-prueba`, y `productos/vino-de-prueba/movimientos` tiene **un solo** marcador con `antes 0 → despues 32`, `operacion {tipo: reponer, cantidad: 32}` y el uid. Cubre lo que el emulador no: el Admin SDK contra el Firestore real y el permiso de la cuenta de servicio | ✅ |
| **Que alguien lo mire y diga si le sirve** | Alguien lo usó (arriba); **falta el juicio del dueño** sobre si la pantalla se entiende | ⏳ |

## Lo que queda abierto

- **Los tests del emulador no corren en CI** (hallazgo 8): `mover.emulador.mjs`
  y los de reglas se corren a mano, y ahora hay dos suites así. Pesa más que
  antes porque una es la que protege la plata. **Disparador:** la sesión de
  `crearOrden`, como ya estaba anotado en ADR 008.
- **HU-05.4** — ver los movimientos de un producto. **Disparador:** la primera
  diferencia que nadie sepa explicar. El dato ya se guarda.
- **Confirmar el tope de 5.000** con el dueño (§1).
- **El `procesarFoto` desplegado NO usa todavía `exigirAdmin`**: el deploy fue
  `--only functions:moverStock` (hallazgo 3) y su fecha de actualización sigue
  siendo la del 2026-09-22. El código del repo sí la usa. Es la misma guarda con
  los mismos mensajes (el `POST` anónimo da el mismo 401), pero **repo y
  producción difieren en esa función** hasta el próximo deploy completo de
  functions, que tiene que repetir los tres controles sobre `procesarFoto`
  porque el permiso público lo puso el dueño a mano.
