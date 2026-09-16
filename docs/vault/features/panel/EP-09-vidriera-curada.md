# EP-09 — La vidriera curada

> Hito 3 · Workflow A · [volver al mapa](overview.md)

**Objetivo:** que lo que la tienda **elige** mostrar lo elija el dueño, no una
regla ni el seed.

**Depende de:** el hito 1. No se cura un catálogo de muestra.

---

## HU-09.1 — Elegir los vinos de la selección de la home

**Como** dueño, **quiero** marcar qué vinos van en *La selección*, **para**
que la home diga la verdad cuando dice *"los elegimos de a uno"*.

- **Ya decidido:** hoy los elige `elegirSeleccion`, una regla por ventas y
  color, y es **provisoria** por eso mismo
  ([ADR 008 §7](../../architecture/decisions/008-catalogo-stock-y-carrito.md)).
  El pendiente está en [`_index.md`](../../_index.md): pide un campo en
  `contratos`, en las reglas y en el panel.
- ⚠️ **La home se hornea en el build.** El cambio se ve **en el próximo
  deploy**, no al guardar, salvo que el tramo 4 meta la home en la purga. La
  pantalla lo tiene que decir (HU-09.4).
- **Ojo:** la tarjeta dibuja una botella: un vino que viene en caja no puede
  estar en la selección.

## HU-09.2 — Armar una caja sugerida

**Como** dueño, **quiero** armar una caja de seis vinos con un nombre,
**para** ofrecerla ya armada en `/vinos`.

- **Ya decidido:**
  - Una caja sugerida **no es un producto**: es una lista de `productoId` que
    llena el carrito, sin precio ni stock propio. Un id repetido son dos
    botellas ([glosario](../../domain/glossary.md)).
  - Exactamente `BOTELLAS_POR_CAJA` entradas, **todas de vinos sueltos**
    ([ADR 009 §10](../../architecture/decisions/009-venta-por-caja.md)).
  - ⚠️ **La escritura está cerrada incluso para el admin.** Comprobar que una
    caja cierra serían seis `get()` facturados por escritura; lo verifica
    `verificarComposicion` en el servidor
    ([ADR 009 §8](../../architecture/decisions/009-venta-por-caja.md)). El panel
    guarda por una **callable**.
- **Lo que más vale:** que el panel no deje elegir un vino en caja, y que diga
  cuántos lugares faltan antes de guardar.

## HU-09.3 — Cambiar, ordenar y quitar cajas sugeridas

**Como** dueño, **quiero** editar las cajas que ya ofrezco, **para** rotarlas
con la temporada.

- **Ya decidido:** todas viven en **un solo documento**,
  `cajasSugeridas/publicas`, que se reescribe entero. Guardar dos veces da lo
  mismo.
- **Ojo:** una caja con un vino despublicado o agotado **se sigue mostrando**,
  con ese lugar marcado ([glosario](../../domain/glossary.md)). El panel lo
  avisa, para que el dueño decida si la cambia.

## HU-09.4 — Saber cuándo mi cambio se ve en la tienda

**Como** operador, **quiero** que el panel me diga cuándo va a verse lo que
guardé, **para** no pensar que no se guardó.

- **Ya decidido:** hasta el tramo 4, un cambio del catálogo tarda hasta **~13
  minutos** con poco tráfico
  ([ADR 008](../../architecture/decisions/008-catalogo-stock-y-carrito.md)), y
  la home, hasta el próximo deploy.
- **Ojo:** el número cambia el día que exista la purga por tag, y la pantalla
  tiene que cambiar con él. Un texto que promete *"en unos minutos"* después
  del tramo 4 miente al revés.
- **Alcance:** aplica a precio (HU-03.5), publicar (HU-03.6) y fotos (EP-04),
  no sólo a esta épica.
