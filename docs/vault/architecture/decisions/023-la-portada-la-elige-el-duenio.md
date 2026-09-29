# ADR 023 — La portada la elige el dueño, y el panel dice cuándo se ve

- **Fecha:** 2026-09-28
- **Estado:** aceptada; **desplegada y verificada en producción el 2026-09-28**, las dos ramas (v0.41.0, `4c75317`). Nadie la miró renderizada: ver *Verificación*, al final
- **Decide:** dónde vive la selección de la portada, qué muestra la portada con
  ella, y cómo le dice el panel a quien guarda cuándo lo va a ver en la tienda
- **Historias:** HU-09.1 y HU-09.4 ([EP-09](../../features/panel/EP-09-vidriera-curada.md)).
  **Primer tramo del hito 3**; el segundo son las cajas sugeridas (HU-09.2 y 09.3)
- **Toca:** [ADR 008 §7](008-catalogo-stock-y-carrito.md) (la home horneada y la
  regla provisoria, que deja de ser la única), [ADR 005](005-hosting-vidriera.md)
  (el tramo 4, que cambia los plazos) y [ADR 014](014-publicar-un-vino.md) (el
  aviso del precio, que pasa a vivir en un archivo compartido)
- **Hace cumplir:** `packages/contratos/test/seleccion.test.ts`,
  `apps/tienda/test/seleccion.test.ts` (bloque *ADR 023*),
  `apps/tienda/test/revalidacion.test.ts` (*la selección del dueño la lee SÓLO
  la home*), `scripts/reglas/seleccion.test.mjs` (**entra a CI** con este
  cambio) y `apps/admin/test/features/vidriera/seleccion_de_la_portada_test.dart`
- **Sin openspec, a pedido del dueño** (2026-09-28): este ADR y la épica son la
  especificación

## Contexto

La escena 2 de la home dice *"Los elegimos de a uno"*, y desde el 2026-09-11 los
elige `elegirSeleccion`: seis por ventas, uno de cada color, sin agotados ni
cajas. ADR 008 §7 la dejó **provisoria** por eso mismo, con el pendiente en
`_index.md`: *"pide un dato que el modelo no tiene"*.

La home se **hornea en el build** (ADR 008 §7): lee el catálogo una vez por
deploy y cero por visita. Eso no cambia acá, y tiene una consecuencia que
HU-09.1 ya anotaba: **lo que el dueño elija se ve con la próxima publicación
de la tienda, no al guardar**. HU-09.4 existe para que el panel lo diga.

## Decisión

### 1. Un documento, `seleccion/publica`, y no un campo en cada producto

`{ productoIds: [...] }`: una lista **ordenada** de hasta 6 ids, que el panel
reescribe entera. Mismo patrón que `cajasSugeridas/publicas` y
`metricas/popularidad`.

- **El orden lo elige el dueño.** Con un campo `enSeleccion` por producto la
  portada tendría que inventar el orden, y el tope de 6 no se podría exigir: las
  reglas no cuentan documentos.
- **No toca `productoValido`.** Es la regla del documento de producto, la que
  protege el precio y el stock; sumarle un campo por la portada sería abrir la
  regla de plata por algo que no es plata.
- **Una escritura por cambio**, y guardar dos veces da lo mismo.

### 2. La escribe el panel directo, con la forma cerrada en las reglas

A diferencia de `cajasSugeridas` —cerrada incluso para el admin, porque que una
caja cierre pide seis `get()` facturados—, la selección **no tiene una regla de
plata**. Que cada vino sea una botella suelta con stock es lo único que costaría
un `get()`, y un vino mal elegido deja **un lugar vacío en la portada**, no un
carrito que no cierra. Las reglas cierran lo que es gratis:

- sólo `seleccion/publica`, sólo el admin, sólo el campo `productoIds`;
- una lista de **hasta 6**, **sin repetidos** (`toSet()`), y cada posición un id
  de producto (se miran las seis a mano: las reglas no iteran);
- **no se borra**: sacar todo es la lista vacía.

El 6 vive en tres lugares —`LUGARES_DE_LA_SELECCION` en contratos, el literal de
las reglas, la constante de Dart— y **dos suites los atan contra
`generated/contratos.json`** (sección `vidriera`): la de reglas y la de Dart.

### 3. Qué muestra la portada

`elegirSeleccion(productos, describirUvas, elegidos)`:

| El documento | La portada |
|---|---|
| No existe (nunca eligió) | La regla provisoria, como hoy |
| Tiene ids, y **al menos uno** se puede dibujar | **Sólo los del dueño**, en su orden. **La regla no completa** |
| Tiene ids y **ninguno** se puede dibujar, o está vacío | La regla provisoria |

"Se puede dibujar" es `puedeIrEnLaSeleccion` de contratos: está en la proyección
pública (publicado, válido, con bodega) y es una botella suelta no agotada —la
tarjeta dibuja **una** botella—. Es la misma condición que ya usaba la regla.

**Por qué la regla no completa.** Con tres elegidos, sumar tres por ventas
volvería a poner en la portada vinos que nadie eligió, que es justo lo que
*"los elegimos de a uno"* no puede decir. La grilla se arma con los que haya.

### 4. El panel dice lo mismo que la portada, antes que ella

`fueraDeLaPortada` (Dart) decide, para cada vino elegido, si se ve y si no por
qué: **no existe**, **la tienda no lo muestra** (lo decide `revisarParaLaTienda`,
la única función del panel que lo sabe), **viene en caja**, **sin stock**. En
ese orden, que es el de la tienda. La pantalla lo dice en el renglón, en rojo,
con qué hacer; y si la portada va a usar la regla —nunca eligió, o no queda
ninguno visible— **lo dice arriba**.

La hoja para elegir **no esconde** los que no pueden ir: los muestra
deshabilitados con el motivo, como la de los pedidos.

### 5. Cada gesto se guarda en el acto

Agregar, subir, bajar y sacar guardan al tocar, sin botón de *Guardar*: un
guardar olvidado es un cambio que nadie hizo. Sacar no pide confirmación —se
deshace volviendo a agregarlo— (criterio 3 del panel). Mientras se guarda, los
botones esperan: dos toques seguidos armarían dos listas sobre la misma de antes.

### 6. HU-09.4: cuándo se ve, en UN archivo

`apps/admin/lib/core/presentation/cuando_se_ve.dart` tiene los dos plazos:

| Qué se guardó | Cuándo se ve | Por qué |
|---|---|---|
| Precio, publicar o sacar, la ficha, las fotos (y las cajas, tramo 2) | **Hasta unos 13 minutos** | La caché de 60 s + la página vencida de Next + el borde (ADR 008) |
| La selección de la portada | **Con la próxima publicación de la tienda** | La home se hornea en el build (ADR 008 §7) |

El aviso sale **después de cada guardado** y, en la portada, además **a la
vista todo el tiempo**. Precio ya lo decía (ADR 014); publicar, la ficha y las
fotos no decían nada.

⚠️ **El día del tramo 4 este archivo miente al revés**: con la purga por tag el
catálogo se ve en segundos. Por eso es uno solo, y el pendiente del tramo 4 en
`_index.md` apunta acá.

## Por qué NO las alternativas

| Alternativa | Por qué no |
|---|---|
| Un campo `enSeleccion` en cada producto | Sin orden, sin tope exigible, y abre `productoValido` (§1) |
| Una callable que valide cada vino | Un `get()` por vino para evitar un lugar vacío, no una pérdida. La portada ya saltea lo que no sirve |
| Completar con la regla hasta 6 | Pone en la portada vinos que nadie eligió (§3) |
| Hacer la home ISR para que el cambio se vea solo | Con el catálogo real, 24 reconstrucciones al día de P + B + 2 lecturas son ~5.500 lecturas, el 11 % de la cuota, para un cambio que el dueño hace de vez en cuando. Lo resuelve el tramo 4, no la portada |
| Un botón de *Guardar* | Un cambio olvidado es un cambio que nadie hizo (§5) |

## Presupuesto de lecturas

| Quién | Cuánto | Cuándo |
|---|---:|---|
| La home de la tienda | **+1** | Por build (`seleccion/publica`, sin caché). Cero por visita |
| El panel, al abrir Vidriera | **1** | La selección. El catálogo ya está en memoria si se pasó por Catálogo; si no, es la misma carga en frío de ADR 012 (~230 con el MVP), una vez por sesión |
| El panel, por cambio | **1 escritura + ~1 lectura** | La del listener, que recibe su propio cambio |

Con **10 cambios por semana**, ~2 lecturas al día: **< 0,01 % de la cuota**. La
suma diaria no se mueve.

## Lo que este ADR deja abierto, con su disparador

| Qué | Disparador |
|---|---|
| **Que alguien elija la portada.** Hoy el catálogo es el de muestra: se puede elegir, pero la portada sigue con `data-catalogo-de-muestra` | Cuando el dueño cargue su catálogo real (el mismo disparador de EP-09) |
| **Los plazos de `cuando_se_ve.dart`** | El tramo 4 (purga por tag, ADR 005) |
| **Que la portada entre a la purga** | El tramo 4: si entra, el plazo de la portada pasa a ser el del catálogo, y el texto cambia |

## Verificación (2026-09-28)

**Desplegado —reglas, panel (v0.41.0, `4c75317`) y la preview de la tienda— y verificado
por bytes. Nadie lo miró renderizado.**

| Qué | Cómo |
|---|---|
| Las suites | CI `36494514104` restada contra `36475268911`: contratos **+8**, tienda **+4**, emulador **+11**, Dart **+9**; `flutter analyze` sin issues |
| El acople que encontró CI | La primera corrida (`36494126137`) tumbó `documento_del_vino_test.dart`: lee la PRIMERA lista de `hasOnly` sobre `d` en `firestore.rules`, y `seleccionValida(d)` quedó antes que `productoValido`. Se renombró el parámetro a `sel`, con el porqué al lado |
| Reglas | API de Rules: el ruleset publicado es **idéntico byte a byte** al archivo; `seleccionValida(sel)` presente; string inventado 0 |
| Panel | Canario discriminante en el canal (4 cadenas nuevas 0 → ≥1, una vieja 1 → 0, inventada 0 → 0) → live con los 4 hashes del artifact, `noindex` |
| Tienda | Rollout `build-2026-09-28-001` `SUCCEEDED` al 100 %, gates cerrados. Sin documento (404), la portada muestra **los mismos 6** que la regla antes del deploy: la rama "nunca eligió" funciona en producción |

**La rama positiva, con autorización del usuario (2026-09-28):** una selección de prueba
en `seleccion/publica` —santa-julia, el bonarda **agotado**, don-david, callia, trumpeter,
alamos— y la preview publicada otra vez (rollout `build-2026-09-29-001`, 100 %, gates
cerrados). La portada muestra **exactamente** santa-julia → don-david → callia →
trumpeter → alamos: santa-julia **aparece** (antes no estaba), latitud-33 y crios-rose
**desaparecen**, el bonarda agotado **se saltea**, y la regla **no completa** el sexto
lugar. Control inventado: ausente. El gate de muestra sigue puesto.

⚠️ **El documento de prueba quedó en producción**: borrarlo lo frenó el clasificador de
permisos. Mientras exista, *Vidriera* lo muestra como si lo hubiera elegido el dueño, y
la próxima publicación de la tienda lo vuelve a hornear. Se limpia desde el panel
—sacar los seis en *Vidriera* guarda la lista vacía, que la portada lee como "no
eligió"— o cuando el dueño elija los suyos.
