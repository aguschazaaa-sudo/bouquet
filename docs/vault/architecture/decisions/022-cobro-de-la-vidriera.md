# ADR 022 — El cobro de la vidriera, del lado que recibe: el aviso, la re-consulta y el pedido falso

- **Fecha:** 2026-09-28
- **Estado:** aceptada; **desplegada el 2026-09-28 con credenciales FALSAS** (functions en
  v0.40.1 `66442a9`, panel `1238d5e`), verificada por respuesta y por bytes. **La conversación
  con Mercado Pago sigue sin probarse**: faltan las claves reales (ver *Lo que falta*)
- **Decide:** cómo entra a una Orden lo que dice Mercado Pago de un pago —el aviso
  (webhook) y la re-consulta a mano—, con qué marcador, y qué ve el panel
- **Historias:** HU-08.1 y HU-08.3 ([EP-08](../../features/panel/EP-08-cobros.md)).
  **Quinto tramo del hito 2**, el primero que es de la vidriera
- **Toca:** [ADR 003](003-pagos.md) (el contrato del webhook: **corrige su regla 3**, ver
  §3), [ADR 002](002-estados-de-orden.md) (la tabla de `estadoPago`), [ADR 010](010-el-checkout.md)
  (Checkout Pro), [ADR 018 §3](018-pedidos-de-whatsapp.md) (`por_fuera`) y
  [ADR 019](019-preparar-despachar-y-cancelar.md) (`cancelarOrden`, que la prueba del desorden usa)
- **Hace cumplir:** `packages/contratos/test/pago.test.ts`,
  `functions/test/pagos/mercadopago.test.ts` y `functions/test/pagos/pago.emulador.mjs`
  (job `suite_emulador`)
- **Sin openspec, a pedido del dueño**: este ADR y la épica son la especificación.
  Workflow D: `revisor-pagos` antes del commit

## Contexto

Del hito 2 quedaba **todo lo de la vidriera**: HU-06.5 (el aviso push), EP-08 (cobros) y el
link de HU-07.3. Las cuatro historias necesitan un pedido de la vidriera **pagado por Mercado
Pago**, y el 2026-09-28 no existía nada de ese camino: ni `crearOrden` de la vidriera, ni el
puerto `ProveedorDePago` que pedía ADR 003, ni el webhook, ni el trigger `entroEnPagada`
(sólo el predicado, en contratos). Secret Manager de `bouquet-vinos` estaba **vacío**: no hay
credenciales de Mercado Pago, ni de prueba. En producción había **0 órdenes**.

El usuario preguntó si se podía construir igual, **con un pedido falso para probarlo**. Se
puede, con un límite que este ADR deja escrito: el pedido falso prueba **todo nuestro lado**
—la firma, la consulta, la transacción, el marcador, los reintentos, el desorden, la
re-consulta y el panel— y **no prueba la conversación con Mercado Pago**. Y sin credenciales
nada de esto se despliega: las functions piden los secretos para desplegarse.

**Alcance:** HU-08.1 y HU-08.3. Quedan afuera HU-08.4 (el reembolso tiene una decisión
abierta y mueve plata), HU-06.5 (APK, FCM y H5: una sesión propia), HU-08.2 (sin caso) y
`crearOrden` con la preferencia (la mitad que **crea**; ésta es la que **recibe**).

## Decisión

### 1. El puerto en contratos; Mercado Pago en functions

`packages/contratos/src/pago.ts` tiene lo que no depende del proveedor: `ConsultaDePago` (lo
que dijo el proveedor de UN pago, ya traducido), el puerto `ProveedorDePago` y
**`resolverConsulta`**, la regla pura que decide si una consulta mueve una Orden.
`functions/src/pagos/mercadopago.ts` tiene lo que es de Mercado Pago: el SDK, la traducción de
sus estados y la firma.

El puerto tiene **tres métodos**, pero no los de ADR 003: `leerAviso` (la firma y el tema),
`consultarPago` y `buscarPagosDeLaOrden`. **`crearPreferencia` no está**, a propósito: la llama
`crearOrden`, que no existe, y un método que nadie llama no está entregado. Entra con ella.
`buscarPagosDeLaOrden` es nuevo: la re-consulta (§5) no puede usar un número de operación que
nunca llegó.

**El SDK es el oficial** (`mercadopago` 3.6.1, cero dependencias), y **la firma la verifica su
`WebhookSignatureValidator`**, no un HMAC nuestro: una implementación recién escrita la probó
sólo quien la escribió.

### 2. Los estados de Mercado Pago, en nuestro eje

| Mercado Pago | `estadoPago` | Por qué |
|---|---|---|
| `approved` | `pagada` | — |
| `pending`, `in_process`, `authorized` | `en_proceso` | `pendiente` es la Orden **sin ningún intento**; un cupón de efectivo generado ya es un intento, y tarda días ([ADR 010 §7](010-el-checkout.md)). `authorized` es una tarjeta sin capturar: la plata no está |
| `rejected`, `cancelled` | `rechazada` | `cancelled` es un cupón vencido: el comprador puede reintentar, y `rechazada` es la que admite reintento |
| `refunded` | `reembolsada` | Un reembolso hecho **en Mercado Pago** entra solo. Es la mitad *"registrar"* de la decisión abierta de HU-08.4, sin costo |
| `charged_back`, `in_mediation` | **nada** (`null`) | Un contracargo o una disputa pueden resolverse a favor de la tienda, y `reembolsada` es **terminal**: sería una decisión irreversible tomada por un estado que no lo es |

Un estado que Mercado Pago agregue mañana también da `null`: no se adivina, se registra.

### 3. El marcador es por HECHO, no por pago — corrige ADR 003

ADR 003 escribía el marcador `pago-{paymentId}`. **Con eso se pierde una venta**: un pago en
efectivo llega `in_process` y días después `approved`, **con el mismo id**. El segundo aviso
encuentra el marcador del primero, se toma por repetido, y la Orden queda *"pago en proceso"*
con la plata cobrada.

El marcador es **`pago-{proveedor}-{paymentId}-{statusCrudo}`**, y si ya se devolvió plata,
**`…-r{centavosDevueltos}`**: *este pago llegó a este estado, con esto devuelto*. Dos estados
crudos que traducen igual (`pending` e `in_process`) son dos hechos. La prueba del emulador
*"en proceso y días después aprobado"* es exactamente ese caso.

**Lo devuelto entra a la llave por el hallazgo ALTO 1 de `revisor-pagos`**: un reembolso
**parcial** deja el estado crudo en `approved` y sólo sube `transaction_amount_refunded`. Con la
llave sin eso, el aviso de la devolución se tomaba por repetido y **no se reevaluaba nunca, ni
con el código corregido**. Sin devolución la llave no cambia. Lo devuelto se guarda en
`pago.reembolsado` y el panel lo muestra.

Y **un hecho que no se aplica también deja su marcador**, con `aplicado: false` y el motivo:
es la regla 4 de ADR 003 (*"rechazar se registra"*). Un reintento del mismo hecho no se
reevalúa, porque todos los motivos son permanentes **para ese hecho**: el monto de un pago no
cambia, una transición que la tabla rechaza no se vuelve válida (los terminales no tienen
salida), y un pedido de WhatsApp no se vuelve de la vidriera.

`aplicarConsulta` (`functions/src/pagos/aplicar.ts`) es **el único lugar que escribe
`estadoPago` después de nacer**. Lee la Orden y el marcador, decide con `resolverConsulta` y
crea el marcador y actualiza la Orden **en la misma transacción**. No toca `estadoEntrega`.

### 4. Las guardas de `resolverConsulta`, en orden

1. La consulta es de **esta** Orden (`external_reference`).
2. La Orden es de la **vidriera**: una de WhatsApp es `por_fuera`, terminal.
3. El estado se sabe traducir (§2).
4. Es en **pesos**.
5. **No es un segundo cobro**: un pago aprobado con **otro** número de operación sobre una Orden
   que ya está pagada por uno. `pagada → pagada` es válido en la tabla (reescribir el mismo
   estado), así que sin esta guarda el segundo **pisaba al primero** en `pago` y nadie se
   enteraba de que al comprador le cobraron dos veces — **hallazgo ALTO 2 de `revisor-pagos`**.
6. **Si dice pagada, el monto es el total de la Orden, al centavo.** Un pago aprobado por un
   centavo de menos (o de más) no es *pagada*: queda registrado y alguien lo tiene que mirar.
   Sólo se compara al pagar: un rechazo o un reembolso por otro monto no cobra nada.
7. La transición la acepta la tabla de ADR 002. Un `pagada` sobre una Orden **cancelada**
   pasa (el operador ve *"cancelada con pago"*); un `rechazada` sobre una `pagada`, no.

### 4 bis. Lo que movió plata y no se aplicó, se VE: `alertaDePago`

Un hecho que no se aplica deja su marcador, pero los marcadores están cerrados a todo cliente
(reglas), así que **el panel no los ve**. Para los que movieron plata que la Orden no refleja
—un cobro aprobado que no se aplicó (segundo cobro, monto distinto, pago sobre una Orden ya
devuelta) o un estado sin traducción (contracargo, disputa)— la misma transacción escribe
**`ordenes/{id}.alertaDePago`**: motivo, operación, estado crudo, monto y hora. Queda la
última. El panel la muestra en rojo, con qué hacer (*"hay que devolverlo desde Mercado
Pago"*), sin una lectura más. Un rechazo tardío o un *"en proceso"* viejo que no se aplican
**no** dejan alerta: no movieron nada, y mostrarlos sería ruido. La regla es
`requiereAtencion`, en contratos.

### 5. La re-consulta (HU-08.3) usa el MISMO núcleo

`revisarPago` busca en Mercado Pago **todos** los intentos de pago de la Orden **por la
referencia** —si el aviso nunca llegó, no hay número de operación que consultar—, los ordena
del más viejo al más nuevo y aplica cada uno con `aplicarConsulta`. El aviso y la re-consulta
escriben **el mismo marcador**: un hecho que llega por los dos caminos a la vez tiene efecto
una vez (prueba *"revisar y el aviso a la vez"*).

Se ofrece sólo en pedidos de la vidriera con el pago **no final**: `pendiente`, `en_proceso` o
`rechazada`. Si Mercado Pago no contesta, devuelve `unavailable` con el código
`proveedor-caido`, y el panel lo dice como *"Mercado Pago no contestó"*, no como un error
nuestro.

### 6. El webhook: la firma primero, y el status HTTP es una decisión

`avisoDeMercadoPago` es **pública** (`invoker: 'public'`): Mercado Pago no tiene un token de
Google, y sin eso IAM la frena con un 403 que el código nunca ve —lo que le pasó a
`procesarFoto` ([ADR 015](015-fotos-del-panel.md))—. Lo que la protege es la firma.

- El `data.id` firmado es **el de la URL**; el del cuerpo sólo si la URL no lo trae. Va **en
  minúsculas**, como pide la documentación para los ids alfanuméricos (el validador del SDK no
  lo hace; en un pago, numérico, no cambia nada).
- **Sin ventana de tiempo.** Repetir un aviso no hace daño —la verdad sale de la consulta— y
  una ventana corta rechazaría un reintento legítimo si Mercado Pago reenvía la marca de hora
  original.

| Contesta | Cuándo | Por qué |
|---|---|---|
| **401** | La firma no cierra | Que reintente: si el secreto rota, lo que se perdió en el medio vuelve |
| **200** | Todo lo procesado, y todo lo que **nunca** va a salir distinto: otro tema, un pago que Mercado Pago no conoce, uno sin referencia nuestra (otra venta de la cuenta), uno que no se aplica, una Orden que no existe | Reintentarlo 24 h sólo hace ruido |
| **500** | La API de Mercado Pago o Firestore caídos | Ese reintento es el que queremos |

**Se procesa antes de contestar**, al revés de lo que sugiere la skill `mp-webhooks`: en Cloud
Functions lo que corre después de responder no tiene CPU garantizada, y un aviso contestado
200 y no procesado es una venta cobrada y no registrada.

Una Orden inexistente se contesta 200 y se loguea como **ERROR**: `crearOrden` va a escribir
la Orden **antes** de la preferencia, así que no debería pasar. Si es de otro entorno que
comparte la cuenta, reintentar no la crea; si fue una carrera, `revisarPago` la recupera.

### 7. Los secretos, y la trampa que dejan en el deploy de functions

`MERCADOPAGO_ACCESS_TOKEN` y `MERCADOPAGO_SECRETO_DE_FIRMA`, en Secret Manager
(`functions/src/pagos/secretos.ts`).

⚠️ **Desde el 2026-09-28 existen con valores FALSOS**, a pedido del usuario, para poder
desplegar antes de que el dueño gestione los de su cuenta: aleatorios, con prefijo `FALSO-` y
la etiqueta `valor=falso, reemplazar=con-el-del-cliente`. **No abren ningún camino a escribir
una Orden**: con el token falso toda consulta a Mercado Pago da 401, así que el aviso contesta
500 sin tocar nada —y aunque alguien adivinara el secreto de firma, que es aleatorio, la verdad
sale de la consulta (regla 1 de ADR 003)—. `revisarPago` dice *"Mercado Pago no contestó"*.

**Para poner los reales:** `firebase functions:secrets:set MERCADOPAGO_ACCESS_TOKEN` y
`MERCADOPAGO_SECRETO_DE_FIRMA`, y **volver a desplegar `avisoDeMercadoPago` y `revisarPago`**:
una function desplegada queda atada a la versión del secreto con la que se desplegó.

### 7 bis. El panel: *"El cobro"* en el detalle de un pedido de la vidriera

`SeccionDelPago` (sólo en pedidos de la vidriera; uno de WhatsApp no muestra nada nuevo) dice
el estado del cobro en palabras —nunca el estado crudo de Mercado Pago—, y si hay `pago`, la
operación **para conciliar** (seleccionable), el monto, **lo devuelto** si hay, y hace cuánto se
consultó. Sin `pago`: *"Todavía no hay un pago de Mercado Pago para este pedido."* Y
`alertaDePago` en rojo.

`BotonDeRevisarPago`, *"Volver a consultar a Mercado Pago"*, aparece sólo con el pago no final
(`Orden.sePuedeRevisarElPago`). Relee el pedido **si Mercado Pago devolvió algún pago**, no sólo
si cambió el estado: una revisión puede escribir lo devuelto o una alerta sin mover el eje.
*"Mercado Pago no contestó"* (`proveedor-caido`) se distingue de la red del propio panel.

Cadena: `enrutador → PaginaDelPedido → DetalleDelPedido → SeccionDelPago → BotonDeRevisarPago`.

### 8. El pedido falso

`functions/test/pagos/pago.emulador.mjs`, en el job `suite_emulador`. **Lo único falso es la
API de pagos de Mercado Pago**: una cuenta en memoria que contesta `GET /v1/payments/{id}` y la
búsqueda con la forma de la API. Todo lo demás corre de verdad: el adaptador, el validador de
firma del SDK, el núcleo del aviso, la transacción y la re-consulta.

- **La Orden de la vidriera** se crea con `crearOrdenDelPanel` de verdad y se le cambian sólo
  `origen` y `estadoPago`: los dos campos que `crearOrden` todavía no decidió escribir.
- **Los avisos se firman con la plantilla de la documentación** de Mercado Pago armada a mano,
  no con el código del SDK: si los dos dejaran de decir lo mismo, la suite lo ve.
- Cubre los cuatro controles de ADR 003 y los del Workflow D: control positivo, firma inválida
  (otro secreto, otro id, sin firma), reintento (tres avisos, dos a la vez: un efecto,
  contado), desorden (pagado después de cancelado), un `payment_id` que la API no conoce.

**No se creó un pedido falso en producción**, a propósito: aparecería en la bandeja del dueño
como un pedido de verdad, y no hay con qué cobrarlo.

## Por qué NO las alternativas

- **Un HMAC propio** — el SDK oficial trae el validador, con comparación en tiempo constante.
- **El marcador `pago-{paymentId}` de ADR 003** — pierde la aprobación de un pago que antes
  estuvo en proceso (§3).
- **Contestar 200 y procesar después** — en Cloud Functions ese "después" no tiene CPU.
- **`charged_back` → `reembolsada`** — terminal para un hecho que puede revertirse.
- **Desplegar con un proveedor falso en producción, para ver el panel** — sería un endpoint
  público que marca órdenes como pagadas según una fuente que controlamos nosotros: el vector
  que ADR 003 regla 1 prohíbe. Y el pedido falso aparecería en la bandeja del dueño.
- **Esperar las credenciales para escribir nada** — el camino ya estaría escrito y probado el
  día que lleguen; lo que falta es el adaptador vivo, no la maquinaria.

## Presupuesto de lecturas

| Qué | Lecturas | Al día (20 ventas, ~3 avisos por pago) |
|---|---|---|
| Un aviso | **2** (la Orden y el marcador, en la transacción); 0 si la firma no cierra o el tema no es un pago | ~120 |
| *"Volver a consultar"* | **1** (la Orden, afuera) + **2 por intento** encontrado + **1** del panel al releer el detalle si hubo alguno | ~10 (se usa a mano, cuando un pago se traba) |
| El panel mostrando el pago y la alerta | **0**: `pago` y `alertaDePago` viajan en el documento que el detalle ya lee | 0 |

**~130 lecturas al día, el 0,26 % de la cuota.** Una transacción reintentada por contención
vuelve a leer sus dos documentos; con el tope de 10 intentos, el peor caso de un aviso es 20.

## Lo que falta, con su disparador

| Qué | Disparador |
|---|---|
| **Reemplazar los secretos FALSOS** por los de la cuenta del dueño (de prueba primero), **redesplegar las dos functions**, y registrar en Mercado Pago la URL del webhook: `https://us-central1-bouquet-vinos.cloudfunctions.net/avisoDeMercadoPago` | El dueño pasa las claves |
| **Verificar contra el sandbox**: una compra de prueba que llegue por aviso, `revisarPago` sobre ella, y los mismos controles de §8 con la API real | Las claves reales |
| **`crearOrden` de la vidriera y `crearPreferencia`**, con los nueve hallazgos de [ADR 008](008-catalogo-stock-y-carrito.md) y `external_reference = ordenId` | La sesión de `crearOrden` |
| **El trigger `entroEnPagada`** | Su primer efecto: el aviso push de HU-06.5 |
| **Devolver la plata desde el panel** (HU-08.4). Hoy un reembolso hecho **en** Mercado Pago entra solo —total como `reembolsada`, parcial como *"Devuelto"*— y un segundo cobro se ve como alerta | HU-08.4 |
| **Cambiar la traducción de un estado** (§2) no reevalúa los hechos ya marcados: sus marcadores dicen *"ya procesado"*. Si pasa, se revisan con un script | El primer cambio de traducción |
| **El link de HU-07.3** a `/pedido/<numero>` | `crearOrden` |

## Revisión de plata (Workflow D, antes del commit)

`revisor-pagos` corrió sobre el diff entero: **2 ALTOS, 2 MEDIOS, 1 BAJO**.

| # | Hallazgo | Qué se hizo |
|---|---|---|
| ALTO 1 | Un reembolso **parcial** deja `approved`: el marcador lo tomaba por repetido y bloqueaba reevaluarlo para siempre | Lo devuelto entra a la llave y a `pago.reembolsado` (§3); prueba de emulador propia |
| ALTO 2 | Dos pagos distintos aprobados por el total: el segundo pisaba al primero, sin alarma. Al comprador le cobraron dos veces | Guarda `pago-duplicado` (§4) y `alertaDePago` (§4 bis); prueba de emulador propia |
| MEDIO 3 | Los secretos que no existen bloquearían un deploy de functions a secas | **Resuelto el mismo día**: los secretos existen con valores falsos (§7) |
| MEDIO 4 | Un contracargo sólo dejaba un log | Deja `alertaDePago` (§4 bis). Que un cambio de traducción no reevalúe lo marcado queda en *Lo que falta* |
| BAJO 5 | El botón de HU-08.3 no estaba enganchado todavía | Lo estaba escribiendo el agente de presentación; la cadena está en §7 bis |

## Verificación (2026-09-28)

Nada de esto corrió en esta máquina (7,9 GB): todo en CI, en ramas descartables, sin tocar
`main` hasta tener el verde.

| Qué | Cómo |
|---|---|
| Compila y pasa, todo junto | CI `36475268911`, `alcance=completo`, restado contra `36466563334`: contratos 245 → **268**, functions 56 → **73 pasados** (los 3 salteados son los de siempre: las fotos del seed no están en el checkout), emulador 162 → **187**, Dart 450 → **488** (+38 = los `test(` de los dos archivos nuevos, 21 + 17), `flutter analyze` **No issues found**, 622 enlaces |
| Que las pruebas discriminen | CI `36473359581`: **cuatro mutaciones** en una rama descartable —el marcador por pago de ADR 003, sin comparar el monto, sin mirar el marcador, sin verificar la firma—. Cada una tumbó **sólo** sus casos: 9 en el emulador (3 + 1 + 4 + 1) y 4 unitarios (2 + 1 + 1); los otros 175 del emulador siguieron verdes |
| Sin huérfanos | 20 símbolos nuevos, cada uno en ≥ 2 archivos (el que lo define y el que lo usa); control inventado: 0. Cadena del panel en §7 bis |

### El deploy (2026-09-28, con credenciales FALSAS)

**El primer intento falló en el análisis, sin subir nada**: esbuild metía el SDK de Mercado Pago
(CommonJS) adentro del bundle ESM y su `require("crypto")` no carga ahí (*"Dynamic require of
crypto is not supported"*). Los tests no lo veían porque importan el TypeScript directo. Quedó
**externo**, como `firebase-admin`, y **CI ahora construye el bundle, lo importa y cuenta las 6
functions** (v0.40.1, corrida `36477703196`): ese error es el control negativo del paso nuevo.

| Qué | Cómo |
|---|---|
| Los secretos | Creados con `gcloud secrets create`, versión 1, etiqueta `valor=falso`. El guardado coincide con el generado (hash comparado, sin imprimir el valor) |
| Las functions | Sólo las dos nuevas (`--only functions:…`): las otras cuatro con su `updateTime` de antes. `avisoDeMercadoPago`: GET **405** (`solo POST`, nuestro código y no IAM), sin firma **401**; firmado con el secreto falso y otro tema **200** `ignorado: merchant_order` (control positivo de que el secreto se lee), firmado con otro secreto **401** (negativo); firmado un pago **500**, y el log dice **`MPAuthenticationError 401`**: la consulta llegó a Mercado Pago con el token falso y no se escribió nada. `revisarPago`: preflight **204** con `Access-Control-Allow-Origin` del panel, anónimo **401 JSON** `UNAUTHENTICATED`. Una function inventada: **404** |
| El panel | Build `36476500980` → canal → canario discriminante (*"Volver a consultar a Mercado Pago"*, *"Para conciliar"*, `revisarPago`: 0 → 1; *"Por preparar"* 1 → 1; inventada 0 → 0; `COMMIT` `fde0b38` → `1238d5e`) → `promover` → live con los **4 hashes iguales** al canal, `noindex` |

### Lo que NO se verificó

- **La conversación con Mercado Pago**: que la API real conteste con la forma que la cuenta en
  memoria imita, y que firme como dice su documentación. Es lo primero con las claves reales.
- **Nadie lo miró renderizado**, y en producción no hay un pedido de la vidriera que lo muestre.
- **Los cuatro controles de ADR 003 contra el sandbox**: están probados contra el emulador, no
  contra Mercado Pago.

Confirmado por la revisión, sin cambios: el panel **no puede escribir `pago` ni `alertaDePago`**
(la lista cerrada de campos del `update` de `ordenes` no los incluye), la firma sin ventana es
segura porque la verdad sale de la consulta, y la lectura de `revisarPago` fuera de la
transacción sólo decide si consultar.
