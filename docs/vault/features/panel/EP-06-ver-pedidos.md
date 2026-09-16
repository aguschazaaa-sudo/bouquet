# EP-06 — Ver pedidos

> Hito 2 · Workflow A · [volver al mapa](overview.md)

**Objetivo:** que el operador sepa, al abrir el panel, qué hay que preparar
hoy y qué está trabado.

**Depende de:** `crearOrden`. Hasta que exista no hay una sola orden que
mostrar, y la forma del `Envío` no está cerrada: **los requerimientos de esta
épica se escriben junto con el spec de `crearOrden`**.

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
- **Abierto:** ese estado combina los dos ejes, y no hay índice sobre una
  proyección. Se filtra en memoria sobre lo cargado o con una consulta por eje;
  se decide con el presupuesto en la mano.

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
- **Abierto:** el canal —aviso en el teléfono, mail, WhatsApp—. Pregunta 4 del
  [mapa](overview.md). Un aviso en el teléfono necesita la app de Android.
