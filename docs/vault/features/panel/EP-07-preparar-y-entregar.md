# EP-07 — Preparar y entregar

> Hito 2 · Workflow A, salvo **HU-07.6**, que va por **D** ·
> [volver al mapa](overview.md)

**Objetivo:** que cada pedido avance por el eje de entrega sin saltearse un
paso, y que el comprador sepa cuándo salió.

**Depende de:** `crearOrden` (EP-06). Y de una tabla que ya existe: las
transiciones de `estadoEntrega`
([ADR 002](../../architecture/decisions/002-estados-de-orden.md)).

```
sin_preparar ─▶ preparando ─▶ despachada ─▶ entregada
     │              │              │  ▲
     └──────────────┴─▶ cancelada  ▼  │
                                 fallida
```

⚠️ **Las reglas no validan la transición.** Sólo miran qué campos cambian
(`editaSolo`). La tabla está en el espejo de Dart, `transicionEntregaValida`:
si el panel tiene un error, las reglas dejan mover una orden de `entregada` a
`sin_preparar`.

---

## HU-07.1 — Marcar que estoy preparando un pedido

**Como** operador, **quiero** marcar que empecé a armar un pedido, **para**
que nadie más lo arme dos veces.

- **Ya decidido:** el operador escribe `estadoEntrega` directo; las reglas lo
  permiten. El panel sólo ofrece los pasos que `transicionEntregaValida`
  acepta desde el estado actual.
- **Abierto:** si la transición también la validan las reglas. Cuesta cero
  lecturas —`resource.data` ya está—, pero duplica la tabla en un tercer
  lugar, y el JSON generado es lo único que hoy la mantiene sincronizada.

## HU-07.2 — Despachar un pedido y cargar el seguimiento

**Como** operador, **quiero** marcar un pedido como despachado con el correo y
el número de seguimiento, **para** poder contestar *"¿dónde está mi vino?"*.

- ⚠️ **Hoy las reglas no lo dejan.** Una orden sólo acepta cambios en
  `estadoEntrega`, `notasOperador` y `actualizadaEn`: el seguimiento necesita
  un campo nuevo en `contratos` y en las reglas.
- **Abierto:** si se puede despachar un pedido impago. Pregunta 5 del
  [mapa](overview.md). Con Mercado Pago como único cobro de la vidriera, lo
  natural es que no, y que la pantalla lo diga.
- **Después:** cuando Envíopack esté contratado, el seguimiento puede llegar
  solo. Hoy se carga a mano.

## HU-07.3 — Avisarle al comprador que su pedido salió

**Como** operador, **quiero** mandarle al comprador por WhatsApp el aviso de
despacho con el link a su pedido, **para** que no tenga que preguntar.

- **Ya decidido:**
  - El teléfono se guarda en **E.164** y el normalizador es **uno solo**, en
    `contratos`. `wa.me` lee los dígitos como E.164 completo: un número mal
    armado **abre un chat con otra persona**
    ([glosario](../../domain/glossary.md)).
  - El comprobante vive en `/pedido/<numero>`, **no va por mail**
    ([ADR 010 §6](../../architecture/decisions/010-el-checkout.md)). Esa ruta
    todavía no existe.
  - El texto lo ve un comprador: pasa por `voz`.
- **Abierto:** un toque del operador (enlace `wa.me`, cero infraestructura) o
  un envío automático (API de WhatsApp Business). Pregunta 6 del
  [mapa](overview.md).

## HU-07.4 — Marcar un pedido como entregado

**Como** operador, **quiero** marcar que un pedido llegó, **para** cerrarlo.

- **Ya decidido:** `entregada` significa que **firmó un mayor de 18**
  ([ADR 002](../../architecture/decisions/002-estados-de-orden.md)). No es "el
  correo dice entregado" a secas.
- **Ojo:** una entrega de un pedido impago cae en `entregada_impaga`, que
  requiere acción (HU-06.3).

## HU-07.5 — Registrar una entrega que falló, y volver a despachar

**Como** operador, **quiero** marcar que una entrega falló con su motivo, y
volver a despacharla, **para** no perder el pedido ni su número.

- **Ya decidido:**
  - El motivo es **obligatorio**, y uno de ellos es *"sin mayor de edad
    presente"*: es un caso operativo real
    ([ARQUITECTURA §9.5](../../../../ARQUITECTURA.md#95-alcohol-y-edad)).
  - `fallida` vuelve a `despachada`: *no había nadie el martes, se vuelve el
    jueves* ([ADR 002](../../architecture/decisions/002-estados-de-orden.md)).
- ⚠️ **Las reglas tampoco dejan guardar el motivo hoy.** Mismo cambio que el
  seguimiento (HU-07.2).

## HU-07.6 — Cancelar un pedido que todavía no salió · D

**Como** operador, **quiero** cancelar un pedido que no se va a entregar,
**para** que vuelva el stock y quede claro qué pasó.

- **Ya decidido:** sólo desde `sin_preparar` o `preparando`. Un pedido
  despachado **no se cancela**: el estado honesto es `fallida`, porque el envío
  ya costó ([ADR 002](../../architecture/decisions/002-estados-de-orden.md)).
- **Por qué es D:** cancelar **repone stock**, y eso lo hace el servidor. Es el
  escenario del hallazgo 1 de `revisor-pagos`: una cancelación que repone 6 en
  un producto recreado deja **12 botellas a la venta sobre 10 físicas**
  ([ADR 008](../../architecture/decisions/008-catalogo-stock-y-carrito.md)).
  La reposición usa el snapshot de `botellas` del ítem, no el producto de hoy.
- **Ojo:** si estaba pagado, queda `cancelada_con_pago`, que pide un reembolso
  (HU-08.4).

## HU-07.7 — Dejar notas internas en un pedido

**Como** operador, **quiero** anotar algo en un pedido —*"llamar antes"*,
*"falta una botella"*—, **para** que quien lo retome lo sepa.

- **Ya decidido:** `notasOperador` ya es un campo que las reglas dejan
  escribir. El comprador no lo ve nunca.
