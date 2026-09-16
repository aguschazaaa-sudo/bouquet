# EP-10 — Ventas por WhatsApp

> Hito 2, **primero** · **Workflow D** · [volver al mapa](overview.md)

**Por qué subió:** el dueño contestó que **sí hay ventas por WhatsApp**
(2026-09-16). Esta épica pasó de *con disparador* al principio del hito 2, y
con ella HU-08.2.

**Objetivo:** que una venta que no pasó por la vidriera descuente stock y siga
el mismo circuito de despacho que las demás.

**Por qué va primero:** estas ventas **ya existen** y no esperan a Mercado
Pago. Llevan el panel a producción con pedidos reales mientras la vidriera
sigue sin cobrar, y estrenan `entroEnPagada` antes que el webhook, que es lo
que [ARQUITECTURA §12](../../../../ARQUITECTURA.md#12-orden-de-construcción)
pedía.

---

## HU-10.1 — Cargar un pedido que me hicieron por mensaje

**Como** operador, **quiero** cargar un pedido que me pidieron por WhatsApp,
**para** que descuente stock y se despache como cualquier otro.

- **Ya decidido:**
  - **Nadie crea una orden desde un cliente**: las reglas lo niegan. Pasa por
    `crearOrden`, o una variante suya, con la misma transacción de stock y el
    mismo contador de números
    ([ARQUITECTURA §4.4](../../../../ARQUITECTURA.md#44-el-carrito-no-es-un-documento)).
  - Una orden cargada a mano puede **nacer pagada**: es el caso con el que
    ADR 002 justifica `onDocumentWritten`
    ([ADR 002](../../architecture/decisions/002-estados-de-orden.md), regla 1).
  - La orden guarda que vino de WhatsApp: de eso depende que se pueda
    despachar sin cobrar (HU-07.2).
- **Poca burocracia:** cargar un pedido tiene que tardar menos que anotarlo en
  un papel. Se eligen vinos de la lista que ya está en memoria, y el teléfono
  se pega tal como vino en el chat: el normalizador de `contratos` lo pasa a
  E.164.
- **Abierto:** si la regla de las seis botellas sueltas vale también para una
  venta por mensaje. La caja física es la misma; el que decide es el dueño
  (pregunta 7 del [mapa](overview.md)).

## HU-10.2 — Mandarle un link de pago

**Como** operador, **quiero** generar un link de Mercado Pago para un pedido
que cargué, **para** cobrarlo sin que el comprador pase por la tienda.

- **Ya decidido:** ARQUITECTURA ya nombra el *"link de pago pre-aprobado"* como
  una de las rutas por las que una orden nace pagada
  ([ARQUITECTURA §4.3](../../../../ARQUITECTURA.md#43-las-tres-reglas-que-salen-de-la-evidencia)).
- **Con un toque**, como el aviso de despacho (HU-07.3): el link viaja por el
  mismo enlace `wa.me`.
- **Abierto:** si esta historia entra al hito 2 depende de cómo se cobran hoy
  los pedidos de WhatsApp (pregunta 9 del [mapa](overview.md)); si es por
  transferencia, alcanza con HU-08.2. Y si es una preferencia de Checkout Pro
  como la de la vidriera, a qué URL vuelve el comprador.
