# Glosario del dominio

> **Regla de lenguaje:** el dominio se nombra en **español**; la infraestructura,
> en **inglés**. `Producto`, `Bodega`, `Orden`, `Despacho` — pero `repository`,
> `provider`, `service`, `widget`, `hook`.
>
> **Por qué el glosario se escribe antes que el código:** §8.2 — cambiar la
> unidad de precio, el IVA o el formato de botella **después** de sembrar el
> catálogo deja órdenes viejas que ya no se pueden interpretar. Un glosario es
> más barato que un backfill.

---

## Catálogo

### Producto
Lo que se vende. Tiene `tipo`, `slug`, `nombre`, `precio`, `stock`,
`presentacion`, `imagenes[]`, `publicado` y `fichaVino`. El modelo entero, con
quién escribe cada campo, está en
[ADR 008](../architecture/decisions/008-catalogo-stock-y-carrito.md).

**No se llama `Vino` a propósito.** Una vinoteca vende también espumantes,
destilados, copas y cajas de regalo. Si la entidad se llama `Vino`, el día que
entre la primera copa Riedel hay dos caminos y los dos son malos: una tabla
paralela, o un `Vino` que no es un vino.

### FichaVino
Sub-objeto del Producto: `bodegaId`, `varietales[]`, `color`, `organico`,
`region`, `anada` y `volumenMl`.

⚠️ **Hoy es obligatoria, y este glosario decía que era opcional.** Las reglas y
`validarProducto` la exigen desde ADR 008: el catálogo es sólo de vinos, y un
vino sin color no se puede filtrar. El día que entre lo primero que no es vino
—una copa, un destilado— se abre con un `tipo` propio, no aflojando la regla de
los vinos.

### Graduación
`fichaVino.graduacion`, desde el 2026-09-18
([ADR 013 §2](../architecture/decisions/013-cargar-un-vino.md)). Opcional, y
**en décimas de grado, entera**: 13,5 % se guarda `135`. El rango 50–250 no
describe a los vinos: atrapa la unidad equivocada —un `14` pensado como 14 %
rebota—. El panel la pide en grados, como la etiqueta.

### Bodega
El productor. Entidad propia porque tiene página indexable (`/bodega/<slug>`) y
porque el mismo nombre escrito de tres formas distintas rompe el filtro.

### Varietal
Malbec, Cabernet Franc, Bonarda… Un producto puede tener **varios** (un corte).
Se guarda como array, y se edita con `arrayUnion`/`arrayRemove`, nunca
reescribiendo el array entero (§4.4).

### Añada
El año de cosecha. Es un entero, no un string, y es **opcional**: un espumante
sin añada existe.

### Slug
El identificador legible en la URL. **Único, e inmutable desde el alta** —no
desde la publicación, como decía este glosario—: desde
[ADR 013 §1](../architecture/decisions/013-cargar-un-vino.md) el slug de un
producto nuevo **es el id de su documento**, y las reglas no dejan cambiarlo.
Por eso el panel muestra la dirección mientras se escribe el nombre.
Cambiar un slug rompe los enlaces entrantes que se ganaron con el SEO — que es
justo el activo por el que se eligió Next.js ([ADR 001](../architecture/decisions/001-stack.md)).
Si hay que cambiarlo, se cambia con redirect 301, nunca a secas.

### Publicado
Booleano. Un producto no publicado no aparece en la vidriera ni en el sitemap.

**Se escribe siempre en la creación, por una única factory.** §4.3: un
`where('publicado','==',true)` **no devuelve los documentos donde el campo no
existe**, y esconde productos en silencio. Un verificador de CI cuenta los
productos sin el campo y sale con exit 1.

### Balde de stock
Lo que la vidriera **muestra** del stock: `disponible` · `quedan-pocas` ·
`agotado`. No es el número. Se cuenta en **botellas**: con 6 o menos es
`quedan-pocas`, así que tres cajas de 2 ya son pocas. Los textos —*Quedan
pocas*, *Se agotó*, y nada para `disponible`— viven en contratos, junto al
cálculo.

§7.4: *"Últimas 3 botellas"* **afirma un número exacto**; *"poco stock"* no. Si
las dos redacciones conviven en el mismo pool, la mitad de las veces se miente.
El balde es el dato público; el número es interno.

### Movimiento de stock
Un cambio del `stock` de un producto, hecho por la callable `moverStock` y
nunca por el panel directo. **Reponer** suma lo que entra; **corregir** fija el
valor que se contó en el depósito, con un motivo de una lista corta (*conteo*,
*rotura*, *otro*) y el `visto`: el stock que se tenía en pantalla al contar, que
la callable exige que siga siendo ése — un valor absoluto pisa las ventas del
medio. Cada uno deja un marcador `productos/{id}/movimientos/{idMovimiento}`
con quién, cuándo, antes y después, que es a la vez su clave de idempotencia y
su registro. El `idMovimiento` nace al abrir la hoja y **no se regenera**.
[ADR 016](../architecture/decisions/016-mover-el-stock.md).

### Tipo
`simple` o `compuesto`. **Explícito e inmutable.** Nadie deduce "compuesto"
porque falte el `stock`: ésa es la forma de dejar a la venta un producto mal
cargado.

### Unidad de venta
Lo que se agrega al carrito y lo que cuenta `stock`: una botella suelta, o una
caja entera. El `precio` es el de la unidad de venta.

### Caja de 2
Un producto **simple** que viene sólo así: `presentacion.botellas = 2`, con su
propio stock, contado en cajas. `presentacion` es inmutable: una botella que
pasa a caja es otro producto. Si la caja comparte botellas con otro producto,
no es esto: es un compuesto.

**Trae su propio embalaje, así que VIAJA SOLA** (`viajaSolo`, 2026-09-15): se
vende suelta, no cuenta para la *venta por caja*, viaja en su propio bulto y no
puede formar parte de una *caja sugerida*. Es una propiedad **derivada** —más
de una botella es, por definición, una caja—, no un campo del documento. El día
que exista un pack sin caja propia, deja de ser derivable.

### Compuesto
Una caja armada con otros productos, **con precio propio**. No tiene stock
propio: lo derivaría de sus componentes simples.

⚠️ **Sigue sin usarse, y eso es una decisión, no un olvido.** Las cajas que
ofrece la tienda no son compuestos: no tienen precio propio —el precio es la
suma de lo que queda en el carrito—, así que no necesitan un documento en
`productos`. Ver *Caja sugerida*. El tipo se deja en el modelo para el día que
exista una caja de regalo con su propio precio; sacarlo sería la migración que
[ADR 008](../architecture/decisions/008-catalogo-stock-y-carrito.md) se ahorró a
propósito.

### Venta por caja
La botella suelta **no se vende sola**: las sueltas de un pedido tienen que
sumar un múltiplo de `BOTELLAS_POR_CAJA`, porque ésa es la caja física con la
que se despacha. Hoy son **6**; si aparecen cajas de 3, es una constante y sus
tests.

⚠️ **Alcanza sólo a las botellas sueltas** (2026-09-15, decisión del dueño). Lo
que viene en su propia caja trae su embalaje y viaja solo: no cuenta, no
completa y no rompe. Un pedido de 4 sueltas + una caja de 2 tiene **seis
botellas y no se puede cobrar**; uno de una sola caja de 2, **sí**.

Se cuenta en **botellas**, no en unidades de venta. Y es una precondición de
**cobro**, no de validez — un carrito de 4 botellas es alguien comprando, y
`parsearCarrito` lo acepta.

### Caja sugerida
Una caja que el vendedor ofrece **ya armada**: un nombre, un slug y una lista de
`productoId`. Un id repetido son dos botellas de ese vino. Son exactamente
`BOTELLAS_POR_CAJA` entradas, **todas de vinos que se venden sueltos**: un vino
que trae su propia caja no arma caja con nadie, así que una sugerencia que lo
incluyera dejaría el carrito sin poder cobrarse.

**No es un producto.** No tiene precio propio, ni stock propio, ni documento en
`productos`: elegirla **llena el carrito**, y desde ahí el comprador cambia lo
que quiera. Viven todas en un solo documento reescrito entero,
`cajasSugeridas/publicas`, con el patrón de `metricas/popularidad`.

Si uno de sus vinos se despublica o se agota, la caja **se muestra igual** con
ese lugar marcado: cinco vinos siguen siendo una idea válida. Sólo se descarta
cuando se la puede juzgar mal —todos sus vinos existen y aun así no suman una
caja—.

### Tope
Cuánto se puede llevar de un producto en un pedido: `min(stock, 12)` unidades
de venta. Por debajo de 12 **es** el stock exacto, y por eso la pantalla nunca
lo dice: el `+` se traba, y listo.

### Popularidad
El puesto de cada vino por unidades vendidas en una ventana de tiempo. Es un
documento que se **recalcula** entero, nunca un contador que suma, para que el
job que la calcule —todavía no existe— pueda correr dos veces sin inflarla. Hoy
la escribe sólo el seed, marcada `simulada: true`. La vidriera recibe el puesto
y nunca las unidades, y sin métricas el orden por popularidad no se ofrece.

---

## Venta

### Orden
Una compra **confirmada**. No existe una Orden en borrador: el carrito vive en
`localStorage` del navegador y no hay colección `carritos`
([ARQUITECTURA §4.4](../../../ARQUITECTURA.md#44-el-carrito-no-es-un-documento)).

**Una Orden puede nacer en su estado final** (§5.1). Todo trigger sobre ella es
`onDocumentWritten` con un helper `entroEn*`, nunca `onDocumentUpdated`.

### Número de orden
Entero secuencial, asignado en la transacción de creación contra
`contadores/ordenes`. Es lo que el cliente dice por WhatsApp; el `ordenId` de
Firestore no se le muestra nunca.

### idCompra
La clave de idempotencia de una compra. Nace en el navegador junto con el
carrito, y `crearOrden` la va a usar para que el mismo pedido mandado dos veces
—un doble toque, un reintento de red— sea **una** Orden. Se renueva después de
cada compra.

### Ítem
Una línea de la Orden: `{productoId, nombre, precioUnitario, cantidad}`.

**Es un snapshot, no una referencia.** El precio del producto cambia; el precio
que se cobró, no. Una Orden que referencia el producto es una Orden que cambia de
total sola.

### estadoPago / estadoEntrega
Los dos ejes independientes del ciclo de vida. Definidos en
[ADR 002](../architecture/decisions/002-estados-de-orden.md). **No hay un campo
`estado`**: el rótulo que se muestra sale de `proyectarEstadoPublico()`.

### por_fuera
Un valor del eje `estadoPago`: **el cobro que el sistema no sigue**. Es el de un
pedido de WhatsApp, que se cobra por fuera y del que el panel no ve nada
([ADR 018 §3](../architecture/decisions/018-pedidos-de-whatsapp.md)). **Es
terminal y nace así**: nada sale de ahí ni llega ahí después, y por eso **no
dispara `entroEnPagada`** ni cae en *entregada impaga*. No significa *«pagado»*:
significa *«no lo miramos»*. El estado público que le corresponde al recién
cargado es `por_preparar`.

### Origen
De dónde vino una Orden: `whatsapp` o `vidriera`. **Lo fija el servidor según qué
callable se llamó**, nunca el pedido: decide una regla de plata —la caja de seis
no aplica a WhatsApp— y si lo declarara quien llama, un comprador se la saltearía
diciendo *«whatsapp»*. Determina el estado de pago con el que nace
(`estadoDePagoInicial`).

### Total de lista
La suma de los precios **de lista** de los ítems de un pedido de WhatsApp. **No es
lo que se cobró**: un precio arreglado por chat puede ser otro y el panel no lo
guarda (ADR 018 §6). Ninguna pantalla lo llama *«cobrado»*.

### Precio
**Entero, en centavos de ARS.** Nunca float, nunca string, nunca "con IVA" en un
campo y "sin IVA" en otro sin decir cuál es cuál en el nombre.

### Cliente
Los datos de contacto y envío que viajan **dentro** de la Orden. **No es una
cuenta ni una colección** — el checkout es sin registro.

Crear la entidad `Cliente` tiene disparador escrito
([ARQUITECTURA §11](../../../ARQUITECTURA.md#11-lo-que-queda-abierto-con-su-disparador)):
cuando el dueño pida "los que más compraron" o repetir un pedido. Antes no —
§8.3: *prometer un ranking sobre datos que no medís es mentirle al usuario.*

---

## Logística

### Envío
Dirección, `zonaId`, costo y ventana de entrega de una Orden. Sólo envío a
domicilio en el MVP; retiro en local tiene disparador escrito.

### Zona
Área de cobertura con su costo. Una dirección fuera de toda zona **no puede
comprar**, y se le dice antes de que cargue el carrito, no en el checkout.

### Despacho
El acto de que la Orden salga. Es lo que mueve `estadoEntrega` de `preparando` a
`despachada`.

### Entrega fallida
`estadoEntrega = 'fallida'` **con motivo obligatorio**. Uno de los motivos es
*"sin mayor de edad presente"* — es un caso operativo real, no un borde
([ARQUITECTURA §9.5](../../../ARQUITECTURA.md#95-alcohol-y-edad)).

---

## Teléfonos

Todo teléfono se guarda **normalizado a E.164** (`+549…`), y el campo se llama
`telefonoE164` para que nadie guarde ahí lo que el usuario tipeó.

§8.1: `wa.me` **siempre** lee los dígitos como E.164 completo. Un número escrito
como se disca en Argentina nunca fue "un número al que le falta el prefijo" —
para WhatsApp `3548…` es el país **3**. Y no falla ruidosamente: **abre un chat
con un desconocido**, que es peor que un error.

Tres cosas del normalizador que no son obvias:

1. **El `+` es dato, no ruido.** Limpiar los no-dígitos *antes* de mirarlo borra
   la única señal que separa un `+56` chileno de un `3548…` local.
2. **El `15` se ubica sin tabla de códigos de área.** Con 12 dígitos sólo puede
   estar en la posición 2, 3 o 4, y las tres se contradicen entre sí. El único
   área de 2 dígitos es el `11`. Bucle de 3 iteraciones, exacto y no heurístico.
3. **`0`, `15` y `9` son notación de cómo discar**, no partes del número. Se
   sacan los tres y el `9` se repone al componer.

La implementación vive en `packages/contratos` con sus fixtures, y la usan la
vidriera (botón de WhatsApp), el panel (aviso de despacho) y las functions.
**Una sola** (§6.4).
