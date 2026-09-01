# ADR 003 — Pagos: proveedor diferido, contrato escrito hoy

- **Fecha:** 2026-09-01
- **Estado:** aceptada (el **proveedor** queda abierto; el **contrato** no)
- **Decide:** qué se construye hoy y qué se difiere, sin que diferirlo sea caro

> ⚠️ **EXTRAPOLADO.** PadelPunilla difirió los pagos a propósito (*"MVP
> recomendado: pagos on-site, la app es la agenda"*). Nada de este ADR está
> validado en producción. Lo que sí está validado es el mecanismo subyacente —
> triggers at-least-once, documentos que nacen en estado final, verificación con
> control positivo — y eso se transfiere sin cambios.
>
> `DIAGNOSTICO.md` lo marca como **el hueco más grande al portar el sistema**, y
> pide explícitamente que este documento exista el día 1.

## Contexto

La elección de proveedor (Mercado Pago Checkout Pro, Bricks, Ualá Bis) es del
dueño y todavía no está tomada. La tentación es no tocar nada de pagos hasta que
decida.

**Eso sería un error, y la razón es §9.6:** *un componente que nunca ejecutó no
tiene evidencia de funcionar, aunque sus tests estén verdes*. Si el eje de pago
nace el día que llega el webhook, el webhook estrena toda la maquinaria de golpe
— y estrena con plata real de por medio.

## Decisión

### Lo que se construye hoy

1. **El eje `estadoPago` existe desde el primer pedido** ([ADR 002](002-estados-de-orden.md)).
   El operador lo marca a mano desde el panel: transferencia bancaria, efectivo
   contra entrega. Es un caso de uso real, no un placeholder.
2. **El trigger `entroEnPagada` corre en producción desde el primer pedido**, con
   su marcador de idempotencia. Manda el mail, avisa al depósito.
3. **Un puerto `ProveedorDePago`** en `packages/contratos`, con una sola
   implementación: `PagoManual`. Tres métodos: `crearPreferencia`,
   `consultarPago`, `verificarFirma`.

Cuando llegue el proveedor real, escribe un adaptador y **enchufa en un camino
que ya se ejecutó cientos de veces**.

### Lo que se difiere

El adaptador concreto y el endpoint del webhook. Nada más.

## El contrato del webhook — las cinco reglas, escritas hoy

Valen igual para Mercado Pago, para Ualá y para el que venga.

### 1. La fuente de verdad es la consulta, no el cuerpo

**El webhook es una notificación de que algo pasó, no la prueba de qué pasó.**

```
recibir(body)
  → verificar firma
  → extraer payment_id
  → CONSULTAR la API del proveedor con ese payment_id     ← la verdad sale de acá
  → escribir estadoPago según la respuesta de la consulta
```

Nunca se escribe `estadoPago` con un valor que venía en el cuerpo. Un endpoint
público que marca órdenes como pagadas a pedido no es un bug: es un vector.

### 2. Verificación de firma, antes de cualquier otra cosa

Un endpoint público que dispara efectos —descontar stock, avisar al depósito— es
superficie de abuso. La firma se verifica antes de parsear nada del cuerpo.

### 3. Idempotencia por marcador, en la misma transacción que el efecto

Los proveedores reintentan. **Asumí entrega múltiple y fuera de orden**, no
"probablemente una vez". El marcador va en
`ordenes/{ordenId}/marcadores/pago-{paymentId}`, escrito en la **misma
transacción** que el cambio de `estadoPago`.

Si no son atómicos, la ventana entre los dos es exactamente donde ocurre el doble
efecto (§5.2).

### 4. Fuera de orden: cada eje escribe el suyo, y las transiciones se validan

Es el caso que motiva los dos ejes de [ADR 002](002-estados-de-orden.md). Un
`pagado` que llega después de un `cancelado`:

- Escribe `estadoPago = pagada`. **No toca `estadoEntrega`**, que sigue en
  `cancelada`.
- La proyección resultante es "pagada pero cancelada" — que es exactamente lo que
  pasó, y es un caso que el operador tiene que ver para devolver la plata.
- La tabla de transiciones de `contratos` rechaza lo que no es válido en el eje
  (por ejemplo `reembolsada → pagada`), y **rechazar se registra**, no se ignora
  en silencio.

**Regla general:** un webhook que llega tarde nunca "revierte" el otro eje. Si
dos notificaciones del mismo eje llegan desordenadas, gana la que la consulta a
la API confirme — porque la verdad sale de la consulta, no del orden de llegada.

### 5. La Orden puede nacer `pagada` — el trigger es `onDocumentWritten`

Ver [ADR 002](002-estados-de-orden.md) §1. Un `onDocumentUpdated` **no se
dispara** para las órdenes que se crean ya pagadas, y no falla: simplemente no
corre.

## Cómo se verifica que el webhook funciona

Escrito ahora para no improvisarlo el día del deploy. Cuatro cosas, todas de
`LECCIONES` §2:

- **Control positivo.** Antes de afirmar que una notificación no llegó, probar
  que el camino de lectura funciona: buscar una que **sí** llegó. Sin control
  positivo, una lista vacía por error de lectura "confirma" cualquier hipótesis.
- **Control negativo.** Mandar una notificación con firma inválida y verificar que
  se rechaza. Un 200 no prueba nada por sí solo.
- **Reintento.** Mandar la misma notificación dos veces y verificar que el efecto
  ocurrió una sola vez — contando, no mirando.
- **Desorden.** Mandar `pagado` sobre una orden ya cancelada y verificar que
  `estadoEntrega` no se movió.

Y la de deploy (§3.5): la lista de funciones a verificar **no es "las que edité"**
— es toda función que enlace el helper que se tocó. `entroEnPagada` lo enlazan
todos los efectos de pago.

## Consecuencias

- El panel necesita, desde el día 1, la acción "marcar como pagada" con su
  confirmación. No es scaffolding: es cómo se cobra hasta que haya proveedor.
- El estado entre "confirmé el pedido" y "el pago resolvió" **no se llama
  `pendiente`** (§5.6). Ver [ADR 002](002-estados-de-orden.md), consecuencias.
- El SDK del proveedor, cuando llegue, es un candidato a bloquear el primer
  pintado de la vidriera (§1.3). Entra con carga diferida y se audita el `<head>`
  como parte del release ([ADR 001](001-stack.md)).
- **Antes del primer deploy que incluya cobro, el deploy pasa a salir de un
  tag**, no de la rama. §3.2: el deploy de front reconstruye desde el HEAD
  pusheado y publica **toda la UI mergeada**. Un botón "Pagar" que llegue a
  producción antes que su webhook es una venta que se cobra y no se registra.
