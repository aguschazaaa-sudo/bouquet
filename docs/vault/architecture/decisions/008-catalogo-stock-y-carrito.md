# ADR 008 — El catálogo, el stock y el carrito

- **Fecha:** 2026-09-11
- **Estado:** aceptada y **aplicada en stage**: `/vinos`, `/vinos/[slug]` y
  `/carrito` funcionan contra `bouquet-vinos` con 20 vinos de muestra. **La
  tienda no se despliega** (ver *Consecuencias*)
- **Decide:** el modelo del Producto y su stock, cómo lee la vidriera el
  catálogo y con qué caché, y el carrito hasta el total, sin cobrar
- **Toca:** [ADR 004](004-frescura-y-lecturas.md) (el balde se renombra y se
  mide en botellas), [ADR 005](005-hosting-vidriera.md) (el `Cache-Tag` de la
  ficha va por slug, y el mecanismo de caché de Next queda escrito) y
  [ADR 006](006-estructura-de-la-tienda.md) (las features se componen con
  slots, y entran tres piezas en `shared/ui`)
- **Hace cumplir:** `scripts/ci/auditar_varietales.mjs` (en el alcance
  `rapido`) y los tests de `packages/contratos` y de `apps/tienda`. Los 24
  casos de `firestore.rules` contra el emulador (`scripts/reglas/`) **corren a
  mano**: todavía no están en CI (hallazgo 7 de abajo)
- **Planificación:** `openspec/changes/catalogo-y-carrito/`

## Contexto

`/vinos` y `/carrito` eran `PaginaEnObra`, y `productos` estaba vacío. Sin
catálogo no hay nada que vender. Y el modelo de stock tenía que quedar bien
**antes** de `crearOrden` y de las cajas que el dueño ya anunció: lo que se
decide mal hoy se paga con una migración sobre datos reales.

El diseño pasó por `revisor-pagos` antes de escribir una línea (14 hallazgos,
todos adentro), y la forma visual se eligió entre dos maquetas navegables con
los datos de stage: ganó **mostrador**.

## Decisión

### 1. El modelo

| Campo | Quién lo escribe | Regla |
|---|---|---|
| `tipo` | el panel, al crear | `simple` o `compuesto`. Inmutable |
| `stock` | **sólo el servidor** | Unidades de venta. El panel crea con `0`; la reposición llega por callable. Prohibido en un compuesto |
| `precio` | el panel | Centavos de la unidad de venta. Obligatorio en todo `update` |
| `presentacion.botellas` | el panel, al crear | Inmutable: una caja de 2 es otro producto |
| `muestra` | sólo el servidor | Los datos de prueba |
| `fichaVino` | el panel | Obligatoria: `bodegaId`, `varietales` (lista cerrada), `color`, `organico`, `region`, `volumenMl`; `anada` puede faltar |

Las reglas cierran el documento con `keys().hasOnly`, también adentro de cada
mapa, porque `affectedKeys()` no mira adentro de un mapa. La lista de
varietales vive dos veces —en las reglas y en contratos— y CI falla si difieren.

### 2. Lo que se deriva, en contratos

- `esCorte`: dos varietales o más. Ningún documento lo guarda aparte.
- `balde`: `agotado` si `stock ≤ 0`; `quedan-pocas` si `stock × botellas ≤ 6`;
  si no, `disponible`. Los textos viven al lado del cálculo.
- `tope`: `max(0, min(stock, 12))`.
- `armarCatalogo`: la proyección pública, **sin `stock` ni unidades vendidas**.
  Deja afuera, y los reporta, los documentos que no validan, los slugs
  duplicados (los dos), los compuestos y los de una bodega que no existe.
- `parsearCarrito`, `resolverCarrito` y `PedidoDeCompra`, con
  `precioUnitarioVisto`.

### 3. La lectura y la caché

- `server/catalogo.ts` lee los productos publicados, las bodegas y
  `metricas/popularidad`: **P + B + 1 lecturas**, adentro de un `unstable_cache`
  de 60 s por instancia con el tag `catalogo`. Las tres rutas comparten esa
  proyección.
- Las rutas son ISR (`revalidate = 60`) y `expireTime: 360`, así que Next emite
  solo `s-maxage=60, stale-while-revalidate=300`. El `Cache-Control` de una
  página no se puede fijar desde `headers()`: una página dinámica sale con
  `private, no-store` (`node_modules/next/dist/docs/01-app/02-guides/cdn-caching.md`).
- `Cache-Tag` sale de `headers()`: `catalogo` en las tres rutas, y la ficha suma
  `producto-<slug>`.
- **Sin `cacheComponents`**: es un interruptor global, y nada de esto lo
  necesitaba.

### 4. El carrito

- `localStorage` guarda `{ version: 1, idCompra, lineas: [{ productoId,
  cantidad }] }`, sin precio ni nombre. Lo valida `parsearCarrito`; si no
  valida, arranca vacío con un `idCompra` nuevo, y sin `localStorage` vive en
  memoria.
- `/carrito` une las líneas con la proyección de hoy. Si el tope bajó, ajusta
  **y guarda** antes de mostrar el total. Una línea agotada o de un vino que ya
  no está queda marcada y no suma.
- **Sin botón de terminar la compra**: `crearOrden` no existe.

### 5. Cómo se componen las features

`catalogo/` y `carrito/` no se importan entre sí. Es `app/` la que pasa
**elementos** por props: el control de compra de cada vino al listado, el
control a la ficha, la ventana de cada botella al carrito, el contador a la
barra. Un elemento de React cruza del servidor al cliente; una función no.
`Precio`, `papel.css` y `cifras.css` nacen en `shared/ui` porque los usan las
dos features desde el día uno (regla 1).

### 6. Lo visual y los datos de muestra

La forma es la de la maqueta mostrador (`design.md §9`), con los tokens en
[`tokens.md`](../../design/tokens.md) y Archivo para las cifras. La maqueta
traía Libre Franklin, y es el único punto en que la vidriera se aparta de ella:
el archivo que sirve Google no tiene cifras tabulares (medido, `tokens.md §5`). La
siembra (`scripts/seed/`) fija el proyecto y su cuota, usa ids `muestra-*`,
recorta y convierte las fotos con `sharp` y las nombra por hash, rechaza el
placeholder de "Imagen no disponible" por hash, y se borra por la lista de ids,
nunca por query.

### 7. La home hornea su selección — 2026-09-11

Los seis vinos de la escena 2 eran inventados y bloqueaban el deploy
(`LA_SELECCION_ES_DE_MUESTRA`). Ahora salen de esta misma proyección:

- **Se leen al armar el build, sin la caché de 60 s.** `app/page.tsx` llama a
  `leerCatalogoSinCache()`, no a `obtenerCatalogo()`. La home sigue estática:
  `○ /` en la tabla del build y `s-maxage=31536000`, medidos.
- **Los elige `elegirSeleccion`** (`features/landing/seleccion.ts`): ni
  agotados ni cajas —la tarjeta dibuja una botella—, uno de cada color si el
  catálogo lo tiene, y el resto por `puesto` con desempate por id. **Es
  provisoria**: "los elegimos de a uno" pide un dato que el modelo no tiene.
- **Sin precio, campo por campo.** `VinoDeLaSeleccion` no tiene `precio`,
  `balde` ni `tope`: horneado, un precio queda viejo hasta el próximo deploy.
  Lo mide `test/seleccion.test.ts` con la lista exacta de campos.
- **La foto va en una ventana prendida.** La foto de bodega trae fondo blanco y
  el `multiply` sólo lo absorbe contra algo claro: es la receta de la ventana
  del catálogo (papel, `multiply`, `isolation`) adentro del cartucho oscuro.
  Sin foto, vuelve la silueta.
- **Se fue la línea de guarda** ("Acostada desde marzo"): ningún dato del
  producto la sostiene, y `voz.md §6` no deja afirmarla.
- **El gate es el de `/vinos`**, `data-catalogo-de-muestra`, con el spread
  condicional de [ADR 007](007-seccion-el-oficio.md).

#### Por qué existe `leerCatalogoSinCache` (no revertir)

`unstable_cache` con un `revalidate` numérico **le baja el `revalidate` a la
página que lo llama**: el caso `prerender-legacy` de
`next/dist/server/web/spec-extension/unstable-cache.js`. Con `obtenerCatalogo`,
la ruta más visitada de la vidriera pasaría sola a ISR de 60 s y leería
Firestore por visita, sin un error ni un aviso. Está **leído en el código de
Next, no medido** con un build de contraste. `test/revalidacion.test.ts` falla
si la home importa la caché, y busca el `import`, no la palabra: su primera
versión se tropezó con el comentario que la nombra para decir que no la usa.

| Alternativa | Por qué no |
|---|---|
| `obtenerCatalogo()` en la home | La vuelve ISR de 60 s en silencio (arriba) |
| Un segundo `unstable_cache` sin `revalidate` | Según su documentación, la caché de datos de Next persiste "entre pedidos y deploys": sin vencimiento, un build podría hornear un catálogo viejo. No se midió |
| Reusar la tarjeta del catálogo, como pedía [`landing-alternativa.md §10`](../../design/landing-alternativa.md) | Trae el precio y el control de compra, y la home no puede llevar precio. Se reusó la receta de la ventana, no la tarjeta |
| Los seis más vendidos, sin regla de color | Con los datos de stage salen seis tintos |

**Presupuesto de lecturas:** por visita, **0**. Por build, una reconstrucción
más: P + B + 1 = **32 hoy** y **231 con el MVP**, el 0,06 % y el 0,46 % de la
cuota de un día, una vez por deploy.

**Consecuencias:**

- ⚠️ **La selección envejece hasta el próximo deploy.** Un vino que se agota
  sigue en la home (su ficha dice "Se agotó"); uno que se despublica deja una
  tarjeta que da 404. El tramo 4 decide si la home entra a la purga: con su
  `Cache-Tag` y un `revalidatePath('/')` desde el trigger costaría una lectura
  por edición, no por visita.
- Mientras las reglas de Storage no estén publicadas, las seis fotos de la home
  dan 400, igual que las del catálogo.

**Lo que hay que medir:**

| Qué | Cómo | Disparador |
|---|---|---|
| La ventana prendida, en un teléfono | Mirarla con las fotos reales | El deploy de las reglas de Storage |
| El gate apagado | Con un catálogo sin muestra, `grep -o data-catalogo-de-muestra` sobre el HTML de `/` tiene que dar 0. Hoy sólo se midió prendido: **2** | El primer catálogo real |

## Por qué NO las alternativas

| Alternativa | Por qué no |
|---|---|
| `'use cache'` sin vencimiento | Vive por instancia y la purga de Cloudflare no llega: un precio viejo quedaría para siempre en esa instancia |
| Sin caché de datos | Cada página regenerada leería P + B + 1 por su cuenta |
| Un documento `catalogo/publico` | ADR 004: nace con el techo de 1 MB a la vista y cuesta en cada escritura. Se reevalúa en el tramo 4 |
| SSR puro con `Cache-Control` en `headers()` | Next lo pisa en las páginas y sale `private, no-store` |
| `Cache-Tag` por id | La ruta sólo conoce el slug, y un header de `next.config` no puede buscar nada. El trigger de purga tiene el slug de antes y el de después |
| `next/image` | Cobra CPU por transformación en Cloud Run (ADR 005 §5), y la foto ya llega recortada en WebP |
| Una página indexable por cepa (`/vinos/malbec`) | Diferida: cada filtro navegaría en vez de filtrar. Se agrega después con los mismos componentes |
| Deducir "compuesto" por la falta de `stock` | Deja a la venta, con tope 12, un producto mal cargado |
| Que el panel sólo pueda incrementar el stock | La regla ve el documento resultante, no la operación: no distingue un `increment` de un valor absoluto calculado sobre un dato viejo |

## Presupuesto de lecturas

Campo obligatorio.

| | Hoy (20 vinos, 11 bodegas) | MVP (200, 30) |
|---|---:|---:|
| Por reconstrucción | 32 | 231 |
| 100 visitas/día | 3.200 | 23.100 (46 %) |
| 250 visitas/día | 8.000 | 57.750 (**115 %**) |

**Hasta el tramo 4, las lecturas escalan con las visitas**, no con las
ediciones: una visita que abre listado, ficha y carrito en el mismo minuto es
una sola reconstrucción. El contador de la barra y el aviso cuestan **cero**
(salen de `localStorage`). La build suma una reconstrucción por build, porque
prerenderiza `/vinos` y `/carrito`.

## Consecuencias

- ⚠️ **El deploy público necesita el tramo 4** (Cloudflare con TTL largo y
  purga por tag). Sin él, con el catálogo real, la cuota se pasa cerca de las
  220 visitas diarias.
- ⚠️ **Un precio puede quedar hasta ~13 minutos en pantalla con poco tráfico**:
  60 s de datos, la página vencida que Next sirve hasta 360 s mientras la
  regenera, 60 del borde y 300 de `stale-while-revalidate`, este último sólo
  para la primera visita después de un rato. **No se puede cobrar**:
  `crearOrden` va a comparar el precio visto. (Decía 8; lo corrigió
  `revisor-pagos`.)
- **Dependencia nueva en la tienda, `@opentelemetry/api`.** El lockfile tenía la
  `@google-cloud/firestore` 8.7.1 de `firebase-admin` sin esa entrada, y el
  cliente de Firestore no cargaba: `npm install` decía "up to date". Se declaró
  explícita.
- `apps/tienda/tsconfig.json` suma `allowImportingTsExtensions`: la tienda nunca
  había importado contratos, y el primer import no compilaba.
- La build de la tienda **lee Firestore** (prerenderiza `/vinos` y `/carrito`):
  la service account de la build de App Hosting va a necesitar lectura.
- El papel todavía **no** respeta `prefers-color-scheme`, como pide
  `direccion.md §3.2`: la spec pide fondo claro, y un papel oscuro necesita
  tokens propios.
- `fichaVino` pasó a ser obligatoria; el glosario decía opcional y ya lo dice.
- Los compuestos quedan fuera de la vidriera hasta que exista el cálculo de su
  stock.

## Lo que hay que medir antes de creerle a este ADR

| Qué | Cómo | Disparador |
|---|---|---|
| Que la Archivo que sirve `next/font` conserve `tnum` | El ancho de "1111" contra "8888" en el render, con el control proporcional al lado (Libre Franklin falló esta misma medición) | La build final de este cambio |
| La vista de teléfono | Mirarla en un teléfono: el Chrome headless de esta máquina no baja de 504 px | La próxima revisión del dueño |
| La foto pública | Hoy da 400 porque el bucket no tiene reglas publicadas; tiene que dar 200 con `image/webp` | El deploy de las reglas de Storage |
| La purga por `producto-<slug>` | La medición 1 de ADR 005 | El tramo 4 |

## Cuándo esta decisión deja de servir

- El catálogo supera ~1.000 productos o la proyección ~2 MB (ADR 004).
- Entra el primer producto que no es vino.
- Existen las cajas mixtas: el stock de un compuesto sale de sus componentes.

## Lo que queda para `crearOrden`

El marcador `compras/{idCompra}` en la misma transacción que el descuento de
stock; expandir los compuestos y **sumar la demanda por producto** antes de
validar; rechazar `publicado != true`, `muestra == true` en producción y un
`precioUnitarioVisto` que no coincida; guardar en cada ítem el snapshot de
`botellas` y de la composición; y la reserva de slug `slugs/{slug}` cuando exista
el panel.

### Lo que encontró `revisor-pagos` sobre este diff (2026-09-11)

Nada bloquea hoy: sin `crearOrden` no hay forma de cobrar. Probó seis caminos
de ataque en el emulador y midió los bordes de contratos con un script.

**Se arregló en este cambio:** el `idCompra` del carrito del servidor pasaba el
parser, y con un checkout que leyera antes de hidratar todos los compradores
mandarían la misma clave (ahora es uno que el parser rechaza, con test); el
parser aceptaba ids reservados de Firestore (`__x__`); la baranda del seed
comparaba el `projectId` consigo mismo y no podía fallar; `borrar.mjs` borraba
fotos sin mirar `muestra`; y el peor atraso de un precio eran ~13 minutos, no 8.

**Queda para antes de `crearOrden`, con el hallazgo:**

| # | Qué | Escenario |
|---|---|---|
| 1 | Borrar y recrear un producto con el mismo id se saltea la inmutabilidad de `tipo` y `presentacion` | Una botella con stock 10 se recrea como caja de 2; una cancelación repone 6 y quedan 12 botellas a la venta sobre 10 físicas. Salida: que el panel no borre (despublica) o que `crearOrden` guarde y use el snapshot de `botellas`. ⚠️ **2026-09-14: NO lo cierra el `botellas` que ahora guarda el carrito** ([ADR 009](009-venta-por-caja.md) §4). Ese campo existe para el contador de la barra y `resolverCarrito` lo PISA con la proyección a propósito: no es un snapshot. `items[]` sigue necesitando el suyo. Lo que sí cambió es que ahora hay un invariante más que depende de `presentacion.botellas` —el de la caja—, y borrar-y-recrear lo puede mover; falla cerrado (el pedido deja de ser múltiplo y se rechaza), pero la dependencia es nueva |
| 2 | Se puede publicar con `precio: 0` | Pasa las reglas y el validador, y un `precioUnitarioVisto: 0` coincide |
| 3 | Un compuesto sin componentes se puede publicar | Si `balde`/`tope` lo reciben crudo dan `disponible` y `NaN`, y `13 > NaN` es `false`. La vidriera hoy lo excluye |
| 4 | `PedidoDeCompra` no tiene validador | `parsearCarrito` lo rechaza (le falta `version`), así que va a nacer un segundo validador. Tampoco está definido qué pasa con el mismo `idCompra` y otras líneas |
| 5 | El carrito no tiene tope de líneas | 10.000 ids inventados validan: cinco llamadas a `crearOrden` son la cuota del día |
| 6 | Next sirve una página vencida hasta 360 s | Con Cloudflare en TTL largo, una purga puede re-cachear la página vieja hasta la próxima purga. El tramo 4 tiene que invalidar también la caché de Next |
| 7 | Los 24 tests de reglas no corren en CI | Sólo a mano, con el emulador |
| 8 | Reglas y validador no dicen lo mismo | `imagenes: ['gs://…']` o `nombre: '   '` se guardan y la vidriera los descarta sin avisar |
