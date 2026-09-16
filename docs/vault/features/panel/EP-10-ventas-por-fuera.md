# EP-10 — Ventas por fuera de la tienda

> **Con disparador** · **Workflow D** · [volver al mapa](overview.md)

**Disparador:** que el dueño conteste que **sí** entran ventas por WhatsApp,
transferencia o en persona (pregunta 2 del [mapa](overview.md)). Si es así,
esta épica sube al hito 2, y con ella HU-08.2.

**Objetivo:** que una venta que no pasó por la vidriera descuente stock y siga
el mismo circuito de despacho que las demás.

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
- **Abierto:** si la regla de las seis botellas sueltas vale también para una
  venta por mensaje. La caja física es la misma; el que decide es el dueño.

## HU-10.2 — Mandarle un link de pago

**Como** operador, **quiero** generar un link de Mercado Pago para un pedido
que cargué, **para** cobrarlo sin que el comprador pase por la tienda.

- **Ya decidido:** ARQUITECTURA ya nombra el *"link de pago pre-aprobado"* como
  una de las rutas por las que una orden nace pagada
  ([ARQUITECTURA §4.3](../../../../ARQUITECTURA.md#43-las-tres-reglas-que-salen-de-la-evidencia)).
- **Abierto:** si es una preferencia de Checkout Pro como la de la vidriera, y
  a qué URL vuelve el comprador.
