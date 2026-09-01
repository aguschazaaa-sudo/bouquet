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
Lo que se vende. Tiene `slug`, `nombre`, `precio`, `stock`, `imagenes[]`,
`publicado` y una `fichaVino` opcional.

**No se llama `Vino` a propósito.** Una vinoteca vende también espumantes,
destilados, copas y cajas de regalo. Si la entidad se llama `Vino`, el día que
entre la primera copa Riedel hay dos caminos y los dos son malos: una tabla
paralela, o un `Vino` que no es un vino.

### FichaVino
Sub-objeto **opcional** del Producto: `bodega`, `varietales[]`, `region`,
`anada`, `graduacion`, `volumenMl`. Un producto sin ficha (una copa, una caja) es
un producto válido.

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
El identificador legible en la URL. **Único, inmutable una vez publicado.**
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
Lo que la vidriera **muestra** del stock: `disponible` · `últimas unidades` ·
`agotado`. No es el número.

§7.4: *"Últimas 3 botellas"* **afirma un número exacto**; *"poco stock"* no. Si
las dos redacciones conviven en el mismo pool, la mitad de las veces se miente.
El balde es el dato público; el número es interno.

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

### Ítem
Una línea de la Orden: `{productoId, nombre, precioUnitario, cantidad}`.

**Es un snapshot, no una referencia.** El precio del producto cambia; el precio
que se cobró, no. Una Orden que referencia el producto es una Orden que cambia de
total sola.

### estadoPago / estadoEntrega
Los dos ejes independientes del ciclo de vida. Definidos en
[ADR 002](../architecture/decisions/002-estados-de-orden.md). **No hay un campo
`estado`**: el rótulo que se muestra sale de `proyectarEstadoPublico()`.

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
