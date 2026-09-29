# ADR 027 — Pedidos sin burocracia: la carga corta, tres fichas y una palabra por estado

- **Fecha:** 2026-09-29
- **Estado:** aceptada; **escrita, falta CI y el deploy** (reglas → `crearOrdenDelPanel` →
  panel). Ver *Verificación*, al final
- **Decide:** qué pide el panel para cargar un pedido de WhatsApp, cómo se agrupan los
  pedidos en la bandeja, cómo se llama cada estado y si existe el paso de preparar
- **Historias:** HU-10.1 (cargar, [EP-10](../../features/panel/EP-10-ventas-por-fuera.md)),
  HU-06.1 y HU-06.3 (la bandeja, [EP-06](../../features/panel/EP-06-ver-pedidos.md)), HU-07.1
  y HU-07.2 (preparar y despachar, [EP-07](../../features/panel/EP-07-preparar-y-entregar.md)).
  Segundo tramo de *pedidos sin burocracia*; el primero es la *Revisión* de
  [ADR 021](021-aviso-de-despacho.md)
- **Toca:** [ADR 002](002-estados-de-orden.md) (la tabla suma `sin_preparar → despachada`),
  [ADR 018](018-pedidos-de-whatsapp.md) §2 y §3 (la forma de `entrega` y el rótulo de
  `por_preparar`), [ADR 019](019-preparar-despachar-y-cancelar.md) §4 (preparar) y
  [ADR 020](020-accion-busqueda-y-notas.md) §1 (*Requieren acción* pasa a *Para hacer*)
- **Reemplaza, de forma explícita:** el rótulo *«Cobro por fuera - falta preparar»* que exigen
  `openspec/changes/pedidos-de-whatsapp/specs/estado-de-pago-por-fuera/spec.md` (con MUST) y el
  escenario de `specs/bandeja-de-pedidos/spec.md`, y el mismo rótulo en ADR 018 §3. Ahora es
  *«Para despachar»* (§4)
- **Hace cumplir:** `packages/contratos/test/{orden,despacho,proyeccion,pedido}.test.ts`,
  `functions/test/pedidos/crear.emulador.mjs`, `scripts/reglas/ordenes.test.mjs` (la matriz con
  la lista exacta, las fichas nuevas y la vidriera impaga desde `sin_preparar` y `fallida`) y
  en `apps/admin/test/`: `entrega_escrita_test`, `accion_busqueda_y_notas_test`,
  `eje_de_entrega_test`, `textos_y_fechas_test` y `resumen_test`
- **Workflow D** —toca `crearOrdenDelPanel`, que descuenta stock, y la tabla de las reglas—.
  **Sin openspec ni maqueta, a pedido del dueño**: *"dale seguí, entregá completo vos"*
  (2026-09-29). Las decisiones de producto las tomó él en la conversación, una por una; este ADR
  es la especificación

## Contexto

El dueño, sobre *Pedidos*: *"muchos campos, muchos campos son obligatorios y con tantos
estados del envío termina confundiendo al usuario"*. Medido en el código antes de proponer:

| | Antes |
|---|---|
| Cargar un pedido | **10 campos, 7 obligatorios**: nombre, teléfono, calle, número, código postal, localidad y provincia. Venían de `validarDatosDeEntrega`, el validador de la **vidriera**, que cotiza con el código postal |
| La bandeja | **7 fichas**: *Requieren acción* y una por estado de entrega. El único pedido de producción, entregado, había que adivinar que estaba en *Entregados* |
| Nombres | **Hasta 3 por estado**: la ficha *"En camino"*, el detalle *"Despachada"*, el botón *"Despachar"*; *"Por preparar"* / *"Cobro por fuera - falta preparar"* / *"Empezar a prepararlo"*; *"No entregados"* / *"Entrega fallida - reprogramar"* |
| Cerrar un pedido | **3 pasos**: preparar → despachar → llegó |

El criterio ya estaba escrito ([overview del panel](../../features/panel/overview.md),
*poca burocracia*): **un paso más tiene que evitar una pérdida concreta**. Se aplicó campo por
campo.

## Decisión

### 1. Cargar: cuatro obligatorios y uno opcional

| Obligatorios | Opcional | Salen |
|---|---|---|
| Nombre, teléfono, **dirección** (calle y número juntos, viaja en `calle`) y localidad | Piso, depto o referencia (uno, viaja en `referencia`, hasta 300) | Código postal, provincia, número aparte y **mail** |

- **El dueño eligió** *"la dirección va, pero no tan completa"*. El código postal y la provincia
  eran de la vidriera: un pedido de WhatsApp no cotiza, el precio y el correo se arreglan por el
  chat y la etiqueta se hace a mano. El mail no lo usaba nada en un pedido de WhatsApp.
- **Validador propio, `validarEntregaDelPanel`** (`contratos/src/envio.ts`). **La vidriera no
  cambia**: sigue con `validarDatosDeEntrega`. Lo que comparten —nombre, teléfono, mail— salió
  a `validarQuienRecibe`, **uno solo para los dos** (LECCIONES 6.4); un test prueba que la
  vidriera sigue rechazando la forma corta.
- **Acepta también la forma vieja completa**, a propósito: la callable se publica antes que el
  panel, y en el medio el panel publicado manda la forma de antes. Si vienen, el número, el
  código postal y la provincia se validan igual que siempre.
- **Lo que falta se escribe `null`, nunca ausente** (la trampa de `publicado`, ARQUITECTURA
  §5.2). `EntregaDeOrden.numero` y `destino.codigoPostal/provincia` pasan a nullable; el lector
  del panel ya los leía como `''`.
- ⚠️ **Un opcional que no es texto se RECHAZA** (hallazgo 4 de `revisor-pagos`): con el `texto()`
  de siempre, un `numero: 120` de un panel con un error quedaba `null` en silencio y el paquete
  salía sin número.
- **El reintento** compara lo guardado con lo nuevo (`firmaDelPedido`): los `null` se escriben
  siempre, así que la firma no cambia, y un caso del emulador lo prueba con el stock.

### 2. Despachar sin preparar

`TRANSICIONES_ENTREGA.sin_preparar` suma `despachada`, y la regla `pasoDeEntrega()` acepta
`antes in ['sin_preparar', 'preparando', 'fallida']` **con la misma guarda**: el despacho
válido y `origen == 'whatsapp' || estadoPago == 'pagada'`. Un pedido de la vidriera impago no
sale tampoco desde `sin_preparar` (probado, y desde `fallida`).

- **El dueño:** arma *"1, a veces 2 o 3"*, pero *"despacha uno solo, y si en general arma uno
  solo, complica más que lo que aporta"*. ADR 019 §4 lo había dejado con ese disparador.
- **El panel no ofrece preparar** (`AccionDelPedido` sin `preparar`, sin `Preparar`). La tabla
  **todavía lo permite**: sacar `sin_preparar → preparando` deja `preparando` y `en_preparacion`
  inalcanzables, y `auditar_estados.mjs` y el test de la proyección lo prohíben; además hay que
  poder mover las Órdenes que ya estén ahí (`preparando → despachada` sigue).
- Desde `sin_preparar` impago, el detalle ahora dice *"Todavía no puede salir: falta que se
  acredite el pago"* en vez de ofrecer *preparar* sin guarda.

### 3. Tres fichas

| Ficha | Qué trae | Consulta |
|---|---|---|
| **Para hacer** (la que abre) | Todo `sin_preparar`, `preparando` y `fallida`, con cualquier pago, **más** lo terminado que pide plata: *entregado sin cobrar* y *cancelado con pago* | `OR` de 5 tramos (`tramosParaHacer`), 8 disjuntos de 30 |
| **En camino** | `despachada` | `estadoEntrega ==` |
| **Terminados** | `entregada` y `cancelada` | `estadoEntrega in [..]` |

- **Un pedido de la tienda que espera el pago está en *Para hacer***: con *"Requieren acción"*
  no estaba en ninguna ficha más que la de su estado, y sin esa ficha no estaría en ninguna.
- *Entregado sin cobrar* y *cancelado con pago* aparecen en *Para hacer* **y** en *Terminados*:
  terminaron y además piden plata. Es a propósito.
- Los tramos **salen de la proyección**, no de una lista: `entregasParaHacer` (los tres estados
  enteros) y los pares de `estadosPublicosQueRequierenAccion` para el resto. La suite de reglas
  arma la misma consulta desde el JSON y comprueba los pares exactos contra las 36 Órdenes.
- **Índices: ninguno nuevo.** `(estadoEntrega, creadaEn)` para las igualdades y el `in`, y
  `(estadoEntrega, estadoPago, creadaEn)` para los tramos con pago (ADR 020 §1).

### 4. Una palabra por estado

Los rótulos del **operador** en `contratos` (y su espejo): hablan del pedido, en masculino, y
dicen lo mismo que la ficha y el botón. Los del **cliente** no cambian (no pasan por `voz`).

| Estado público | Antes | Ahora |
|---|---|---|
| `por_preparar`, `en_preparacion` | *Cobro por fuera - falta preparar*, *En preparacion* | **Para despachar** |
| `pagada` | *Pagada - falta preparar* | **Pagado - para despachar** |
| `recibida` | *Recibida - falta cobrar* | *Recibido - falta cobrar* |
| `en_camino` | *Despachada* | **En camino** |
| `entregada` / `entregada_impaga` | *Entregada* / *ENTREGADA SIN COBRAR* | **Entregado** / *ENTREGADO SIN COBRAR* |
| `no_entregada` | *Entrega fallida - reprogramar* | **No se pudo entregar** |
| `cancelada` / `cancelada_con_pago` / `reembolsada` | *Cancelada* / … | **Cancelado** / *CANCELADO CON PAGO - devolver* / *Reembolsado* |

Los botones van en paralelo: **"Salió: marcar en camino"** → *En camino*; **"Llegó: marcar
entregado"** → *Entregado*; **"No se pudo entregar"** → vuelve a *Para hacer*. La hoja de
despacho pregunta *"¿Por dónde salió?"*. *Resumen* dice **"Para despachar"**, con el mismo
conteo que antes (ver *abierto*). Un test fija que la ficha, el rótulo y el botón coinciden.

## Por qué NO las alternativas

- **La dirección opcional, o en un solo campo libre** — el dueño: *"la dirección va"*.
- **Preparar como marca opcional** (*"lo estoy armando yo"*) — propuesta mía para cuando arman 2 o
  3; el dueño: *"complica más que lo que aporta"*.
- **Cerrar `sin_preparar → preparando`** — deja dos estados inalcanzables (§2).
- **Cancelar una entrega fallida** (el paquete que vuelve y el cliente ya no lo quiere) — se le
  preguntó con las dos salidas a la vista y eligió dejarlo como está: cierra el abierto de ADR 019.
- **`en_preparacion` en el conteo de *Resumen*** — la proyección lo da con **cualquier** pago y
  contaría un pedido de la tienda impago.
- **Contadores en las fichas** — una consulta más por ficha (ADR 018, *Presupuesto*).
- **Sacar el mail pero dejarlo en el validador obligatorio** — el mail ya era opcional; sale sólo
  del formulario.

## Presupuesto de lecturas

Cuota: **50.000 lecturas/día y 20.000 escrituras/día**. Calculado por mí con los supuestos de
ADR 019 (30 aperturas de la bandeja, 20 pedidos/día); **no corrió `presupuesto-lecturas`**: el
cambio sólo saca consultas y pasos.

| Operación | Antes | Ahora |
|---|---:|---:|
| Peor caso por apertura (todas las fichas × 25) | 7 × 25 = **175** | 3 × 25 = **75** |
| Con el supuesto de ADR 019 (3 fichas por apertura) | 2.250/día | **≤ 2.250/día** (son todas) |
| Preparar (1 escritura + 1 relectura por pedido) | 20 + 20 | **0** |
| Cargar, despachar, *Resumen* | — | sin cambio |

**Propio de este cambio: baja.** Ahorra ~20 lecturas y ~20 escrituras al día del paso de preparar,
y el techo de la bandeja cae de 5.250 a 2.250. El acumulado del panel queda en **~5.900/día
(11,8 %) o menos**.

## Lo que encontró `revisor-pagos` (2026-09-29)

Corrió sobre el backend **antes** del commit: **ningún ALTO, 3 MEDIO y 6 BAJOS**, y verificó 13
caminos que no rompen (entre ellos: la guarda de la vidriera impaga desde `sin_preparar`, que no
se pisa un despacho, `cancelarOrden` igual en los 6 estados, la firma del reintento con `null`,
que ningún otro consumidor lee `entrega` —functions, vidriera, scripts— y que nadie compara
contra los rótulos). Cada uno se evaluó con su escenario:

| # | Sev. | Qué | Qué se hizo |
|---|---|---|---|
| 1 | MEDIO | La matriz de reglas contaba 5 pares y ahora son 6 | **Corregido**, y ahora compara la **lista** exacta: un par de más o de menos se nombra |
| 2 | MEDIO | Commitear el backend solo, o desplegar el panel antes, rompe (el espejo de Dart, la carga, despachar) | Va **todo en un commit** y se despliega en orden; `functions` desde el árbol limpio (su `predeploy` empaqueta el árbol de trabajo) |
| 3 | MEDIO | `en_preparacion` dice *"Para despachar"* también para un pedido `pendiente` en `preparando`, que no sale; y uno `por_fuera` en `preparando` no se resalta ni se cuenta | **No se tocó**: latente (no hay pedidos de la vidriera ni en `preparando`, y el panel nuevo no escribe ese estado). Abierto, abajo |
| 4 | BAJO | Un opcional que no es texto quedaba `null` en silencio | **Corregido**, con su prueba |
| 5 | BAJO | Faltaba `fallida` en la vidriera impaga y *"lo que no es un despacho"* desde `sin_preparar` | **Corregido** |
| 6 | BAJO | Faltaban este ADR y reemplazar las specs viejas; la suite corría la consulta de *Requieren acción* | Este ADR; la suite corre *Para hacer* y *Terminados* |
| 7 | BAJO | El validador de Dart espeja sin fixtures del JSON | Abierto: sin plata en juego (un rechazo es `datosInvalidos`) |
| 8 | BAJO | Un despacho equivocado queda sin vuelta atrás, ahora a un paso | Abierto, con el camino manual |
| 9 | BAJO | `consultarOrden` y un correo integrado van a leer `null` | Abierto |

## Lo que este ADR deja abierto, con su disparador

| Qué | Disparador |
|---|---|
| **Un pedido `pendiente` en `preparando` dice *"Para despachar"* y no sale**; `preparando` no se resalta ni cuenta en *Resumen* | `crearOrden` de la vidriera, o el primer pedido que aparezca en `preparando` |
| **Una pestaña vieja del panel todavía ofrece *preparar*** hasta que se recarga | Si aparece un pedido en `preparando` después del deploy |
| **Un despacho equivocado** no se deshace: queda en camino, y el stock se devuelve a mano con `moverStock` | El primer despacho equivocado |
| **`consultarOrden` y la etiqueta automática** leerán código postal y provincia `null` en los pedidos del panel | La sesión de `crearOrden`, o Envíopack contratado |
| **Fixtures de entrega en el JSON** para el espejo de Dart | El primer `datosInvalidos` que el panel no anticipó |
| **Nadie lo miró renderizado**, y no hubo maqueta | Que el dueño cargue un pedido y mire las tres fichas |

## Verificación

*Pendiente: se completa al publicar.*
