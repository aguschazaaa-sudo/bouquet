## Why

El panel ya muestra el catálogo y carga bodegas (2026-09-17), pero **un vino
todavía no se puede cargar**: los únicos productos que existen son los 20 de
muestra que escribió el seed. El hito 1 —que el dueño cargue su catálogo real
sin pedirle nada al desarrollador— empieza acá, y todo lo que falta del hito
(fotos, stock, publicar) necesita que el vino **ya exista**.

Historias: **HU-03.2 · HU-03.3 · HU-03.4** de
[EP-03](../../../docs/vault/features/panel/EP-03-productos.md).

**Por qué estas tres juntas:** son **un solo formulario**. HU-03.3 es un campo
de HU-03.2 —las botellas por unidad— con su aviso de que no tiene vuelta
atrás, y HU-03.4 es el mismo formulario abierto sobre un vino que ya existe.
Separarlas serían tres deploys de la misma pantalla.

## What Changes

- **Dar de alta un vino (HU-03.2):** nombre, bodega elegida de la lista (con
  el atajo para cargar una que falta), varietales de la **lista cerrada**,
  color, orgánico, región, añada opcional, volumen, **graduación** opcional y
  precio escrito en pesos. Nace con `publicado: false`, `stock: 0`,
  `tipo: 'simple'` e `imagenes: []`, escritos siempre por una única factory.
- **El id del producto es su slug, y las reglas lo exigen.** Un vino nuevo se
  guarda en `productos/{slug}`, y Firestore garantiza la unicidad sin ninguna
  lectura extra. **Reemplaza la reserva `slugs/{slug}`** que
  [ADR 008](../../../docs/vault/architecture/decisions/008-catalogo-stock-y-carrito.md)
  había dejado anotada para cuando existiera el panel.
- **`graduacion` entra al modelo** (glosario: *"entra con el panel"*):
  `fichaVino.graduacion`, opcional, **entero en décimas de grado** —13,5 % es
  `135`—, en `contratos` y en `firestore.rules`.
- **El precio se escribe como lo escribe un argentino** —`12.500`,
  `12.500,50`— y se guarda como entero en centavos. Lo ambiguo (`12.50`) no se
  adivina: se pregunta.
- **Un producto que viene en su propia caja (HU-03.3):** las botellas por
  unidad se eligen al crear. La pantalla dice **siempre, antes de guardar**,
  que no se cambian después, y pide confirmación cuando es una caja.
- **Corregir un vino (HU-03.4):** el mismo formulario sobre un vino existente.
  Viaja **sólo lo que cambió**; los varietales, con `arrayUnion`/`arrayRemove`.
  Las botellas, el tipo y la dirección se muestran fijos. El precio se corrige
  **mientras el vino no está en la tienda**.
- **Las reglas se endurecen:** `slug == productoId` al crear, y el `slug` no
  cambia en un `update`.
- **Los varietales viven tres veces** —reglas, `contratos` y ahora el panel—
  y `auditar_varietales.mjs` pasa a comparar las tres.
- **Catálogo tiene puertas nuevas:** un botón para cargar un vino, y el renglón
  de cada vino pasa a ser tocable y abre su corrección.

### Lo que este cambio NO hace

- **No publica ni despublica** (HU-03.6), **no cambia el precio de un vino que
  está en la tienda** (HU-03.5) y **no dice por qué un vino no aparece**
  (HU-03.7). Las dos primeras son Workflow D, y las tres necesitan el espejo
  en Dart de `validarProducto` y del balde: van juntas en el próximo change.
- **No sube fotos** (EP-04): el recorte a WebP necesita su propio ADR.
- **No toca el stock** (EP-05): su callable se diseña junto con `crearOrden`.
- **No borra productos.** El panel nunca lo va a hacer (hallazgo 1 de
  `revisor-pagos`, ADR 008).
- **No carga compuestos**: el `tipo` existe y no se usa (glosario).
- **No agrega `descripcion`.** HU-03.4 la nombra, pero **el modelo no la
  tiene**: ni `contratos`, ni las reglas —que cierran el documento con
  `hasOnly`—, ni la ficha de la vidriera. Es un campo nuevo en tres lugares y
  la historia se escribió suponiendo que existía.
- **No toca la vidriera.** `graduacion` entra en `contratos`, pero la ficha no
  la muestra todavía: hacerlo es un deploy de tienda, y la tienda arrastra todo
  lo mergeado.

## Presupuesto de lecturas

Campo obligatorio (`CLAUDE.md`). Cuota: **50.000 lecturas/día**.

| Qué | Lecturas | Por qué |
|---|---:|---|
| Abrir el formulario, elegir bodega, ver regiones y slugs ocupados | **0** | Sale del catálogo que ya está en memoria (HU-03.1) |
| Alta de un vino | **2** | La transacción lee `productos/{slug}` antes de escribir, y el stream trae el documento nuevo |
| Corrección de un vino | **1** | El stream trae el documento que cambió |
| Las reglas nuevas | **0** | `slug == productoId` no necesita `get()`. La reserva `slugs/{slug}` con `getAfter()` habría costado una lectura facturada por evaluación |

**Cargar los 200 vinos del MVP cuesta ~400 lecturas, una sola vez: el 0,8 % de
la cuota de un día.** El uso diario no cambia: corregir un vino cuesta una.

## Capabilities

### New Capabilities

- `panel-vino`: dar de alta un vino, uno que viene en su propia caja, y
  corregirlo desde el panel (HU-03.2, HU-03.3, HU-03.4), con las puertas desde
  Catálogo.

### Modified Capabilities

- `catalogo-producto`: se le **agregan** requisitos —el id es el slug y el slug
  no cambia; `graduacion` opcional en décimas—. La capability la define el
  change `catalogo-y-carrito`, que **todavía no está archivado**, así que no
  existe en `openspec/specs/` y el delta va como `ADDED`.

## Impact

- **`packages/contratos`:** `FichaVino.graduacion` y su validación. Nada más
  se mueve; `proyectarProducto` no la proyecta todavía.
- **`firestore.rules`:** `fichaValida` acepta `graduacion`; `productos` exige
  `slug == productoId` al crear y el slug fijo al actualizar. Casos nuevos en
  `scripts/reglas/productos.test.mjs`. **Deploy de reglas antes que el panel.**
- **`scripts/ci/auditar_varietales.mjs`:** compara también la lista del panel.
- **`apps/admin`:** la ficha entera en `ProductoDelPanel`; el borrador del vino
  con su validación (Dart puro, con tests); los parsers de precio y graduación;
  `crear` y `corregir` en el repositorio; el formulario, sus rutas
  (`/catalogo/nuevo`, `/catalogo/vinos/:id`) y las puertas desde
  Catálogo. `HojaDeBodega.mostrar` devuelve la bodega creada.
- **Los vinos de muestra no se tocan.** Tienen id `muestra-<slug>`, así que un
  vino real con el mismo nombre **no choca en la base**; el formulario avisa, y
  el choque de verdad —dos publicados con el mismo slug— lo decide HU-03.6.
- **Deploy:** reglas → panel. Sin functions, sin tienda.
