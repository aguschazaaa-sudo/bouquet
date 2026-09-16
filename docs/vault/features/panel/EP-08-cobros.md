# EP-08 — Cobros

> Hito 2 · **Workflow D en todas las historias** — `revisor-pagos`
> obligatorio, y el backend verificado **antes** que la pantalla ·
> [volver al mapa](overview.md)

**Objetivo:** que el operador sepa si cada pedido está cobrado sin entrar a
Mercado Pago, y que pueda resolver lo que el webhook no resolvió.

**Depende de:** `crearOrden`. HU-08.1, HU-08.3 y HU-08.4 dependen además de
la preferencia de Mercado Pago y su webhook
([ADR 010 §8](../../architecture/decisions/010-el-checkout.md)); **HU-08.2 no**,
y por eso sale antes, con las ventas por WhatsApp.

⚠️ **El panel no escribe `estadoPago`.** Lo prohíben las reglas: todo cambio de
pago pasa por el servidor, con la transición validada y su marcador de
idempotencia ([ADR 003](../../architecture/decisions/003-pagos.md)).

---

## HU-08.1 — Ver el estado del pago

**Como** operador, **quiero** ver si un pedido está pagado, en proceso o
rechazado, y el número de operación de Mercado Pago, **para** conciliar sin
cambiar de pantalla.

- **Ya decidido:** la fuente de verdad es **la consulta al proveedor**, no el
  cuerpo del webhook ([ADR 003](../../architecture/decisions/003-pagos.md),
  regla 1). El rótulo sale de la proyección, como en HU-06.2.

## HU-08.2 — Marcar un pedido como pagado a mano

**Como** dueño, **quiero** registrar un pago que llegó por fuera de Mercado
Pago, **para** que el pedido siga su curso.

- **Ya decidido:** es el camino que ARQUITECTURA quería ejercitar **desde el
  primer pedido**: marcar `pagada` a mano dispara el mismo `entroEnPagada` que
  va a usar el webhook, así el cobro online se enchufa en algo que ya corrió
  ([ARQUITECTURA §12](../../../../ARQUITECTURA.md#12-orden-de-construcción)).
- **Su caso son las ventas por WhatsApp** (respuesta del dueño): la vidriera
  cobra sólo por Mercado Pago, así que un pago a mano llega únicamente de un
  pedido de EP-10. Por eso esta historia sale **con EP-10, al principio del
  hito 2**, y es la que estrena `entroEnPagada` en producción.
- **Abierto:** por qué medio se cobran esos pedidos —transferencia, efectivo al
  entregar, link de Mercado Pago—. Pregunta 9 del [mapa](overview.md). Un
  pedido que se despachó sin cobrar (HU-07.2) se cierra acá.

## HU-08.3 — Revisar un pago que quedó en proceso

**Como** operador, **quiero** volver a consultar a Mercado Pago un pago que
quedó en proceso, **para** no depender de que el webhook haya llegado.

- **Ya decidido:** los finales son **tres**, no dos: un pago en efectivo tarda
  días y vuelve `in_process`, que ya es `en_proceso` en la máquina
  ([ADR 010 §7](../../architecture/decisions/010-el-checkout.md)). La consulta
  es `consultarPago`, del puerto `ProveedorDePago`
  ([ADR 003](../../architecture/decisions/003-pagos.md)).
- **Ojo:** la re-consulta y el webhook pueden llegar a la vez. Los dos escriben
  con el mismo marcador: el efecto ocurre una vez.

## HU-08.4 — Devolver la plata

**Como** dueño, **quiero** reembolsar un pedido pagado que se canceló o tuvo
un problema, **para** cerrar el caso con el comprador.

- **Ya decidido:** `pagada → reembolsada`, y `reembolsada` es terminal
  ([ADR 002](../../architecture/decisions/002-estados-de-orden.md)).
- **Abierto:** si el reembolso se pide a la API de Mercado Pago desde el panel,
  o se hace en Mercado Pago y el panel sólo lo registra. La primera es más
  cómoda y es una function que **mueve plata**.
