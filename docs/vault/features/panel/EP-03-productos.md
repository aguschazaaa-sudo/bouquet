# EP-03 — Productos

> **CERRADA el 2026-09-22.** Las tres historias que faltaban —HU-03.5, HU-03.6
> y HU-03.7— están construidas, en el change
> [`panel-publicar-un-vino`](../../../../openspec/changes/panel-publicar-un-vino/proposal.md)
> ([ADR 014](../../architecture/decisions/014-publicar-un-vino.md)). Falta el
> deploy del panel y que alguien publique un vino real y lo mire — eso no
> reabre la épica, es lo que falta para que el change se archive.
>
> Hito 1 · Workflow A, salvo **HU-03.5** y **HU-03.6**, que fueron por **D** ·
> [volver al mapa](overview.md)

**Objetivo:** que el dueño cargue y mantenga su catálogo sin pedirle nada al
desarrollador, y sin poder dejar a la venta un producto mal cargado.

**Fuera de alcance:** el stock (EP-05), las fotos (EP-04) y los compuestos —el
`tipo` existe y no se usa ([glosario](../../domain/glossary.md))—.

El modelo, con quién escribe cada campo, está en
[ADR 008 §1](../../architecture/decisions/008-catalogo-stock-y-carrito.md).

---

## HU-03.1 — Ver el catálogo entero y buscar

**Como** operador, **quiero** ver todos los productos —publicados o no— y
filtrarlos escribiendo, **para** encontrar uno en segundos.

- **Ya decidido:** filtro `contains` normalizado **en memoria**, sin búsqueda
  difusa
  ([ARQUITECTURA §7](../../../../ARQUITECTURA.md#7-búsqueda-una-sola-implementación)).
  La caché del catálogo **no lleva `autoDispose`**: descartarla hace releer
  todo en cada navegación
  ([ARQUITECTURA §6.3](../../../../ARQUITECTURA.md#63-el-presupuesto-completo)).
- **Presupuesto:** una carga en frío del MVP son **230 lecturas** (200
  productos + 30 bodegas); diez sesiones en frío, **2.300/día, 4,6 %** de la
  cuota. El ~200 que dice ARQUITECTURA supone que la caché sobrevive entre
  sesiones: hay que medirlo (hallazgo 7 del [mapa](overview.md)).

## HU-03.2 — Dar de alta un vino

**Como** operador, **quiero** cargar un vino nuevo con su ficha, **para**
poder venderlo.

- **Ya decidido:**
  - Nace con `publicado: false` y `stock: 0`; el primer stock llega por la
    reposición (HU-05.1). Lo exigen las reglas.
  - `publicado` se escribe **siempre**, por una única factory: un
    `where('publicado','==',true)` no devuelve los documentos sin el campo
    ([ARQUITECTURA §5.2](../../../../ARQUITECTURA.md#52-los-campos-que-tienen-trampa-y-cuál-es)).
  - `fichaVino` es obligatoria: bodega (elegida de la lista, HU-02.2),
    varietales de la **lista cerrada**, color, orgánico, región, volumen. La
    añada puede faltar.
  - El precio se escribe en pesos y se guarda como **entero en centavos**.
  - `graduacion` no existe en el modelo y *"entra con el panel"*
    ([glosario](../../domain/glossary.md)): es un cambio en `contratos` y en las
    reglas, no sólo en la pantalla.
- ~~**Ojo:** el slug tiene que ser **único**, y las reglas no lo pueden
  comprobar sin un `get()`.~~ **Resuelto el 2026-09-18** en
  [ADR 013 §1](../../architecture/decisions/013-cargar-un-vino.md): el id del
  producto **es** su slug y las reglas lo exigen, así que la base no deja
  repetirlo. Reemplaza la reserva `slugs/{slug}` de ADR 008.
- **`graduacion` entró** en décimas de grado, entera, entre 50 y 250
  ([ADR 013 §2](../../architecture/decisions/013-cargar-un-vino.md)).

## HU-03.3 — Dar de alta un producto que viene en su propia caja

**Como** operador, **quiero** cargar un producto indicando cuántas botellas
trae su caja, **para** que la tienda lo venda suelto y lo despache en su propio
bulto.

- **Ya decidido:** `presentacion.botellas` es **inmutable**: una botella que
  pasa a caja es otro producto. Más de una botella significa que **viaja
  solo** y no cuenta para la caja de seis
  ([ADR 009 §10](../../architecture/decisions/009-venta-por-caja.md)).
- **La pantalla lo dice antes de guardar**, no después: es el único campo del
  alta que no tiene vuelta atrás, junto con el tipo.

## HU-03.4 — Corregir los datos de un vino

**Como** operador, **quiero** corregir el nombre, la ficha o la descripción de
un vino, **para** arreglar un error sin darlo de baja.

- **Ya decidido:** un `update` no puede tocar `tipo`, `presentacion`, `stock`
  ni `muestra` (reglas). Los varietales se editan con
  `arrayUnion`/`arrayRemove`, nunca reescribiendo el array
  ([ARQUITECTURA §5.3](../../../../ARQUITECTURA.md#53-escrituras-concurrentes-en-arrays)).
- **Ojo:** el slug de un vino publicado **no cambia**; si hace falta, va con
  redirect 301 ([glosario](../../domain/glossary.md)). El panel no ofrece
  editarlo después de publicar. **Desde ADR 013 no cambia nunca**: es el id.
- ~~⚠️ **"La descripción" no existe en el modelo**~~ (hallazgo 14 del
  [mapa](overview.md)). **Contestado el 2026-09-21: la ficha la lleva.**
  `FichaVino.descripcion`, opcional, hasta 600 caracteres, y **llega al
  comprador** en la ficha de la vidriera — si no llegara sería un campo de
  escritura, como le pasa hoy a `graduacion`. Se corrige **también en un vino
  publicado**, a diferencia del precio: no es plata.
  [ADR 014](../../architecture/decisions/014-publicar-un-vino.md) §4 a §7.

## HU-03.5 — Cambiar el precio · D

**Como** dueño, **quiero** cambiar el precio de un vino, **para** acompañar los
costos sin tocar código.

- **Ya decidido:**
  - `crearOrden` va a comparar el `precioUnitarioVisto`: un cambio de precio
    **rechaza los carritos que ya estaban abiertos** con el precio anterior.
  - Hasta el tramo 4 (Cloudflare), el precio nuevo puede tardar **~13 minutos**
    en verse
    ([ADR 008, Consecuencias](../../architecture/decisions/008-catalogo-stock-y-carrito.md)).
    La pantalla lo dice (HU-09.4).
- ~~**Abierto:** una baranda contra el dedo gordo —un precio que baja 90 % pide
  confirmación— escrita sobre el **valor nuevo**, no sólo sobre el anterior
  ([ARQUITECTURA §9.4](../../../../ARQUITECTURA.md#94-la-baranda-de-config-tiene-que-proteger-la-primera-escritura)).~~
  **CONSTRUIDO el 2026-09-22:** `cambio_de_precio.dart` —10× la mediana de los
  publicados (con 5 o más) **o** mitad/doble del anterior, sobre el valor
  **nuevo**—, con su propia hoja de confirmación
  (`hoja_de_precio.dart`) y el aviso de los ~13 minutos.
  [ADR 014](../../architecture/decisions/014-publicar-un-vino.md), sección
  «HU-03.5, HU-03.6 y HU-03.7».

## HU-03.6 — Publicar y despublicar · D

**Como** operador, **quiero** publicar un vino cuando está listo y sacarlo de
la tienda sin borrarlo, **para** no perder su historia.

- **CONSTRUIDO el 2026-09-22:** el interruptor de publicar/despublicar
  (`interruptor_de_tienda.dart`), con la revisión previa
  (`revision_para_publicar.dart`) y `RepositorioDeProductos.publicar`/
  `despublicar`. [ADR 014](../../architecture/decisions/014-publicar-un-vino.md),
  sección «HU-03.5, HU-03.6 y HU-03.7».
- **Ya decidido:** **el panel no borra productos: despublica.** Borrar y
  recrear con el mismo id se saltea la inmutabilidad de `tipo` y
  `presentacion` (hallazgo 1 de `revisor-pagos`, ADR 008). ~~⚠️ Las reglas
  todavía permiten el `delete`.~~ **Cerrado el 2026-09-21:** `allow delete: if
  false` está desplegado (`04b8a471`, ADR 014), y el panel tampoco lo ofrece
  desde ningún lado.
- **Para publicar**, el panel valida lo mismo que la vidriera, o la vidriera lo
  descarta **sin avisar** (hallazgo 8): precio mayor que cero (hallazgo 2),
  nombre que no sea sólo espacios, imágenes con URL pública.
- ~~**Abierto:** si hace falta al menos una foto para publicar.~~
  **Decidido el 2026-09-21: la foto NO bloquea publicar.** Fundado en el
  código, no en el gusto: `VentanaDeBotella.tsx:45` ya dibuja la silueta con
  «sin foto», y con EP-04 sin construir bloquear dejaría **el hito 1 trabado
  sin poder publicar nada**. Lo que sí hace falta es que el panel lo avise
  antes, y eso es HU-03.7.
  [ADR 014](../../architecture/decisions/014-publicar-un-vino.md) §3.

## HU-03.7 — Ver lo que ve el comprador

**Como** operador, **quiero** ver cómo sale un vino en la tienda —publicado o
no, su balde de stock, el enlace a su ficha—, **para** confirmar que lo que
cargué salió.

- **CONSTRUIDO el 2026-09-22:** `en_la_tienda.dart` (`revisarParaLaTienda`,
  `revisarParaPublicar`) y `como_se_ve_en_la_tienda.dart`. Con esto, **EP-03
  queda cerrada**: las tres historias que faltaban están construidas.
  [ADR 014](../../architecture/decisions/014-publicar-un-vino.md), sección
  «HU-03.5, HU-03.6 y HU-03.7».
- **Ya decidido:** el balde (`disponible` · `quedan-pocas` · `agotado`) sale de
  `contratos`, nunca de una cuenta propia del panel. Mismo principio que la
  proyección de estados ([ADR 002](../../architecture/decisions/002-estados-de-orden.md)).
- **Lo que más vale:** decir **por qué un vino publicado no aparece**.
  `armarCatalogo` descarta y reporta los que no validan, los slugs duplicados y
  los de una bodega inexistente; hoy eso sólo se lee en el log del build.
