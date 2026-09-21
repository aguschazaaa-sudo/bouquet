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

- [ ] 2.1 `packages/contratos/src/producto.ts`: exportar las entradas de
      muestra (`CASOS_DE_BALDE`, `CASOS_DE_DESCARTE`) al lado de `balde` y
      `tope`, como ya hace `texto.ts` con `ENTRADAS_DE_TEXTO`. **No se toca ni
      `balde`, ni `tope`, ni `armarCatalogo`.**
- [ ] 2.2 Los casos del balde cubren los **tres** baldes y las dos formas de
      unidad —suelta y caja—: el control positivo y el negativo del espejo.
- [ ] 2.3 Los casos de descarte cubren **uno que entra** al catálogo y uno por
      cada motivo: no valida, slug duplicado, no publicado, compuesto, bodega
      inexistente.
- [ ] 2.4 `packages/contratos/scripts/generar.mjs`: el bloque `catalogo` con
      esas fixtures, calculadas llamando a `balde`, `tope` y `armarCatalogo`.
- [ ] 2.5 Regenerar (`npm run -w @bouquet/contratos generar`) y commitear el
      JSON. Correr dos veces: los bytes tienen que ser idénticos.
- [ ] 2.6 `scripts/ci/auditar_estados.mjs`: auditar el bloque nuevo con sus dos
      controles —los tres baldes, y al menos un documento que entra—.
      **Control negativo del auditor:** una copia del contrato con un solo
      balde sale con 1.
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

- [ ] 4.1 `core/contratos/catalogo_publico.dart`: `Balde`, `balde(...)`,
      `tope(...)` y `MotivoDeDescarte`, espejo del contrato. Con las marcas y
      el comentario que explica por qué vive tres veces.
- [ ] 4.2 `test/core/contratos/catalogo_publico_test.dart`: compara **contra
      `generated/contratos.json`**, iterando las fixtures. No una lista
      copiada.
- [ ] 4.3 `domain/producto_del_panel.dart`: `imagenes`, con el mapeo seguro
      (lista vacía si falta o si el documento trae otra cosa).
- [ ] 4.4 `data/repositorio_de_productos_firestore.dart`: leer `imagenes`.
- [ ] 4.5 `domain/en_la_tienda.dart`: `revisarParaLaTienda(producto, catalogo)`
      → si aparece, y si no, los motivos. Incluye el aviso de "sin foto", que
      **no** frena. Cero lecturas.
- [ ] 4.6 `test/features/catalogo/en_la_tienda_test.dart`: los escenarios del
      spec `panel-espejo-vidriera` y los de la revisión previa de
      `panel-publicar-vino`, con el caso que pasa al lado de cada uno que falla.
- [ ] 4.7 `domain/cambio_de_precio.dart`: la baranda —10× la mediana de los
      publicados, o mitad/doble del anterior—, con el caso de catálogo chico.
- [ ] 4.8 `test/features/catalogo/cambio_de_precio_test.dart`: pide y no pide
      confirmación, con menos de 5 publicados y con muchos.
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
- [ ] 4.10 `domain/repositorio_de_productos.dart`: `publicar(id)`,
      `despublicar(id)` y `cambiarPrecio(id, centavos)`.

## 5. `apps/admin` — data

- [ ] 5.1 `publicar`/`despublicar`: `update` de `publicado` y nada más.
- [ ] 5.2 `cambiarPrecio`: `update` de `precio` y nada más. **Ninguno de los
      tres toca `stock`, `tipo`, `presentacion`, `muestra` ni `slug`.**
- [x] 5.3 `data/documento_del_vino.dart` escribe `fichaVino.descripcion` y
      **omite la clave** cuando es `null`; `campos.dart` gana
      `textoOpcionalDe`, que lee el blanco como `null` —el Admin SDK no pasa
      por las reglas y un documento viejo puede traerlo—. El test del mapeo
      compara las claves contra `firestore.rules` **leyendo el archivo**, que
      es la unidad externa que le faltaba.
- [ ] 5.4 Los tres traducen el fallo de Firestore con `fallos_de_firestore.dart`,
      para que un rechazo de reglas no se lea como un problema de permisos.

## 6. `apps/admin` — presentation, de la hoja a la página

- [ ] 6.1 `vino/revision_para_publicar.dart` — los motivos, campo por campo, y
      el aviso de "se va a ver sin foto".
- [ ] 6.2 `vino/interruptor_de_tienda.dart` — poner y sacar de la tienda, con
      el estado de escritura y la vuelta atrás si rebota. No disponible en un
      vino de muestra, diciendo por qué.
- [ ] 6.3 `vino/como_se_ve_en_la_tienda.dart` — balde, número de stock, tope y
      el enlace a la ficha.
- [ ] 6.4 `vino/hoja_de_precio.dart` — el precio nuevo con su vista previa en
      pesos, la confirmación con los dos precios, y el aviso de los ~13
      minutos.
- [ ] 6.5 `vino/pagina_del_vino.dart` — ordena las secciones nuevas sin pasar
      de 200 líneas (`widget-size-guard`).
- [ ] 6.6 `renglon_de_producto.dart` — el motivo corto cuando un vino publicado
      no aparece. **Es el renglón que ya existe**: no se duplica.
- [ ] 6.7 El campo de la descripción en el formulario del vino: texto largo,
      contador de lo que queda sobre 600, y **editable aunque el vino esté
      publicado** —no es plata, no dispara la baranda—.
- [ ] 6.8 Textos en `textos_del_vino.dart` / `textos_del_catalogo.dart`. **No
      pasa por `voz`**: es el panel, no una pantalla que ve un comprador.

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
- [~] 7.2 Título: **«De esta botella»**, en el patrón de los que ya están
      («Los datos», «Hasta que sale») y sin reclamar autoridad enológica, que
      es lo que `voz.md` §0 prohíbe: bouquet no hace el vino, lo guarda.
      **Falta pasarlo por el agente `voz`** antes de que la vidriera se
      despliegue; hoy no se despliega, así que no llega a ningún comprador.
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

- [ ] 8.1 `dart format` sobre todo lo tocado.
- [ ] 8.2 `dart analyze lib test` en el panel.
- [ ] 8.3 `dart test` del panel; `npm test` y `npx tsc --noEmit`.
- [ ] 8.4 `node scripts/ci/auditar_estados.mjs` y
      `node scripts/ci/auditar_varietales.mjs`.
- [ ] 8.5 `bash scripts/hooks/probar_hooks.sh`, y los hooks del panel sobre los
      archivos nuevos **con ruta absoluta** y un canario positivo.
- [ ] 8.6 `node scripts/ci/verificar_enlaces.mjs .`
- [ ] 8.7 **`cazador-de-puertas`**: nadie huérfano, con control negativo.
- [~] 8.8 **`revisor-pagos`**: corrido sobre la rebanada de reglas + contrato +
      descripción. 2 ALTO, 3 MEDIO, 2 BAJO. Los dos ALTO **resueltos** (la
      proyección espeja `precioCoherente`; el documento congelado lo destraba
      el deploy de reglas), los otros cinco anotados en ADR 014 con su
      disparador. **No cierra la tarea**: HU-03.5 y HU-03.6 —el interruptor y
      el cambio de precio, que son lo que de verdad toca plata— todavía no
      existen y necesitan otra pasada.
      ⚠️ Lo corrí **después** de commitear, y esta tarea dice antes.

## 9. Documentar y commitear

- [ ] 9.1 ADR 014 con el presupuesto de lecturas adentro, la decisión de la
      foto, la baranda de la mediana y el aviso de los ~13 minutos.
- [ ] 9.2 ADR 008: tildar los hallazgos 1 y 2 de `revisor-pagos`, apuntando al
      014. EP-03: cerrar el "Abierto" de la foto y el de la baranda.
- [ ] 9.3 Mapa del panel y `_index.md` (tope 5). Glosario si cambia algo.
- [ ] 9.4 `/commit` leyendo el diff.

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
