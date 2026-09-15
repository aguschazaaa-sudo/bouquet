## Why

El vino se despacha en cajas físicas de 6, así que **no se puede vender suelto**:
una botella sola no tiene con qué viajar. Hoy la vidriera deja armar un carrito
de cualquier tamaño y calcula un total que nunca se va a poder despachar.

La restricción tiene que estar dicha **antes de agregar**, no descubrirse en el
carrito: una compra que se entera al final es una compra que se abandona. Y
tiene que entrar **antes que `crearOrden`**, porque después es una regla de
cobro que se agrega sobre un carrito que ya aprendió a mentir.

## What Changes

- **BREAKING** — El carrito deja de poder terminar en cualquier cantidad: para
  poder cobrarse tiene que sumar un **múltiplo de 6 botellas**. Hoy nadie cobra
  (`crearOrden` no existe), así que el cambio no rompe ninguna venta en curso:
  rompe una expectativa que la pantalla todavía no prometió.
- **La cuenta es en BOTELLAS, no en unidades de venta.** `cantidad ×
  presentacion.botellas`. El catálogo de muestra ya tiene **2 productos de 2
  botellas** sobre 20: tres de ésos son una caja completa. Contar unidades daría
  el número equivocado desde el primer día.
- **El comprador arma su caja.** Agrega botellas de a una como hoy; lo que
  cambia es que la vidriera le muestra el avance y le dice cuántas le faltan o
  le sobran.
- **El vendedor ofrece cajas sugeridas.** Una caja sugerida **no es un
  producto**: es una lista de seis `productoId` con un nombre. Al elegirla se
  llena el carrito con esos seis, y desde ahí el comprador los cambia. No tiene
  precio propio, ni stock propio, ni descuento.
- **El documento de `productos` NO se toca.** Ni un campo. Sin `componentes`,
  sin stock derivado, sin índices compuestos nuevos.
- `tipo: 'compuesto'` **se queda sin usar**, reservado para una caja de regalo
  con precio propio. Sacarlo sería la migración que
  [ADR 008](../../../docs/vault/architecture/decisions/008-catalogo-stock-y-carrito.md)
  se ahorró a propósito.
- **Sin descuento, en ninguna de las dos formas.** El precio es siempre la suma
  de lo que hay en el carrito.
- **Un tamaño, una constante.** `BOTELLAS_POR_CAJA = 6`. El día que existan
  cajas de 3, el cambio es esa línea y sus tests.

### Non-goals

- `crearOrden` y el checkout. Este cambio **deja escrita y probada** la
  precondición; cobrarla es la tarea siguiente.
- Descuentos por volumen, de cualquier tipo.
- Cajas de regalo con precio propio (el `compuesto` del modelo).
- Que la home muestre cajas sugeridas. `elegirSeleccion` las sigue dejando
  afuera.
- El panel para cargar cajas sugeridas. `apps/admin` son cinco archivos Dart y
  no tiene pantalla de nada; entran por el seed, como entraron los 20 vinos.

## Capabilities

### New Capabilities

- `venta-por-caja`: la regla de múltiplo de 6 botellas — dónde vive el cálculo,
  qué cuenta, qué NO valida (un carrito a medio llenar es válido) y cuál es la
  precondición que `crearOrden` va a heredar.
- `vidriera-caja-en-curso`: cómo la vidriera comunica la restricción — el aviso
  antes de agregar, el avance en el contador de la barra, y cuántas faltan o
  sobran en el carrito.
- `cajas-sugeridas`: el documento único que las guarda, cómo se lee, el carril
  en `/vinos`, y qué pasa cuando una sugerencia nombra un vino que ya no está.

### Modified Capabilities

<!-- Ninguna: `openspec/specs/` está vacío. Las capacidades que este cambio toca
     -`vidriera-catalogo`, `vidriera-carrito`, `vidriera-ficha`- viven en el
     cambio `catalogo-y-carrito`, que todavía no se archivó, así que no hay
     spec principal contra la cual escribir un delta. Están listadas en Impact. -->

## Impact

**Código**

| Dónde | Qué |
|---|---|
| `packages/contratos/src/carrito.ts` | `BOTELLAS_POR_CAJA`, `botellasEnCarrito`, `estadoDeLaCaja`. **`parsearCarrito` no cambia** |
| `packages/contratos/src/cajas.ts` *(nuevo)* | Validación del documento de cajas sugeridas y su proyección |
| `apps/tienda/src/server/catalogo.ts` | Una lectura más, adentro del `unstable_cache` que ya existe |
| `apps/tienda/src/features/carrito/` | `ContadorDelCarrito`, `PaginaDelCarrito`, `textos.ts` |
| `apps/tienda/src/features/catalogo/` | El carril de cajas sugeridas y el aviso en la ficha |
| `firestore.rules` | La colección nueva: lectura pública, escritura de nadie |
| `scripts/seed/` | Las cajas sugeridas de muestra |

**Specs de cambios sin archivar que este cambio supera:**
`vidriera-catalogo`, `vidriera-carrito` y `vidriera-ficha`, de
`catalogo-y-carrito`. Cuando se archive ése, estas capacidades tienen que
quedar consistentes con las de acá.

**Lecturas de Firestore:** una colección nueva, leída como **un solo
documento**, adentro de la caché que ya envuelve al catálogo: **+1 por
reconstrucción**, que hasta el tramo 4 escala con las visitas, no con los
deploys. **+0,5 puntos de la cuota** en el peor renglón. El cálculo completo, en
`design.md`.

**Deploy:** `reglas` → `tienda`. No toca `functions`.

**Riesgo principal:** que la restricción se comunique tarde. Es el único modo de
falla que convierte esta regla en carritos abandonados, y por eso
`vidriera-caja-en-curso` es una capacidad propia y no un detalle de
implementación.
