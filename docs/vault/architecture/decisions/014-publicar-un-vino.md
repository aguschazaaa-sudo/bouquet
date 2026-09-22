# ADR 014 — Endurecer el producto, y la descripción punta a punta

- **Fecha:** 2026-09-21
- **Estado:** aceptada y **aplicada en el código**. **Reglas desplegadas**
  (`04b8a471`, 2026-09-21); **panel sin desplegar** todavía: ver *Lo que
  falta*
- **Decide:** que un producto no se borre nunca, que un vino publicado tenga
  precio, que cada imagen sea una URL `https://`, y que la ficha de un vino
  lleve una **descripción** que el comprador lee
- **Historias:** parte de HU-03.4 (la descripción) y la base de HU-03.5 ·
  HU-03.6 ([EP-03](../../features/panel/EP-03-productos.md))
- **Toca:** [ADR 008](008-catalogo-stock-y-carrito.md) — cierra sus hallazgos
  1 y 2 de `revisor-pagos` — y [ADR 013](013-cargar-un-vino.md), que ya está
  desplegado
- **Hace cumplir:** `firestore.rules` (15 casos nuevos en
  `scripts/reglas/productos.test.mjs`, con cinco mutaciones),
  `scripts/ci/auditar_varietales.mjs` —ahora compara **cuatro** números en
  tres copias—, los tests de `contratos` y los de Dart
- **Planificación:** `openspec/changes/panel-publicar-un-vino/`

## Contexto

Dos agujeros que `revisor-pagos` dejó anotados en ADR 008 seguían abiertos, y
los dos son de plata, no de higiene:

1. **Un admin podía borrar un producto.** Borrar y recrear con el mismo id
   **se saltea** la inmutabilidad de `tipo` y de `presentacion.botellas` que el
   `update` garantiza. Una botella suelta con stock 10, recreada como caja de
   2, deja **12 botellas a la venta sobre 10 físicas** después de una
   cancelación.
2. **Se podía publicar con `precio: 0`.** Pasaba las reglas
   (`d.precio is int && d.precio >= 0`) y el validador de `contratos`, y un
   `precioUnitarioVisto: 0` coincidiría cuando exista `crearOrden`.

Y un tercero que nadie había anotado: **las reglas no miraban el contenido de
`imagenes`, sólo su largo.** `armarCatalogo` sí exige el `https://`, así que
una entrada que no lo cumpla **descarta el producto entero de la vidriera sin
un error visible**. La regla y la proyección tienen que pedir lo mismo.

Aparte, el dueño contestó el 2026-09-21 la pregunta que EP-03 tenía abierta
desde el mapa del panel (hallazgo 14): **la ficha del vino lleva una
descripción.**

## Decisión

### 1. Un producto no se borra: se despublica

`allow delete: if false` en `productos`, para todos los clientes, **incluido un
admin**. Sacar un vino de la venta es `publicado: false`, que tiene vuelta
atrás con un toque y conserva el id, el slug y la historia.

El seed sigue funcionando porque `scripts/seed/proyecto.mjs` usa el Admin SDK
con `applicationDefault()`, que **no pasa por las reglas por diseño**. No es
una suposición: hay un test contra el emulador que borra con
`withSecurityRulesDisabled` y verifica que el documento desapareció.

### 2. Un publicado tiene precio; un borrador puede no tenerlo

`precioCoherente(d)`: `d.publicado == false || d.precio > 0`.

El 0 se prohíbe **sólo cuando el vino está en la tienda**. Un borrador nace en
0 y se completa después, y prohibirlo en el alta rompería HU-03.2.

**Se midió producción antes de escribir la regla**, porque una condición nueva
puede dejar atascado un documento que ya existe —sin poder corregirlo sin
despublicarlo—: **0** productos publicados con `precio <= 0`, con control
positivo (el mismo filtro con `precio <= 99999999` devuelve los 20).

⚠️ **La regla sola NO cierra el hallazgo 2, y `revisor-pagos` lo midió.** La
vidriera lee con el Admin SDK (`applicationDefault()` en
`apps/tienda/src/server/firebase-admin.ts`), que **no pasa por las reglas**:
`firestore.rules` no está en el camino que llega al comprador. La última puerta
es `validarProducto`, y aceptaba `precio >= 0`. Un vino escrito por el seed, por
una reposición o por un script con `publicado: true` y `precio: 0` se
proyectaba, se mostraba en $ 0,00, y el día que exista `crearOrden` un
`precioUnitarioVisto: 0` **coincidiría**.

Por eso `validarProducto` **espeja `precioCoherente`**: un publicado con precio
0 no valida, y `armarCatalogo` lo descarta con su motivo. Las dos mitades, o el
hallazgo no está cerrado.

### 3. Cada imagen es una URL `https://`, escrita diez veces

`imagenesValidas(l)`: el tope de 10 **y una condición por índice**.

**Las reglas de Firestore no iteran**: no hay `map`, `filter` ni `for`. Como el
tope son 10, la única forma demostrable es escribir las diez, y cada una se
cumple sola cuando la lista es más corta. Es largo y es verificable; **una
lista sin tope no se podría escribir así, y por eso el tope va primero.**

La lista vacía sigue siendo válida: un vino sin foto se publica, y
`VentanaDeBotella.tsx:45` ya dibuja la silueta con «sin foto».

Se midió antes: **0** entradas sin `https://` en producción, control positivo
19 URLs leídas.

### 4. La descripción vive en `fichaVino`, y llega al comprador

`FichaVino.descripcion: string | null`, opcional como `anada` y `graduacion`.
Va en `fichaVino` y no al lado de `nombre` porque `fichaVino` está en
`ProductoBase`: **la tienen los dos tipos de producto**, simple y compuesto.
Una caja armada es justo lo que más necesita una descripción.

**Y llega a `ProductoPublicado`.** Sin eso sería un campo de escritura, que es
exactamente lo que le pasa hoy a `graduacion`: el panel la carga y el comprador
no la ve nunca.

`null` es la **única** forma de decir "no se cargó". Una cadena en blanco la
rechazan las reglas: dos maneras de decir nada son dos maneras de leerla.

### 5. El tope son 600 caracteres, y vive en las reglas

El número no es estético. **El catálogo entero viaja al navegador de cada
visitante** para filtrarse en memoria (ADR 006), así que cada carácter lo paga
todo el que abre `/vinos`, no sólo quien abre esa ficha.

**Medido el 2026-09-21, y es distinto de lo que dice la pantalla:** el listado
**no dibuja** la descripción —cero títulos, ningún `<p>` con el texto— pero el
texto **sí viaja en el payload serializado** de `/vinos`. Por eso el tope está
en las reglas y no sólo en el formulario: un formulario se saltea, una regla
no. Si algún día pesa, la salida es proyectar una forma más liviana para el
listado, no bajar el tope.

**`size()` de las reglas cuenta caracteres, no bytes.** Se verificó contra el
emulador con 600 eñes. Si contara bytes UTF-8, el tope real en castellano sería
la mitad del que dice el formulario, y nadie se enteraría hasta que un texto
normal rebotara.

El 600 vive tres veces —`DESCRIPCION_MAXIMA`, `descripcionValida` y
`descripcionMaxima`— y `auditar_varietales.mjs` compara las tres. Sin esa
comparación, los tests de cada lado **se miden contra sí mismos**: pasarían los
tres con el tope en 5.

### 6. La descripción se corrige aunque el vino esté publicado

A diferencia del precio, `conDescripcion` **no** tiene la puerta de
`precioFijo`. No es plata, no dispara ninguna baranda, y arreglar una falta de
ortografía no puede obligar a sacar el vino de la tienda primero.

### 7. En la vidriera es texto plano, y su sección desaparece

`NotaDelVino.tsx` devuelve `null` cuando no hay descripción: se va la sección
**entera**, título incluido. Un vino sin nota se ve completo, igual que uno sin
foto — y hoy casi ninguno la tiene, porque el campo recién existe.

Lo escribe una persona en un formulario, no un editor de confianza: **nunca**
`dangerouslySetInnerHTML`. React escapa, y `white-space: pre-line` respeta los
saltos de línea sin necesitar marcas. Verificado sirviendo una descripción con
`<b>` y `<script>`: sale `&lt;b&gt;`, y hay **cero** `<script>alert(1)</script>`
ejecutable en la página.

El título es **«De esta botella»**, en el patrón de los que ya están («Los
datos», «Hasta que sale»). No reclama autoridad enológica, que es lo que
[`voz.md`](../../design/voz.md) §0 prohíbe: bouquet no hace el vino, lo guarda.

## Por qué NO las alternativas

| Alternativa | Por qué no |
|---|---|
| Que borrar sea sólo del servidor, con una callable | Más superficie para el mismo resultado. La regla es una línea y no se puede saltear |
| Prohibir `precio: 0` siempre | Rompe HU-03.2: un vino nace sin precio y se completa después |
| `imagenes.join()` y una sola regex | Frágil: una URL con el separador adentro rompe la validación en silencio. Diez condiciones son feas y son demostrables |
| La descripción al lado de `nombre`, no en `fichaVino` | `fichaVino` está en `ProductoBase`, así que ya la tienen los dos tipos. Mover el campo no compra nada |
| Sin tope, o el tope sólo en el formulario | El catálogo entero viaja al navegador. Un formulario se saltea |
| `Markdown` o HTML enriquecido en la descripción | Es texto que escribe una persona en un input. Interpretar marcas es una superficie que nadie pidió |
| Proyectar la descripción sólo en la ruta de la ficha | Hoy hay 20 vinos. Es una segunda forma de `ProductoPublicado` que tocaría carrito y checkout, por un costo que el tope ya acota |

## Presupuesto de lecturas

**Cero lecturas nuevas.** Nada de este ADR agrega una consulta:

| Qué | Lecturas | Contra la cuota de 50.000/día |
|---|---|---|
| Las tres reglas nuevas | **0** | Se evalúan sobre `request.resource.data` y `resource.data`, que ya están en memoria. Ningún `get()` ni `exists()` |
| `descripcion` en el alta y en la corrección | **0** | Viaja adentro del mismo documento que ya se escribía |
| `descripcion` en la vidriera | **0** | Sale del mismo `armarCatalogo` que ya corría, cacheado 60 s por `unstable_cache` con tag `catalogo` |

La alternativa que ADR 008 había dejado anotada para el slug —`slugs/{slug}`
con `getAfter()`— costaba **una lectura facturada por evaluación**. No se usa;
la unicidad la da el id, como decidió ADR 013.

## Consecuencias

- Los dos hallazgos abiertos de `revisor-pagos` en ADR 008 **quedan cerrados**.
- `fichaVino` en producción **no tenía ni `graduacion` ni `descripcion`** — los
  20 documentos son anteriores—, así que sumarlas al `hasOnly` es aditivo y no
  rebota nada de lo que ya está.
- **Los 20 productos de producción son `muestra: true`.** Hasta que alguien
  cargue un vino real (9.6 de `panel-cargar-un-vino`), publicar y despublicar
  no se pueden probar contra producción: en un vino de muestra el interruptor
  va deshabilitado a propósito.
- Un vino publicado con una imagen que no es `https://` **ya no se puede
  guardar**. No hay ninguno hoy; si apareciera, hay que arreglar el dato antes
  de que la regla se despliegue.

## HU-03.5, HU-03.6 y HU-03.7: publicar, cambiar el precio, y ver cómo se ve

Lo que `design.md` de este change dejaba decidido (Decisions 1 a 8) **ya no es
plan: es código**, verificado contra el emulador de reglas y contra
`dart test` archivo por archivo — la suite completa la corre CI, que sigue
siendo lo único que compila el panel entero en esta máquina.

- **`apps/admin/lib/core/contratos/catalogo_publico.dart`**: el espejo de
  `balde`, `tope` y `MotivoDeDescarte` (5 categorías), verificado contra
  `packages/contratos/generated/contratos.json` — la unidad externa, no el
  panel comparado consigo mismo (Decision 2 de `design.md`).
- **`apps/admin/lib/features/catalogo/domain/en_la_tienda.dart`**:
  `revisarParaLaTienda` da el estado real que ve la vidriera; `revisarParaPublicar`
  simula `publicado: true` para que un borrador no muestre siempre "no
  publicado" y tape el motivo de fondo —precio en 0, bodega inexistente— que
  HU-03.6 necesita mostrar **antes** de publicar.
- **`apps/admin/lib/features/catalogo/domain/cambio_de_precio.dart`**:
  `pideConfirmarElCambio` — el precio nuevo se aparta 10× o más de la mediana
  de los publicados (sólo con 5 o más) **o** es menos de la mitad o más del
  doble del anterior (Decision 5 de `design.md`).
- **`RepositorioDeProductos`** ganó `publicar`, `despublicar` y
  `cambiarPrecio`, cada uno un `update` de un solo campo — nunca tocan
  `stock`, `tipo`, `presentacion`, `muestra` ni `slug`
  (`_actualizarUnCampo` privado, compartido por los tres).
- **Presentación, bottom-up**: `interruptor_de_tienda.dart` (129 líneas),
  `revision_para_publicar.dart` (43), `como_se_ve_en_la_tienda.dart` (76) y
  `hoja_de_precio.dart` (175), agrupados en `seccion_de_la_tienda.dart` (76) e
  insertados en `pagina_del_vino.dart` **arriba** del formulario, y **sólo**
  al corregir un vino existente — nunca en un alta (Decision 3). El renglón
  del catálogo (`renglon_de_producto.dart`, 198 líneas, al límite del hook)
  gana el motivo corto vía `motivo_corto_de_tienda.dart` cuando un publicado
  igual no aparece.
- **La descripción entró al formulario**, en `seccion_del_vino.dart` (142
  líneas), **sin** el gate de `precioFijo`: no es plata, y una falta de
  ortografía no puede obligar a despublicar primero (§6 de este mismo ADR).
- **`packages/contratos`**: `CASOS_DE_BALDE` (10) y `CASOS_DE_DESCARTE` (19,
  empezó en 11) exportados como fixtures, calculadas llamando a `balde`,
  `tope` y `armarCatalogo` **reales** — mismo patrón que `ENTRADAS_DE_TEXTO`.
  `scripts/ci/auditar_estados.mjs` audita el bloque con sus dos controles: al
  menos un caso que entra al catálogo, al menos uno que no.

### La segunda pasada de `revisor-pagos` (2026-09-22, obligatoria por Workflow D)

Corrió `armarCatalogo` de verdad contra 12 documentos de contraste, no lo leyó
a ojo. **2 ALTO, 3 MEDIO, 4 BAJO — los 9 corregidos antes de commitear**, al
revés de la primera pasada de este mismo ADR (tabla de abajo, hallazgo 2: esa
corrió **después**).

1. **ALTO — el precio publicado podía salir sin la baranda de HU-03.5.** El
   interruptor de publicar vive en la misma página que el formulario de
   edición, arriba. `BorradorDeVino._borrador` se construye una sola vez
   (campo `late`) y `key: ValueKey(vino.id)` evita que se recree cuando el
   catálogo trae el vino actualizado: `precioFijo` — que lee
   `original?.publicado` — quedaba congelado en el momento en que se abrió la
   página. Publicar el vino **con el formulario abierto** y guardar después un
   precio nuevo mandaba ese precio sin confirmación y sin el aviso de los ~13
   minutos. Arreglado con `BorradorDeVino.conOriginalActualizado(nuevo)` —
   refresca sólo el `original`, preserva todo lo tecleado —, llamado desde
   `didUpdateWidget` de `_FormularioDelVinoState`. Cierra el caso de un solo
   operador con dos paneles abiertos y el de dos operadores en dos
   dispositivos, porque lo dispara el mismo stream de Firestore que ya se
   estaba escuchando.
2. **ALTO — "está en la tienda" podía ser falso contra un vino de muestra.**
   `revisarParaLaTienda` usaba `ChoqueDeDireccion.bloquea` de
   `Catalogo.quienTiene` para decidir el slug duplicado, pero esa bandera
   contesta otra pregunta — "¿se puede guardar el ALTA?", donde
   [ADR 013 §1](013-cargar-un-vino.md) decidió que un choque contra un vino de
   **muestra** se avisa y no frena —. `armarCatalogo` cuenta TODOS los
   documentos crudos que comparten un slug, de muestra o no, y descarta a los
   dos **antes** de mirar `publicado`. El primer vino real que compartiera
   nombre con uno de los 20 de muestra — que viven en la misma base:
   `.firebaserc` tiene un solo proyecto — quedaba **afuera de la vidriera** y
   el panel decía que estaba **adentro**: el modo de falla exacto que HU-03.7
   existe para cerrar. Arreglado sacando el `.bloquea`: cualquier choque de
   slug, de muestra o no, es `slugDuplicado`. Un par de fixtures nuevo en
   `CASOS_DE_DESCARTE` (un vino real + uno de muestra compartiendo slug) hacía
   fallar la versión vieja.
3. **MEDIO — el espejo de validación cubría 4 de ~12 familias.** Ampliado a
   10: slug con formato inválido, `volumenMl` ausente o ≤0,
   `anada`/`graduacion` presentes pero fuera de rango, varietales repetidos,
   descripción sobre el tope — todas verificables porque `ProductoDelPanel`
   conserva el dato sin normalizarlo. Las 4 que quedan afuera (`botellas < 1`,
   `organico` mal tipado, `imagenes` ausente vs. lista vacía, un compuesto con
   `stock`) **no son elegibles**: `data/campos.dart` (`enteroDe`, `boolDe`,
   `textosDe`) ya les pone un valor por omisión **al leer** el documento,
   antes de que el dominio los vea — cerrarlas pide cambiar cómo el panel
   entero lee Firestore, no esta revisión. Documentado como límite real en el
   comentario de `en_la_tienda.dart`, no escondido.
4. **MEDIO — "Deshacer" podía reventar o publicar sin revisión.** El
   `SnackBar` de despublicar sobrevive a navegar a otra pantalla
   (`ScaffoldMessenger` vive arriba del `Navigator` en `MaterialApp.router`);
   tocar "Deshacer" después de volver al catálogo llamaba `setState` sobre un
   `State` ya dispuesto. Y el "Deshacer" tampoco pasaba por
   `revisarParaPublicar` antes de republicar. Las dos corregidas: guardia de
   `mounted` primero, y la revisión antes de reintentar publicar.
5. **MEDIO — la hoja de precio decidía con datos viejos.** `HojaDePrecio`
   evaluaba `pideConfirmarElCambio` contra el precio y la mediana del momento
   en que se abrió la hoja modal, no contra la base: un cambio de otra
   persona mientras estaba abierta se pisaba sin que la baranda lo viera, y
   encima con la comparación equivocada. Corregido releyendo el catálogo vivo
   (0 lecturas extra, ya está en memoria) justo antes de decidir.
6. **BAJO — el texto de "compuesto" afirmaba algo indistinguible.** El panel
   no puede distinguir "compuesto" de "simple sin stock cargado" desde
   `ProductoDelPanel`. Corregido en los dos textos que lo usan.
7. **BAJO — el auditor no comparaba el motivo real contra la clase
   declarada.** `scripts/ci/auditar_estados.mjs` ahora lo hace, con control
   negativo: una clase mal puesta en `producto.ts` sale con el id y la clase
   real nombrados.
8. **BAJO — la spec pedía publicar también desde el renglón del catálogo, y
   eso no se construyó.** Se corrigió la **spec**
   (`specs/panel-publicar-vino/spec.md`), no el código: un interruptor inline
   en una fila de lista arriesga despublicar sin la revisión previa al lado.
   La acción queda sólo en la página; el renglón informa.
9. **BAJO — nada que corregir**, quedó anotado que se revisó.

**Trece caminos verificados y sin hallazgo**, entre ellos: los tres métodos de
escritura tocan un solo campo cada uno — grepeado: una sola línea nueva de
`.update(` en todo el diff —; el panel no ofrece borrar en ningún lado;
`imagenes` no se escribe por ningún camino nuevo — sigue siendo sólo de
lectura, EP-04 sigue sin construir —; `revisarParaLaTienda` replica el
**orden** exacto de `armarCatalogo` paso a paso; y las reglas ya desplegadas
(`04b8a471`) cierran el hallazgo 2 de ADR 008 **en la base**, no en la
pantalla.

## Lo que encontró `revisor-pagos` (Workflow D, obligatorio)

Corrió sobre esta rebanada —reglas, contrato y descripción—. **No cubre
HU-03.5 ni HU-03.6**, que son las que de verdad tocan plata y todavía no
existen: cuando entren el interruptor y el cambio de precio hace falta otra
pasada.

| # | Hallazgo | Estado |
|---|---|---|
| **1** | `precioCoherente` cerraba sólo el camino del panel; la proyección seguía publicando un `precio: 0` | **Resuelto.** `validarProducto` lo espeja, con dos tests: el del validador y el del descarte, cada uno con su control positivo |
| **2** | La descripción de prueba se escribió en producción **antes** de desplegar la regla que la permite, y dejó el documento **congelado**: con `descripcion` en `fichaVino` y un `hasOnly` que no la lista, `update` rebota con `permission-denied` | **Resuelto** desplegando las reglas. Ver abajo |
| **3** | El ruleset publicado no correspondía a ningún commit | **Anotado y corregido en el procedimiento.** Ver abajo |
| **4** | El hallazgo 1 de ADR 008 queda cerrado **para el camino del cliente**; del lado del Admin SDK lo sostienen dos guardas de `muestra: true` en los scripts del seed, no una regla | **Aceptado**, escrito acá para que no se lea como cerrado del todo |
| **5** | Un documento con el slug mal tecleado **ya no se puede borrar**: sólo despublicar. No cuesta nada en la vidriera —`armarCatalogo` lee sólo los publicados— pero el catálogo del panel lee la colección entera, así que cada documento basura es una lectura en cada sesión fría, para siempre | **Aceptado con su salida:** si aparece, se borra con un script de Admin SDK en `scripts/`. Es el precio de cerrar la puerta del `delete`, y es más barato que el modo de falla que cierra |
| **6** | El tope de 600 se midió contra `ñ`, que discrimina bytes de caracteres pero **no** caracteres de unidades UTF-16 | **Medido, y no era un problema:** con 350 caracteres fuera del BMP —350 puntos de código, 700 unidades UTF-16— las reglas **rechazan**, así que `size()` cuenta **unidades UTF-16**, igual que `.length` de JS y de Dart. Los tres lados cuentan lo mismo. Hay un test que lo afirma: si algún día pasa a verde, las reglas se volvieron más permisivas que el panel |
| **7** | La baranda del precio vive sólo en `presentation`. Nada en reglas ni en contrato acota el precio **por arriba**: un cero de más convierte $ 16.500 en $ 165.000 y no rebota nada | **Aceptado, y dicho.** Las reglas de `config` argumentan lo contrario en §9.4 —*"la baranda vive en el trigger y las reglas garantizan que no exista otro camino"*—, pero una mediana vive en una consulta que las reglas **no pueden hacer sin `get()` facturados por evaluación**. Hoy el panel es el único escritor de `precio`, así que el widget **es** la única puerta. Si algún día otro camino escribe precios, esto deja de alcanzar |

### El orden se invirtió para un campo, y se midió cuánto cuesta

Lo que se ejecutó fue: **panel desplegado → escritura de prueba a producción con
un campo que las reglas vivas prohíben → reglas pendientes.** Eso es
`front → reglas` para `descripcion`, al revés de lo no negociable.

**Qué pasó de verdad, medido contra el emulador con el ruleset publicado
bajado de la API:** el documento con `descripcion` rebota en `update` de
`nombre`, de `precio` **y de `publicado`**. Control positivo: el mismo
documento sin ese campo acepta las tres.

Hoy fue barato —un vino `muestra: true`, y la vidriera no está desplegada—.
La misma secuencia sobre un vino real: **el dueño no le puede corregir el
precio ni despublicarlo**, y con `allow delete: if false` no le queda ninguna
salida desde el cliente. El vino se queda en la tienda con el precio
equivocado hasta que alguien despliegue reglas.

⚠️ **Y poner el campo en `null` NO lo descongela**: un campo en `null` sigue
teniendo su clave presente, y `hasOnly` mira claves. Las salidas son desplegar
la regla o **borrar el campo**.

### `firebase deploy --only firestore:rules` sube el ÁRBOL, no HEAD

El ruleset `0310466f` es `d871218:firestore.rules` **más una línea que en ese
momento no estaba commiteada**. Es la versión "reglas" de *el deploy de front
reconstruye desde el HEAD pusheado*, y es peor: arrastra hasta lo que no está
en git.

Fue benigno —sumar un varietal sólo ensancha el conjunto aceptado— pero **la
dirección es la peligrosa: reglas más anchas que el contrato.** Un documento
con ese varietal se podía escribir, y el `validarProducto` desplegado lo
habría descartado de la vidriera **sin error visible**.

`auditar_varietales.mjs` no puede ver esta deriva: compara tres archivos **del
repo**, no lo desplegado.

**Procedimiento, desde acá:** `firebase deploy --only firestore:rules` **sólo
con `git status --short` vacío**, y la verificación compara el ruleset contra
**HEAD** y contra el archivo del árbol.

## Lo que falta

- ~~**Las reglas de este ADR no están desplegadas.**~~ **Desplegadas el
  2026-09-21**: `0310466f` → `04b8a471`, verificado con la API de Rules —
  cuatro canarios que aparecen (`precioCoherente`, `imagenesValidas`,
  `descripcionValida`, `'descripcion'`) y uno que desaparece (`allow delete:
  if esAdmin()` en `productos`) —, y con escrituras reales contra el ruleset
  **publicado**, no contra el archivo del repo.
- **HU-03.5, HU-03.6 y HU-03.7 no necesitaron una sola regla nueva.** Las tres
  condiciones que las protegen —el `delete` cerrado, `precioCoherente`, las
  imágenes— ya las cerraba `04b8a471`, desplegado para HU-03.2 a HU-03.4. Si
  el día de mañana otro escritor de `productos` cambia esto, se dice acá; no
  se da por sentado.
- **Falta el deploy del panel.** El de reglas ya salió; el panel con
  HU-03.5 a HU-03.7 sigue sólo en el árbol de trabajo. Es el Grupo 10 de
  `tasks.md`: CI `alcance=panel` → `publicar.sh preview` → `promover` →
  `verificar` sobre live.
- **Falta que alguien publique un vino real y lo mire en la tienda** (10.7 de
  `tasks.md`). Sigue igual desde el change anterior, y **bloquea que este
  change se archive**: los 20 productos de producción son `muestra: true`, así
  que publicar y despublicar todavía no se probaron contra un vino de verdad.
- **El título «De esta botella» SÍ pasó por el agente `voz`, confirmado sin
  cambios.** Pero `voz` dejó una nota propia, sin resolver: el disparador de
  [`voz.md` §12](../../design/voz.md) —"antes del primer vino con descripción
  sensorial"— ya se cumplió, con `FichaVino.descripcion` en producción desde
  el commit `633f7bf`, **sin ningún campo de autoría**, y `voz.md` §3.2 dice
  *"sin autor, no existe"*. No es un defecto de este título: es una decisión
  del dueño sobre el dato que todavía nadie tomó, y no la toma este change.
- **Hay una descripción de prueba escrita en `muestra-alamos-malbec`.** Con
  `04b8a471` desplegado el documento **se descongeló y se verificó**: vuelve a
  aceptar `update` de nombre, precio y `publicado`. Sigue sin confirmarse si
  el campo de prueba se borró. Para sacarla hay que **borrar el campo**, no
  ponerlo en `null`.
