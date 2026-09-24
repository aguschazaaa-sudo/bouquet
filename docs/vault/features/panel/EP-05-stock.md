# EP-05 — Stock

> Hito 1 · **Workflow D en todas las historias** — `revisor-pagos` obligatorio ·
> [volver al mapa](overview.md)

> **Construida el 2026-09-23** (HU-05.1 a 05.3), sin openspec: la decisión, el
> presupuesto de lecturas y los ocho hallazgos de `revisor-pagos` están en
> [ADR 016](../../architecture/decisions/016-mover-el-stock.md). **HU-05.4 se construyó el 2026-09-24**
> (ADR 016 §6), antes de su disparador.

**Objetivo:** que la tienda nunca venda lo que no hay, y que el número del
panel sea el del depósito.

**Fuera de alcance:** la reserva de stock antes de pagar, que tiene disparador
propio: la primera sobreventa real
([ARQUITECTURA §11](../../../../ARQUITECTURA.md#11-lo-que-queda-abierto-con-su-disparador)).

⚠️ **El panel no escribe `stock`.** Lo prohíben las reglas, y la reposición
llega por una callable del servidor
([ADR 008 §1](../../architecture/decisions/008-catalogo-stock-y-carrito.md)).
Esa callable y `crearOrden` escriben el mismo campo: **se diseñan juntas**.

---

## HU-05.1 — Reponer stock cuando llega mercadería

**Como** operador, **quiero** sumar unidades a un producto cuando entra
mercadería, **para** que la tienda lo pueda vender.

- **Ya decidido:** el stock se cuenta en **unidades de venta**: botellas para un
  vino suelto, **cajas** para uno que viene en caja
  ([glosario](../../domain/glossary.md)). La pantalla nombra la unidad; "sumar
  6" a una caja de 2 son doce botellas.
- **Ojo:** un alta nace con stock 0 (HU-03.2), así que ésta es también la
  primera carga de cada vino.

## HU-05.2 — Corregir el stock después de contar

**Como** operador, **quiero** fijar el stock real cuando cuento el depósito
—roturas, faltantes—, con un motivo, **para** que la tienda no venda lo que no
hay.

- **Ya decidido:** ADR 008 descartó que el panel sólo pudiera incrementar,
  porque una regla no distingue un `increment` de un valor absoluto calculado
  sobre un dato viejo. Con una callable sí se distingue.
- ⚠️ **Un valor absoluto pisa las ventas del medio.** Si entre que el operador
  contó y guardó se vendieron dos, fijar el número las borra. La callable
  recibe **el valor que el operador vio**, igual que `crearOrden` recibe el
  `precioUnitarioVisto`, y rechaza si cambió.
- **Poca burocracia:** el motivo se elige de una lista corta —conteo, rotura,
  otro— con un toque. No es un formulario.

## HU-05.3 — Ver qué se está agotando

**Como** operador, **quiero** ver los productos agotados y los que quedan
pocos, **para** reponer a tiempo.

- **Ya decidido:** el panel **sí** ve el número exacto; el balde es el dato
  público, el número es interno ([glosario](../../domain/glossary.md)).
- **Presupuesto:** cero lecturas de más: sale del catálogo que ya está en
  memoria (HU-03.1).

## HU-05.4 — Ver los movimientos de stock de un producto

**Como** dueño, **quiero** ver quién y cuándo cambió el stock de un vino
—reposiciones, ajustes, ventas, cancelaciones—, **para** explicar una
diferencia.

- **CONSTRUIDA el 2026-09-24**, antes de su disparador (*la primera
  diferencia que nadie sepa explicar*), para cerrar el hito 1. Una hoja con los
  últimos 20; **dice `Vos` u `Otra persona`, no un nombre** porque el movimiento
  guarda un uid ([ADR 016 §6](../../architecture/decisions/016-mover-el-stock.md)).
- **Abierto:** es una colección nueva y lecturas nuevas; su presupuesto se
  cuantifica en el ADR antes de proponerla (`CLAUDE.md`).
