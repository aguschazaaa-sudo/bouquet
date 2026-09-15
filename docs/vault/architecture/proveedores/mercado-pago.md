# Mercado Pago — cómo se integra en la práctica

- **Fecha:** 2026-09-15
- **Estado:** investigación cerrada. Mercado Pago es el proveedor de pago
  elegido para bouquet, se cobra desde el día 0. ⚠️ Esto **adelanta** lo que
  dice [ADR 003](../decisions/003-pagos.md) hoy —*"la elección de proveedor...
  es del dueño y todavía no está tomada"*—: cerrar esa desactualización en el
  ADR es trabajo del ADR, no de este documento.
- **Qué contesta:** cómo se crea un cobro, cómo se recibe y se verifica el
  webhook, qué significan los estados que devuelve la API, y con qué datos de
  prueba se puede probar sin plata real.
- **Qué NO contesta:** la comisión exacta en Argentina, los plazos de
  acreditación reales, y si Mercado Pago aprueba la cuenta de bouquet para
  vender alcohol (no se investigó — es una pregunta de negocio, no técnica).

**Relación con [ADR 003](../decisions/003-pagos.md).** El ADR ya fija el
contrato del webhook — las cinco reglas: la fuente de verdad es la consulta
y no el cuerpo, firma antes de parsear, idempotencia por marcador en la
misma transacción, cada eje escribe el suyo aunque llegue desordenado, la
Orden puede nacer `pagada`. Esas reglas **valen sin cambios** para Mercado
Pago y no se repiten acá. Este documento trae lo específico del proveedor:
la forma exacta del payload, cómo se calcula la firma en la práctica, y la
traducción de sus estados al eje `estadoPago` de
[ADR 002](../decisions/002-estados-de-orden.md).

**Cómo leer las fuentes.** Cada afirmación lleva su URL. Donde dice
**"verificado con fetch real"** es porque se probó contra el recurso de
verdad (una página que devuelve 404, un registro npm, un status code) y no
sólo se leyó la promesa de la doc.

---

## 1. Las tres formas de cobrar

| | Esfuerzo | ¿Sale del sitio? | PCI | Medios en Argentina |
|---|---|---|---|---|
| **Checkout Pro** | Bajo — 1 endpoint (crear preferencia) + redirección | Sí, va a Mercado Pago y vuelve por `back_urls` | Ninguna carga: la tarjeta nunca toca el servidor de bouquet | Toda la gama de MP: tarjetas, Mercado Crédito, transferencia, efectivo (Rapipago/Pago Fácil) |
| **Bricks** | Medio — componentes embebidos + JS propio | No, queda en el sitio | Reducida: MP tokeniza dentro del componente | Misma gama, con más control de UI |
| **Checkout API** | Alto — formulario propio, tokenización manual, 3DS | No | Alta: el formulario y el flujo son responsabilidad de bouquet | Misma gama, con el costo de mantener el formulario a mano |

Overviews: https://www.mercadopago.com.ar/developers/es/docs/checkout-pro/landing
y https://www.mercadopago.com.ar/developers/es/docs/checkout-api/landing

**Para bouquet: Checkout Pro.** Es el que menos superficie de PCI y de
mantenimiento agrega, y calza con "el eje existe y se usa a mano desde el
día 1" — no hace falta invertir en UI de pago propia para empezar a cobrar.

## 2. Crear una preferencia

`POST https://api.mercadopago.com/checkout/preferences` con
`Authorization: Bearer <access_token>`.
https://www.mercadopago.com.ar/developers/en/reference/online-payments/checkout-pro/preferences/create-preference/post

⚠️ La versión `/es/` de ese mismo path da **404 hoy** (verificado con fetch
real) — la referencia sólo está en inglés.

| Campo | Obligatorio | Nota |
|---|---|---|
| `items[]` (`title`, `quantity`, `unit_price`, `currency_id`) | Sí | |
| `payer` | No | |
| `back_urls.{success,pending,failure}` | No, pero necesario para volver al sitio | |
| `auto_return: "approved"` | No | ver ⚠️ abajo |
| `external_reference` | No en la API | **obligatorio de hecho**, ver §3 |
| `notification_url` | No | |
| `expires` | No | |

⚠️ **`auto_return: "approved"` con una `back_urls.success` en `localhost`
hace que la API rechace la preferencia ENTERA**, no que ignore el campo.
Ojo con probar esto en desarrollo local sin un túnel público.

## 3. `external_reference` es opcional en el papel, no en los hechos

Es el ancla de reconciliación entre el pago y la Orden de bouquet: sin él,
`GET /v1/payments/{id}` devuelve un pago que no dice a qué pedido
corresponde. Tiene que llevar el id de la Orden, siempre.

## 4. No existe más el ambiente sandbox

⚠️ **La regla más importante de este documento.** No hay `sandbox_init_point`
que usar: siempre `init_point`. Lo que cambia entre prueba y producción es
la **credencial** (de test o real), no el endpoint ni el campo de la
respuesta. Usar `sandbox_init_point` es un error que compila, corre, y
redirige a un ambiente que ya no existe.

## 5. El webhook

Documentación:
https://www.mercadopago.com.ar/developers/es/docs/your-integrations/notifications/webhooks.md
— ⚠️ esa URL exacta (con `.md`) da **404 hoy** (verificado con fetch real);
anotado para no perder tiempo la próxima vez.

### Payload

```json
{"id": 123456, "live_mode": true, "type": "payment", "action": "payment.created", "data": {"id": "999999999"}}
```

Headers: `x-signature: ts=...,v1=...` y `x-request-id`.

### La firma, en la práctica

El **manifest**, textual:

```
id:{data.id};request-id:{x-request-id};ts:{ts};
```

- Si `data.id` viene vacío, se **omite ese par entero** del manifest.
- El `id` va en **minúsculas**.
- Se calcula `HMAC-SHA256` en hexadecimal con el *signature secret* del
  Dashboard como clave.
- Se compara contra `v1` **en tiempo constante** (no `===` directo — eso es
  lo que abre a un ataque de timing).

Esto es exactamente la regla 2 de [ADR 003](../decisions/003-pagos.md):
firma antes de parsear nada del cuerpo. Acá está el detalle operativo que el
ADR no necesitaba tener.

### Otros topics, además de `payment`

`orders`, `subscription_preapproval`, `subscription_authorized_payment`,
`subscription_preapproval_plan`, `mp-connect`, `wallet_connect`,
`stop_delivery_op_wh`, `topic_claims_integration_wh`, `topic_card_id_wh`,
`topic_merchant_order_wh`, `topic_chargebacks_wh`, `point_integration_wh`.

⚠️ **Los nombres de topic que se ven en el Dashboard no siempre coinciden
con el valor de `type` en el body.** El handler tiene que filtrar por
`type === "payment"` en el payload, no asumir que sólo van a llegar
notificaciones de pago porque en el Dashboard sólo se activó esa casilla.

## 6. Consultar un pago

`GET https://api.mercadopago.com/v1/payments/{id}` — devuelve `status`,
`status_detail`, `transaction_amount`, `external_reference`,
`date_approved`, `payment_method_id`.

Es el paso obligatorio de la regla 1 de ADR 003: **la fuente de verdad es
esta consulta, nunca el cuerpo del webhook.**

## 7. Los 9 valores de `status`, traducidos al eje de ADR 002

Confirmados contra el enum oficial del SDK Java:
https://mercadopago.github.io/sdk-java/com/mercadopago/resources/payment/PaymentStatus.html

| `status` de MP | `estadoPago` (ADR 002) | Ambigüedad |
|---|---|---|
| `pending` | `pendiente` | — |
| `in_process` | `en_proceso` | Coincide literal con la definición de ADR 002: "el proveedor la tomó y no resolvió" |
| `authorized` | `en_proceso` | Autorizado pero no capturado; no es plata cobrada todavía |
| `approved` | `pagada` | — |
| `rejected` | `rechazada` | — |
| `cancelled` | ⚠️ sin mapeo limpio | ADR 002 no tiene un estado "cancelada" en el eje de **pago** (sólo en `estadoEntrega`). Una preferencia vencida sin pagarse, o un pago cancelado antes de resolver, hoy forzaría `rechazada`, que no es exactamente lo mismo. **Decisión pendiente para quien escriba el adaptador** |
| `in_mediation` | ⚠️ sin mapeo | Una disputa abierta no es "rechazada" ni "pagada". El eje de 5 estados no la contempla; queda afuera hasta que se decida |
| `refunded` | `reembolsada` | — |
| `charged_back` | ⚠️ mapea a `reembolsada` por comodidad | Un contracargo lo inicia el banco del comprador, no bouquet — semánticamente distinto de una devolución que bouquet decide. Candidato a un sexto estado si en la práctica hace falta distinguirlos |

**Esta tabla es la pieza que va a necesitar el adaptador**, y deja explícito
que 3 de los 9 estados de Mercado Pago (`cancelled`, `in_mediation`,
`charged_back`) no tienen un lugar limpio en el eje de 5 estados de ADR 002
— no es un error de este documento, es que el eje se diseñó antes de conocer
el detalle del proveedor real.

## 8. `status_detail` comunes

`accredited`, `partially_refunded`, `pending_capture`,
`pending_contingency`, `pending_review_manual`,
`pending_waiting_transfer`, `pending_waiting_payment`, `expired`,
`by_collector`, `by_payer`.
https://www.mercadopago.com.br/developers/en/docs/checkout-api-payments/response-handling/query-results.md

## 9. Motivos de rechazo

`cc_rejected_insufficient_amount`, `cc_rejected_bad_filled_card_number`,
`cc_rejected_bad_filled_date`, `cc_rejected_bad_filled_security_code`,
`cc_rejected_bad_filled_other`, `cc_rejected_call_for_authorize`,
`cc_rejected_card_disabled`, `cc_rejected_duplicated_payment`,
`cc_rejected_invalid_installments`, `cc_rejected_max_attempts`,
`cc_rejected_blacklist`, `cc_rejected_high_risk`.
https://www.mercadopago.com.mx/developers/en/docs/checkout-pro/how-tos/improve-payment-approval/reasons-for-rejection

Útil para traducir un `rejected` a un mensaje que el comprador entienda, en
vez de mostrar el código crudo.

## 10. `X-Idempotency-Key`

Obligatorio en `POST /v1/payments` y en refunds: un UUID v4 por **intento
real** — un reintento del mismo intento reenvía la MISMA key, no una nueva.

⚠️ **No se pudo confirmar si aplica a `POST /checkout/preferences`.** Ver
última sección.

## 11. Credenciales y usuario de prueba

- `access_token`: sólo backend, nunca en el navegador.
- `public_key`: para el front (Bricks, si algún día se usa).
- Usuario de prueba: `POST https://api.mercadopago.com/users/test` con
  `{"site_id":"MLA"}` → devuelve `nickname`, `password`, `email`.
  https://www.mercadopago.com.ar/developers/en/reference/test_user/_users_test/post

## 12. Tarjetas de prueba (Argentina)

| Marca | Número | CVV | Vencimiento |
|---|---|---|---|
| Mastercard crédito | 5031 7557 3453 0604 | 123 | 11/30 |
| Visa crédito | 4509 9535 6623 3704 | 123 | 11/30 |
| American Express | 3711 803032 57522 | 1234 | 11/30 |
| Mastercard débito | 5287 3383 1025 3304 | 123 | 11/30 |
| Visa débito | 4002 7686 9439 5619 | 123 | 11/30 |

https://www.mercadopago.com.ar/developers/es/docs/checkout-api/additional-content/your-integrations/test/cards

## 13. Nombres mágicos del titular (para forzar un resultado)

| Nombre | Resultado |
|---|---|
| `APRO` | Aprobado |
| `OTHE` | Rechazo general |
| `CONT` | Pendiente |
| `CALL` | Autorización requerida |
| `FUND` | Fondos insuficientes |
| `SECU` | Código de seguridad inválido |
| `EXPI` | Vencimiento inválido |
| `FORM` | Error de formulario |
| `CARD` | Número faltante |
| `INST` | Cuotas inválidas |
| `DUPL` | Pago duplicado |
| `LOCK` | Tarjeta deshabilitada |
| `CTNA` | Tipo de tarjeta no permitido |
| `ATTE` | Intentos de PIN excedidos |
| `BLAC` | En lista negra |
| `TEST` | Monto de prueba |

## 14. SDK oficial

Paquete `mercadopago` en npm, **versión 3.6.1**, publicada el **2026-09-09**
(verificado con fetch real contra el registro). `engines.node: ">=18"`,
**cero dependencias runtime**, con tipos propios — sirve tal cual en Cloud
Functions Node 22/24, que es el runtime del proyecto
([`_index.md`](../../_index.md) confirma `nodejs24`). Se podría hacer todo
con `fetch` directo, pero la memoria del proyecto prefiere dependencia a
implementación propia cuando la dependencia existe y está mantenida.

## 15. Los cinco errores clásicos

| # | Error | Síntoma |
|---|---|---|
| 1 | Usar `sandbox_init_point` | Redirige a un ambiente que ya no existe (§4) |
| 2 | Confiar en los query params de `back_url` sin reconsultar `GET /v1/payments/{id}` en el servidor | El comprador puede volver a `success` sin haber pagado — la URL de retorno no prueba nada, sólo la consulta prueba |
| 3 | `auto_return` con `localhost` | La API rechaza la preferencia entera, no sólo ese campo (§2) |
| 4 | No verificar la firma antes de procesar | Endpoint público que dispara efectos de negocio a pedido de cualquiera — mismo vector que describe la regla 2 de ADR 003 |
| 5 | Hacer trabajo pesado antes de devolver 200 | MP reintenta con backoff exponencial hasta ~24 h; un handler lento multiplica duplicados en vez de evitarlos |

## 16. MCP y skills en este entorno

**El MCP de Mercado Pago no está instalado** en esta máquina. Las skills
oficiales `mp-integrate` y `mp-webhooks` funcionaron igual, con sus
referencias empaquetadas — no dependieron del MCP para esta investigación.

---

## Lo que NO está confirmado

| Punto | Disparador |
|---|---|
| **Comisión exacta en Argentina** | Las páginas oficiales de costos devuelven **403** al fetch (intentado, no logrado); fuentes de terceros se contradicen entre 2,99 % y 6,99 % + IVA. Mirar el panel de la cuenta real de bouquet antes de fijar el precio del envío o del producto |
| **Plazos de acreditación reales** | Mismo motivo — mirar el panel de la cuenta real |
| Prefijos `APP_USR-` / `TEST-` en las credenciales | Documentados en fuentes de terceros, no se confirmó el texto exacto contra la doc oficial. Verificar al generar las credenciales reales |
| Si `X-Idempotency-Key` aplica a `POST /checkout/preferences` (no sólo a `/v1/payments`) | Al escribir `crearPreferencia` del adaptador — probar con y sin el header y comparar respuesta |
| Peso en KB del paquete `mercadopago` | Bundlephobia dio **429** al intentar el fetch (intentado, no logrado). Repetir antes de decidir si audita el `<head>` como candidato a bloquear el primer pintado (ADR 003, consecuencias) |
| Si `unit_price` espera el importe en la unidad de moneda (pesos, con decimales) o en centavos | No se verificó explícitamente en esta sesión. bouquet guarda todo en `Centavos` (CLAUDE.md) — es una conversión que el adaptador va a necesitar para un lado o el otro, y hay que confirmarla contra la doc antes de escribir `crearPreferencia`, no asumirla |
| Si Mercado Pago aprueba una cuenta de bouquet para vender alcohol | Pregunta de negocio, no técnica — no se investigó en esta sesión. Antes de la primera venta real |
