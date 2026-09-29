# ADR 024 — Las cajas sugeridas se arman desde el panel, por una callable

- **Fecha:** 2026-09-28
- **Estado:** aceptada; **desplegada y verificada por bytes el 2026-09-28** (v0.42.0, `dacfb58`). Nadie guardó una caja desde el panel todavía: ver *Verificación*, al final
- **Decide:** cómo arma, cambia, ordena y saca el dueño las cajas sugeridas, y
  qué verifica el servidor antes de guardarlas
- **Historias:** HU-09.2 y HU-09.3 ([EP-09](../../features/panel/EP-09-vidriera-curada.md)).
  **Segundo tramo del hito 3**, y con él EP-09 entera
- **Toca:** [ADR 009 §8 y §10](009-venta-por-caja.md) (la escritura cerrada y lo
  que viaja solo), [ADR 023](023-la-portada-la-elige-el-duenio.md) (la sección
  Vidriera y los plazos de `cuando_se_ve.dart`)
- **Hace cumplir:** `packages/contratos/test/cajas.test.ts` (bloque *el pedido
  del panel*), `functions/test/vidriera/guardar.emulador.mjs` (**entra a CI**) y
  `apps/admin/test/features/vidriera/cajas_sugeridas_test.dart`
- **Sin openspec, a pedido del dueño** (2026-09-28): este ADR y la épica son la
  especificación

## Contexto

`cajasSugeridas/publicas` existe desde el 2026-09-14 y lo lee `/vinos`: un
documento con las cajas que el vendedor ofrece ya armadas (ADR 009). Hasta hoy
lo escribía **sólo el seed**. Las reglas lo cierran **incluso al admin**: la
única regla que importa de una caja es que **sume una caja**, y comprobarlo en
las reglas serían seis `get()` facturados por escritura (ADR 009 §8). El
comentario de `verificarComposicion` ya lo anticipaba: *"si mañana un panel
escribe cajas por una callable, esa callable tiene que llamarla a mano"*.

## Decisión

### 1. Una callable, `guardarCajasSugeridas`, que reescribe el documento entero

El panel manda **la lista entera**, en el orden en que se ofrecen:
`{ cajas: [{ nombre, productoIds }] }`. La callable:

1. exige el claim `rol: admin`;
2. valida la forma con **`armarCajasSugeridas`** (contratos): hasta **6 cajas**,
   nombre de hasta **40 letras**, exactamente **6 ids** por caja, y **deriva el
   slug del nombre** (`aSlug`);
3. lee los ids **distintos** de todas las cajas en **una** llamada (`getAll`);
4. corre **`verificarComposicion`** por caja: que cada id exista, que ninguno
   venga en su propia caja, que sumen seis;
5. `set` del documento **entero**: `{ cajas: [{ slug, nombre, productoIds }] }`.
   Sin `muestra`: el primer guardado del dueño saca la marca del seed.

**Todo o nada**: si una caja no cierra, no se escribe ninguna, y el error dice
cuál (`failed-precondition` con `details.caja`).

### 2. Sin transacción, a propósito

`presentacion.botellas` es **inmutable por reglas** y un producto **no se
borra** desde un cliente: lo que se leyó en el paso 3 no puede cambiar antes del
paso 5. Y el `set` entero hace idempotente el guardado.

### 3. El slug lo pone el servidor, y dos nombres iguales se rechazan

El slug es la clave de la tarjeta en `/vinos`, y **dos cajas con el mismo slug
quedan afuera las dos** (`validarCajasSugeridas`). Si el panel mandara el slug,
un nombre repetido se guardaría y desaparecería de la tienda sin aviso. Así, se
rechaza con un motivo; y el borrador del panel lo frena **antes** de tocar
*Guardar*.

### 4. No exige publicado ni stock

HU-09.3: una caja con un vino despublicado o agotado **se sigue mostrando**, con
el lugar marcado. Si la callable lo exigiera, reordenar las cajas fallaría por
una caja vieja que nadie tocó. Sólo se exige **la composición**. Para armar un
lugar **nuevo**, el panel no ofrece lo que no se llena (`fueraAlElegir`).

### 5. El panel

En la sección **Vidriera**, debajo de la portada:

- **Cada caja** con sus seis vinos y lo que la tienda va a hacer: los lugares que
  se verán marcados —no está en la tienda, sin stock, *no alcanza para otra
  copia*— y, aparte, la caja que **no se muestra entera** porque tiene un vino
  que viaja solo. Es el espejo de `resolverCajasSugeridas`, contando las copias
  del mismo vino contra su tope.
- **Armar o cambiar** abre una hoja con el nombre y seis lugares, que dice
  **cuántos faltan todo el tiempo**. Si guardar falla, la hoja **no se cierra**:
  rearmar seis lugares por un corte de red es trabajo tirado.
- **Subir, bajar y sacar** guardan en el acto. **Sacar** ofrece *Deshacer*, que
  vuelve a guardar la lista de antes: no hace falta confirmar lo que se deshace
  en un toque.
- El aviso de cuándo se ve es el del catálogo (**hasta ~13 minutos**): `/vinos`
  se rearma solo ([ADR 023 §6](023-la-portada-la-elige-el-duenio.md)).

La hoja para elegir un vino es **una sola** para la portada y las cajas: recibe
el título y el *por qué no* de cada vino.

## Por qué NO las alternativas

| Alternativa | Por qué no |
|---|---|
| Abrir la escritura en las reglas y validar en el panel | Seis `get()` facturados por escritura para validar en las reglas, o ninguna validación del lado del servidor: una caja que no cierra deja un carrito con la caja abierta (ADR 009) |
| Una callable por caja (crear, cambiar, sacar) | El documento es uno y el orden es parte de él: tres puertas que reescriben lo mismo, y el orden en una cuarta |
| Que el panel mande el slug | Un nombre repetido desaparece de la tienda sin aviso (§3) |
| Exigir publicado y stock al guardar | Reordenar fallaría por una caja vieja (§4) |
| Transacción | Nada de lo leído puede cambiar (§2) |
| Confirmar antes de sacar una caja | Se deshace en un toque; el criterio del panel confirma sólo lo que no tiene vuelta atrás |

## Presupuesto de lecturas

| Quién | Cuánto | Cuándo |
|---|---:|---|
| La callable | **≤ 36** (ids distintos, en general ~12) | Por guardado |
| El panel, al abrir Vidriera | **+1** | El documento de cajas, sobre la selección y el catálogo de ADR 023 |
| El panel, por cambio | **~1** | El listener recibe el documento nuevo |
| `/vinos` | **0 nuevas** | Ya leía el documento (P + B + 2, ADR 009) |

Con **10 guardados por semana**, ~20 lecturas al día: **0,04 % de la cuota**.

## Lo que este ADR deja abierto, con su disparador

| Qué | Disparador |
|---|---|
| **Las cajas de stage siguen siendo las del seed**, con `muestra: true`. El primer guardado desde el panel las reemplaza | Cuando el dueño arme la primera caja |
| **Dos personas editando cajas a la vez**: gana la última, sobre la lista que la segunda veía al guardar (no al abrir) | Si pasa. Son seis cajas y una familia |
| **Un `presentacion.botellas` roto** se reporta como *"el producto no existe"* | Si aparece un documento así: el formulario no lo deja escribir |

## Verificación (2026-09-28)

**Desplegada —`guardarCajasSugeridas` y el panel (v0.42.0, `dacfb58`)— y verificada por
bytes. Nadie armó una caja desde el panel, ni la miró renderizada.**

| Qué | Cómo |
|---|---|
| Las suites | CI `36502552119` restada contra `36494514104`: contratos 276 → **284 (+8)**, emulador 198 → **209 (+11, la suite nueva, que entra a CI)**, Dart 497 → **509 (+12)**; tienda y functions unitarios sin cambios (38, 76). `flutter analyze` sin issues. El bundle carga **7 functions**, con la nueva |
| Lo que CI encontró | La primera corrida (`36502072153`) cayó en `tipos`: el test nuevo redeclaraba `SEIS`, que `cajas.test.ts` ya tenía igual. Se reusó |
| La callable | `ACTIVE`; preflight con `Origin` del panel **204** con `access-control-allow-origin`; `POST` anónimo **401** con el JSON de `exigirAdmin` (corre el código, no lo frena IAM); una inventada **404**. Las otras 6 functions conservan su `updateTime`: el deploy fue sólo de ésta |
| El deploy de functions | Falló una vez con `Timeout after 90000` cargando el código en la máquina (707 MB libres); con `FUNCTIONS_DISCOVERY_TIMEOUT=300`, al primer intento |
| Panel | Build `36502963910` → canal → canario (4 cadenas nuevas 0 → 1, `COMMIT` `4c75317` → `dacfb58`, inventada 0 → 0) → live con los 4 hashes del artifact, `noindex` |
| Quién lo abre | Cadena `secciones` → `enrutador` → `PantallaDeLaVidriera` → `SeccionDeCajasSugeridas` → `RenglonDeCaja` / `HojaDeLaCaja` → `LugarDeLaHoja` / `HojaParaElegirUnVino`; cada función del dominio y de `data/` con su llamada (grep directo; control inventado 0) |

⚠️ **Lo que sigue:** que el dueño arme una caja real desde *Vidriera*. Es lo único que
prueba la callable con una cuenta de verdad; el primer guardado reemplaza las cajas de
muestra del seed.
