# ADR 014 — Endurecer el producto, y la descripción punta a punta

- **Fecha:** 2026-09-21
- **Estado:** aceptada y **aplicada en el código**. Reglas y panel **sin
  desplegar** todavía: ver *Lo que falta*
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

- **Las reglas de este ADR no están desplegadas.** Lo publicado es el ruleset
  `0310466f`, que es el de ADR 013. El deploy es **reglas → panel**, sin
  functions y sin tienda.
- **El panel todavía no tiene el campo de la descripción en la pantalla.** El
  dominio, el mapeo y los tests están; falta el widget del formulario.
- **Publicar y despublicar (HU-03.6) y el espejo de la vidriera (HU-03.7) no
  están construidos.** Las reglas que los habilitan sí.
- **El título «De esta botella» no pasó por el agente `voz`.** La vidriera no
  se despliega en este change, así que no llega a ningún comprador todavía.
- **Hay una descripción de prueba escrita en `muestra-alamos-malbec`.** Con
  las reglas de este ADR desplegadas es un documento válido; **hasta que se
  desplieguen está congelado**. Para sacarla hay que **borrar el campo**, no
  ponerlo en `null`.
