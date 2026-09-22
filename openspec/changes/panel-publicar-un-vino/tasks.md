# Tareas

**Workflow D** — HU-03.5 y HU-03.6 tocan plata: `revisor-pagos` es obligatorio
y el backend va verificado **antes** que la pantalla.

Orden de implementación = orden de deploy: `contratos` y reglas primero, el
panel después. **Sin `functions/` y sin tienda.**

## 0. Destrabar: entregar el change anterior

`panel-cargar-un-vino` toca `firestore.rules` y está **sin desplegar**. Si este
change edita las reglas antes, un solo deploy publica los dos y se pierde qué
rompió qué.

- [x] 0.1 Desplegar las reglas de `panel-cargar-un-vino`. Hecho el 2026-09-21,
      autorizado por el dueño. Ruleset `a4520800` → `0310466f`. Aparecen
      `slug == productoId` (0→1), `graduacion` (0→5), `graduacionValida` (0→2)
      y `Pinot Grigio` (0→1). Control positivo `fichaValida` 2→2; negativo
      `inventadoQueNoExiste` 0→0. La fuente publicada es byte a byte
      `firestore.rules`.
- [x] 0.2 `bash scripts/panel/publicar.sh promover panel`. Hecho: `hosting:clone`
      del canal `panel` a live, sin recompilar. Antes verifiqué el canal: los
      cuatro hashes contra el build de la corrida 35394181820 y el control
      negativo. No hubo push entre verificar y promover.
- [x] 0.3 `bash scripts/panel/publicar.sh verificar https://bouquet-vinos.web.app`
      — exit 0. Canario `COMMIT`: live pasó de `3b46a39` a `d871218`. Los
      cuatro hashes coinciden, el archivo inventado no pasa por `main.dart.js`
      y el `X-Robots-Tag: noindex` sigue.
- [x] 0.4 Tildado 9.2 y 9.5 en `panel-cargar-un-vino/tasks.md`. **9.6 queda
      abierta**: es el dueño cargando un vino de verdad y mirándolo.

## 1. Medir producción antes de endurecer las reglas

Las dos reglas nuevas pueden rebotar documentos que **ya existen**. Se mide, no
se supone.

- [x] 1.1 Listar los productos con `publicado == true` y `precio <= 0`. Dio
      **0** sobre 20 documentos. **Control positivo:** el mismo filtro con
      `precio <= 99999999` devuelve **20**, así que el filtro discrimina.
- [x] 1.2 Listar los productos con alguna entrada de `imagenes` que no empiece
      con `https://`. Dio **0**. **Control positivo:** leí **19** URLs en
      total, todas de Firebase Storage — no estoy mirando un campo vacío.
- [x] 1.3 No apareció ninguno: las dos reglas nuevas no dejan atascado nada de
      lo que ya está. Dos datos de yapa, medidos el 2026-09-21: `fichaVino` en
      producción tiene sólo `anada, bodegaId, color, organico, region,
      varietales, volumenMl` —**ni siquiera `graduacion`**, los 20 documentos
      son anteriores—, así que sumar `descripcion` al `hasOnly` es aditivo. Y
      **los 20 productos son `muestra: true`**: hasta que el dueño cargue un
      vino real (9.6 del change anterior) el interruptor de publicar no se
      puede probar contra producción, porque en un vino de muestra está
      deshabilitado a propósito.

## 2. `contratos` — las fixtures del balde, el tope y los descartes

- [x] 2.1 `packages/contratos/src/producto.ts`: `CASOS_DE_BALDE` (10) y
      `CASOS_DE_DESCARTE` (11), al lado de `balde` y `tope`, patrón
      `ENTRADAS_DE_TEXTO`. **`balde`, `tope` y `armarCatalogo` intactos**
      (diff 100 % aditivo, `git diff --numstat` da `218 0`).
- [x] 2.2 Los 10 casos del balde cubren los **tres** baldes y las dos formas
      de unidad —suelta y caja—, más los cuatro bordes: el umbral (6/7), el
      tope (12/13) y el stock negativo.
- [x] 2.3 Los 11 casos de descarte cubren **dos que entran** (suelta y caja) y
      las **cinco** clases: `no-valida`, `slug-duplicado`, `no-publicado`,
      `compuesto`, `bodega-inexistente` — la lista exacta y exhaustiva de
      `armarCatalogo`.
- [x] 2.4 `packages/contratos/scripts/generar.mjs`: `fixturesDelCatalogo()` y
      el bloque `catalogo`, calculados llamando a `balde`, `tope` y
      `armarCatalogo` reales — ninguna salida escrita a mano.
- [x] 2.5 Regenerado. **Determinismo verificado:** dos corridas seguidas,
      mismo sha256. Control negativo del propio chequeo: un byte de más en la
      copia y `cmp` sale 1.
- [x] 2.6 `scripts/ci/auditar_estados.mjs`, sección "2 quater": los tres
      baldes, las dos unidades, los dos cortes del tope, y de los descartes
      un control positivo (al menos uno que entra) **y** uno negativo (al
      menos uno que no). Compara además la etiqueta declarada (`clase`)
      contra lo que `armarCatalogo` hizo de verdad.
      **Dos controles negativos del auditor, corridos y revertidos:** un solo
      balde → `1` ("ningún espejo que devuelve siempre el mismo balde
      pasaría"); los dos que entran puestos en `publicado: false` → `1`,
      nombrando el id que se declaraba "entra" y `armarCatalogo` descartó.
- [x] 2.7 `FichaVino.descripcion: string | null` y su validación en
      `validarFicha`: opcional como `anada`; si viene, no vacía al recortar y
      de hasta `DESCRIPCION_MAXIMA` (600) caracteres.
- [x] 2.8 `ProductoPublicado.descripcion` y `proyectarProducto`. **Sin esto el
      campo es de escritura**, como le pasa hoy a `graduacion`.
- [x] 2.9 Tests del contrato: 24 → 28 tests en `producto.test.ts`. **Control
      negativo:** sacando la validación fallan 3 de los 4 nuevos; el cuarto
      —el del camino feliz— sigue pasando, que es lo correcto. El tope va
      ESCRITO (`assert.equal(DESCRIPCION_MAXIMA, 600)`) y no leído de la
      constante: un test que arma el caso con la constante pasa con el tope
      en 5.
- [x] 2.10 `npm run -w @bouquet/contratos test`: **180/180**. `npx tsc
      --noEmit` en `contratos` y en `apps/tienda`: **0 errores** (encontró los
      5 constructores de `ProductoPublicado` de los tests, que faltaba
      completar).

## 3. Reglas — las tres condiciones

- [x] 3.1 `firestore.rules`: `allow delete: if false` en `productos`, con el
      porqué al lado (hallazgo 1 de `revisor-pagos`, ADR 008).
- [x] 3.2 `precioCoherente(d)`: `publicado == false || precio > 0`. Un no
      publicado sigue pudiendo tener 0.
- [x] 3.3 `imagenesValidas(l)`: el tope de 10 **y** una condición por índice.
      Las reglas no iteran —no hay `map`, `filter` ni `for`—, así que la
      única forma demostrable es escribir los diez, y cada uno se cumple solo
      cuando la lista es más corta. La lista vacía sigue siendo válida.
- [x] 3.4 `scripts/reglas/productos.test.mjs`: los casos del spec
      `catalogo-producto`, **cada uno con su aceptado y su rechazado** —borrar
      vs. despublicar; publicar con 0 vs. con 1; publicar uno guardado con 0;
      `http://`, un número y `[]`.
- [x] 3.5 Suite entera contra el emulador: **53/53**, de 38 a 53 tests (+15,
      que son los nuevos). Dos preguntas que sólo el emulador contesta, y las
      contestó: **`matches()` compara la cadena entera** —`xhttps://…` rebota—
      y **`size()` cuenta caracteres, no bytes** —600 eñes entran—. Si contara
      bytes, el tope real en castellano sería la mitad del que dice el
      formulario.
- [x] 3.6 `fichaValida`: `descripcion` entra en el `hasOnly`, y si está tiene
      que ser `string`, con `.trim().size() > 0` y `.size() <= 600`. El tope
      vive acá y no sólo en el formulario: el catálogo entero viaja al
      navegador.
- [x] 3.7 Los casos de `descripcion` en la suite de reglas, cada uno con su
      lado que pasa: sin clave, texto normal, `'   '`, 600 y 601.
- [x] 3.8 **Cinco mutaciones**, cada una rompiendo exactamente lo suyo:
      sin `allow delete: if false` → 2; sin `precioCoherente` → 3; volviendo
      `imagenesValidas` a la regla vieja (sólo el tope) → 2; sin
      `descripcionValida` → 3. Y la que más importaba: debilitar **sólo el
      índice 9** de `imagenValida` rompe **sólo** el test que mira la última
      posición, así que las diez condiciones no son decorativas. Restaurado y
      53/53.

## 4. `apps/admin` — el espejo (Dart puro, con tests)

- [x] 4.1 `core/contratos/catalogo_publico.dart`: `Balde` (con `.clave`
      string↔JSON, guion no camelCase), `balde(...)`, `tope(...)` y
      `MotivoDeDescarte` (5 valores), espejo del contrato.
- [x] 4.2 `test/core/contratos/catalogo_publico_test.dart`: compara **contra
      `generated/contratos.json`**, control positivo (3 baldes) y negativo (5
      clases).
- [x] 4.3 `domain/producto_del_panel.dart`: `imagenes` (`List<String>`,
      default `const []`).
- [x] 4.4 `data/repositorio_de_productos_firestore.dart`: lee `imagenes` con
      `textosDe`.
- [x] 4.5 `domain/en_la_tienda.dart`: `revisarParaLaTienda(producto, catalogo)`
      espeja el ORDEN exacto de `armarCatalogo` (válida → slug duplicado → no
      publicado → compuesto → bodega inexistente), sobre lo que ya está en
      memoria. Incluye `sinFoto`, que no frena. Cero lecturas.
      **Agregado por mí, después del primer paso:** `revisarParaPublicar`, la
      misma revisión pero simulando `publicado: true` — sin ella, un borrador
      siempre daba `noPublicado` y tapaba el motivo real (precio en 0, bodega
      inexistente) que HU-03.6 necesita mostrar **antes** de publicar. 6 tests
      propios, con control: un publicado con precio 0 (imposible en
      producción, pero si un documento roto lo tuviera) no esconde el motivo.
- [x] 4.6 `test/features/catalogo/en_la_tienda_test.dart`: los 5 escenarios del
      spec `panel-espejo-vidriera`, cada uno con el caso que pasa al lado, MÁS
      los 11 `casosDeDescarte` del contrato generado comparados uno a uno
      (documento crudo → `ProductoDelPanel` → misma `clase`).
      **Ambigüedad resuelta:** `Catalogo.quienTiene` ganó `exceptoId`
      (default `null`, sin cambiar el comportamiento de HU-03.2) — sin
      excluirse a sí mismo, un vino real siempre se encontraba primero y el
      escenario "slug duplicado, en los dos" nunca llegaba al choque real.
      **Ambigüedad resuelta:** "compuesto" no es distinguible de "simple sin
      el campo stock" desde `ProductoDelPanel` (no lleva `tipo`); se usa
      `stock == null` como proxy, ya documentado así en el propio campo, y
      hoy el panel no da de alta compuestos (Non-goal, EP-05) así que no
      colisiona con ningún caso real.
- [x] 4.7 `domain/cambio_de_precio.dart`: `pideConfirmarElCambio(...)` — 10×
      la mediana (ambas direcciones, sólo con 5+ publicados) O mitad/doble del
      anterior (cualquiera de las dos dispara). Con menos de 5 publicados sólo
      aplica la condición relativa.
- [x] 4.8 `test/features/catalogo/cambio_de_precio_test.dart`: pide y no pide
      confirmación, con menos de 5 publicados y con muchos, bordes exactos
      incluidos (justo el doble no pide; un poco más sí).
- [x] 4.9 `domain/ficha_del_vino.dart` y `domain/borrador_de_vino.dart`:
      `descripcion` (`String?`), `CampoDelVino.descripcion`,
      `conDescripcion(...)` **sin la puerta de `precioFijo`** y el tope medido
      sobre el texto YA RECORTADO —medirlo sobre lo tecleado rebotaría un
      texto que cabe—. `descripcionMaxima = 600` en el espejo de
      `core/contratos/producto.dart`, y `auditar_varietales.mjs` ahora compara
      las **tres** copias del número: control negativo corrido de los dos
      lados, panel en 500 → rojo, reglas en 500 → rojo.
      Tests del panel: 146 → **153**, `dart analyze` limpio (atrapó el
      `switch` no exhaustivo de los rótulos). Dos mutaciones, un test roto
      cada una.
- [x] 4.10 `domain/repositorio_de_productos.dart`: `publicar(id)`,
      `despublicar(id)` y `cambiarPrecio(id, centavos)`.

## 5. `apps/admin` — data

- [x] 5.1 `publicar`/`despublicar`: `update` de `publicado` y nada más.
- [x] 5.2 `cambiarPrecio`: `update` de `precio` y nada más. **Ninguno de los
      tres toca `stock`, `tipo`, `presentacion`, `muestra` ni `slug`** —
      `_actualizarUnCampo` privado, compartido por los tres.
- [x] 5.3 `data/documento_del_vino.dart` escribe `fichaVino.descripcion` y
      **omite la clave** cuando es `null`; `campos.dart` gana
      `textoOpcionalDe`, que lee el blanco como `null` —el Admin SDK no pasa
      por las reglas y un documento viejo puede traerlo—. El test del mapeo
      compara las claves contra `firestore.rules` **leyendo el archivo**, que
      es la unidad externa que le faltaba.
- [x] 5.4 Los tres traducen el fallo de Firestore con `fallos_de_firestore.dart`,
      para que un rechazo de reglas no se lea como un problema de permisos.

## 6. `apps/admin` — presentation, de la hoja a la página

- [x] 6.1 `vino/revision_para_publicar.dart` (43 líneas) — llama SIEMPRE a
      `revisarParaPublicar` (nunca `revisarParaLaTienda`), motivo por motivo
      vía `textoDelMotivoParaPublicar`, y el aviso de "se va a ver sin foto"
      que no frena.
- [x] 6.2 `vino/interruptor_de_tienda.dart` (129 líneas) — publicar sólo
      habilitado si `revisarParaPublicar(...).aparece`; despublicar
      inmediato, sin diálogo, con `SnackBar` + "Deshacer" (vuelta atrás con un
      toque); sin estado optimista propio — el stream de Firestore ya revierte
      solo si las reglas rebotan. No disponible en `muestra`, con el texto de
      por qué.
- [x] 6.3 `vino/como_se_ve_en_la_tienda.dart` (76 líneas) — balde en palabras
      + número exacto de stock + tope, motivo real con `revisarParaLaTienda`
      cuando no aparece. **El enlace a la ficha, resuelto sin inventar una
      URL**: la vidriera nunca se desplegó, así que muestra el path relativo
      `/vinos/<slug>` como texto informativo, no un link tocable, con nota de
      que todavía no hay tienda publicada — cita el Open Question de
      design.md para cuando exista el dominio.
- [x] 6.4 `vino/hoja_de_precio.dart` (175 líneas) — hoja modal con el precio
      nuevo, diálogo de confirmación con los DOS precios en pesos cuando
      `pideConfirmarElCambio` da `true`, y el aviso de ~13 minutos a cargo del
      llamador (`SeccionDeLaTienda`) después de guardar, siempre.
- [x] 6.5 `vino/pagina_del_vino.dart` (132 líneas) — `SeccionDeLaTienda` (76
      líneas, archivo propio) agrupa 6.1–6.4 y se inserta ARRIBA del
      formulario, sólo al corregir un vino existente, nunca en un alta.
- [x] 6.6 `renglon_de_producto.dart` (198 líneas, al límite) + nuevo
      `motivo_corto_de_tienda.dart` — el motivo corto vía `Catalogo` pasado
      desde `lista_del_catalogo.dart`/`pantalla_del_catalogo.dart`. **Es el
      renglón que ya existe**, ampliado con un parámetro opcional.
- [x] 6.7 El campo de descripción en `seccion_del_vino.dart` (142 líneas) —
      multilínea, contador de lo que queda sobre `descripcionMaxima`, y
      `b.conDescripcion(v)` directo, **sin** el gate de `precioFijo`.
- [x] 6.8 Textos nuevos en `textos_del_vino.dart` (107 líneas) y
      `textos_del_catalogo.dart` (39 líneas), uno por escenario del spec. No
      pasó por `voz`: es el panel, no una pantalla que ve un comprador.
      ⚠️ Verificado por lectura de código (agente de UI cortado por rate
      limit antes de correr `dart analyze` — retomado y revisado a mano);
      falta correr `dart analyze`/`dart test` **por CI**, no localmente.

## 7. `apps/tienda` — la ficha muestra la descripción

La vidriera **nunca se desplegó** (medido: sin `apphosting.yaml`, sin backends,
sin Cloud Run), así que esto no agrega un objetivo al deploy. Se verifica con
`npm run dev`, y **en `localhost`, no en `127.0.0.1`**: ahí el HMR falla y React
no monta, y parece un defecto del componente.

- [x] 7.1 `features/catalogo/NotaDelVino.tsx` (componente propio, nacido
      dentro de la feature — regla 1 de ADR 006), enganchado en
      `FichaDeVino.tsx`. La sección con la descripción,
      que **desaparece entera** cuando no hay. Texto plano y `white-space:
      pre-line` para los saltos de línea: nunca `dangerouslySetInnerHTML`.
- [x] 7.2 Título: **«De esta botella»**, confirmado por el agente `voz` sin
      cambios — mismo patrón de largo y forma que «Los datos» y «Hasta que
      sale», cero vocabulario de autoridad enológica (grepeado contra §7.1,
      control negativo, con «Elegí»/«Llevate» como control positivo de que el
      grep lee), y distingue prosa libre de dato estructurado por contraste
      (no dice «datos» ni «ficha»).
      ⚠️ **Hallazgo del propio `voz`, para anotar en ADR 014 o `_index.md`:**
      el disparador de voz.md §12 —"antes del primer vino con descripción
      sensorial"— ya se cumplió: `FichaVino.descripcion` es un campo real en
      producción (commit `633f7bf`) sin ningún campo de autoría, y voz.md §3.2
      dice "sin autor, no existe". No es un problema de este título; es una
      decisión del dueño sobre el dato que todavía nadie tomó.
- [x] 7.3 El listado **no la dibuja** —cero títulos, ningún `<p>` con el
      texto— pero **sí viaja en el payload serializado**, porque el catálogo
      entero va al navegador para filtrarse en memoria. Medido, no supuesto, y
      anotado en el spec: es exactamente lo que acota el tope de 600.
- [x] 7.4 `npm run dev` en `localhost`, los tres casos en la misma corrida:
      **con** descripción la sección aparece y los dos saltos de línea
      sobreviven vía `pre-line`, sin un solo `<br>` inyectado; **sin**
      descripción no hay ni título ni hueco; y una con `<b>` y `<script>` se
      sirve como `&lt;b&gt;`, con **cero** `<script>alert(1)</script>`
      ejecutable en la página.
      Para poder mirarlo hizo falta un vino con texto: se lo escribí a
      `muestra-alamos-malbec` (dato de prueba, `muestra: true`) con
      `updateMask.fieldPaths=fichaVino.descripcion`, que **fusiona** — las
      otras siete claves de la ficha sobrevivieron, y eso se verificó. Se
      borra con un `PATCH` del mismo campo en `null`.

## 8. Verificar lo escrito, antes de commitear

- [x] 8.1 `dart format` corrido **por archivo, al tocar cada uno** (el
      usuario cortó dos corridas de `dart analyze lib test` completas,
      colgadas a 120s+: *"para que mierda tenemos CI"*). Sin cambios
      pendientes en lo tocado de este change.
- [~] 8.2 `dart analyze lib test` — **delegado a CI** (`alcance=panel`, que
      además compila el panel para 10.4). No se corre la suite completa en
      esta máquina. La IDE sí mostró diagnósticos en vivo mientras se
      editaba, y quedaron todos en cero antes de seguir.
- [~] 8.3 `dart test` del panel — corrido **archivo por archivo** contra lo
      tocado (`borrador_de_vino_test.dart` 35/35,
      `en_la_tienda_test.dart` 53/53, más los de `admin-datos` y
      `admin-presentacion`), nunca la suite completa. El conteo total va por
      CI. `npm test` de contratos: **185/185**. `npx tsc --noEmit` en
      `contratos` y `apps/tienda`: **0 errores**.
- [x] 8.4 `node scripts/ci/auditar_estados.mjs`: verde, con su control
      negativo corrido y revertido (BAJO 2 de `revisor-pagos`).
      `node scripts/ci/auditar_varietales.mjs`: verde (y atrapó una mutación
      de prueba sin revertir que no era mía, restaurada).
- [x] 8.5 `bash scripts/hooks/probar_hooks.sh`: **35/35**. Los 12 archivos
      nuevos/tocados de `presentation/` y `domain/` corridos a mano contra
      `widget-size-guard`, `one-widget-per-file`, `no-hardcoded-colors` y
      `layer-boundary` con ruta absoluta: limpios. Canario negativo de
      `widget-size-guard` con un archivo de 251 líneas: bloquea.
- [x] 8.6 `node scripts/ci/verificar_enlaces.mjs .`: **443/443**.
- [x] 8.7 **`cazador-de-puertas`**: sin hallazgos. Cadena completa verificada de
      dominio → widget → `SeccionDeLaTienda` → `PaginaDelVino` → ruta
      `/catalogo/vinos/<id>` en `enrutador.dart` → click real desde
      `RenglonDeProducto`. Los 9 textos nuevos con call site. Control
      negativo: un símbolo inventado da grep vacío.
- [~] 8.8 **`revisor-pagos`, primera pasada** (2026-09-18, reglas + contrato +
      descripción): 2 ALTO, 3 MEDIO, 2 BAJO. Los dos ALTO resueltos entonces.
      ⚠️ Corrida **después** de commitear.

      **Segunda pasada (2026-09-22, HU-03.5/03.6/03.7, obligatoria por
      Workflow D y corrida ANTES de commitear esta vez):** corrió
      `armarCatalogo` de verdad contra 12 documentos de contraste, no leyó el
      código a ojo. **2 ALTO, 3 MEDIO, 4 BAJO — los 9 corregidos:**
      - **ALTO 1** — el interruptor de la tienda (arriba, en la misma página
        que `formulario_del_vino.dart`) podía publicar un vino mientras el
        formulario seguía abierto con `precioFijo` congelado en el snapshot
        de cuando se abrió la página: el precio nuevo viajaba **sin** la
        baranda de HU-03.5. Corregido con
        `BorradorDeVino.conOriginalActualizado` + `didUpdateWidget` en
        `_FormularioDelVinoState`, que refresca el `original` sin tocar una
        letra de lo tecleado. 2 tests nuevos.
      - **ALTO 2** — `revisarParaLaTienda` usaba `ChoqueDeDireccion.bloquea`
        para "¿hay slug duplicado?", pero esa bandera contesta "¿se puede
        guardar el ALTA?" (ADR 013 §1: un choque contra un vino de muestra
        se avisa y no frena). El primer vino real que compartiera nombre con
        uno de muestra quedaba afuera de la vidriera **y el panel decía que
        estaba adentro**. Corregido sacando el `.bloquea`: cualquier otro
        documento con el mismo slug, de muestra o no, es `slugDuplicado`. Par
        de fixtures nuevo en `CASOS_DE_DESCARTE` (real + muestra compartiendo
        slug) que hacía fallar la fixture vieja. 2 tests nuevos en Dart.
      - **MEDIO 1** — el espejo de `_valida()` sólo cubría 4 de ~12 familias
        de "no válida". Se sumaron las 6 que el mapeo del panel NO pisa con
        un default antes de que el dominio las vea: slug con el formato de
        `SLUG`, `volumenMl` ausente o ≤0, `anada`/`graduacion` presentes pero
        fuera de rango, varietales repetidos, descripción sobre el tope. Las
        otras 4 (`botellas < 1`, `organico` mal tipado, `imagenes` ausente
        vs. vacía, compuesto con stock) quedan **documentadas como límite
        real**: `campos.dart` ya las normaliza con un default al leer el
        documento, antes de que `en_la_tienda.dart` las vea — cerrarlas pide
        cambiar cómo el panel entero lee Firestore, no esta revisión. 6
        fixtures nuevas, todas con su motivo verificado contra el JSON.
      - **MEDIO 2** — el "Deshacer" del `SnackBar` de despublicar llamaba a
        `_cambiar(true)` sin `mounted` (revienta si ya se volvió al
        catálogo: el `ScaffoldMessenger` vive arriba del `Navigator`) y sin
        `revisarParaPublicar` (publica a ciegas si algo cambió en el rato
        que el aviso estuvo abierto). Las dos corregidas.
      - **MEDIO 3** — `HojaDePrecio` evaluaba la baranda contra el precio y
        la mediana del momento en que se abrió, no contra la base: un cambio
        de otra persona mientras la hoja estaba abierta se pisaba sin que la
        baranda lo viera. Corregido releyendo el catálogo vivo (0 lecturas,
        ya está en memoria) justo antes de decidir.
      - **BAJO 1** — el texto de "compuesto" afirmaba algo que el panel no
        puede distinguir de "simple sin stock cargado". Texto corregido en
        los dos lados (`textoDelMotivoEnLaTienda`/`textoDelMotivoParaPublicar`).
      - **BAJO 2** — el auditor tenía el `motivo` real en la mano y nunca lo
        comparaba contra la `clase` declarada. Agregado en
        `auditar_estados.mjs`, con control negativo corrido y revertido: una
        `clase` mal puesta en `producto.ts` (`no-publicado` escrito como
        `no-valida`) nombra el id y la clase real.
      - **BAJO 3** — la spec pedía publicar/despublicar también desde el
        renglón del catálogo, y el código sólo agregó el motivo corto. Se
        corrigió la spec en vez del código: un interruptor inline en una
        lista arriesga despublicar por un toque de más sin la revisión
        previa al lado. La acción queda sólo en la página.
      - **BAJO 4** — nada que hacer, quedó anotado que se revisó.
      13 caminos verificados sin hallazgos (los tres métodos de escritura
      tocan un solo campo cada uno, el panel no ofrece borrar en ningún
      lado, `imagenes` no se escribe por ningún camino nuevo, cero lecturas
      de más, el orden de `revisarParaLaTienda` replica a `armarCatalogo`
      paso por paso, entre otros). Detalle completo en el hand-back del
      agente, resumido acá y en ADR 014.

- [x] 9.1 ADR 014: sección nueva "HU-03.5, HU-03.6 y HU-03.7" con la
      arquitectura construida, los 9 hallazgos de la segunda pasada de
      `revisor-pagos` con su arreglo, y "Lo que falta" reescrita (reglas
      desplegadas, sólo falta el deploy del panel y publicar un vino real).
- [x] 9.2 ADR 008: hallazgos 1 y 2 de `revisor-pagos` marcados RESUELTO,
      apuntando a ADR 014. EP-03: HU-03.5 (baranda) y HU-03.6 (interruptor,
      `delete` cerrado) y HU-03.7 (espejo) marcadas CONSTRUIDO. **EP-03 queda
      CERRADA.**
- [x] 9.3 `_index.md` (tope 5, entrada de 2026-09-16 movida a `_log.md` con
      sus links reajustados). El propio agente de vault encontró y corrigió
      una contradicción preexistente: ADR 014 decía "reglas sin desplegar" en
      dos lugares cuando ya estaban en producción desde el 2026-09-21.
- [ ] 9.4 `/commit` leyendo el diff. Los 9 hallazgos de la segunda pasada de
      `revisor-pagos` (sección nueva de ADR 014) ya están corregidos, cada
      uno con test — esta vez la revisión corrió **antes** de commitear.

## 10. Desplegar y verificar — reglas → panel

- [x] 10.1 **`git status --short` vacío antes de desplegar.**
      `firebase deploy --only firestore:rules` sube el **árbol de trabajo, no
      HEAD**: el ruleset `0310466f` salió con una línea sin commitear adentro.
      Comparar el ruleset publicado con **HEAD y con el archivo del árbol**: la
      diferencia es sólo la de este change.
      Hecho: árbol en 0 sucios, `firestore.rules` idéntico a
      `HEAD:firestore.rules` (`63ab77d`), y contra lo publicado 58 líneas
      agregadas y 4 quitadas, todas de este change.
- [x] 10.2 **Reglas** desplegadas el 2026-09-21: `0310466f` → `04b8a471`.
      Cuatro canarios que **aparecen** (`precioCoherente`, `imagenesValidas`,
      `descripcionValida`, `'descripcion'`, todos 0→2) y uno que
      **desaparece**: `allow delete: if esAdmin()` 2→1 — bodegas lo conserva,
      productos no. Control positivo `fichaValida` 2→2, negativo
      `inventadoQueNoExiste` 0→0. La fuente publicada es byte a byte el
      archivo del árbol **y de HEAD**.
- [x] 10.3 **Escrituras reales contra el ruleset publicado**, bajado de la API
      y corrido en el emulador — los bytes que sirven, no el archivo del repo.
      El documento que congelé (`descripcion` con el `hasOnly` viejo) **vuelve
      a editarse**: nombre, precio y `publicado`. Control positivo: uno sin
      descripción sigue editándose. Y las tres condiciones, cada una con su
      lado que pasa: borrar rebota / despublicar pasa; `precio: 0` rebota;
      `http://` rebota / `https://` pasa; `'   '` rebota / un texto pasa.
- [ ] 10.4 CI `alcance=panel`. **Leer la corrida, no el color** — `build_panel`
      en `success`, que `skipped` no cuenta.
- [ ] 10.5 `publicar.sh preview` → hashes, canarios (uno nuevo y uno que
      desaparece, **sin tildes**: `dart2js` los escapa) y que la app arranca
      sin errores de consola.
- [ ] 10.6 `publicar.sh promover` y `publicar.sh verificar` sobre live.
- [ ] 10.7 **Que alguien publique un vino de verdad y lo mire en la tienda.**
      Sin esto el change no se archiva.
- [ ] 10.8 `/opsx:archive`, recién después de 10.7.
