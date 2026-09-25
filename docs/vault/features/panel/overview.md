# El panel — épicas e historias de usuario

- **Fecha:** 2026-09-16
- **Estado:** con **dos rondas de respuestas del dueño**, las dos del
  2026-09-16. Falta un dato suyo: el número de WhatsApp de la tienda.
  **Construidas: EP-01 entera (2026-09-16), EP-02 + HU-03.1 (2026-09-17), EP-03
  entera (2026-09-22, HU-03.2 a 03.7), EP-04 (2026-09-22 HU-04.1 · HU-04.3 · HU-04.4; **HU-04.2 recortada a *elegir la
  principal* el 2026-09-24**, change `panel-foto-principal`) y EP-05 entera (2026-09-23 HU-05.1 ·
  HU-05.2 · HU-05.3; **HU-05.4 el 2026-09-24**, **sin openspec, a pedido del dueño**: el estado de esas
  cuatro NO se calcula con el `grep` de abajo porque no tienen change — el ADR
  016 es su especificación). **Hito 2, primer tramo (2026-09-24, change
  `pedidos-de-whatsapp`, [ADR 018](../../architecture/decisions/018-pedidos-de-whatsapp.md)):
  HU-10.1, HU-06.1 y HU-06.2** — el estado no se tilda acá, se calcula con el
  `grep` de abajo
- **Qué es:** el plan de la app de gestión, en dos capas — **épicas** que
  agrupan **historias de usuario**. La tercera capa, los **requerimientos**, se
  escribe después, historia por historia (ver *Cómo sigue*)
- **Qué NO es:** un registro de avance. Acá no hay casillas de "hecha" a
  propósito ([WORKFLOWS §7](../../../../WORKFLOWS.md)): el estado se deriva, no
  se escribe

> Cada historia lleva lo que **ya está decidido** y la restringe, con el enlace
> al ADR. Ese es el valor de escribirlas acá y no en una planilla: una historia
> que no sabe que `stock` lo escribe sólo el servidor termina en una pantalla
> que las reglas rechazan.

---

## Quién usa el panel

| Rol | Qué hace | Nota |
|---|---|---|
| **La familia** | Todo: catálogo, stock, pedidos, cobros y lo que muestra la vidriera | **Un solo rol**, el claim `rol: admin` ([ARQUITECTURA §9.2](../../../../ARQUITECTURA.md#92-el-rol-va-en-un-custom-claim-no-en-un-documento)). Varias personas, **gente no técnica**, desde la compu o el teléfono |
| **Comprador** | No entra al panel | Aparece como el que **recibe** algo: el aviso de despacho, el reembolso |

Las historias dicen *operador* o *dueño* según qué **sombrero** lleva quien la
usa, no según un permiso: es la misma cuenta.

### El criterio: poca burocracia

*"Es negocio familiar, el panel no debe exceder la burocracia"* (el dueño,
2026-09-16). Traducido a reglas que se aplican historia por historia:

1. **Un solo rol.** Todos los que entran pueden todo. No hay aprobaciones ni
   permisos por sección.
2. **Un paso más tiene que evitar una pérdida concreta**: plata, stock o un
   comprador mal atendido. Si no evita ninguna, no va.
3. **Se confirma sólo lo que no tiene vuelta atrás**: el tipo y las botellas de
   un producto, cancelar, reembolsar, un precio que cambia mucho.
4. **Un motivo es un toque, no un formulario.** Donde hace falta —una entrega
   fallida, un ajuste de stock— se elige de una lista corta.

**El repartidor no es un rol todavía.** [ARQUITECTURA §9.5](../../../../ARQUITECTURA.md#95-alcohol-y-edad)
le pide marcar `fallida` con motivo, pero `REPARTIMOS_NOSOTROS = false`: hoy
todo sale por correo ([ADR 010 §1](../../architecture/decisions/010-el-checkout.md)).
Entra cuando se prenda el reparto propio.

---

## Las épicas

| Épica | Qué resuelve | Historias | Hito | Toca plata |
|---|---|---:|---|---|
| [EP-01](EP-01-entrar-al-panel.md) | **Entrar al panel** — acceso, permisos, web y teléfono | 5 | 1 | — |
| [EP-02](EP-02-bodegas.md) | **Bodegas** — alta sin duplicados, sin borrar vinos de rebote | 4 | 1 | — |
| [EP-03](EP-03-productos.md) | **Productos** — alta, edición, precio, publicar | 7 | 1 | 03.5 · 03.6 |
| [EP-04](EP-04-fotos.md) | **Fotos** — subir desde la compu o el teléfono, y que llegue a la vidriera | 4 | 1 | — |
| [EP-05](EP-05-stock.md) | **Stock** — reponer, corregir, ver qué se agota | 4 | 1 | todas |
| [EP-06](EP-06-ver-pedidos.md) | **Ver pedidos** — lista, detalle, qué requiere acción | 5 | 2 | — |
| [EP-07](EP-07-preparar-y-entregar.md) | **Preparar y entregar** — el eje `estadoEntrega` | 7 | 2 | 07.6 |
| [EP-08](EP-08-cobros.md) | **Cobros** — el eje `estadoPago` | 4 | 2 | todas |
| [EP-09](EP-09-vidriera-curada.md) | **La vidriera curada** — la selección de la home y las cajas sugeridas | 4 | 3 | — |
| [EP-10](EP-10-ventas-por-fuera.md) | **Ventas por WhatsApp** — cargarlas para que descuenten stock y se despachen; el cobro va por fuera | 1 | **2, primero** | todas |
| [EP-11](EP-11-parametros-y-tablero.md) | **Parámetros y tablero** — envío sin cargo, resumen del día | 3 | disparador | 11.1 |

**48 historias** (eran 49: HU-10.2 se descartó, y su ID no se reusa). Las que tocan plata van por **Workflow D**, con
`revisor-pagos` obligatorio y el backend verificado antes que la pantalla
(`WORKFLOWS.md` §4). El resto, por **Workflow A**.

### Los hitos

| Hito | Épicas | Qué destraba | De qué depende |
|---|---|---|---|
| **1 — Cargar el catálogo real** | 01 · 02 · 03 · 04 · 05 | Que el dueño cargue sus vinos sin el seed, y con eso el gate `data-catalogo-de-muestra` y la selección de la home, que esperan *"cuando el dueño cargue su catálogo real"* ([`_index.md`](../../_index.md)) | Los habilitadores, abajo. **No** depende de `crearOrden` |
| **2 — Atender pedidos, empezando por los de WhatsApp** | 10 · 06 · 07 · 08 | Que las ventas que **ya existen** se carguen, descuenten stock y se despachen —el cobro va por fuera—; después, las de la vidriera | `crearOrden` con una variante para el panel. **Los pedidos de WhatsApp no esperan a Mercado Pago**; los de la vidriera, sí |
| **3 — Curar la vidriera** | 09 | Que la home diga la verdad cuando dice *"los elegimos de a uno"* | El hito 1 |
| **Con disparador** | 11 | — | El dato que falta, escrito en cada historia |

⚠️ **Las ventas por WhatsApp llevan el panel a producción antes que el cobro
online.** Cargarlas descuenta stock y las despacha, y nada de eso espera a
Mercado Pago: el panel atiende **ventas reales** mientras la vidriera sigue sin
cobrar (sexto gate). El orden de deploy no cambia: reglas → functions → panel,
con `revisor-pagos`.

~~Y devuelven un camino que el checkout había borrado~~: **no lo devuelven.**
[ARQUITECTURA §12](../../../../ARQUITECTURA.md#12-orden-de-construcción) quería
que `entroEnPagada` corriera en producción desde el primer pedido, marcado
pagado a mano, y la primera ronda de respuestas parecía recuperarlo con un
pedido de WhatsApp cobrado por transferencia. La segunda lo descartó: **el
cobro de WhatsApp se gestiona por fuera y no se ve en el panel**. El trigger se
estrena con el webhook, como quedó con
[ADR 010](../../architecture/decisions/010-el-checkout.md).

⚠️ **El hito 1 se aparta de [ARQUITECTURA §12](../../../../ARQUITECTURA.md#12-orden-de-construcción)
en un punto: no espera a `crearOrden`.** Nada del hito 1 lee órdenes. Pero hay
un acople que no se ve en la tabla: **la reposición de stock (HU-05.1) y
`crearOrden` escriben el mismo campo**. Las dos callables se diseñan juntas, o
la segunda en escribirse descubre que la primera no dejó lugar para su
transacción.

⚠️ **Los requerimientos del hito 2 se escriben junto con la callable que crea la
Orden, no antes.** El panel lee lo que esa función escribe. **La forma de la Orden
se cerró el 2026-09-24 con `crearOrdenDelPanel`** ([ADR 018 §2](../../architecture/decisions/018-pedidos-de-whatsapp.md)),
y los requerimientos de HU-10.1, 06.1 y 06.2 están en el change
`pedidos-de-whatsapp`. **Siguen abiertos** el `Envío` cotizado, el correo y el
seguimiento: son de EP-07 y de la vidriera.

⚠️ **El hito 2 no está entregado con esto.** Se puede cargar un pedido y verlo, pero
**no avanzarlo**: sin EP-07 los pedidos se acumulan en `sin_preparar`, la bandeja
cuesta 25 lecturas por apertura y el aviso de stock de la hoja de corrección no es
fiable (ADR 018 §9). **EP-07 es lo que sigue.**

### Los habilitadores

No son historias —nadie los pide—, pero sin ellos ninguna llega a producción.

| # | Qué | Por qué hoy no está |
|---|---|---|
| H1 | **Conectar Firebase** (`flutterfire configure`, `Firebase.initializeApp`) | `main.dart` lo tiene como `TODO`: sin eso, `firestoreProvider` falla al ejecutar |
| H2 | **La dirección visual del panel** (`/disenio`) | No corrió para el panel. La de la vidriera es editorial —papel, cartucho— y un panel de uso diario para gente no técnica pide otra cosa |
| H3 | **Build y deploy del panel por CI** | El repo tiene **sólo `ci.yml`**: no hay workflow de deploy para ningún objetivo. Y el panel **no compila en esta máquina** (`CLAUDE.md`): su único ciclo de feedback es CI. Web va a Firebase Hosting con canal de preview y `hosting:clone` ([ARQUITECTURA §10](../../../../ARQUITECTURA.md#10-deploy-y-entornos)). Android es **una APK** (respuesta del dueño), y su build se dispara a mano: los builds nunca son automáticos |
| H4 | **Asignar el claim `rol: admin`** | Lo escribe sólo el Admin SDK. La primera versión es un script (HU-01.3) |
| H5 | **Repartir la APK y mantenerla al día** | Hace falta **desde el hito 2**, por los avisos. ⚠️ **Una APK no se actualiza sola**, y la web sí: un teléfono con una APK vieja tiene un espejo viejo de los estados de Orden, y un estado nuevo le llega sin rótulo. Hace falta una versión mínima que el panel lea al abrir y un *"actualizá la app"*. Cómo se reparte —Firebase App Distribution o el archivo directo— se decide en su ADR |

---

## Lo que apareció planificando, y ningún documento sabía

1. ~~**Una foto subida desde el panel no llega como la espera la vidriera.**~~
   **Cerrado el 2026-09-22** en
   [ADR 015](../../architecture/decisions/015-fotos-del-panel.md):
   `procesarFoto`, una Cloud Function **callable**, aplica la MISMA tubería que
   el seed —`trim(12)` → `resize(1200)` → `webp(82)`—, compartiendo los tres
   números vía `packages/contratos/src/foto.ts` sin compartir el código
   (`contratos` no puede depender de `sharp`; el número sí, el `sharp.trim()`
   no). La vidriera sigue sirviendo la foto ya recortada en WebP, sin
   `next/image` ([ADR 008](../../architecture/decisions/008-catalogo-stock-y-carrito.md)).
   → HU-04.1
2. **Reordenar fotos choca con una regla.** [ARQUITECTURA §5.3](../../../../ARQUITECTURA.md#53-escrituras-concurrentes-en-arrays)
   manda `arrayUnion`/`arrayRemove` y *nunca* reescribir el array, pero un
   cambio de orden **es** reescribirlo. → HU-04.2. **Sigue sin construirse, a
   propósito**: `panel-fotos-de-un-vino`
   ([ADR 015](../../architecture/decisions/015-fotos-del-panel.md)) la deja
   afuera con disparador — el primer vino con dos fotos; el seed tiene una
   sola por producto —, no la resuelve
3. **Las reglas no validan la transición de `estadoEntrega`.** Sólo miran qué
   campos cambian (`editaSolo`). La tabla está en el espejo de Dart
   (`transicionEntregaValida`), así que un panel con un error puede mover una
   orden de `entregada` a `sin_preparar` y las reglas lo aceptan. → HU-07.1
4. **Las reglas de `ordenes` no dejan escribir ni el seguimiento ni el motivo
   de una entrega fallida.** Hoy sólo `estadoEntrega`, `notasOperador` y
   `actualizadaEn`. → HU-07.2 · HU-07.5
5. **Borrar una bodega esconde sus vinos en silencio.** Las reglas permiten el
   `delete`, y `armarCatalogo` deja afuera los productos de una bodega que no
   existe. → HU-02.4. **La baranda quedó en el panel, no en las reglas**, con
   el riesgo que queda escrito en
   [ADR 012 §5](../../architecture/decisions/012-el-catalogo-del-panel.md)
6. **Las reglas todavía permiten borrar productos**, y `revisor-pagos` pidió
   que el panel no borre: despublique (hallazgo 1 de ADR 008). → HU-03.6
7. ~~**El presupuesto del catálogo del panel es optimista.**~~ **Cerrado el
   2026-09-17** en [ADR 012](../../architecture/decisions/012-el-catalogo-del-panel.md).
   [ARQUITECTURA §6.3](../../../../ARQUITECTURA.md#63-el-presupuesto-completo)
   dice **~200** lecturas/día *"con caché de sesión"* suponiendo que sobrevive
   entre sesiones, y la de Riverpod muere con la pestaña: una carga en frío del
   MVP son **230** (200 productos + 30 bodegas). Diez sesiones en frío,
   **2.300/día, el 4,6 % de la cuota**. → HU-03.1

**Y lo que trajeron las respuestas del dueño:**

8. **La Orden no sabe de dónde vino.** Un pedido de WhatsApp no sigue su pago
   ni la regla de la caja, uno de la vidriera sí, y hoy nada los distingue. →
   HU-07.2 · HU-10.1
9. **Una APK no se actualiza sola.** Un teléfono con una versión vieja tiene un
   espejo viejo de los estados de Orden. → H5
10. **Entrar con contraseña y con Google usando el mismo mail tiene una
    trampa**: la contraseña sin verificar se puede desvincular. → HU-01.1
11. **Un aviso "con un toque" sale del WhatsApp de quien lo toca.** → HU-07.3
12. **El origen del pedido pasa a decidir una regla de plata.** La regla de las
    seis botellas no aplica a WhatsApp: si quien llama a `crearOrden` pudiera
    declarar el origen, un comprador de la vidriera se la saltearía. Lo fija el
    servidor según **qué callable** se llamó. → HU-10.1
13. **Un pedido cuyo pago no se sigue no tiene un `estadoPago` que le calce.**
    `pendiente` lo deja para siempre como *entregada impaga*, y `pagada` afirma
    algo que nadie comprobó. → HU-10.1 · HU-06.3

**Y lo que apareció construyendo:**

14. **HU-03.4 nombra "la descripción" de un vino, y el modelo no la tiene**
    (2026-09-18). Ni `contratos`, ni las reglas —que cierran el documento con
    `hasOnly`—, ni la ficha de la vidriera. Es un campo nuevo en cuatro
    lugares, y la historia se escribió suponiendo que existía. **Pregunta para
    el dueño**: ¿la ficha lleva un texto del vino? → HU-03.4,
    [ADR 013](../../architecture/decisions/013-cargar-un-vino.md)

---

## Lo que contestó el dueño (2026-09-16)

| # | Pregunta | Respuesta | Qué cambió |
|---|---|---|---|
| 1 | ¿Quién usa el panel? | *"Es negocio familiar, el panel no debe exceder la burocracia"* | Un solo rol y el criterio de arriba. HU-01.3 sigue siendo un script primero |
| 2 | ¿Entran ventas por fuera de la tienda? | **Sí, por WhatsApp** | EP-10 sube al hito 2 y va **primero**. HU-08.2 recuperaba su caso, hasta la respuesta 9 |
| 3 | ¿Mail y contraseña, o Google? | *"Creo que ambos"* | HU-01.1 con los dos, y una trampa de Firebase anotada ahí |
| 4 | ¿Por dónde enterarse de un pedido nuevo? | **Aviso en el teléfono, por una APK** | HU-06.5 con notificaciones push; la APK hace falta desde el hito 2 (H5) |
| 5 | ¿Se despacha un pedido impago? | *"No, pero capaz para ventas por WhatsApp"* | HU-07.2: los de la vidriera no; en los de WhatsApp el panel no mira el pago (respuesta 9). La Orden tiene que saber **de dónde vino** |
| 6 | El aviso de despacho, ¿un toque o automático? | **Con un toque** | HU-07.3 es un enlace `wa.me`: cero infraestructura |

Las respuestas 3 y 5 vinieron con un *"creo"* y un *"capaz"*: se confirman
cuando se escriban los requerimientos de esas historias. **Pasan a ADR en ese
mismo momento**, con su presupuesto de lecturas, que hoy no se puede calcular.

### La segunda ronda, con las preguntas que salieron de la primera

| # | Pregunta | Respuesta | Qué cambió |
|---|---|---|---|
| 7 | ¿La regla de las seis botellas vale para una venta por WhatsApp? | **No aplica** | HU-10.1 no la exige, y el origen del pedido pasa a ser una regla de plata (hallazgo 12) |
| 8 | ¿La tienda tiene un WhatsApp propio, o cada uno avisa desde el suyo? | *"Tenés razón"*: el botón de aviso **se activa o desactiva por persona**. **El número todavía no existe**; lo va a pasar el dueño | HU-07.3. Es el mismo número que falta en `/oficio` (quinto gate) |
| 9 | ¿Cómo se cobran los pedidos de WhatsApp? | **Se gestionan por fuera: el pago no se ve en el panel** | **HU-10.2 se descarta**; HU-08.2 vuelve a esperar un disparador; `entroEnPagada` se estrena con el webhook; y aparece el hallazgo 13 |

---

## Lo que no es una épica todavía

| Qué | Disparador | Fuente |
|---|---|---|
| El rol **repartidor** | Cuando se prenda `REPARTIMOS_NOSOTROS` | [ADR 010 §1](../../architecture/decisions/010-el-checkout.md) |
| **Clientes** y "los que más compraron" | Cuando el dueño lo pida | [ARQUITECTURA §11](../../../../ARQUITECTURA.md#11-lo-que-queda-abierto-con-su-disparador) |
| **Retiro en local** | Si aparece un local | [ADR 010](../../architecture/decisions/010-el-checkout.md) |
| **Etiquetas del correo** desde el panel | Cuando Envíopack esté contratado | [`enviopack.md`](../../architecture/proveedores/enviopack.md) |
| **Tarifas y zonas editables** | `zonas` y `config` son del servidor por regla; se reevalúa con las tarifas reales | [ARQUITECTURA §9.4](../../../../ARQUITECTURA.md#94-la-baranda-de-config-tiene-que-proteger-la-primera-escritura) |

---

## Cómo sigue

**Paso 2 — de historia a requerimientos.** Cuando una historia (o un grupo de la
misma épica que sale junto) se toma para construir, nace su change con
`/opsx:propose`. Sus requerimientos van en `specs/`, con `SHALL` y escenarios, y
la propuesta **cita los IDs** (`HU-03.2`). Antes, para lo visual, la maqueta: lo
visual se juzga mirándolo, y en este proyecto las maquetas encontraron defectos
que ningún documento vio.

**El orden, con las respuestas:** los habilitadores H1 y H2, el hito 1 entero,
y en el hito 2, EP-10 antes que las demás.

**No se abren los 48 changes de una vez.** Un change que se abre y no se toma es
el cementerio de 33 carpetas que describe [WORKFLOWS §2](../../../../WORKFLOWS.md#22-los-24-abiertos-y-la-sorpresa-que-traen).

**Paso 3 — construir**, por Workflow A o D, y cerrar en **producción
verificada**.

**El estado de una historia se calcula, no se tilda:**

```bash
grep -rl "HU-03.2" openspec/changes --exclude-dir=archive   # en curso
grep -rl "HU-03.2" openspec/changes/archive                 # verificada en producción
```

Archivar es el paso 10 del Workflow A, **después** de verificar producción: un
change archivado es una historia entregada. Ninguna de las dos líneas da nada
hoy, y eso es el estado real.
