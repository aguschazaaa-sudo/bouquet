# El panel — épicas e historias de usuario

- **Fecha:** 2026-09-16
- **Estado:** borrador para que lo corrija el dueño. **Ninguna historia está
  construida**: `apps/admin` es andamio (un placeholder, los enums espejados y
  el provider de Firestore)
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
| **Operador** | Carga el catálogo, repone stock, prepara y despacha pedidos | **Gente no técnica**: la claridad es el requisito, no el adorno. Entra con el claim `rol: admin` ([ARQUITECTURA §9.2](../../../../ARQUITECTURA.md#92-el-rol-va-en-un-custom-claim-no-en-un-documento)) |
| **Dueño** | Todo lo anterior, más precios, cobros, accesos y lo que muestra la vidriera | Hoy puede ser la misma persona que el operador — **pregunta 1** |
| **Comprador** | No entra al panel | Aparece como el que **recibe** algo: el aviso de despacho, el reembolso |

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
| [EP-10](EP-10-ventas-por-fuera.md) | **Ventas por fuera de la tienda** — pedidos por WhatsApp | 2 | disparador | todas |
| [EP-11](EP-11-parametros-y-tablero.md) | **Parámetros y tablero** — envío sin cargo, resumen del día | 3 | disparador | 11.1 |

**49 historias.** Las que tocan plata van por **Workflow D**, con
`revisor-pagos` obligatorio y el backend verificado antes que la pantalla
(`WORKFLOWS.md` §4). El resto, por **Workflow A**.

### Los hitos

| Hito | Épicas | Qué destraba | De qué depende |
|---|---|---|---|
| **1 — Cargar el catálogo real** | 01 · 02 · 03 · 04 · 05 | Que el dueño cargue sus vinos sin el seed, y con eso el gate `data-catalogo-de-muestra` y la selección de la home, que esperan *"cuando el dueño cargue su catálogo real"* ([`_index.md`](../../_index.md)) | Los habilitadores, abajo. **No** depende de `crearOrden` |
| **2 — Atender pedidos** | 06 · 07 · 08 | Que una venta de la vidriera se prepare, se despache y se cobre | `crearOrden` y el webhook de Mercado Pago, que son lo próximo del proyecto |
| **3 — Curar la vidriera** | 09 | Que la home diga la verdad cuando dice *"los elegimos de a uno"* | El hito 1 |
| **Con disparador** | 10 · 11 | — | La respuesta del dueño o el dato que falta, escritos en cada épica |

⚠️ **El hito 1 se aparta de [ARQUITECTURA §12](../../../../ARQUITECTURA.md#12-orden-de-construcción)
en un punto: no espera a `crearOrden`.** Nada del hito 1 lee órdenes. Pero hay
un acople que no se ve en la tabla: **la reposición de stock (HU-05.1) y
`crearOrden` escriben el mismo campo**. Las dos callables se diseñan juntas, o
la segunda en escribirse descubre que la primera no dejó lugar para su
transacción.

⚠️ **Los requerimientos del hito 2 se escriben junto con el spec de
`crearOrden`, no antes.** El panel lee lo que esa función escribe, y la forma
de la Orden todavía no está cerrada: el `Envío`, el correo, el seguimiento.

### Los habilitadores

No son historias —nadie los pide—, pero sin ellos ninguna llega a producción.

| # | Qué | Por qué hoy no está |
|---|---|---|
| H1 | **Conectar Firebase** (`flutterfire configure`, `Firebase.initializeApp`) | `main.dart` lo tiene como `TODO`: sin eso, `firestoreProvider` falla al ejecutar |
| H2 | **La dirección visual del panel** (`/disenio`) | No corrió para el panel. La de la vidriera es editorial —papel, cartucho— y un panel de uso diario para gente no técnica pide otra cosa |
| H3 | **Build y deploy del panel por CI** | El repo tiene **sólo `ci.yml`**: no hay workflow de deploy para ningún objetivo. Y el panel **no compila en esta máquina** (`CLAUDE.md`): su único ciclo de feedback es CI. Web va a Firebase Hosting con canal de preview y `hosting:clone` ([ARQUITECTURA §10](../../../../ARQUITECTURA.md#10-deploy-y-entornos)); Android, a decidir |
| H4 | **Asignar el claim `rol: admin`** | Lo escribe sólo el Admin SDK. La primera versión es un script (HU-01.3) |

---

## Lo que apareció planificando, y ningún documento sabía

1. **Una foto subida desde el panel no llega como la espera la vidriera.** La
   vidriera sirve la foto **ya recortada en WebP**, sin `next/image`
   ([ADR 008](../../architecture/decisions/008-catalogo-stock-y-carrito.md)), y
   hoy ese recorte lo hace el seed con `sharp`. Desde el panel llega cruda: falta
   una pieza, en el cliente o en una function de Storage. → HU-04.1
2. **Reordenar fotos choca con una regla.** [ARQUITECTURA §5.3](../../../../ARQUITECTURA.md#53-escrituras-concurrentes-en-arrays)
   manda `arrayUnion`/`arrayRemove` y *nunca* reescribir el array, pero un
   cambio de orden **es** reescribirlo. → HU-04.2
3. **Las reglas no validan la transición de `estadoEntrega`.** Sólo miran qué
   campos cambian (`editaSolo`). La tabla está en el espejo de Dart
   (`transicionEntregaValida`), así que un panel con un error puede mover una
   orden de `entregada` a `sin_preparar` y las reglas lo aceptan. → HU-07.1
4. **Las reglas de `ordenes` no dejan escribir ni el seguimiento ni el motivo
   de una entrega fallida.** Hoy sólo `estadoEntrega`, `notasOperador` y
   `actualizadaEn`. → HU-07.2 · HU-07.5
5. **Borrar una bodega esconde sus vinos en silencio.** Las reglas permiten el
   `delete`, y `armarCatalogo` deja afuera los productos de una bodega que no
   existe. → HU-02.4
6. **Las reglas todavía permiten borrar productos**, y `revisor-pagos` pidió
   que el panel no borre: despublique (hallazgo 1 de ADR 008). → HU-03.6
7. **El presupuesto del catálogo del panel es optimista.** [ARQUITECTURA §6.3](../../../../ARQUITECTURA.md#63-el-presupuesto-completo)
   dice **~200** lecturas/día *"con caché de sesión"*, pero una sola carga en
   frío del MVP ya son **230** (200 productos + 30 bodegas). Diez sesiones en
   frío son **2.300/día, el 4,6 % de la cuota**. No cambia ninguna decisión; sí
   cambia el número contra el que se va a medir. → HU-03.1

---

## Preguntas para el dueño

Cada una cambia el backlog, no sólo un detalle.

| # | Pregunta | Qué cambia |
|---|---|---|
| 1 | ¿Quién va a usar el panel: sólo vos, o también alguien más? | Si dar acceso es un script o una pantalla (HU-01.3), y si hacen falta dos roles |
| 2 | ¿Entran ventas por fuera de la tienda —WhatsApp, transferencia, en persona—? | Si EP-10 y HU-08.2 suben al hito 2 o quedan con disparador |
| 3 | ¿Cómo querés entrar: mail y contraseña, o tu cuenta de Google? | HU-01.1 |
| 4 | ¿Por dónde querés enterarte de un pedido nuevo: aviso en el teléfono, mail o WhatsApp? | HU-06.5, y si hace falta la app de Android desde el hito 2 |
| 5 | ¿Se despacha un pedido que todavía no está pagado? | HU-07.2: con Mercado Pago como único cobro, la respuesta natural es no |
| 6 | El aviso de despacho, ¿lo mandás vos desde tu WhatsApp con un toque, o tiene que salir solo? | HU-07.3: un toque es un enlace `wa.me`; que salga solo es la API de WhatsApp Business |

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

**No se abren los 49 changes de una vez.** Un change que se abre y no se toma es
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
