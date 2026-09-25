# ADR 019 — Preparar, despachar, entregar y cancelar un pedido

- **Fecha:** 2026-09-25
- **Estado:** aceptada, **escrita y sin desplegar** (ver *Verificación*, al final)
- **Decide:** cómo avanza una Orden por el eje de entrega desde el panel: quién
  escribe cada paso, qué campos lleva, y cómo cancelar devuelve el stock
- **Historias:** HU-07.1, HU-07.2, HU-07.4, HU-07.5 y HU-07.6
  ([EP-07](../../features/panel/EP-07-preparar-y-entregar.md)). **Segundo tramo
  del hito 2.** Quedan afuera HU-07.3 (el aviso por WhatsApp: no existe el número
  de la tienda ni `/pedido/<numero>`) y HU-07.7 (notas: las reglas ya las
  permiten y no dependen de nada)
- **Toca:** [ADR 002](002-estados-de-orden.md) (la tabla pasa a las reglas),
  [ADR 008](008-catalogo-stock-y-carrito.md) (hallazgo 1: reponer con el
  snapshot), [ADR 016](016-mover-el-stock.md) (mismo campo `stock`, mismo
  registro de movimientos), [ADR 018](018-pedidos-de-whatsapp.md) (cierra su §9 y
  su §10)
- **Hace cumplir:** `packages/contratos/test/despacho.test.ts`,
  `functions/test/pedidos/reponer.test.ts`,
  `functions/test/pedidos/cancelar.emulador.mjs`,
  `scripts/reglas/ordenes.test.mjs` (la matriz de pares lee el JSON generado),
  `apps/admin/test/core/contratos/despacho_test.dart` y
  `apps/admin/test/features/pedidos/eje_de_entrega_test.dart`. **Y desde este
  cambio las suites de emulador corren en CI** (job `suite_emulador`, §8)
- **Sin openspec, a pedido del dueño** (2026-09-25): este ADR y `EP-07` son la
  especificación. El alcance y las tareas se decidieron en la conversación

## Contexto

Desde el 2026-09-24 el panel carga pedidos de WhatsApp y los ve, pero **no los
puede avanzar** (ADR 018 §10): todos quedan en `sin_preparar`, la bandeja se
llena, el aviso de stock de la hoja de corrección no es fiable (§9) y **un pedido
mal cargado o duplicado no se puede sacar, y su stock ya bajó**. Es lo que puede
costar vino.

## Decisión

### 1. Dos caminos: el panel escribe lo que no toca stock; cancelar es del servidor

| Paso | Historia | Quién lo escribe | Por qué |
|---|---|---|---|
| `sin_preparar → preparando` | HU-07.1 | el panel, directo | No toca nada más que el estado |
| `preparando → despachada`, `fallida → despachada` | HU-07.2, 07.5 | el panel, directo | Estado + `despacho` |
| `despachada → entregada` | HU-07.4 | el panel, directo | Sólo el estado |
| `despachada → fallida` | HU-07.5 | el panel, directo | Estado + `entregaFallida` |
| `sin_preparar/preparando → cancelada` | HU-07.6 | **`cancelarOrden`** | **Devuelve stock**, y `stock` lo escribe sólo el servidor (ADR 008) |

⚠️ **`cancelada` NO la puede escribir ningún cliente**, aunque la tabla la
permita (`SOLO_LO_ESCRIBE_EL_SERVIDOR` en `contratos`). Si las reglas la
dejaran, un panel con un error cancelaría **sin reponer** y el vino quedaría
vendido para siempre. Es la misma frontera que `stock`: el paso que mueve plata o
mercadería no pasa por una escritura de cliente.

**Por qué no todo por callable:** una Cloud Function por paso son cuatro
arranques en frío más por pedido, cuatro callables que desplegar y mantener, y
**no ganan seguridad**: las reglas ven lo mismo (`resource.data`) y lo validan
con **cero lecturas**. La callable se justifica sólo donde hace falta una
transacción sobre otro documento, y eso es únicamente cancelar.

### 2. Las reglas validan la TRANSICIÓN (hallazgo 3 del mapa del panel)

Hasta hoy la regla `update` de `ordenes` sólo miraba que `estadoEntrega` fuera
uno de los seis: un panel con un error podía pasar una orden de `entregada` a
`sin_preparar`. Ahora `pasoDeEntrega()` es la tabla de ADR 002 menos `cancelada`,
y cada paso dice **qué campos lleva y ningún otro** (`editaSolo`). El mismo
estado (`anota()`) sólo deja cambiar `notasOperador` y `actualizadaEn`.

**Es la tercera copia de la tabla** (`contratos` y Dart son las otras), que era
la objeción de EP-07. **Se sincroniza con un test, no con cuidado:** la suite de
reglas lee `despacho.laEscribeElPanel` del JSON generado y prueba los 36 pares.
Cambiar la tabla en `contratos` sin tocar las reglas pone la suite en rojo.

**Y trae una concurrencia gratis:** dos personas con el mismo pedido abierto;
una despacha, la otra aprieta "despachar" con la pantalla vieja. La regla ve
`despachada → despachada` con un `despacho` distinto y **lo rechaza**: el
segundo no pisa el seguimiento del primero. El panel lo dice y relee (§6).

### 3. Qué guarda cada paso

```text
despacho        { correo, seguimiento | null, en }   ← al despachar (y al volver a despachar)
entregaFallida  { motivo, en }                        ← al no poder entregar; QUEDA al volver a despachar
cancelacion     { motivo, por, en, sinReponer[] }     ← sólo cancelarOrden
```

- `en` es **`request.time`**, exigido por la regla: un cliente no fecha un
  despacho para atrás.
- `seguimiento` va **siempre**, aunque sea `null`: la regla pide la clave. Un
  mapa sin ella es un botón que falla siempre.
- `entregaFallida` no se borra al volver a despachar: es el historial de por qué
  no llegó la primera vez.

### 4. Las listas — **decisiones mías, el dueño las puede cambiar**

| Lista | Valores | Nota |
|---|---|---|
| `CORREOS` | Andreani, Correo Argentino, OCA, *Lo llevamos nosotros*, Otro | `en_mano` porque un pedido de WhatsApp de la zona lo puede llevar la familia, aunque el reparto propio de la vidriera esté apagado |
| Seguimiento | **opcional**, hasta 60 caracteres | Una entrega en mano no tiene, y una etiqueta se puede imprimir después. Poca burocracia: lo único obligatorio es el correo |
| `MOTIVOS_DE_FALLA` | *No había un mayor de 18*, *No había nadie*, *La dirección estaba mal*, *No lo quisieron recibir*, Otro | El primero es el legal (ARQUITECTURA §9.5) |
| `MOTIVOS_DE_CANCELACION` | *Lo cargué mal o está repetido*, *El cliente ya no lo quiere*, *No teníamos el vino*, Otro | |

**Preparar es un paso aparte**, con un toque y sin confirmar. EP-07 dudaba si
merecía un botón; se dejó porque evita la pérdida que la historia nombra —dos
personas armando el mismo pedido— y porque la máquina de estados no deja saltar
de `sin_preparar` a `despachada`: esconderlo obligaría al panel a hacer dos
escrituras seguidas, con una falla a mitad posible. **Disparador para
cambiarlo:** que el dueño diga que el paso sobra.

**Entregar pide confirmar** —es terminal— **y la confirmación es la declaración
legal:** el botón dice *"Sí, lo recibió un mayor de 18"*, no *"Aceptar"*.

**Un pedido de la vidriera impago no se despacha** (`sePuedeDespachar`, y la
regla lo repite sobre `resource.data`); uno de WhatsApp sí. Hoy no hay pedidos
de la vidriera, pero la regla queda puesta **antes** de que exista `crearOrden`,
no después. El panel no esconde el botón en silencio: dice *"falta que se
acredite el pago"*.

### 5. ⭐ Cancelar: `cancelarOrden`, con la Orden como su propio marcador

Una transacción: lee la Orden, lee los vinos, **devuelve el stock**, escribe un
movimiento por vino y marca la Orden `cancelada`.

- **Idempotencia sin marcador aparte.** `cancelada` es terminal y la **única**
  escritura que la produce es esta transacción, que devuelve el stock en el mismo
  commit. "Ya está cancelada" quiere decir "el stock ya volvió, una vez": un
  reintento devuelve `repetido: true` sin tocar nada. Tres cancelaciones a la vez
  aplican una (probado contra el emulador).
- **Qué se puede cancelar lo decide la tabla** (`transicionEntregaValida(estado,
  'cancelada')`), no una lista escrita en la callable. Un pedido que ya salió
  rechaza con `ya-salio` y el estado de ahora: el envío ya costó, y lo honesto es
  una entrega fallida (ADR 002).
- **Se repone con el SNAPSHOT** (hallazgo 1 de ADR 008): `items[].cantidad` en
  la unidad de venta que fijó `items[].botellas` al vender. Si el vino de hoy
  tiene otra presentación —se borró y se recreó con el mismo slug—, esa línea
  **no vuelve** (`otra_presentacion`): sumar "1" donde salió una caja de seis deja
  5 botellas a la venta que no existen.
- ⭐ **Cancelar nunca se traba por una línea** — decisión mía. Un vino borrado,
  recreado, compuesto o roto **no impide cancelar**: esa línea va a `sinReponer`
  con su motivo, queda escrita en la Orden y el detalle la muestra en rojo cada
  vez que se abre. La alternativa —rechazar la cancelación entera— es exactamente
  el pedido que no se puede sacar de la bandeja (ADR 018 §10), que es lo que este
  cambio existe para resolver.
- Mira del vino **lo mismo que `moverStock`** antes de escribir `stock` (que sea
  `simple` y que el stock sea un entero sano) y además la presentación. **No**
  corre `validarProducto` entero: un campo que no tiene que ver con el stock no
  puede impedir que vuelvan las botellas.
- ⭐ **No aplica `TOPE_DE_STOCK`** — decisión mía. El tope frena un dedo gordo al
  *tipear* una reposición; acá vuelve lo que salió. Pasarlo sólo es posible si
  alguien repuso cerca del tope entre la venta y la cancelación, y un `corregir`
  lo baja. Recortar perdería botellas en silencio.
- **El movimiento** es `cancelacion-<ordenId>`, con la forma de los de venta
  (`operacion: { tipo: 'cancelacion', cantidad, idPedido, numero }`). La hoja de
  HU-05.4 lo dice *"Volvió al stock: 2 botellas (pedido 7, cancelado)"*. `create`,
  no `set`: un choque tiene que fallar.
- `maxAttempts: 10` y `timeoutSeconds: 120`, por la misma cuenta que
  `crearOrdenDelPanel` (hallazgo 10 de ADR 018): compite por los mismos productos.

### 6. El panel: sólo ofrece lo que la tabla permite, y relee después de cada cambio

- **Los botones salen de `accionesDe(orden)`**, que usa `laEscribeElPanel` y
  `sePuedeDespachar` del espejo: el panel no tiene una lista propia de "qué se
  puede desde cada estado".
- **Después de cada cambio se relee el pedido** (una lectura): la pantalla
  muestra lo que tiene el servidor, no lo que el panel cree que escribió.
  Mientras relee, sigue mostrando la Orden anterior en vez de un "Buscando…".
- **Un rechazo de las reglas se lee como "otra persona lo movió"** y relee: el
  panel sólo ofrece pasos válidos desde lo que muestra, así que un
  `permission-denied` casi siempre es una pantalla vieja. Sin conexión, en
  cambio, **no** relee: el error queda escrito arriba de los botones.
- Las hojas (despacho, falla, cancelación) **no escriben**: devuelven lo elegido
  y el detalle lo guarda. Así un error se muestra en el pedido, que es donde se
  reintenta.

### 7. El aviso de la hoja de corrección, más firme (cierra ADR 018 §9)

ADR 018 dejó escrito que el aviso de *"ventas sin despachar"* podía ser más firme
cuando existiera el despacho. Ahora dice *"que todavía no se marcaron como
despachados"* y la segunda salida dice qué hacer: *"si ya salieron, marcá el
pedido como despachado y contá lo que hay"*. **Sigue siendo condicional**: un
pedido que salió y nadie marcó figura abierto, y decir "restale" a secas haría
restar de más.

### 8. Las suites de emulador pasan a CI

Hasta hoy las suites de reglas y de las transacciones (`moverStock`,
`crearOrdenDelPanel`) **se corrían sólo a mano**, y eran justo las que prueban
plata (hallazgo 7 de ADR 008, *empeoró* en ADR 018). Con ~700 MB libres, esta
máquina no levanta el emulador al lado del editor, así que el Workflow D se
habría verificado por razonamiento. Job nuevo `suite_emulador`
(`alcance=tests|completo`): Java 21, `firebase-tools` global, las cinco suites
**en serie** y con piso de conteo (158). Quedan afuera, con motivo,
`procesar_foto.emulador.mjs` (emulador de Functions) y `acceso.test.mjs` (Auth).

## Por qué NO las alternativas

- **Cancelar escribiendo `cancelada` desde el panel y reponiendo en un trigger**
  — el trigger es at-least-once y corre *después*: entre las dos escrituras el
  pedido figura cancelado con el stock sin volver, y un trigger que falla deja la
  diferencia para siempre. ADR 002 regla 3: lo crítico no va en un trigger.
- **Un marcador `ordenes/{id}/marcadores/cancelacion` aparte** — redundante: el
  estado terminal ya es el marcador, escrito en la misma transacción.
- **Rechazar la cancelación si una línea no se puede reponer** — deja el pedido
  trabado en la bandeja, que es el problema de ADR 018 §10 (§5).
- **La tabla sólo en Dart, como hasta hoy** — un panel con un error mueve una
  orden entregada a sin preparar y nadie lo frena. Validarla en las reglas cuesta
  cero lecturas (§2).
- **Seguimiento obligatorio** — frena el despacho de una entrega en mano o de una
  etiqueta que se imprime después, y no evita ninguna pérdida (criterio 2 de
  *poca burocracia*).

## Presupuesto de lecturas

Cuota: **50.000 lecturas/día y 20.000 escrituras/día**, compartidas con la preview.
Medido por `presupuesto-lecturas` contra el código (2026-09-25), con los supuestos de
ADR 018 (3 personas, 20 pedidos/día de 3 líneas, 30 aperturas de la bandeja) más ~4
pasos por pedido y 1 cancelación por día:

| Operación | Lecturas | Escrituras | Al día |
|---|---:|---:|---|
| Avanzar un paso (update directo) | **1**: la relectura del detalle | 1 | 80 pedidos-paso: **80 + 80** |
| Las reglas de `ordenes` evaluando la transición | **0**: sólo `resource.data` y `request.resource.data`, ningún `get()` | — | 0 |
| Cancelar, `n` vinos | 1 Orden + `n` vinos + 1 relectura | `n` stock + `n` movimientos + 1 Orden | 1 × 3 líneas: **5 + 7** |
| …lo que le cobra al listener del catálogo | `n` por panel abierto | — | 3 paneles: **9** |
| La bandeja | hasta 25 por estado mirado; cambiar de estado relee | — | **2.250** con 3 estados por apertura (reemplaza los 750 de ADR 018, que medía con un solo estado útil) |
| Hoja de corrección | sin cambio de código | — | el mismo; el número real **baja**, porque los abiertos dejan de acumularse |

**Propio del código de EP-07: ~94 lecturas y ~87 escrituras por día.** Con el
recálculo de la bandeja: **~1.594 lecturas/día (3,2 %)**. **Acumulado del panel:
~5.894/día, 11,8 % de la cuota**; escrituras ~247/día, 1,2 %.

⚠️ **El número grande es un supuesto de uso, no un dato del código:** cuántas de las
seis fichas de estado mira el operador por apertura. Con 3 da 2.250; con 5, 3.750 (el
panel quedaría en ~13,9 %, todavía holgado). `entregada` y `cancelada` son terminales y
se llenan: desde la primera semana esas fichas devuelven la página entera.

**Con la preview de la vidriera martillada no entra, y ya no entraba**: 48.960 de la
preview + 5.894 del panel = **109,7 %** (era 102,6 % con ADR 018). Lo que hay que
recortar sigue siendo la preview (ADR 017), no este cambio.

## Lo que este ADR deja abierto, con su disparador

| Qué | Disparador |
|---|---|
| **HU-07.3, el aviso de despacho por WhatsApp** | El número de la tienda (lo pasa el dueño) y la ruta `/pedido/<numero>` de la vidriera |
| **HU-07.7, las notas internas** | Cuando se tome: las reglas ya las aceptan (`anota()`), falta la pantalla |
| **Cajas y peso en el detalle** (ADR 018 §7 lo dejó para HU-07.2) — **no se construyó**: el correo se arregla a mano y el operador ve las líneas con sus botellas | Envíopack contratado, o que el dueño lo pida al despachar |
| **Quién preparó o despachó** — el pedido guarda `actualizadaEn`, no un uid por paso | Dos personas que se pisen armando pedidos |
| **Las listas de correos y motivos** son mías (§4) | Que el dueño use otro correo o extrañe un motivo |
| **Cancelar un pedido de la vidriera pagado** lo deja en *cancelada con pago*, que pide un reembolso que el panel no hace (HU-08.4) | La sesión del cobro |
| **Una línea `sinReponer` se resuelve a mano** (con `moverStock`) | Si pasa más de una vez |
| ⚠️ **Un pedido con la entrega fallida no se cancela** (hallazgo 3 de `revisor-pagos`): el paquete que vuelve y el cliente que ya no lo quiere no tienen salida, y el stock no se entera. Agregar `fallida → cancelada` es cambiar la tabla de ADR 002 y **lo decide el dueño** | El primer paquete que vuelve de un pedido que ya no se entrega |
| **Cuántas fichas de estado mira el operador por apertura** decide el número grande del presupuesto (2.250 con 3, 3.750 con 5) | Una semana de uso real |

## Lo que encontró `revisor-pagos` (2026-09-25)

Corrió sobre el backend y el panel **antes** del commit: **ningún ALTO, 1 MEDIO y 3
BAJOS**, y verificó 18 caminos que no rompen —entre ellos tres cancelaciones a la vez,
cancelar contra `moverStock` y contra una venta del mismo vino, que un pedido que salió
no se cancele, que `sinReponer` sobreviva a un reintento, que la forma que escribe Dart
sea la que piden las reglas, y que **el panel publicado hoy no se rompa con las reglas
nuevas** (`anota()` acepta todo lo que el panel viejo escribía). Cada uno se evaluó con
su escenario; nada se aplicó por venir del informe.

| # | Sev. | Qué | Qué se hizo |
|---|---|---|---|
| 1 | MEDIO | `suite_emulador` no corre con `rapido`, que es lo que dispara un push: un verde automático no ejecuta las suites de plata | Es el plan: `alcance=tests` **a mano, y leída**, antes de tocar producción. Queda en *Verificación* |
| 2 | BAJO | Un panel publicado antes que `cancelarOrden` recibe `not-found` de la callable inexistente, y decía *"este pedido ya no existe"* | **Corregido**: sólo con el `codigo: 'no-existe'` que manda `cancelar.ts` es el pedido; un `not-found` pelado es `desconocido`. Con un test |
| 2b | BAJO | Un panel publicado antes que las reglas ve `permission-denied` y dice *"otra persona lo movió"* | No se corrige: no se distingue desde el cliente, y el orden reglas → functions → panel lo evita. Nada se escribe a medias |
| 3 | BAJO | **Un pedido `fallida` no se puede cancelar** (tabla de ADR 002): si el correo lo devuelve y el cliente ya no lo quiere, queda en *"Entrega fallida - reprogramar"* para siempre, y sus botellas vuelven a la estantería sin volver al stock | **No se tocó la tabla**: es una decisión de producto, y ADR 002 la tomó (*"el envío ya costó"*). Queda abierto con disparador, abajo. Mientras tanto: `moverStock` para devolver las botellas |
| 4 | BAJO | El predeploy de `functions` arma el bundle desde el árbol de trabajo (hallazgo 13 de ADR 018) | Se despliega con todo commiteado y el árbol limpio |

## Verificación

*(Se completa al verificar.)*
