# EP-10 — Ventas por WhatsApp

> Hito 2, **primero** · **Workflow D** · [volver al mapa](overview.md)

> **HU-10.1 construida el 2026-09-24**, en el change
> [`pedidos-de-whatsapp`](../../../../openspec/changes/pedidos-de-whatsapp/proposal.md):
> la decisión, con sus alternativas y su presupuesto de lecturas, está en
> [ADR 018](../../architecture/decisions/018-pedidos-de-whatsapp.md). **Lo que
> quedaba «abierto» acá se decidió:** el pago de estos pedidos es un valor nuevo,
> `por_fuera` (§3); el pedido guarda **el precio de lista**, no el arreglado por
> chat (§6). Lo que **no** se puede todavía: cancelar ni despachar un pedido
> (EP-07), y por eso un pedido mal cargado no sale de la bandeja (§10).

**Por qué subió:** el dueño contestó que **sí hay ventas por WhatsApp**
(2026-09-16). Esta épica pasó de *con disparador* al principio del hito 2.

**Objetivo:** que una venta que no pasó por la vidriera descuente stock y siga
el mismo circuito de despacho que las demás.

**El cobro queda afuera.** Los pedidos de WhatsApp *"se gestionan por fuera, el
pago no se vería in app"* (el dueño, segunda ronda). El panel sabe qué se
vendió y a dónde va; no sabe si se cobró.

**Por qué va primero:** estas ventas **ya existen** y no esperan a Mercado
Pago. Llevan el panel a producción con pedidos reales mientras la vidriera
sigue sin cobrar. ~~Y estrenan `entroEnPagada` antes que el webhook~~: **no**,
porque su pago no pasa por el panel.

---

## HU-10.1 — Cargar un pedido que me hicieron por mensaje

**Como** operador, **quiero** cargar un pedido que me pidieron por WhatsApp,
**para** que descuente stock y se despache como cualquier otro.

- **Ya decidido:**
  - **Nadie crea una orden desde un cliente**: las reglas lo niegan. Pasa por
    `crearOrden`, o una variante suya, con la misma transacción de stock y el
    mismo contador de números
    ([ARQUITECTURA §4.4](../../../../ARQUITECTURA.md#44-el-carrito-no-es-un-documento)).
  - La orden guarda que vino de WhatsApp: de eso dependen la regla de la caja,
    el pago y el despacho (HU-07.2).
- **Decidido por el dueño:** **la regla de las seis botellas no aplica** a una
  venta por WhatsApp.
- ⚠️ **Eso convierte el origen en una regla de plata.** `crearOrden` tiene que
  rechazar todo pedido cuyas sueltas no sumen una caja (hallazgo 9 de
  `revisor-pagos`, [ADR 009](../../architecture/decisions/009-venta-por-caja.md)).
  Si el origen lo pudiera declarar quien llama, un comprador de la vidriera se
  saltearía la regla diciendo *"whatsapp"*. Lo fija **el servidor**, según qué
  callable se llamó, y la del panel exige el claim.
- ⚠️ **Su pago no se sigue, y ningún `estadoPago` le calza.** Los cinco estados
  describen un cobro que el sistema mira
  ([ADR 002](../../architecture/decisions/002-estados-de-orden.md)). Con
  `pendiente`, el pedido queda para siempre como *entregada impaga*, entre los
  que requieren acción: ruido, y contra el criterio de poca burocracia. Con
  `pagada`, afirma algo que nadie comprobó y dispara `entroEnPagada`. Las
  salidas —un estado nuevo, o que la proyección mire el origen— se deciden en
  los requerimientos, y **las dos cambian el contrato** de `packages/contratos`.
- **Poca burocracia:** cargar un pedido tiene que tardar menos que anotarlo en
  un papel. Se eligen vinos de la lista que ya está en memoria, y el teléfono
  se pega tal como vino en el chat: el normalizador de `contratos` lo pasa a
  E.164.
- **Abierto:** si el pedido guarda precios. El cobro va por fuera y el precio
  arreglado por WhatsApp puede no ser el de la lista; puede bastar con qué
  vinos y cuántos. De eso depende si estos pedidos suman a los totales del
  panel.

---

**HU-10.2 se descartó el 2026-09-16.** Era *mandarle un link de pago* a un
pedido cargado a mano, y el cobro de WhatsApp se gestiona por fuera. Su ID no
se reusa.
