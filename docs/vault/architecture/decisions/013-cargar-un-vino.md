# ADR 013 — Cargar y corregir un vino desde el panel

- **Fecha:** 2026-09-18
- **Estado:** aceptada y **aplicada en el código**. Reglas y panel **sin
  desplegar** todavía: ver *Lo que hay que medir*
- **Decide:** cómo se garantiza que el slug de un producto no se repita, cómo
  entra `graduacion` al modelo, cómo se lee un precio escrito a mano, cómo se
  corrigen los varietales sin reescribir la lista, y qué se confirma al cargar
- **Historias:** HU-03.2 · HU-03.3 · HU-03.4
  ([EP-03](../../features/panel/EP-03-productos.md))
- **Toca:** [ADR 008](008-catalogo-stock-y-carrito.md) (reemplaza la reserva
  `slugs/{slug}` que dejó anotada) y [ADR 012](012-el-catalogo-del-panel.md)
  (mismo patrón de id igual al slug que las bodegas)
- **Hace cumplir:** `firestore.rules` (con 12 casos nuevos en
  `scripts/reglas/productos.test.mjs`), `scripts/ci/auditar_varietales.mjs`
  —ahora compara tres copias— y los tests de Dart del panel
- **Planificación:** `openspec/changes/panel-cargar-un-vino/`

## Contexto

El panel veía el catálogo y cargaba bodegas, pero **un vino no se podía
cargar**: los únicos productos eran los 20 de muestra del seed. Todo lo que
falta del hito 1 —fotos, stock, publicar— necesita que el vino ya exista.

Tres cosas estaban abiertas desde antes: la unicidad del slug (ADR 008 anotó
una reserva `slugs/{slug}` "para cuando exista el panel"), `graduacion` (el
glosario decía *"entra con el panel"*) y cómo escribe un precio una persona.

## Decisión

### 1. El id del producto es su slug, y las reglas lo exigen

```
create: … && request.resource.data.slug == productoId
update: … && request.resource.data.slug == resource.data.slug
```

Firestore no deja que dos documentos compartan id, así que **la unicidad la da
la base por construcción**. El alta va en una transacción que se niega si el
documento existe, igual que las bodegas (ADR 012 §6).

| Alternativa | Por qué no |
|---|---|
| La reserva `slugs/{slug}` de ADR 008 | Una colección más, reglas con `getAfter()` —una lectura **facturada por evaluación**, el costo invisible que ADR 008 evita con el claim— y nadie que borre la reserva de un slug que cambió |
| Id aleatorio + chequeo en memoria | Deja abierta la carrera entre dos personas de la familia; dos publicados con el mismo slug quedan **afuera los dos** de la vidriera, sin error |
| Id aleatorio + transacción sobre una query | Las transacciones del SDK cliente no bloquean una query |

**Lo que se paga:** el slug queda fijo **desde el alta**, no desde la
publicación como decía el glosario. Se mitiga mostrando la dirección mientras
se escribe el nombre.

**Los de muestra** tienen id `muestra-<slug>`: no chocan con un vino real en
la base, sí en la vidriera y sólo si los dos se publican. El formulario
**avisa y deja guardar**; con un vino real, **frena**.

⚠️ **Lo que las reglas NO frenan, escrito como tripwire.** Un `set()` sobre un
vino que existe es un `update` para las reglas. Si el vino tiene stock, rebota
por la regla del stock; **si no tiene, pasa**. Lo que lo impide es la
transacción del panel. `productos.test.mjs` tiene el caso que lo afirma: si
alguien endurece las reglas, falla y hay que volver acá.

### 2. `graduacion`: entero en décimas, entre 50 y 250

`fichaVino.graduacion`, opcional como la añada. 13,5 % se guarda `135`.

- **Entero**, por la misma razón que el precio: un `14.0` de Dart y un `14` de
  JS se guardan distinto en Firestore, y `is int` rechazaría uno de los dos.
- **El piso en 50 no describe a los vinos: atrapa la unidad equivocada.** Un
  `14` pensado como 14 % valdría 1,4 % y rebota; `13.5` no es entero; `1350`
  pasa el techo. Cada confusión posible rebota — se probó cada una contra el
  emulador.
- ⚠️ **Un vino sin alcohol no tiene graduación que le quepa.** Hoy no hay
  ninguno; si aparece, va sin el campo.

Los dos números viven **tres veces** —`contratos`, reglas y panel— y
`auditar_varietales.mjs` los compara.

### 3. El precio se lee en formato argentino, y lo ambiguo se pregunta

`leerPesos` en Dart: `12.500` y `12.500,50` se leen; `12.50` **no se adivina**
—¿12,50, o 12.500 con un cero que se perdió?— y el campo lo pregunta. Se
parsea como texto, nunca `double * 100`.

**No es `desdePesos` de `contratos`**: aquél lee `19.99` como diecinueve con
noventa y nueve —el formato de un archivo—, y un argentino escribe `12.500`
para doce mil quinientos. Sólo el panel lee un precio tipeado por una persona.

**La unidad externa:** debajo del campo se ve el precio con `enPesos`, el
espejo de `formatearARS` verificado contra las fixtures del TypeScript.

### 4. El formulario es un borrador en Dart puro

`BorradorDeVino.revisar(catalogo)` devuelve los problemas por campo, el alta o
los cambios. **Es la única fuente de "¿se puede guardar?"**, y tiene tests con
`dart test`, que sí corre en esta máquina. El widget no decide nada.

Los cambios se comparan contra el vino **como se abrió**: lo que otra persona
corrigió mientras tanto en otro campo no viaja y no se pisa.

**La factory del documento vive en `data/documento_del_vino.dart` sin
Firebase adentro**, para que un test la compare contra los `hasAll`/`hasOnly`
**leídos de `firestore.rules`**: la unidad externa, no una lista copiada.

### 5. Los varietales: un batch con `arrayUnion` y `arrayRemove`

ARQUITECTURA §5.3 prohíbe reescribir la lista, y un mismo `update` no puede
llevar las dos operaciones sobre el mismo campo. Van en un `WriteBatch` con dos
`update` al mismo documento.

**Medido en el emulador, no supuesto:** se temía que las reglas evaluaran el
estado intermedio y que reemplazar el único varietal (sacar Malbec, poner
Syrah) pasara por una lista vacía. **Las reglas ven el estado final del batch**:
los dos órdenes se aceptan. El control: quitar el último varietal solo **se
rechaza**, así que las reglas sí miraron la lista.

### 6. Qué se confirma, y qué se corrige

- **Las botellas por unidad** se eligen al crear y la pantalla dice siempre
  que no se cambian. **Se confirma sólo una caja**: es la que cambia qué
  significa cada unidad de stock y la saca de la caja de seis. Confirmar la
  botella suelta en cada uno de los 200 vinos del MVP no evita ninguna pérdida
  (criterio 2 del [mapa del panel](../../features/panel/overview.md)).
- **El precio se corrige sólo con el vino fuera de la tienda.** Publicado,
  nunca llegó a un comprador; publicado, es HU-03.5 (Workflow D). ⚠️ **La
  restricción es del panel, no de las reglas**, igual que el slug de la bodega.
- **El alta es una página con URL** (`/catalogo/nuevo`), no una hoja: son diez
  campos. **No `/catalogo/vinos/nuevo`**: un vino llamado "Nuevo" quedaría
  tapado.

## Presupuesto de lecturas

Cuota: **50.000/día**.

| Qué | Lecturas |
|---|---:|
| Abrir el formulario, bodegas, regiones sugeridas, direcciones ocupadas | **0** — el catálogo en memoria |
| Alta | **2** — la transacción + el documento nuevo por el stream |
| Corrección | **1** — el documento que cambió |
| Las reglas nuevas | **0** — ningún `get()` |

**Cargar los 200 vinos del MVP: ~400 lecturas, una vez. El 0,8 % de un día.**

## Consecuencias

- ⚠️ **HU-03.4 nombra "la descripción" y el modelo no la tiene.** Ni
  `contratos`, ni las reglas —que cierran con `hasOnly`—, ni la ficha de la
  vidriera. Es un campo nuevo en cuatro lugares. Pregunta para el dueño.
- **El glosario cambió:** el slug es fijo desde el alta, y `graduacion` existe.
- **`auditar_varietales.mjs` audita más de lo que dice su nombre**: la lista
  del panel, su orden, y el rango de la graduación. Se mantuvo el nombre por lo
  mismo que ADR 012 mantuvo el de `auditar_estados.mjs`.
- **La vidriera no muestra la graduación todavía.** Hacerlo es un deploy de
  tienda, y la tienda arrastra todo lo mergeado.
- La suite de reglas se adaptó entera: **toda alta pasa por `alta()`**, que usa
  el slug como id. Con otro id, un `assertFails` pasaría por el slug y no por
  lo que el caso dice probar.

## Lo que hay que medir antes de creerle a este ADR

| Qué | Cómo | Disparador |
|---|---|---|
| Las reglas publicadas | API de Rules: el ruleset vigente contiene `slug == productoId` y `graduacionValida` | El deploy de reglas |
| El formulario, renderizado | Que alguien cargue un vino de verdad y lo mire: nadie lo vio compilado todavía | El deploy del panel |
| El `DropdownMenu` de bodegas en un teléfono | Filtrar escribiendo con el teclado abierto | La primera carga desde el teléfono |
