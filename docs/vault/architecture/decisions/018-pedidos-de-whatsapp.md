# ADR 018 — Los pedidos de WhatsApp: cargarlos, y verlos

- **Fecha:** 2026-09-24
- **Estado:** aceptada el 2026-09-24; **en construcción**. Lo que está escrito,
  desplegado y verificado se anota al final, en *Verificación*, tarea por tarea,
  y no en esta línea
- **Decide:** cómo nace una Orden que no pasó por la vidriera —qué guarda, qué
  estado de pago le calza, quién la puede crear— y cómo la ve el panel
- **Historias:** HU-10.1 ([EP-10](../../features/panel/EP-10-ventas-por-fuera.md)),
  HU-06.1 y HU-06.2 ([EP-06](../../features/panel/EP-06-ver-pedidos.md)).
  Primer tramo del **hito 2**
- **Toca:** [ADR 002](002-estados-de-orden.md) (agrega un valor al eje de pago),
  [ADR 008](008-catalogo-stock-y-carrito.md) («lo que queda para `crearOrden`»),
  [ADR 016](016-mover-el-stock.md) (misma transacción sobre el mismo campo)
- **Hace cumplir:** `packages/contratos/test/`, `functions/test/pedidos/`
  (emulador), `scripts/reglas/ordenes.test.mjs` y los tests de Dart de
  `apps/admin/test/features/pedidos/`

## Contexto

Hay ventas que **ya existen** y no pasan por la vidriera: se piden por
WhatsApp y se cobran por fuera ([EP-10](../../features/panel/EP-10-ventas-por-fuera.md)).
Hoy nada las registra, así que el stock del panel miente en cuanto se entrega
una. Cargarlas es la primera pieza del hito 2 porque no espera a Mercado Pago,
y la primera que **crea una Orden**: la forma del documento la fija esta
decisión, y la vidriera va a escribir la misma cuando exista su `crearOrden`.

Es **Workflow D**: la callable descuenta stock y numera. `revisor-pagos` corre
sobre el backend antes de commitear, y el formulario sale **después** de que el
backend esté verificado.

## Decisión

### 1. Una callable del panel, no un `crearOrden` con un parámetro

`crearOrdenDelPanel` es una callable propia, con `exigirAdmin`. **El origen no
viaja en el pedido: lo fija el servidor según qué callable se llamó** (hallazgo
12 del mapa). Si `crearOrden` aceptara `origen: 'whatsapp'`, un comprador de la
vidriera se saltearía la regla de las seis botellas diciéndolo.

Las dos comparten el núcleo —la transacción— y difieren en las guardas: la del
panel exige el claim y **no exige la caja de seis** (respuesta 7 del dueño); la
de la vidriera, cuando exista, exigirá lo contrario y no exigirá claim.

### 2. La Orden, con su forma

```text
ordenes/{ordenId}        ordenId = idPedido  (ver §4)
  numero          entero secuencial, de contadores/ordenes
  origen          'whatsapp' | 'vidriera'      ← escrito por el servidor
  estadoPago      'por_fuera' para whatsapp    ← §3
  estadoEntrega   'sin_preparar'
  items[]         { productoId, nombre, precioUnitario, cantidad, botellas }
  subtotal        centavos: Σ precioUnitario × cantidad
  envio           null  (no se cotiza: el precio y el correo se arreglan por el chat)
  total           centavos == subtotal
  contacto        { nombre, telefonoE164, email | null }
  entrega         { calle, numero, piso | null, referencia | null,
                    destino: { codigoPostal, localidad, provincia, propio } }
  creadaEn · actualizadaEn   serverTimestamp
  creadaPor       uid de quien la cargó
```

- **`items[]` es un snapshot y guarda `botellas`** (hallazgo 1 de ADR 008): la
  cancelación futura repone con **ese** número, no con el del producto de hoy.
- **`contacto` y `entrega` van separados** porque el índice
  `numero + contacto.email` ya está declarado en `firestore.indexes.json` para
  `consultarOrden`: la forma del contacto tiene que ser la que ese índice espera.
- **`envio: null` siempre escrito**, nunca ausente: un campo que puede faltar
  es la trampa de `publicado` (ARQUITECTURA §5.2).
- **Los datos de entrega se validan con `validarDatosDeEntrega`**, el mismo
  validador de la vidriera: dos validadores del mismo dato se desincronizan. El
  teléfono se pega tal cual vino del chat y el normalizador lo pasa a E.164.

### 3. ⭐ El pago de un pedido de WhatsApp es `por_fuera` — **decisión mía**

Los cinco estados de pago describen un cobro que el sistema **mira**
([ADR 002](002-estados-de-orden.md)). Un pedido de WhatsApp se cobra por fuera
y el panel no lo sigue, así que ninguno le calza:

| Opción | Por qué no |
|---|---|
| `pendiente` | El pedido entregado cae en *entregada impaga* y **queda para siempre** entre los que requieren acción: ruido, y contra el criterio de poca burocracia |
| `pagada` | Afirma algo que nadie comprobó, y **dispara `entroEnPagada`**: el aviso, y mañana el mail, saldrían por un cobro que no pasó por acá |
| Que la proyección mire `origen` | Deja un `estadoPago: pendiente` que **dice algo falso** en la base, y cualquier consulta por `estadoPago` (HU-08.x) lo cuenta como deuda |
| **`por_fuera`** | **Es lo que pasa.** Un valor nuevo del eje |

**`por_fuera` es terminal y sin transiciones**: nada sale de ahí ni entra
después. Nace sólo en una Orden de origen `whatsapp`, y la invariante
*origen ⇔ estadoPago inicial* vive en `contratos` (`estadoDePagoInicial`), no
en la callable, para que la vidriera no pueda nacer `por_fuera` ni el panel
`pendiente`.

Consecuencias, **todas en `contratos`** y espejadas en Dart:

- `ESTADOS_PAGO` 5 → 6, y la proyección pasa de **30 a 36 pares**.
- **Un estado público nuevo, `por_preparar`**, para `por_fuera|sin_preparar`.
  Ni `pagada` (afirmaría un cobro) ni `recibida` (dice *«falta cobrar»*). Su
  rótulo de operador es **«Cobro por fuera - falta preparar»** y **entra en
  `REQUIEREN_ACCION`**: hay que prepararlo, igual que uno pagado.
- El resto de los pares de `por_fuera` reutilizan estados que ya existen:
  `preparando → en_preparacion`, `despachada → en_camino`, `entregada →
  entregada` (**no** `entregada_impaga`), `fallida → no_entregada`,
  `cancelada → cancelada` (no hay pago que devolver).
- `entroEnPagada` **no dispara** para `por_fuera`, y eso es lo correcto.

⚠️ **Es un cambio de contrato**: se bumpea minor y **el panel de Android con una
APK vieja** recibiría un `estadoPago` que su enum no conoce. Hoy no hay APK
repartida (H5 del mapa); **el día que la haya, esto es un motivo más para la
versión mínima**.

### 4. Idempotencia: el documento es su propio marcador

`idPedido` lo genera **el formulario al abrirse y no se regenera nunca**
(la lección de `moverStock`: un id nuevo tras un error ambiguo es un pedido
duplicado). **`ordenId = idPedido`**, así que crear la Orden **es** escribir el
marcador, en la misma transacción que el descuento de stock y el contador. No
hay una ventana entre las dos.

- La transacción lee primero la Orden. Si existe **y el pedido entero coincide**
  —líneas, contacto y entrega—, es un reintento: devuelve el `numero` que ya
  tiene, sin tocar nada.
- Si existe con **algo distinto**, no es un reintento: `already-exists`, **con el
  `numero` de la Orden que ya existe**. Con otras líneas sería descontar algo que
  el operador no cargó; con otra dirección u otro cliente sería devolver *«éxito»*
  sin haber guardado lo que escribió.
  ⚠️ **Se comparaba sólo las líneas, y era un error** (hallazgo 3 de
  `revisor-pagos`): un reintento con la dirección corregida devolvía
  `repetido: true`, el panel mostraba éxito y la Orden seguía con la dirección
  vieja, en silencio. Corregir un dato de una Orden ya creada no es un reintento:
  es EP-07, y hoy no se puede.
- `maxAttempts: 10` con `timeoutSeconds: 120`: compite con `moverStock` por el
  mismo documento de producto, y un aborto por contención no es un error del
  operador. El backoff de Firestore suma ~75 s en diez intentos, así que con los
  60 s de por defecto la función moría a mitad y dejaba un resultado ambiguo
  (hallazgo 10).

### 5. Lo que la callable valida, y contra qué

Todo **adentro** de la transacción, contra lo que se acaba de leer:

| Qué | Cómo | Por qué |
|---|---|---|
| El producto existe y es `simple` | `validarProducto` | Un compuesto no tiene stock propio (ADR 009 §10) |
| **No es de muestra** (`muestra == true`) | rechazo | Los 20 vinos del seed no existen: vender uno descuenta un stock inventado |
| `precioUnitarioVisto == precio` | rechazo con el precio de ahora | La lista del panel puede tener atraso; un precio viejo no se guarda |
| `stock >= cantidad` | rechazo `sin-stock` con `{ productoId, actual }` | Nunca negativo |
| `precio >= 1` | rechazo `sin-precio` | Un borrador con precio 0 daba `cambio-el-precio` con `actual: 0`, y el panel ofrecía reintentar a $0, que el parser no deja mandar (hallazgo 9) |
| `precio <= PRECIO_MAXIMO` (~600 millones de pesos) | el parser rechaza el visto; el núcleo, el del producto (`producto-roto`) | Por encima, `sumar` lanza un `RangeError` que la callable contestaría `internal` en vez de rechazar con un motivo (hallazgo 6) |
| Largo de los textos de la entrega | `LARGOS_DE_ENTREGA`: calle 120, referencia 300, mail 254… | Una `referencia` de 900.000 caracteres dejaba la Orden cerca del MiB (hallazgo 8). El validador es el mismo de la vidriera |
| Sin líneas repetidas | el parser rechaza | Sumar la demanda por producto es lo que evita validar dos veces contra el mismo stock |
| Tope de líneas y de cantidad | 30 líneas · `cantidad ≤ TOPE_DE_STOCK` | Hallazgo 5 de ADR 008: 10.000 ids inventados validan |

⚠️ **El `idPedido` no puede ser un id reservado `__x__`** de Firestore (hallazgo 7): como
es el id de la Orden, pasaba el parser y Firestore lo rechazaba con `internal`.

**No exige que el vino esté publicado.** Un pedido de WhatsApp puede ser de un
vino que la tienda no muestra; el operador sabe lo que vende. Sí exige el precio
visto, para que el snapshot sea lo que tenía en pantalla.

### 6. El precio es el de lista — **decisión mía**

Un precio arreglado por chat puede no ser el de lista. **No se construye
un precio por línea**: el snapshot guarda el de lista y **el total no es lo que
se cobró**. Por eso estos pedidos **no suman a ningún total del panel**
(no existe ninguno todavía), y el detalle **no dice «cobrado»**: dice el total
de lista. Disparador para cambiarlo: el primer pedido cuyo precio real no fue el
de lista y alguien lo quiera ver.

### 7. El panel ve los pedidos por lo que hay que hacer (HU-06.1, HU-06.2)

- La lista es `estadoEntrega == X` ordenada por `creadaEn` descendente, con
  `limit(25)`, sobre el índice ya declarado. **Se verifica corriendo la
  consulta**, no mirando que el índice esté `READY`.
- Las reglas de `ordenes` piden `limit <= 50` en un `list`, igual que
  `movimientos`: sin tope, una lista lee **todas** las órdenes.
- El detalle **recibe la Orden que ya trajo la lista**: cero lecturas extra. Con
  la URL directa lee **una**.
- El rótulo sale de `proyectarEstadoPublico`, nunca de mirar los dos campos.
- **Queda afuera de HU-06.2 *cuántas cajas son y cuánto pesan***: pide espejar
  `bultosDelPedido` en Dart, y hoy nada lo consume. Disparador: HU-07.2
  (despachar), que es quien lo necesita. `items[]` ya guarda `botellas`, así que
  no hace falta ningún dato nuevo.

### 8. Cada venta deja su movimiento (hallazgo 2)

La transacción escribe **un movimiento por línea** en
`productos/{id}/movimientos/venta-{idPedido}`, con la misma forma que los de
`moverStock` (`antes`, `despues`, `por`, `en`) y `operacion: { tipo: 'venta',
cantidad, idPedido, numero }`. Sin esto, la hoja de HU-05.4 mostraba *0 → 32* y
después *30 → 29*, y **faltaban dos unidades sin explicación**: el registro
existe justamente para explicar diferencias
([ADR 016 §6](016-mover-el-stock.md)). Y el remedio de un pedido mal cargado
—reponer con `moverStock`— quedaba registrado como *«Cargó 2 botellas»*.

Cuesta **una escritura por línea y cero lecturas**. El id lleva el `idPedido`, así
que un reintento no lo duplica, y no choca con los de `moverStock`, que son
hexadecimales sin guion. Es `create`, no `set`: un choque tiene que fallar.

### 9. Corregir el stock con ventas sin despachar (hallazgo 1, ALTO)

**Es el bloqueante que [ADR 016](016-mover-el-stock.md) dejó escrito para el día
que existiera este descuento**, y este cambio lo activa. Con 10 en la base y en la
estantería, se carga un pedido de 2: la base dice 8 y las botellas **siguen en la
estantería** hasta que se despachan. El dueño cuenta 10, corrige con `visto: 8,
valor: 10` y `moverStock` lo acepta porque `visto` coincide: **la base dice 10
cuando hay 8 disponibles**, y la próxima venta sobrevende dos botellas.

**Decisión:** la hoja de corrección **dice cuántas unidades hay vendidas y sin
despachar** de ese vino, y explica que ya están descontadas pero siguen en la
estantería: *«al contar, restale esas N»*. Se cuenta leyendo los pedidos en
`sin_preparar` y `preparando` (`limit(50)`) y sumando sus ítems de ese vino:

- **Sin campo nuevo en la Orden ni índice.** Un `productoIds[]` con `array-contains`
  lo haría exacto, pero es un esquema y un índice que hoy no se justifican con
  una familia y pocas decenas de pedidos abiertos. Si se llenan más de 50, el aviso
  **dice que el número puede ser mayor** en vez de afirmar uno incompleto.
- **Cuesta hasta 50 lecturas por apertura de la hoja**, que es una operación rara
  (contar el depósito). No suma al catálogo ni a la bandeja.
- Es un **aviso**, no una baranda: no bloquea corregir. Restar por uno no es
  posible sin saber qué ya salió, y bloquear frenaría un conteo legítimo.

Disparador para el campo exacto (`productoIds[]`): más de 50 pedidos sin despachar,
o el primer conteo que el aviso no alcance a explicar.

### 10. Lo que un pedido mal cargado NO tiene todavía (hallazgo 5)

Un pedido cargado con un error **no se puede cancelar** hasta HU-07.6 (Workflow D:
la cancelación repone stock en el servidor). Y queda en `REQUIEREN_ACCION`, así que
**puede costar vino**, no sólo desorden: se pierde la respuesta, el operador cambia
una cantidad, abre un formulario nuevo y carga otro —#7 y #8 quedan los dos «por
preparar»—.

**Mitigaciones que sí están:** un reintento con algo cambiado devuelve
`already-exists` **con el número**, y el panel manda a **abrir el pedido que ya
existe** (`/pedidos/<idPedido>`) en vez de dejar cargar otro; y el id nace al abrir
el formulario y **no se regenera**. **Lo que no está:** sacar un pedido duplicado de
la bandeja. Es lo primero que hay que construir después de este cambio (HU-07.6).

## Por qué NO las alternativas

- **Un `crearOrden` único con `origen` en el pedido** — el origen pasa a ser
  una regla de plata que decide quien llama (§1).
- **Una colección aparte, `pedidosPorWhatsapp`** — el circuito de despacho es
  **el mismo**; dos colecciones son dos bandejas, dos índices y dos pantallas
  para una sola tarea.
- **Escribir la Orden desde el panel con las reglas** — el descuento de stock y
  el número van en una transacción que las reglas no pueden expresar
  ([ARQUITECTURA §4.3](../../../../ARQUITECTURA.md)); `allow create: if false`.
- **`estadoPago: 'pagada'` con una marca `cobradoPorFuera`** — dispara
  `entroEnPagada` y afirma el cobro (§3).

## Presupuesto de lecturas

Cuota: **50.000/día**, compartida con el panel y la preview.

| Operación | Lecturas | Al día |
|---|---:|---|
| Cargar un pedido de `n` líneas | `n` productos + 1 contador + 1 Orden (el marcador) = **n + 2 por intento**, y `n + 1` escrituras más los movimientos | 20 pedidos de 3 líneas: **100 (0,2 %)** |
| …con un panel abierto | el listener del catálogo relee los `n` productos que cambian: **2n + 2** | 20 pedidos de 3 líneas: **160 (0,3 %)** |
| Abrir la hoja de corrección de un vino | hasta **50** (los pedidos `sin_preparar` y `preparando`) | contar el depósito es raro: unas pocas al día |
| Abrir la bandeja | hasta 25 por estado | 10 aperturas × 3 estados: **750 (1,5 %)**, techo |
| Abrir un detalle desde la lista | **0** | — |
| Abrir un detalle por URL directa | 1 | — |

**Total: ~1.000/día, 2 %.** El techo de la bandeja es una cota, no un promedio:
la mayoría de las aperturas traen bastante menos de 25.

## Lo que este ADR deja abierto, con su disparador

| Qué | Disparador |
|---|---|
| **El tope de 30 líneas y el de `cantidad ≤ 5000`** son decisión mía | Un pedido real que los toque |
| **Un precio arreglado por chat no se guarda** (§6) | El primer pedido cuyo precio no fue el de lista |
| **`crearOrden` de la vidriera** comparte el núcleo, pero no existe | La sesión del cobro. Sigue bloqueada por los 9 hallazgos de ADR 008 |
| **Cajas y peso en el detalle** (§7) | HU-07.2 |
| **La APK vieja no conoce `por_fuera`** (§3) | El día que se reparta una APK (H5) |
| ⚠️ **Sin `cancelar`**: un pedido mal cargado o duplicado **no sale de la bandeja**, y su stock ya bajó (§10). Puede costar vino | **HU-07.6, lo primero que sigue.** Mientras tanto se repone con `moverStock` y se avisa a quien prepara |
| **`productoIds[]` en la Orden**, para contar las vendidas sin despachar exactas (§9) | Más de 50 pedidos sin despachar, o un conteo que el aviso no explique |
| **La regla `update` de `ordenes` no valida la TRANSICIÓN** (`cancelada → sin_preparar` pasa) | EP-07: es el hallazgo 3 del [mapa](../../features/panel/overview.md). Hoy sólo se cerró que `estadoEntrega` no se pueda borrar ni inventar |
| **`crearOrden` de la vidriera** también necesita el aviso de §9 y su propio parser (`PedidoDeCompra` sigue sin validador) | La sesión del cobro |
| **Los casos del emulador de esta callable no corren en CI**, igual que los de `moverStock` (ADR 016, hallazgo 8) | La sesión de `crearOrden` |

## Lo que encontró `revisor-pagos` (2026-09-24)

Corrió sobre el backend **antes** del commit, con 14 hallazgos: **1 ALTO, 4 MEDIOS,
9 BAJOS**. Verificó además 14 caminos que no rompen (idempotencia con llamadas
simultáneas, el stock que nunca queda negativo, el origen que no se puede inyectar,
la carrera contra `moverStock`, los números sin huecos…). Cada uno se evaluó con su
escenario; nada se aplicó por venir del informe.

| # | Sev. | Qué | Qué se hizo |
|---|---|---|---|
| 1 | **ALTO** | `corregir` pisa lo vendido sin despachar | **§9**: la hoja de corrección lo dice, con el número. Aviso, no baranda |
| 2 | MEDIO | La venta no deja un movimiento | **§8**: uno por línea, en el mismo registro |
| 3 | MEDIO | La idempotencia comparaba sólo las líneas | **§4**: el pedido entero; `already-exists` trae el número |
| 4 | MEDIO | La regla `update` aceptaba `deleteField()` sobre `estadoEntrega` y notas de cualquier tipo | Cerrado, **medido contra el emulador**: uno de los seis estados, notas ≤ 1000, `actualizadaEn` una hora. La transición queda para EP-07 |
| 5 | MEDIO | Un pedido mal cargado no tiene salida | **§10**: documentado, mitigado en la pantalla, **no resuelto**: es HU-07.6 |
| 6 | BAJO | El parser lanzaba en vez de rechazar con un precio enorme | `PRECIO_MAXIMO`, en el parser y en el núcleo |
| 7 | BAJO | `idPedido` aceptaba `__x__` | Rechazado |
| 8 | BAJO | Sin tope de largo en la entrega | `LARGOS_DE_ENTREGA`, espejado en Dart contra el JSON |
| 9 | BAJO | Precio 0 daba un rechazo engañoso | Código `sin-precio` |
| 10 | BAJO | `maxAttempts: 10` no entra en 60 s | `timeoutSeconds: 120` |
| 11 | BAJO | La cuota no contaba el listener del catálogo | Corregido en *Presupuesto* |
| 12 | BAJO | Vender un vino despublicado contradice ADR 014 | El selector lo marca *«no está en la tienda»*. Pregunta para el dueño abierta |
| 13 | BAJO | El predeploy arma el bundle desde el árbol de trabajo | Commit con rutas explícitas y deploy con `contratos` y `functions` en su commit |
| 14 | BAJO | Comentarios desactualizados | Corregidos |

**Correcciones a lo que este ADR afirmaba:** la tabla de ADR 008 tiene **8** filas, no 9
(el noveno hallazgo se sumó aparte), y el parser rechaza campos de más en la raíz y en
las líneas, **no** dentro de `entrega`: ahí los ignora, sin que lleguen a la Orden.

**De los hallazgos previos de ADR 008:** cerrados para esta callable el 1, el 2, el 4 y
el 5; **no aplican** el 3 ni el 6; **siguen abiertos para la vidriera** el 4 y el 5; el 7
(las suites sin CI) **empeora**: ahora son tres suites manuales, y se corren **en
serie**, porque comparten emulador (medido: en paralelo fallaron 8 casos ajenos).
