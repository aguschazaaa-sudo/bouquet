## Why

`/vinos` es un `PaginaEnObra`: la barra y los dos CTA de la home apuntan a un
catálogo que no existe, y las seis tarjetas de la home, a fichas que dan 404.
Sin catálogo no hay nada que vender. Y el modelo de stock tiene que quedar bien
**antes** de que existan `crearOrden` y las cajas que el dueño ya anunció: lo
que se decida mal hoy se paga con una migración sobre datos reales.

## What Changes

- **Modelo de `Producto` en `packages/contratos`:** `tipo` simple o compuesto
  (inmutable), `stock` en unidades de venta y escrito sólo por el servidor,
  `presentacion.botellas` inmutable (una caja de 2 es un producto distinto),
  `fichaVino.color`, `fichaVino.organico` y varietales de una lista cerrada.
  Cepa o corte se deduce. Salen de ahí el balde, el tope y la proyección
  pública **sin stock**, y también `parsearCarrito` y el tipo `PedidoDeCompra`
  (con `idCompra` y el precio que vio el comprador) que va a recibir
  `crearOrden`.
- **BREAKING (reglas):** el `update` de `productos` deja de permitir borrar
  `precio`, `publicado` e `imagenes`, y el panel ya no puede escribir `stock`
  ni `muestra`. No rompe a nadie: el panel todavía no existe.
- **Colección nueva `metricas/popularidad`:** un documento, que se recalcula
  entero y nunca se acumula. `bodegas` pasa a tener datos.
- **`server/catalogo.ts`:** una sola proyección por reconstrucción (P + B + 1
  lecturas), con caché de datos de 60 s, `s-maxage=60` y `Cache-Tag`.
  `firebase-admin.ts` pasa a ADC con `projectId` explícito, y `.env.example`
  pierde el mecanismo de revalidación de ADR 004, que ADR 005 reemplazó.
- **`/vinos`:** hasta 3 vinos por fila, filtros por color, cepa o corte y
  orgánico, y orden por precio, nombre y popularidad. La popularidad no
  aparece si no hay métricas. Todo corre en el navegador, y lo agotado va al
  final.
- **`/vinos/[slug]`:** la ficha, oscura arriba y clara abajo, con agregar al
  carrito hasta el tope.
- **`/carrito`:** en `localStorage`, `{version, idCompra, lineas}` y sin
  precio. El ajuste al tope se guarda, lo agotado no suma y el contador vive
  en la barra. **Sin botón de terminar la compra.**
- **El primer modo papel:** los tokens claros y la grotesca de cifras
  (`direccion.md §12`), más `docs/vault/design/tokens.md`, que sigue sin
  existir.
- **Datos de muestra en stage** (`scripts/seed/`): 20 vinos argentinos de gama
  media, sus bodegas, la popularidad simulada y las fotos en Storage.
  Re-ejecutable, se borra por la lista de ids que escribió, y se niega a
  correr fuera de `bouquet-vinos`.
- **La forma visual se elige** entre dos maquetas navegables (cava y
  mostrador), antes del primer componente.

### Lo que este cambio NO hace

- `crearOrden`, el checkout, `zonas`, `/orden/[numero]` ni la reposición de
  stock por callable: van a la próxima sesión, y con ellas el marcador
  `compras/{idCompra}`.
- El trigger de purga `revalidarVidriera`, que es el tramo 4. **Es requisito
  del deploy público con el catálogo real**: sin él, las lecturas escalan con
  las visitas y la cuota se pasa cerca de las 220 visitas diarias.
- Las cajas mixtas: el modelo las deja previstas (`tipo: 'compuesto'`), pero
  no se crea ninguna.
- La home: sus seis tarjetas siguen apuntando a slugs de muestra.

## Capabilities

### New Capabilities

- `catalogo-producto`: el modelo de Producto, sus reglas de Firestore y los
  derivados que viven en `contratos` (balde, tope, proyección, parser del
  carrito, pedido de compra).
- `vidriera-catalogo`: `/vinos`, con filtros, orden, estados de stock y la
  caché de la proyección.
- `vidriera-ficha`: `/vinos/[slug]`.
- `vidriera-carrito`: el carrito en `localStorage`, el tope, el total y el
  contador de la barra.
- `datos-de-muestra`: la siembra de stage y las fotos en Storage.

### Modified Capabilities

Ninguna: `openspec/specs/` está vacío.

## Impact

- **`packages/contratos`:** módulos nuevos de producto y de carrito.
- **`firestore.rules`:** `productos` endurecido, más `bodegas` y `metricas`.
  `storage.rules` no cambia. El bucket por defecto **ya existe**
  (`bouquet-vinos.firebasestorage.app`, `southamerica-east1`, creado el
  2026-09-10).
- **`apps/tienda`:** `server/catalogo.ts` y `server/firebase-admin.ts`; las
  features nuevas `catalogo/` (listado y ficha) y `carrito/`; `navegacion/`
  (`EnlaceCarrito` recibe el contador); las rutas `app/vinos`,
  `app/vinos/[slug]` y `app/carrito`; los tokens del modo papel y una tercera
  familia tipográfica en el layout.
- **`scripts/`:** `seed/`, y un chequeo de CI que compara la lista de
  varietales de las reglas con la de `contratos`.
- **`docs/vault/`:** ADR 008, `design/tokens.md` y `_index.md`.
- **Dependencias:** ninguna nueva (`sharp` y `firebase-admin` ya están).
- **Deploy:** reglas de Firestore y de Storage a stage. La tienda sigue
  bloqueada por los gates que ya existían.
