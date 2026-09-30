# ADR 029 — La carga inicial del catálogo real: un script que da de alta como el panel y nunca pisa

- **Fecha:** 2026-09-30
- **Estado:** aceptada y **aplicada en producción** el mismo día — ver *Verificación*
- **Decide:** cómo entran de una vez los vinos que el dueño ya sabe que tiene, con foto y
  descripción, sin cargar 24 formularios; y qué pasa con los datos de muestra
- **Toca:** [ADR 008](008-catalogo-stock-y-carrito.md) (la muestra y su borrado por lista),
  [ADR 013](013-cargar-un-vino.md) (el id es el slug), [ADR 015](015-fotos-del-panel.md) (la
  tubería de foto), [ADR 016](016-mover-el-stock.md) (los movimientos de stock),
  [ADR 023](023-la-portada-la-elige-el-duenio.md) y [ADR 024](024-cajas-sugeridas-desde-el-panel.md)
- **Hace cumplir:** `validarProducto` sobre cada documento **antes** de escribir nada, y
  `functions/test/foto/tuberia.test.ts`, que ahora cubre también las fotos de esta carga
  (ver §3)
- **Sin openspec:** a pedido del dueño —*"inventá cantidades y precios, después
  corregimos"*—. Son datos, no una feature.

## Contexto

El 2026-09-30, con la tienda a punto de publicarse, el dueño pasó una lista de 24 vinos que
sabe que tiene —*"es más la mitad de lo que hay"*— y pidió las fichas armadas, con fotos y
descripciones, y el stock falso fuera. El stock todavía no está contado.

## Decisión

### 1. Un vino real, no uno de muestra

`scripts/catalogo/cargar.mjs` escribe lo mismo que escribe el panel
(`documento_del_vino.dart`): **sin `muestra`**, id igual al slug, las claves opcionales
vacías omitidas. Las bodegas también, con id igual al slug.

**Descartado: sembrarlos con el seed.** `muestra: true` es exactamente la marca que
`scripts/seed/borrar.mjs` usa para decidir qué borra. Un vino real marcado como muestra es un
vino que la próxima limpieza se lleva, con su foto.

**Descartado: cargarlos desde el panel.** Son 24 formularios y 24 fotos buscadas a mano, y
el dueño pidió justamente no hacerlo.

### 2. Nunca pisa

Un vino o una bodega que ya existe **se saltea**. Después de cargado, la verdad es lo que el
dueño corrigió en el panel, no el JSON. Por eso el mismo script sirve para la segunda mitad
del stock: se agregan vinos a un JSON y se vuelve a correr.

Si algún id ya existe **como muestra**, frena todo antes de escribir.

### 3. La foto pasa por la misma tubería, y la tubería es una sola

`prepararFoto` salió de `seed.mjs` a **`scripts/seed/foto.mjs`**, y la importan los dos
scripts. Así, lo que carga `cargar.mjs` queda cubierto por `tuberia.test.ts`, que corre
`seed.mjs --probar-foto` y exige el mismo SHA-256 que `procesarFoto`, sin escribir un test
nuevo. La foto va a `productos/{id}/{hash}.webp`, la ruta de la callable.

Las fotos son packshots de supermercados (Jumbo, Carrefour, Más Online, Día), de la tienda
oficial de Luigi Bosca y de vinotecas en Tiendanube. **Se eligieron mirándolas**, en una hoja
de contacto: 9 de las primeras candidatas no eran una botella sino una composición de
supermercado (la botella cortada y un cartel de *"750 cc"*), que el recorte deja pasar
porque su borde es blanco. **Dos eran el placeholder de Jumbo**, que `PLACEHOLDERS` ya tenía
por hash: el control positivo de esa lista.

### 4. El stock nace sin movimiento

El stock inventado se escribe en el alta, y **no** se registra un `reponer` en
`productos/{id}/movimientos`. No hubo una reposición: registrarla sería inventar un hecho en
el registro que existe para no tenerlos. El primer conteo del dueño (`corregir`, ADR 016)
es el primer movimiento.

**Ningún stock inventado queda en 6 o menos:** eso dibujaría *"Quedan pocas"* sobre un
número que no existe, que es urgencia fabricada ([voz §7.1](../../design/voz.md)).

### 5. Las descripciones siguen voz, y no afirman lo que no se sabe

Origen como sustantivo —bodega, lugar, altura, crianza— sacado de la ficha de la bodega o
de su tienda, y una escena en vez de una nota de cata ([voz §3](../../design/voz.md)).
Medidas contra §7.1 y §8 con un control positivo (una frase con *"notas de"*, *"en boca"*,
*"descubrí"* y una exclamación da 4 fallas; las 24 dan 0).

**Revisión del mismo día, a pedido del dueño: el segundo párrafo se reescribió en los 24.**
El primero lo aprobó; el segundo era un molde —*"Para X. Plato, plato, escena."*— y **22
nombraban comida** (*"¿todo vino es para comida acaso?"*). La causa era la guía, no el que
escribió: [voz §3.3](../../design/voz.md) cuenta por qué y fija la regla nueva. Ahora sale de
lo que ese vino tiene de propio —cómo guardarlo o servirlo, qué quiere decir su dato, su
nombre, para quién es— y la comida queda en **3 de 24**. Dos correcciones más del dueño:
**ninguna ventana de consumo** (*"no digas que se toma el mismo año, capaz alguna botella es
vieja"*) y **cada hecho chequeado en una fuente** antes de escribirse: la bodega (Catena
Zapata, Trivento, Luigi Bosca, Fabre Montmayou), el INV (Bonarda, Torrontés, San Juan).
Se escribió **sólo `fichaVino.descripcion`**, por REST con precondición de `updateTime`,
después de comprobar que la base seguía igual a la carga (nadie había corregido nada), y el
JSON se sincronizó reemplazando las cadenas, sin re-serializarlo. Medido con el mismo
contador sobre los textos viejos como control positivo: comida 22 → 3, arranques con
*"Para"* 14 → 1, frases que suponen la edad de la botella 0.

**La añada vacía no es neutra:** la ficha dice *"Sin añada"*, o sea que afirma un vino NV.
Por eso las que el dueño no dijo llevan la probable de góndola, marcadas en el JSON
(`anadaDelDuenio: false`) para confirmar con la botella.

### 6. Lo que apuntaba a la muestra, una sola vez

Fuera del script, porque son curaduría del dueño y el script corre de nuevo:

- **Cajas sugeridas**: reescritas con vinos reales (*Seis tintos*, *Mitad y mitad*, *Seis
  blancos*), con la forma que escribe `guardarCajasSugeridas` y las mismas validaciones.
- **Portada**: apuntaba a seis vinos borrados. **El dueño pidió que la eligiera el
  script** (*"la portada va con vinos reales"*), así que va una elección y no la regla:
  la regla desempata por id cuando no hay ventas medidas, y habría puesto los seis
  primeros del abecedario. Seis vinos de **seis bodegas**, tintos y blancos alternados, de
  $16.500 a $34.000: D.V. Catena Cabernet-Malbec, La Linda Torrontés, Zuccardi Serie A
  Malbec, Trumpeter Sauvignon Blanc, Coquena Cabernet Sauvignon y El Buscapleito. Se
  cambia desde *Vidriera* en el panel ([ADR 023](023-la-portada-la-elige-el-duenio.md)).
- **Los dos vinos de prueba del dueño** (`ve` y `vino-de-prueba`) **borrados a pedido
  suyo**, con sus movimientos y sus fotos —`ve` tenía un crudo huérfano de una subida que
  no terminó—. Un producto no se borra ni siendo admin (reglas, hallazgo 1 de ADR 008):
  se hizo con el Admin SDK porque son pruebas que nunca van a recrearse. **El Pedido 1**
  —entregado, cobrado por fuera— sigue ahí con su renglón de 3 botellas: su `items[]` es
  una copia y no depende del vino.

## Presupuesto de lecturas

Cada reconstrucción del catálogo cuesta P + B + 2 ([ADR 008](008-catalogo-stock-y-carrito.md)).
Pasó de 21 + 11 + 2 = **34** a 23 + 15 + 2 = **40**: **+6 por reconstrucción**, dentro del
escenario de 200 productos de [ARQUITECTURA §6.3](../../../../ARQUITECTURA.md#63-el-presupuesto-completo).
El script lee 39 documentos una vez por corrida. Nada cambia por visita.

## Verificación (2026-09-30)

| Qué | Cómo |
|---|---|
| Firestore | Releído: 24 vinos y 15 bodegas nuevos, **cero** documentos con `muestra`; la popularidad (real) y las cajas no se borraron |
| Fotos | Las 25 URLs de productos dan 200 `image/webp` **y el SHA-256 del contenido coincide con el nombre del archivo**; una ruta inventada da 404 |
| `/vinos` en vivo | Canario que aparece: `Violinista Malbec` (no existía en la muestra) 0 → 3. Canarios que desaparecen: `Portillo`, `Latitud 33`, `Callia`, `muestra-`, `vino de prueba` → 0 |
| Fichas | Cuatro nuevas en 200, con descripción, precio, añada y foto; `portillo-malbec` (muestra), el borrador y una ruta inventada en 404 |
| Renderizado | Chrome por CDP a 1280 y 390, puerta de edad aceptada: fotos sobre el papel, filtros con 11 Malbec, 2 cortes y 1 orgánico |
| La home | Se hornea en el build, así que hizo falta desplegar `tienda`. `build-2026-09-30-005` arrastró la v0.50.0 y salió **sin `noindex`** (ADR 017 §4, revertido); `build-2026-09-30-006` es el bueno: `preview.sh verificar` entero en verde —`noindex` en 7 rutas, 23 fichas contra 23 publicados, gates y puerta de edad—, y en la home `muestra-` 10 → 0 y los seis de la portada 0 → 2 cada uno, con su foto |

## Lo que NO se resolvió

- **Cordero con Piel de Lobo Dulce quedó como borrador**: las fuentes dicen *"blend"*, otras
  Chenin o Moscatel, y ninguna de las dos está en la lista cerrada de varietales. Lleva
  *Torrontés* **sin confirmar**; se publica cuando el dueño mire la contraetiqueta. Si es
  Chenin o Moscatel, agregarla es un cambio en dos lugares y CI (`auditar_varietales.mjs`).
- **Lo que eligió el script y el dueño puede corregir**: la línea de cinco vinos que la lista
  no decía (Salentein *Reserva*, Fabre Montmayou *Reserva*, Trivento *Reserve*, El Buscapleito
  *Bonarda Reserva*, Coquena *Cabernet Sauvignon*), el Argento *orgánico Estate*, el corte de
  Brazos de los Andes (varía por añada), y el Cafayate Terroir de Altura como Malbec.
