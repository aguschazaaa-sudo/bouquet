# ADR 012 — El catálogo del panel y las bodegas

- **Fecha:** 2026-09-17
- **Estado:** aceptada y **aplicada en el panel**
- **Decide:** dónde vive la normalización de texto, cómo lee el panel el
  catálogo y con qué caché, y dónde vive la baranda que impide despublicar
  vinos sin querer
- **Historias:** HU-02.1 · HU-02.2 · HU-02.3 · HU-02.4 · HU-03.1
  ([EP-02](../../features/panel/EP-02-bodegas.md),
  [EP-03](../../features/panel/EP-03-productos.md))
- **Toca:** [ADR 008](008-catalogo-stock-y-carrito.md) (el modelo del Producto,
  que acá se lee) y [ADR 011](011-entrar-al-panel.md) (la mezcla C, que acá
  estrena los renglones)
- **Hace cumplir:** `scripts/ci/auditar_estados.mjs`, ampliado — ahora también
  las fixtures de texto y de plata, y que el panel las espeje
- **Planificación:** `openspec/changes/panel-catalogo-y-bodegas/`
- **NO toca `firestore.rules`.** `productos` y `bodegas` ya tenían `read`,
  `create` y `update` para `esAdmin()`

## Contexto

El panel tenía puerta desde el 2026-09-16 y estaba publicado desde el
2026-09-17, con Catálogo y Pedidos **vacíos y diciéndolo**. Nada del hito 1
puede empezar sin dos cosas: un lugar donde ver lo que hay, y las bodegas —
`fichaVino.bodegaId` es obligatorio, así que un vino no se puede cargar contra
una bodega que no existe.

## Decisión

### 1. La normalización vive en `contratos`, y son cuatro funciones

[ARQUITECTURA §7](../../../../ARQUITECTURA.md#7-búsqueda-una-sola-implementación)
decía que la normalización *"vive en `packages/contratos` con sus fixtures. Un
solo lugar"*. **No vivía en ninguno**: lo único parecido era un slugify escrito
a mano adentro de `apps/tienda/src/features/catalogo/PanelDeFiltros.tsx`.

| Función | Qué hace | Para qué |
|---|---|---|
| `normalizar` | minúsculas, sin acentos, espacios colapsados | el `contains` de la búsqueda |
| `clave` | `normalizar` + sólo letras y números | comparar nombres |
| `aSlug` | `normalizar` + lo no alfanumérico a `-` | derivar el slug del nombre |
| `seParecen` | una `clave` contiene a la otra | el aviso de duplicados |

**Cuatro y no una porque buscar y comparar no son lo mismo.** Si `normalizar`
sacara los espacios, buscar "catena zapata" —que es como lo escribe el
operador— no encontraría nada.

**`seParecen` es contención, no distancia de edición.** §7 dice que el panel
*"no necesita búsqueda difusa, así que no hay una segunda implementación que
mantener sincronizada"*. Un Levenshtein acá sería esa segunda implementación.

⚠️ **Una clave vacía está contenida en todas.** Sin el corte explícito,
`seParecen` de un nombre sin letras contra cualquier otro daría verdadero por
álgebra, y **toda bodega nueva parecería un duplicado de todo**. Tiene su
escenario y su test.

### 2. El espejo en Dart se verifica contra fixtures, no contra una lectura

Mismo patrón que el enum de estados ([ADR 002](002-estados-de-orden.md)): el
TypeScript es la fuente, `generar.mjs` calcula pares entrada→salida y los emite
en `generated/contratos.json`, y el test de Dart los corre.

**Viajan las fixtures y no la implementación** porque una implementación no se
puede transportar en JSON. `auditar_estados.mjs` ya verificaba que el JSON no
envejezca; sin esa pieza el test de Dart compara contra fixtures viejas y es
teatro.

**Y encontró algo en la primera corrida.** El espejo necesita sacar acentos, y
**Dart no trae normalización Unicode en el SDK** — no existe `String.normalize`.
Se resolvió con `diacritic` y no con una tabla de caracteres a mano: una tabla
falla **en silencio** con el carácter que nadie pensó, y "Château" habría dado
el slug `ch-teau` sin que nada avisara.

⚠️ **Dónde termina el acuerdo, escrito a propósito.** `removeDiacritics`
traduce las ligaduras a ASCII y el `NFD` de TypeScript no. **El contrato son
las fixtures**, no la igualdad para toda entrada posible, y ninguna fixture usa
una ligadura. Hoy no tiene consumidor: el único que deriva el slug de una
bodega es el panel. El test fija las dos salidas porque son lo que se **midió**:
la primera versión suponía `ss` para la eszett y **falló** — el espejo da `s`.

### 3. El precio también se espeja, y por el mismo mecanismo

`formatearARS` ya existía en `contratos` y el panel tenía que mostrar **el
mismo** número que la vidriera. No es cosmética: con el separador de miles y el
decimal cambiados de lugar, no es un número mal alineado — es otro número.

⚠️ **El espacio entre el signo y la cifra es U+00A0, no la barra
espaciadora.** Se midió: los code points de `$ 12.500,00` son
`24 a0 31 32 2e 35 30 30 2c 30 30`. Una implementación escrita a ojo pone el
otro. La fixture lo fija, y el test lo comprueba por code unit.

**Se escribió a mano en vez de usar `NumberFormat` de `intl`** porque el
contrato no es "algún formato argentino": es exactamente lo que muestra la
vidriera, y con `intl` eso depende de los datos de locale de la versión que
resuelva pub ese día. Escrito, se compara contra una unidad externa.

### 4. `snapshots()` sin `autoDispose`

[ARQUITECTURA §6.3](../../../../ARQUITECTURA.md#63-el-presupuesto-completo) ya
pedía que la caché del catálogo no llevara `autoDispose`. Lo que se decide acá
es **stream y no `get()`**:

- Con `get()`, cada ida y vuelta a Pedidos puede costar 230 lecturas.
- Con un stream vivo, las 230 se pagan **una vez por sesión** y cada cambio
  cuesta **una**: la del documento que cambió.
- Y es lo correcto además de lo barato: dos personas de la familia cargando
  bodegas a la vez se ven sin recargar.

### 5. La baranda de HU-02.4 vive en el panel, en dos capas

**Por qué no en las reglas:** contar los vinos de una bodega dentro de
`firestore.rules` serían `get()` **facturados por evaluación**, invisibles en
cualquier auditoría porque no aparecen en ninguna query. Es textualmente el
costo que ADR 008 evita con el custom claim.

**Por qué no cerrar el `delete`:** entonces tampoco se podría borrar una bodega
vacía —la que se cargó con un error de tipeo y nunca tuvo vinos—, y la historia
pide poder.

1. El renglón cuenta con el catálogo en memoria y, con uno o más vinos, **el
   botón de borrar no existe**. No está apagado: no está.
2. Al confirmar, una query por `fichaVino.bodegaId` con `limit(1)` y
   **`Source.server`**. Cuesta **1 lectura**, no necesita índice compuesto
   —igualdad sobre un campo anidado, que Firestore indexa solo— y cierra la
   ventana entre que se abrió la pantalla y se apretó el botón.

**`Source.server` y no la caché** porque preguntarle a la caché derrotaría el
único motivo por el que esa consulta existe. Sin red **falla** en vez de
contestar que no hay vinos, y el borrado no ocurre: es lo correcto para algo
que no tiene vuelta atrás.

⚠️ **El riesgo que queda, escrito.** Las reglas siguen permitiendo el `delete`,
así que quien use el SDK por fuera del panel puede borrar una bodega con vinos
y despublicarlos en silencio. Hoy quien puede hacer eso es la familia, que es
el único rol. **Si alguna vez hay más de un rol, esto vuelve a decidirse.**

### 6. El slug de una bodega no cambia, y es el id del documento

HU-02.3 lo dejaba abierto. Se cierra como el del producto publicado: **no
cambia**. La bodega va a tener una página indexable por slug, y un slug que se
mueve es un 404 en Google. El `update` manda **sólo `nombre`**.

El id del documento **es** el slug, y el alta va en una transacción que se
niega si ya existe. Un `set()` suelto **sobrescribiría en silencio**: para las
reglas, escribir sobre un documento que existe es un `update` legítimo.

⚠️ **Las reglas permitirían mandar `slug` en un `update`.** La restricción es
del panel, no de las reglas, y queda dicho para que no se lea al revés.

⚠️ **El seed usa ids con prefijo `muestra-` y slug sin él**, así que una bodega
real puede quedar con el mismo slug que una de muestra. Lo atrapa el aviso de
HU-02.2, que compara **nombres**, no ids.

### 7. El panel muestra lo que la vidriera descarta

`armarCatalogo` deja afuera, **sin error**, los productos de una bodega que no
existe, y hoy eso sólo se lee en el log del build. La postura de las dos
pantallas es opuesta a propósito:

| | La vidriera | El panel |
|---|---|---|
| Documento roto | lo **descarta** y lo reporta a un log | lo **muestra** con lo que se pudo leer |
| Bodega inexistente | el vino no aparece | el renglón dice *"Sin bodega: no aparece en la tienda"* |

**Un vino que el operador no ve es un vino que no puede arreglar.**

## Presupuesto de lecturas

Cuota: **50.000/día**.

| Qué | Lecturas |
|---|---:|
| Catálogo en frío (MVP: 200 productos + 30 bodegas) | **230** por sesión |
| Buscar, filtrar, contar vinos por bodega, ver parecidas | **0** |
| Alta o corrección de una bodega | **1** — el `snapshot` del documento que cambió |
| Alta, además | **1** — la transacción lee antes de escribir |
| Borrar una bodega | **1** — la pregunta fresca, `limit(1)` |

**Diez sesiones en frío por día son 2.300: el 4,6 % de la cuota.** Hoy, con 20
vinos de muestra y 11 bodegas, son ~31 por sesión.

⚠️ **El ~200 de ARQUITECTURA §6.3 suponía que la caché sobrevive entre
sesiones, y no sobrevive**: la de Riverpod muere con la pestaña. **230 es el
número contra el que hay que medir** — hallazgo 7 del
[mapa del panel](../../features/panel/overview.md), cerrado.

## Consecuencias

- **El panel puede cargar bodegas en producción.** Los vinos todavía no:
  HU-03.2 arrastra `graduacion` —que entra en `contratos` **y** en las
  reglas— y la reserva `slugs/{slug}` para la unicidad del slug de un producto.
- **`--filete-papel` dejó de ser un token sin uso.** Es la línea del renglón de
  la libreta, en el catálogo y en las bodegas.
- **`auditar_estados.mjs` audita más de lo que dice su nombre.** Se mantuvo el
  nombre a propósito: lo nombran 22 archivos, y renombrarlo por prolijidad es
  más riesgo que el que evita. El encabezado del script lo dice.
- ⚠️ **Del lado de TypeScript, estas funciones todavía no las abre ningún
  producto.** `_verdad.md` lo dice: a `normalizar`, `aSlug` y `seParecen` las
  referencian el generador, sus tests y el auditor — **nadie más**. No es un
  huérfano: el generador ES su consumidor, porque de ahí salen las fixtures que
  el panel espeja. Pero significa que el "un solo lugar" de ARQUITECTURA §7
  está construido y **todavía no cobrado**: el slugify inline de
  `PanelDeFiltros.tsx` sigue sin apuntar acá.
- **Queda deuda anotada, no hecha:** mover ese slugify es un deploy de tienda, y
  el deploy de tienda arrastra todo lo mergeado. Entra con la próxima tarea que
  toque la vidriera, no sola.
- ⚠️ **`clave` da falsos positivos en `_verdad.md`.** El conteo es léxico y
  `clave` es una palabra corriente en castellano: aparece como variable en seis
  archivos de la tienda que no importan nada de `contratos`. El número de ese
  renglón no se puede leer como "call sites".
- **`dart analyze` SÍ corre en esta máquina.** Terminó en minutos y encontró
  dos infos reales. `CLAUDE.md` prohíbe `flutter analyze`, que es otra cosa: el
  panel dejó de depender sólo de CI para saber si compila.
