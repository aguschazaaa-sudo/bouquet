## Why

El panel tiene puerta desde el 2026-09-16 y está publicado desde el 2026-09-17,
pero **las dos secciones salen vacías y lo dicen**. El hito 1 —que el dueño
cargue su catálogo real— no puede empezar sin dos cosas: un lugar donde ver lo
que hay, y las bodegas, porque `fichaVino.bodegaId` es obligatorio y un vino no
se puede cargar contra una bodega que no existe.

Historias: **HU-02.1 · HU-02.2 · HU-02.3 · HU-02.4** (EP-02 entera) y
**HU-03.1** de [EP-03](../../../docs/vault/features/panel/EP-03-productos.md).

**Por qué HU-03.1 viaja con EP-02 y no con el resto de su épica:** HU-02.4 —no
poder borrar una bodega que tiene vinos— necesita los productos en memoria.
Comprobarlo en las reglas serían `get()` facturados por evaluación, que es
exactamente el costo invisible que
[ADR 008](../../../docs/vault/architecture/decisions/008-catalogo-stock-y-carrito.md)
evita con el custom claim. La baranda vive donde ya están los datos.

## What Changes

- **Normalizar, en `contratos` (ARQUITECTURA §7):** `normalizar`, `clave`,
  `aSlug` y `seParecen`, con fixtures que viajan en `generated/contratos.json`
  y un espejo en Dart que se verifica contra ellas. Hoy la normalización no
  existe en ningún lado compartido: lo único parecido es un slugify inline en
  `apps/tienda/src/features/catalogo/PanelDeFiltros.tsx`.
- **Ver el catálogo entero y buscar (HU-03.1):** todos los productos
  —publicados o no—, con filtro `contains` normalizado **en memoria** y el
  nombre de su bodega resuelto. Sin `autoDispose`.
- **Dar de alta una bodega (HU-02.1):** nombre, y el slug derivado del nombre
  con `aSlug`. La forma queda en `{nombre, slug}`, que es lo que cierran las
  reglas.
- **Avisar de las parecidas (HU-02.2):** antes de guardar, el panel muestra las
  bodegas cuya clave normalizada contiene a la nueva o está contenida en ella
  —"Catena" contra "Catena Zapata"—. **Cero lecturas extra.**
- **Corregir el nombre (HU-02.3):** el nombre se edita; **el slug no cambia**,
  por la misma regla que el de un producto publicado
  ([glosario](../../../docs/vault/domain/glossary.md)). La bodega va a tener
  página indexable.
- **No borrar una bodega con vinos (HU-02.4):** el renglón de una bodega dice
  cuántos vinos tiene, y con uno o más el borrado no se ofrece. Con cero, se
  pide confirmación y **se vuelve a preguntar contra Firestore** antes de
  borrar.

### Lo que este cambio NO hace

- **No da de alta ni edita un vino** (HU-03.2 a HU-03.7). Arrastran dos
  decisiones abiertas: `graduacion`, que entra en `contratos` **y** en las
  reglas, y la reserva `slugs/{slug}` para la unicidad, que ADR 008 dejó
  anotada para cuando existiera el panel.
- **No toca `firestore.rules`.** `productos` y `bodegas` ya tienen `read`,
  `create` y `update` para `esAdmin()`, y `bodegas` no necesita campos nuevos.
  El deploy es sólo front.
- **No cierra el `delete` de bodegas en las reglas.** La baranda es del panel;
  el porqué y el riesgo que queda están en el ADR.
- **No toca la vidriera.** Dejar el slugify de `PanelDeFiltros.tsx` apuntando a
  `contratos` es deuda anotada, no de este cambio: mover eso es un deploy de
  tienda, y la tienda arrastra todo lo mergeado.
- **Fotos (EP-04) y stock (EP-05)**: ninguna de las dos. EP-05 dice que su
  callable y `crearOrden` se diseñan juntas.

## Presupuesto de lecturas

Campo obligatorio (`CLAUDE.md`). Cuota: **50.000 lecturas/día**.

| Qué | Lecturas | Cuándo |
|---|---:|---|
| Catálogo en frío (MVP: 200 productos + 30 bodegas) | **230** | Una vez por sesión |
| Buscar, filtrar, contar vinos por bodega | **0** | Está todo en memoria |
| Ver las parecidas al cargar una bodega (HU-02.2) | **0** | Ídem |
| Alta o edición de una bodega | **1** | El `snapshot` devuelve el documento que acaba de cambiar |
| Borrar una bodega | **1** | La pregunta fresca a Firestore, `limit(1)` |

**Diez sesiones en frío por día son 2.300 lecturas: el 4,6 % de la cuota.** Hoy,
con 20 vinos de muestra, son ~30 por sesión.

⚠️ **El ~200 que dice [ARQUITECTURA §6.3](../../../ARQUITECTURA.md#63-el-presupuesto-completo)
supone que la caché sobrevive entre sesiones, y no sobrevive**: la caché de
Riverpod muere con la pestaña. 230 es el número contra el que hay que medir
(hallazgo 7 del [mapa del panel](../../../docs/vault/features/panel/overview.md)).

**Por qué `snapshots()` y no `get()`:** con `get()` cada navegación entre
secciones puede relee 230 documentos. Con un stream vivo sin `autoDispose`, las
230 se pagan una vez y cada cambio cuesta **una** lectura, la del documento que
cambió. Es más barato y además es correcto: dos personas de la familia cargando
bodegas a la vez se ven.

## Capabilities

### New Capabilities

- `texto-normalizado` — la normalización compartida y sus fixtures.
- `panel-bodegas` — alta, aviso de parecidas, corrección y borrado con baranda.
- `panel-catalogo` — ver todos los productos y buscarlos.
