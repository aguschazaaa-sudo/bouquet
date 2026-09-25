# EP-06 — Ver pedidos

> Hito 2 · Workflow A · [volver al mapa](overview.md)

> **HU-06.1 y HU-06.2 construidas el 2026-09-24**, en el change
> [`pedidos-de-whatsapp`](../../../../openspec/changes/pedidos-de-whatsapp/proposal.md)
> ([ADR 018 §7](../../architecture/decisions/018-pedidos-de-whatsapp.md)): entraron
> porque sin ellas cargar un pedido no se podía verificar en pantalla. **HU-06.3 y
> HU-06.4 construidas el 2026-09-25**, sin openspec ([ADR 020](../../architecture/decisions/020-accion-busqueda-y-notas.md) es la especificación): la
> bandeja abre en *"Requieren acción"* y un pedido se busca por número. **HU-06.5 sigue
> sin construirse** (el aviso push: APK, FCM y un trigger; su caso fuerte es la vidriera). En 06.2 **queda afuera *cuántas cajas y cuánto
> pesan***: pide espejar `bultosDelPedido` en Dart y hoy nada lo consume; lo trae
> HU-07.2.

**Objetivo:** que el operador sepa, al abrir el panel, qué hay que preparar
hoy y qué está trabado.

**Depende de:** una Orden que mostrar. Desde el 2026-09-24 la escribe
`crearOrdenDelPanel` ([ADR 018 §2](../../architecture/decisions/018-pedidos-de-whatsapp.md)
fija su forma); la de la vidriera (`crearOrden`) escribirá **la misma**. La forma
del `Envío` cotizado sigue sin cerrarse: `envio` es `null` en un pedido de WhatsApp.

---

## HU-06.1 — Ver los pedidos por lo que hay que hacer

**Como** operador, **quiero** ver los pedidos separados por estado de entrega,
con los más nuevos arriba, **para** saber qué despachar hoy.

- **Ya decidido:** la consulta es `estadoEntrega == X` ordenada por `creadaEn`
  descendente, con su índice declarado, y **se verifica corriéndola**, no
  mirando que el índice esté `READY`
  ([ARQUITECTURA §5.5](../../../../ARQUITECTURA.md#55-índices)).
- **Presupuesto:** páginas de 25; ~250 lecturas/día con diez sesiones
  ([ARQUITECTURA §6.3](../../../../ARQUITECTURA.md#63-el-presupuesto-completo)).

## HU-06.2 — Ver el detalle de un pedido

**Como** operador, **quiero** ver un pedido entero —número, qué lleva,
quién lo recibe, a dónde va, cómo viaja, cuánto se cobró y en qué estado
está—, **para** prepararlo sin preguntar nada.

- **Ya decidido:**
  - Los ítems son un **snapshot**: el precio que se cobró, no el de hoy
    ([ARQUITECTURA §5.2](../../../../ARQUITECTURA.md#52-los-campos-que-tienen-trampa-y-cuál-es)).
  - El rótulo del estado sale de `proyectarEstadoPublico`, que ya está
    espejado en Dart. **Nunca** se arma mirando los dos campos
    ([ADR 002](../../architecture/decisions/002-estados-de-orden.md)).
  - El nombre del correo **sí** se muestra acá: la vidriera no lo dice, pero
    el dato viaja para el panel
    ([ADR 010](../../architecture/decisions/010-el-checkout.md)).
  - Cuántas cajas son y cuánto pesan: un pack viaja en su propio bulto
    ([ADR 009 §10](../../architecture/decisions/009-venta-por-caja.md)).

## HU-06.3 — Ver primero lo que requiere acción

**Como** operador, **quiero** que se destaquen los pedidos que esperan algo de
mí, **para** no olvidarme ninguno.

- **Ya decidido:** el conjunto existe en el espejo de Dart,
  `estadosPublicosQueRequierenAccion`: pagada sin despachar, **entregada
  impaga**, no entregada y cancelada con pago. La trampa es la segunda:
  entregado y visualmente "listo", pero sin cobrar.
- ⚠️ **Un pedido de WhatsApp no puede caer en *entregada impaga*.** Su cobro va
  por fuera y el panel no lo sigue: si cae ahí, queda marcado para siempre.
  Se resuelve en HU-10.1.
- ~~**Abierto:** ese estado combina los dos ejes, y no hay índice sobre una
  proyección.~~ **Decidido** ([ADR 020](../../architecture/decisions/020-accion-busqueda-y-notas.md) §1): una ficha más, la primera y la que abre, con
  un `OR` de tramos sacados de la proyección y un índice compuesto
  `(estadoEntrega, estadoPago, creadaEn)`.

## HU-06.4 — Encontrar un pedido por su número

**Como** operador, **quiero** buscar un pedido por su número, **para**
contestarle a quien me escribe por WhatsApp.

- **Ya decidido:** el número es lo que dice el comprador; el `ordenId` no se le
  muestra nunca ([glosario](../../domain/glossary.md)).
- **Presupuesto:** una igualdad sobre `numero`, **una lectura** por búsqueda.

## HU-06.5 — Enterarme de un pedido nuevo

**Como** operador, **quiero** enterarme cuando entra un pedido pagado,
**para** prepararlo sin estar mirando el panel.

- **Ya decidido:** es un efecto **accesorio**: un trigger propio con
  `onDocumentWritten` + `entroEnPagada` y su marcador de idempotencia en la
  misma transacción. Que falle no puede tumbar nada más
  ([ADR 002](../../architecture/decisions/002-estados-de-orden.md), reglas 1 a
  3).
- **Ojo:** una orden puede **nacer** pagada. Un trigger sobre
  `onDocumentUpdated` no avisaría justo de ésas.
- **Decidido por el dueño:** **un aviso en el teléfono**, por la APK con
  notificaciones push. Por eso la APK hace falta desde este hito
  (habilitador H5 del [mapa](overview.md)).
- **Lo que eso trae:**
  - Cada teléfono registra su token de notificaciones en algún lado: es un dato
    nuevo, con sus reglas. El aviso cuesta **una lectura por teléfono por
    pedido**; con tres teléfonos y cinco pedidos por día, 15.
  - Android 13 en adelante pide permiso para notificar. Si se niega, el panel
    lo dice: un aviso que nunca llega es otro fallo invisible.
- **Ojo:** el caso fuerte es el pedido de la **vidriera**, que nadie de la
  familia cargó. Uno de WhatsApp lo cargó alguien que ya lo sabe; avisarle a
  él es ruido.
