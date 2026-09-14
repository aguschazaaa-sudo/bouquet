## Context

`/vinos` y `/carrito` son `PaginaEnObra`. `productos` está vacío, no hay
functions y el panel no existe. El proyecto `bouquet-vinos` funciona como
**stage**, con plan Blaze, y el bucket por defecto se creó el 2026-09-10 en
`southamerica-east1`.

El diseño se aprobó en conversación con el dueño y después pasó por
`revisor-pagos`, que es obligatorio porque el cambio toca stock y precio. Sus
14 hallazgos están incorporados abajo; siete cambiaron el modelo, y el dueño
los aprobó.

**Restricciones que no se negocian:** ADR 004 (la vidriera no lee Firestore por
visitante y filtra en memoria), ADR 005 (SSR con caché de borde purgada por
tag), ADR 006 (feature-first y las cinco reglas de `shared/`),
`direccion.md §3, §6 y §7`, `voz.md §6 y §9`, y los hooks `widget-size-guard`,
`one-widget-per-file`, `no-hardcoded-colors`, `frontera-features` y
`server-only-guard`.

## Goals / Non-Goals

**Goals:**

- Un catálogo que se pueda recorrer, filtrar y ordenar, con datos reales de
  stage y fotos en Storage.
- Un modelo de stock que no haya que migrar cuando lleguen `crearOrden`, la
  reposición y las cajas.
- El carrito completo hasta el total, sin nada que se pueda cobrar.
- El primer modo papel y `tokens.md`.

**Non-Goals:**

- `crearOrden`, checkout, `zonas`, `/orden/[numero]`, reposición por callable.
- El trigger de purga (tramo 4) y el deploy público.
- Cajas mixtas y búsqueda de texto.

## Decisions

### 1. Una sola proyección, con caché explícita

`server/catalogo.ts` lee `productos` con `where('publicado', '==', true)`,
`bodegas` entera y `metricas/popularidad`: **P + B + 1 lecturas por
reconstrucción**. La consumen `/vinos`, `/vinos/[slug]` y `/carrito`.

| Capa | Qué | TTL |
|---|---|---|
| Datos de Next | La proyección, en memoria por instancia | **60 s**, nunca sin vencimiento |
| Origen | `Cache-Control: public, s-maxage=60, stale-while-revalidate=300` y `Cache-Tag` | 60 s |
| Cloudflare | TTL largo con purga por tag | **Apagado** hasta el tramo 4 |

**El mecanismo de Next 16 (decidido en apply, tarea 4.2):** el modelo previo a
Cache Components, sin tocar `cacheComponents`.

- **Datos:** `unstable_cache(leerCatalogo, ['catalogo'], { revalidate: 60,
  tags: ['catalogo'] })` en `server/catalogo.ts`. Las tres rutas comparten una
  proyección por instancia y por minuto.
- **Páginas:** ISR con `export const revalidate = 60`. Next arma solo el
  `Cache-Control` de una página ISR, `s-maxage={revalidate},
  stale-while-revalidate={expire − revalidate}` (`02-guides/cdn-caching.md`), y
  `expireTime: 360` en `next.config.ts` lo deja en `s-maxage=60,
  stale-while-revalidate=300`. Una página dinámica sale con `private,
  no-store`, y el `Cache-Control` de una página no se puede fijar desde
  `headers()`: por eso ISR y no SSR puro.
- **`Cache-Tag`:** desde `headers()` de `next.config.ts`. La ficha lleva
  `producto-<slug>`, no `producto-<id>`: la ruta sólo conoce el slug, y el
  trigger de purga tiene los dos slugs (antes y después) si cambia.
- **Descartado, `cacheComponents` + `'use cache'`:** es un interruptor global y
  la documentación lo exige para `'use cache'`; no hacía falta para nada de
  este cambio.

⚠️ **Dos diferencias con lo escrito antes de medir:** el header sale sin
`public` (Next no lo emite, y `s-maxage` ya habilita las cachés compartidas), y
el atraso máximo de un precio en pantalla no son "unos 2 minutos" sino hasta
~13 con poco tráfico: datos 60 s + la página vencida, que Next sirve hasta 360 s
mientras la regenera + borde 60 s + `swr` 300 s (decía 8; lo corrigió
revisor-pagos). Sigue sin poder cobrarse: `crearOrden` compara el precio visto.

- **Alternativa descartada, `'use cache'` sin vencimiento:** la purga de
  Cloudflare no llega a esa capa, así que un precio quedaría viejo para
  siempre (hallazgo 6). La documentación de Next confirma que vive por
  instancia (`use-cache.md`, *runtime caching considerations*).
- **Alternativa descartada, sin caché de datos:** cada render leería P + B + 1.
- **Alternativa diferida, un documento `catalogo/publico`:** bajaría la
  reconstrucción a 1 lectura. ADR 004 lo descartó por el techo de 1 MB y el
  costo de mantenerlo en cada escritura. Se reevalúa en el tramo 4.

### 2. Filtros y orden en el navegador

Lo eligió el dueño (opción A). La página no lee `searchParams`, así que hay una
sola entrada de caché, y el estado vive en la URL por `replaceState`.

- **Alternativa diferida, páginas por categoría indexables**
  (`/vinos/malbec`): suman SEO, pero cada filtro navega en vez de filtrar.
  Se pueden agregar después con los mismos componentes.

### 3. Dos features, y `app/` compone el carrito con slots

`features/catalogo/` tiene el listado **y** la ficha, porque son el mismo
dominio y así comparten tarjeta, precio y balde sin importarse.
`features/carrito/` tiene el estado, las líneas y el contador. La ficha y la
barra necesitan piezas del carrito, y ADR 006 prohíbe el import entre features.
Por eso **`app/` las compone con slots**: `app/vinos/[slug]/page.tsx` le pasa a
la ficha el control de agregar, y `app/layout.tsx` le pasa a la barra el
contador.

- **El texto del balde** (*Quedan pocas*, *Se agotó*) va a `contratos`, junto al
  cálculo, igual que los rótulos de la Orden ya viven en `proyeccion.ts`.
- **`Precio`** nace en `shared/ui/` porque lo importan las dos features desde
  el día uno: la regla 1 ya está satisfecha, igual que pasó con
  `PaginaEnObra`. Va en un commit propio y no conoce vino, sólo centavos.
- **Alternativa descartada, `shared/carrito/`:** rompe la regla 5, porque
  `shared/` no sabe de productos.
- **Alternativa descartada, un import relativo entre features:**
  `frontera-features.sh` no lo ve, y justamente por eso no se usa.

### 4. El modelo de stock (hallazgos 1, 4 y 7)

`tipo` explícito e inmutable; `stock` en la raíz, en unidades de venta y
escrito sólo por el servidor; `presentacion` inmutable. Una caja de 2 es un
producto con su propio inventario. El compuesto futuro no tiene stock: lo
deriva de sus componentes simples, sin anidar, con un `componenteIds[]` plano
para el trigger.

- **Alternativa descartada, que el panel sólo pueda incrementar:** la regla ve
  el documento resultante, no la operación, así que no distingue un
  `increment(10)` de un valor absoluto calculado sobre un dato viejo.
- **Alternativa descartada, deducir "compuesto" por la falta de `stock`:**
  deja a la venta, con tope 12, un producto mal cargado.

### 5. Balde, tope y lo que llega al navegador

Balde en botellas (6 o menos es *quedan pocas*); tope `max(0, min(stock, 12))`
en unidades de venta. **Debajo de 12 el tope es el stock exacto y llega al
navegador.** Se acepta porque la pantalla nunca lo afirma y `crearOrden` valida.
La proyección excluye los documentos que no validan y los slugs duplicados.

### 6. El carrito no guarda precios, pero el pedido sí lleva el que se vio

`{ version: 1, idCompra, lineas }`. El `idCompra` es la clave de idempotencia
de `crearOrden` (hallazgo 2), y `PedidoDeCompra` lleva `precioUnitarioVisto`
para rechazar en vez de cobrar otro monto (hallazgo 5). Los dos tipos se
definen acá y los consume la próxima sesión.

### 7. La popularidad

Un documento recalculado, nunca acumulado (hallazgo 9). La vidriera recibe el
puesto, y sin métricas el orden por popularidad no se ofrece. En stage lo
escribe el seed con `simulada: true`.

### 8. La siembra

`projectId` explícito, porque gcloud apunta hoy a `red-social-ryb3mf` y la
cuota de las credenciales a `quiz-hoot-7ymbj0` (medido). Ids deterministas, las
fotos nombradas por hash, y el borrado por la lista de ids. Las fotos salen de
`scratchpad/fotos/` (elegidas mirando una hoja de contacto) y se copian a
`scripts/seed/fotos/`, que **no se commitea**.

### 9. Lo visual: mostrador (elegida por el dueño el 2026-09-11)

Hubo dos maquetas navegables con los datos y las fotos de stage: **cava** (la
ceremonia y la luz) y **mostrador** (la función). El dueño las comparó y eligió
mostrador, "por mucho". Queda fijado:

| Qué | Decisión |
|---|---|
| Orden por defecto | **Precio, de menor a mayor.** No depende de métricas, así que no cambia si la popularidad desaparece. Lo agotado va al final en cualquier orden |
| Grotesca de cifras | **Archivo** (Omnibus-Type, Buenos Aires), por `next/font` y sólo en números. La maqueta traía Libre Franklin, pero el archivo de Google no tiene `tnum`: medido en apply, "1111" y "8888" miden distinto con cifras tabulares. Archivo las iguala. Es el único punto en que la vidriera se aparta de la maqueta elegida |
| La palabra | **Corte**, no *blend*: la eligieron las dos lentes por separado y es la del glosario. `voz` la confirma |
| Comprar | Un toque desde la tarjeta: `Agregar` se vuelve el selector de cantidad. El `+` no pasa el tope y no lo nombra |
| Filtros | El color, en pestañas con su cuenta arriba de la grilla. Cepa, corte y orgánico, en una hoja que sube desde la barra del pulgar; desde 1100 px, en una columna fija |
| El aviso | Una línea (`role="status"`) que dice qué pasó, con `Ver el carrito`. No es un toast (`direccion.md §6`) |
| Fotos | Ventana de papel cálido con `multiply`. El recorte al borde de la botella lo hace el seed (`sharp().trim()`), no el navegador: lo pidieron las dos lentes |
| Papel | Los tokens de la maqueta, en `tokens.md`. Sobre papel, el dorado es sólo línea |

**Cómo se compone sin romper ADR 006** (amplía la decisión 3): la tarjeta y la
ficha son de `catalogo/`; el control de compra, el contador y el aviso son de
`carrito/`. `app/` las junta pasando **elementos** por props:
`app/vinos/page.tsx` arma `controles = { [id]: <ControlDeCompra …/> }` y el
listado, que es cliente, pone `controles[id]` en cada tarjeta. Un elemento de
React cruza del servidor al cliente; una función no. Con la misma forma,
`app/carrito/page.tsx` le pasa al carrito la ventana de cada botella.

**Se descartó de la maqueta, a propósito:** la barra en modo papel sobre
`/carrito`. Tocaba `navegacion/`, que tiene cambios del dueño sin commitear, y
la barra sigue siendo cava en todas las rutas.

## Risks / Trade-offs

- **[Cuota] Hasta el tramo 4, las lecturas crecen con las visitas** → con 200
  vinos se pasa la cuota cerca de las 220 visitas por día (ver la tabla).
  Mitigación: el tramo 4 es requisito del deploy público con el catálogo real,
  y mientras tanto se puede subir el TTL de datos sin riesgo de cobro.
- **[Precio viejo] Hasta ~13 minutos en pantalla con poco tráfico** (ver §1)
  → no se puede cobrar: `crearOrden` rechaza si el precio visto no coincide.
- **[Stock] El tope filtra el stock exacto por debajo de 12** → aceptado (ver
  la decisión 5).
- **[Fotos] Baja resolución (Portillo, 173×438) y recortes cerrados (Callia)**
  → quedan como estados reales que el diseño tiene que aguantar.
- **[Next] `cacheComponents` es un interruptor global** → sólo se activa si la
  build demuestra que no cambia las rutas existentes.
- **[Hooks] Componentes de más de 200 líneas** → la grilla, los filtros y la
  ficha se parten desde el principio.

**Presupuesto de lecturas** (campo obligatorio del ADR):

| | Hoy (20 vinos, 12 bodegas) | MVP (200, 30) |
|---|---:|---:|
| Por reconstrucción | 33 | 231 |
| 100 visitas/día | 3.300 | 23.100 (46 %) |
| 250 visitas/día | 8.250 | 57.750 (**115 %**) |

## Migration Plan

Greenfield: no hay datos que migrar. El orden:

1. Desplegar las reglas de Firestore y de Storage a stage.
2. Correr el seed.
3. Verificar la tienda en una build de producción local (`next build` +
   `next start`) contra stage.

El deploy de la tienda sigue bloqueado por los gates que ya existían. Para
volver atrás: el script de borrado y un redeploy de las reglas anteriores.

## Open Questions

- El orden por defecto, la grotesca y los tokens de papel: salen de la maqueta
  elegida.
- *Blends* o *cortes* en pantalla: el dueño dijo "blends" y el glosario dice
  "corte". Lo resuelve el agente `voz`.
- Fraunces o Bodoni Moda (`direccion.md §12`): se mantiene Fraunces salvo que
  el dueño quiera verlo.
