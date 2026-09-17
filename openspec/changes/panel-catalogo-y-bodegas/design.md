# Diseño — el catálogo y las bodegas del panel

## 1. La normalización: cuatro funciones, no una

ARQUITECTURA §7 dice *"la normalización vive en `packages/contratos` con sus
fixtures. Un solo lugar"*, y hoy no vive en ninguno: lo más parecido es un
slugify inline en `apps/tienda/src/features/catalogo/PanelDeFiltros.tsx`.

Son cuatro porque **buscar y comparar no son lo mismo**:

| Función | Qué hace | Para qué |
|---|---|---|
| `normalizar` | minúsculas, sin acentos, espacios colapsados | el `contains` de la búsqueda |
| `clave` | `normalizar` + saca todo lo que no es letra o número | comparar dos nombres |
| `aSlug` | `normalizar` + lo no alfanumérico pasa a `-` | derivar el slug del nombre |
| `seParecen` | una `clave` contiene a la otra | el aviso de duplicados |

**Por qué `normalizar` NO saca los espacios:** si los sacara, buscar "catena
zapata" no encontraría nada, porque el texto indexado tampoco los tendría y el
`contains` compararía `"catenazapata"` contra lo que escribió el operador tal
cual. Sacarlos es tarea de `clave`, que compara nombres enteros, no fragmentos.

**Por qué `seParecen` es contención y no distancia de edición:** ARQUITECTURA §7
dice que el panel *"no necesita búsqueda difusa, así que no hay una segunda
implementación que mantener sincronizada"*. La contención resuelve el caso que
la historia nombra —"Catena" contra "Catena Zapata"— con una línea. Un
Levenshtein acá sería la segunda implementación.

⚠️ **Una clave vacía está contenida en todas.** `seParecen("···", "Norton")`
daría verdadero por álgebra, y entonces toda bodega nueva parecería un
duplicado de todo. Las dos claves vacías dan `false` explícito, y tiene su
escenario.

### El espejo en Dart

Mismo patrón que el enum de estados, que ya está probado en este repo: el
TypeScript es la fuente, `generar.mjs` emite las **fixtures** en
`generated/contratos.json`, y el test de Dart las lee y compara.

**Van las fixtures y no la implementación** porque una implementación no se
puede transportar en JSON. Lo que el JSON transporta son pares
`entrada → salida` calculados **por el TypeScript de hoy**, y
`auditar_estados.mjs` ya verifica que ese JSON no envejezca. Sin esa pieza, el
test de Dart compara contra fixtures viejas y es teatro — el mismo modo de
falla que documenta ese script.

Las fixtures incluyen los casos que rompen: `ñ`, `Torrontés`, espacios dobles,
una cadena que no produce slug, y las mayúsculas del turco no entran porque
`toLowerCase` de Dart y de JS coinciden en los caracteres que usa una bodega
argentina. Si algún día no coinciden, la fixture lo va a decir.

## 2. `snapshots()` sin `autoDispose`

ARQUITECTURA §6.3 ya lo pide para la caché del catálogo. Lo que se agrega acá es
**por qué stream y no `get()`**:

- Con `get()`, cada ida y vuelta a Pedidos puede costar 230 lecturas.
- Con un stream vivo, las 230 se pagan **una vez por sesión** y cada cambio
  cuesta **una** lectura: la del documento que cambió.
- Y es lo correcto además de lo barato: dos personas de la familia cargando
  bodegas a la vez se ven sin recargar.

El riesgo conocido es el contrario —un stream que nadie cierra—, y lo cierra
Riverpod cuando muere el `ProviderContainer`, o sea con la pestaña.

## 3. La baranda de HU-02.4 vive en el panel, y se dice el riesgo que queda

**Por qué no en las reglas:** contar los vinos de una bodega dentro de
`firestore.rules` serían `get()` **facturados por evaluación**, y son invisibles
en cualquier auditoría porque no aparecen en ninguna query. Es textualmente el
costo que ADR 008 evita con el custom claim.

**Por qué no `allow delete: if false`:** entonces tampoco se podría borrar una
bodega vacía —la que se cargó con un error de tipeo y no llegó a tener vinos—, y
la historia pide poder.

**Las dos capas del panel:**

1. El renglón cuenta los vinos con el catálogo que ya está en memoria y, con uno
   o más, **no ofrece borrar**.
2. Al confirmar, una query `where('fichaVino.bodegaId','==',id).limit(1)`
   contra Firestore. Cuesta **1 lectura**, no necesita índice compuesto —es
   igualdad sobre un campo anidado, que Firestore indexa solo— y cierra la
   ventana entre que se abrió la pantalla y se apretó el botón.

**El riesgo que queda, escrito:** las reglas siguen permitiendo el `delete`, así
que quien use el SDK por fuera del panel puede borrar una bodega con vinos y
despublicarlos en silencio. Hoy quien puede hacer eso es la familia, que es el
único rol. **Si alguna vez hay más de un rol, esto vuelve a decidirse.**

## 4. El slug de la bodega no cambia al corregir el nombre

HU-02.3 lo dejaba abierto. Se cierra como el del producto publicado: **no
cambia**. La bodega va a tener `/bodega/<slug>` indexable, y un slug que se
mueve es un 404 en Google. El `update` escribe sólo `nombre`.

Las reglas permiten mandar `slug` en un `update`; el panel **no lo manda**. Es
una restricción del panel, no una regla — y queda dicho acá para que no se lea
como si las reglas la hicieran cumplir.

## 5. Las rutas

`/catalogo` y `/catalogo/bodegas`, hija. **Bodegas no es una sección**: no entra
en `secciones.dart` y se llega desde Catálogo. `Seccion.estaActiva` ya marca
activa la sección padre con `ubicacion.startsWith('$ruta/')`, así que estando en
Bodegas la navegación sigue marcando Catálogo — que es lo correcto, porque no
se salió de ahí.

El alta y la edición de una bodega son una **hoja modal**, no una ruta: son un
formulario de un campo y no tiene sentido que se puedan compartir por URL.

## 6. La composición, de la hoja a la página

Bottom-up, y cada widget público en su archivo (`one-widget-per-file`), ninguno
arriba de 200 líneas (`widget-size-guard`):

```
core/presentation/       campo_de_busqueda · estado_de_carga · aviso (ya existe)
features/catalogo/
  domain/                bodega · producto_del_panel · los dos puertos
  data/                  las dos implementaciones con el SDK
  presentation/          renglon_de_producto  ─┐
                         lista_del_catalogo   ─┤─ pantalla_del_catalogo
                         renglon_de_bodega    ─┐
                         hoja_de_bodega       ─┤─ pantalla_de_bodegas
                         bodegas_parecidas    ─┘
```

`layer-boundary.sh` no deja que `presentation/` importe `data/` ni el SDK:
las pantallas piden `catalogo_providers.dart`, que es el único archivo que
conoce las implementaciones.
