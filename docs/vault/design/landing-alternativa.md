# La landing en cuatro escenas — alternativa a `escenas.md`

- **Fecha:** 2026-09-04
- **Estado:** **construida y navegable** en la rama `home-parallax`, **sin
  mergear a `main` y sin desplegar**. No reemplaza a
  [`escenas.md`](escenas.md): compite con él.
- **Por qué existe:** el dueño no quedó convencido de `escenas.md`. Sus cuatro
  objeciones, textuales, están en §1 y cada una tiene abajo qué se hizo con
  ella.
- **Qué contesta:** qué muestra la home, en qué orden, con qué texto y con qué
  movimiento — y qué se midió sobre la página corriendo, no sobre el diseño.
- **Qué NO contesta:** el catálogo, la ficha, el carrito. Y no reemplaza
  `tokens.md`, que sigue sin existir: §9.
- **Insumos que NO se tocaron:** [`parallax.md`](parallax.md) (el movimiento),
  [`direccion.md`](direccion.md) (el color y la forma) y [`voz.md`](voz.md) (el
  lenguaje). Los tres siguen vigentes tal cual. Lo único que se descarta es la
  **composición**.

---

## 0. La tesis, en una línea

**`escenas.md` es un recorrido de ánimos. Esto es la secuencia de preguntas que
hace alguien que podría comprar.**

El scroll no va de una puerta a una lámpara: va del problema que el lector ya
vivió hasta su propia mesa, pasando por el vino y por la prueba.

---

## 1. Las cuatro objeciones, y qué se hizo con cada una

| Objeción del dueño | Qué la causaba en `escenas.md` | Qué se hizo |
|---|---|---|
| **"Mucha ceremonia, poco vino"** | Cinco escenas de marca; el catálogo aparecía en la **cuarta**, con **una** botella y sin precio. Seis pantallas de scroll para ver un vino | El vino pasa a la escena **2** y son **seis**, con bodega, varietal, añada y región. Y son **cuatro** escenas, no cinco |
| **"El arco narrativo"** | umbral → origen → sorbo → vitrina → mesa. Ninguna escena decía qué es el negocio | problema → selección → custodia → mesa. Cada escena contesta una pregunta que un comprador hace de verdad |
| **"Parece muy abstracto, poca definición"** | La escena que enseñaba lo hacía con **el color del menisco de una copa**: cierto, pero sobre el vino, que es justo lo que la marca no puede firmar | La escena 3 enseña sobre la **custodia**: tres mecanismos físicos con su porqué. Es lo único que bouquet hizo, y se puede verificar en cualquier manual |
| **"Los copys son cortos para desktop"** | Escenas de 2 y 3 frases. En 1440 px sobraba pantalla | ~340 palabras contra ~120. La escena 3 va a **tres columnas** de prosa en escritorio y es la más densa de la página |

### 1.1 Lo que se conservó de `escenas.md`, porque era bueno

- **Una lámpara por escena**, tres números, y el radio crece a lo largo de la
  página. Acá va `30 → 78 → 44 → 96`, con la contracción en la escena que
  enseña.
- **El ritmo lugar/objeto** y su consecuencia: las de objeto llevan rótulo, las
  de lugar no.
- **El cartucho** como sistema, con chaflán en dos esquinas opuestas y filete de
  grosor constante.
- **La corrección de signos de su §5** — ver §4.

---

## 2. Las cuatro escenas

### 2.1 El problema · *lugar* · 5 planos · la capa del LCP

> **Un vino puede estar bien hecho y llegar mal.**
>
> Entre la bodega y tu mesa hay meses. El vino los pasa en algún lado: parado en
> una góndola, con luz encima, al lado de una heladera que arranca y para.
>
> Nosotros nos ocupamos de ese tramo. Acostado, a temperatura pareja, sin luz.
> Es todo lo que hacemos, y por eso lo hacemos bien.

**El texto no se escribió: estaba escrito.** Es [`voz.md §10.2`](voz.md), el
ejemplo curado de "quiénes somos", que vivía enterrado dentro de una tabla
comparativa y decía exactamente lo único que la marca puede sostener sin mentir.

Arriba, en versalitas, la tesis del nombre: *el aroma lo trae la uva, el bouquet
lo gana esperando*. Es **el único lugar de todo el sitio** donde la palabra se
usa como término de enología; `voz.md §1` lo prohíbe en cualquier otro lado.

CTA **blando**. El sujeto es el **culo de una botella acostada**: un encuadre que
no llega al área de etiqueta, así que no hay que elegir entre mostrar una marca
ajena o taparla con sombra. **Se resuelve por recorte, no por desenfoque**, y el
plano conserva la nitidez máxima que `parallax.md §3.4` le exige a z2.

### 2.2 La selección · *objeto* · 3 planos · CTA duro

> `La selección`
>
> **Lo que hay guardado ahora.**
>
> Cada uno llegó acostado y así sigue. Los elegimos de a uno: no hay góndola que
> llenar ni un mínimo de marcas que sostener.

Seis tarjetas retrato en cartucho. Cada una: nombre, bodega, varietal · añada,
región, y **una línea de guarda**.

> **La línea de guarda es la decisión que más rinde de esta composición.** No es
> una nota de cata —`voz.md §3.2` no deja firmar una— sino un hecho de custodia:
> *"Acostada desde marzo"*, *"Cuatro años acostada acá"*. Es la única frase que
> **sólo bouquet puede escribir**, es falsable, y ocupa el renglón donde
> cualquier otra tienda pondría *"taninos redondos, final persistente"*.

**Sin precio.** Es lo que mantiene la landing 100 % estática y fuera del circuito
de purga por tag de [ADR 005](../architecture/decisions/005-hosting-vidriera.md).
Y no está oculto por estilo: **no está en los datos**.

**Las botellas son SVG monolineal, no fotos.** Seis fotos con recorte
consistente —misma altura, misma perspectiva, misma luz— no existen como stock,
y conseguirlas exige producción propia. El dibujo no lo mitiga: lo elimina. Es
el mismo argumento con el que `escenas.md §3.3` resolvió el par de copas.

### 2.3 La custodia · *lugar* · 3 planos · la que enseña

> `Cómo se guarda`
>
> **Tres cosas, y ninguna es un secreto.**
>
> No hay una técnica propia acá. Hay tres condiciones que cualquiera puede
> verificar, y el trabajo es sostenerlas todos los meses que haga falta.

| Mecanismo | Qué dice |
|---|---|
| **Acostada** | El corcho se mantiene húmedo mientras el vino lo toca. Seco se contrae, y por ese milímetro entra aire |
| **Temperatura pareja** | Importa menos el número que el movimiento. Cada subida y bajada dilata el vidrio y el líquido a distinta velocidad |
| **Sin luz** | La luz descompone, y no hace falta que sea sol. Por eso el vidrio del vino es oscuro |

Y cierra con la frase que sostiene el negocio entero:

> Nada de esto es una opinión sobre el vino. Es lo que le pasa a una botella
> mientras espera, y ese tramo —que no firma nadie— es el único que podemos
> firmar nosotros.

⚠️ **Los tres mecanismos son enología general, no afirmaciones operativas.** No
se dice a cuántos grados se guarda ni cuántos metros tiene el depósito: eso sería
un dato que `voz.md §6` prohíbe hasta poder sostenerlo. **La escena enseña un
hecho físico y reclama una práctica, sin poner un número que nadie midió.**

### 2.4 La mesa · *lugar* · 2 planos · CTA duro · cierre

> **Después no te vas a acordar del vino.**
>
> Te vas a acordar de la mesa. De quién estaba, de la hora que era, de que nadie
> tenía apuro por irse.
>
> Por eso el trabajo termina antes de que la abras. Lo que pasa después ya no es
> nuestro, y está bien así.

Es la lectura correcta de *"sabor eterno"* según `voz.md §1.1`: **no una promesa
sobre el gusto —que sería imposible de sostener— sino una sobre la memoria.** Y
cierra el paréntesis de §1.2: la marca tiene el *antes* de la custodia y el
*después* del recuerdo, y el sorbo, lo único que no hizo, queda en el medio.

**Cero caras** en el asset, y es requisito duro: *quién más* es del lector.

---

## 3. El sistema, y dónde vive

| Pieza | Archivo | Qué hace |
|---|---|---|
| Los colores literales | `apps/tienda/src/tokens/tokens.css` | **El único lugar** con hex. El hook `no-hardcoded-colors` lo hace cumplir |
| El espejo en TS | `apps/tienda/src/tokens/colores.ts` | Sólo para `themeColor`, que sale del documento y no puede leer una `var()` |
| El motor de planos | `apps/tienda/src/estilos/sistema.css` | Un `@keyframes`, un timeline, un token por plano |
| La composición | `apps/tienda/src/estilos/escenas.css` | Layout y la lámpara de cada escena |
| Los componentes | `apps/tienda/src/components/landing/` | 8 archivos, todos bajo el tope de 200 líneas |
| Los datos | `apps/tienda/src/contenido/seleccion.ts` | ⚠️ **De muestra.** §9 |

### 3.1 Las fuentes

**Fraunces** (display) y **Newsreader** (texto), las dos de `direccion.md §4.2`.
Descargadas en build por `next/font` y servidas desde el propio dominio: se
verificó que hay **9 `.woff2` en disco** y **cero pedidos a
`fonts.googleapis.com`** en el HTML servido.

**No entra una tercera familia.** El presupuesto de §4.5 reserva una grotesca de
cifras tabulares para donde haya un número que no se pueda leer mal, y en esta
página no hay ninguno: no hay precio, ni stock, ni número de Orden.

⚠️ **Bodoni Moda sigue abierta** como alternativa de display. La decide el dueño.

---

## 4. Los signos: se implementó la corrección de `escenas.md §5`

`parallax.md §4.1` escribe las amplitudes en **negativo** para los planos lentos.
`escenas.md §5` dice que están invertidas. **Los dos no pueden tener razón**, y
el pendiente seguía abierto desde el 2026-09-03.

La aritmética: sobre el rango `cover`, el contenedor recorre
`(alto de viewport + alto del elemento)` hacia arriba. Para que un plano recorra
**menos**, hay que sumarle desplazamiento hacia abajo. **Lento → positivo.**

Y ahora está medido sobre la página corriendo, leyendo el `translate` calculado:

| `scrollY` | ambiente (`v = 0.40`) | escenario (`v = 0.55`) |
|---:|---:|---:|
| 0 | `69,13 px` | `51,84 px` |
| 300 | `94,92 px` | `71,19 px` |
| 600 | `120,71 px` | `90,53 px` |
| 900 | `144,72 px` | `108,54 px` |

Los dos **crecen** (positivo, o sea que se quedan atrás) y su recorrido está en
proporción `75,6 / 56,7 = 1,333`, que es exactamente `18vh / 13,5vh`. **La
cámara de `parallax.md §2.1` se cumple en el píxel.**

⚠️ Esto confirma la aritmética, **no la sensación**. El pendiente de scrollear
con el dedo en un teléfono sigue abierto: si el fondo se siente adelantado o
pegado, la respuesta está ahí y no en esta tabla.

---

## 5. Los cinco defectos que sólo aparecieron mirando

Ninguno se veía en el código. Todos salieron de capturar la página y abrir el
PNG.

| # | Defecto | Por qué pasó |
|---|---|---|
| 1 | **La foto de la mesa venía con marca de agua `Unsplash+` tileada** | Es un asset de pago. La API devuelve la previsualización marcada sin decir que lo es. **Ninguna revisión de código lo encuentra jamás** |
| 2 | **Las fotos se renderizaban a tamaño nativo, no cubriendo la escena** | El selector era `.plano > img`, y el `<img>` es hijo de `<picture>`, no del plano. Hijo directo: no matcheaba |
| 3 | **El scrim se leía como un panel rectangular translúcido** | Los radios eran `76% / 70%`: el degradé llegaba a transparente **más allá** del borde de la caja, así que el borde lo cortaba. Tienen que ser ≤ 50 % |
| 4 | **La dirección de arte horizontal salía sobre-ampliada** | El sangrado parejo de 24vh hacía el plano mucho más alto que el viewport, y `object-fit: cover` compensaba ampliando. Ahora **cada rol sangra lo que su propia amplitud necesita** |
| 5 | **La página medía 9,71 pantallas en móvil**, contra el techo de 8 de `parallax.md §4.5` | Seis ventanas de 9:16 a una columna son ~3.600 px de una sola escena |

**El 5 se corrigió sin sacar vino**, porque menos vino es exactamente lo
contrario del pedido: en pantalla angosta la tarjeta pasa a **fila horizontal**,
con la botella en una columna finita a la izquierda. Sigue habiendo **un vino por
fila** —`direccion.md §7.2` al pie de la letra— y la botella recupera su retrato
de 9:16, que es justo lo que se perdía al achatar la ventana. Resultado:
**5,88 pantallas**.

> El defecto 1 es el más caro de los cinco y el único que no tiene arreglo
> técnico: **hay que mirar cada foto**. La API de Unsplash marca los assets de
> pago con `plus: true`, y ese campo ahora se chequea antes de bajar nada.

---

## 6. Los assets, con su licencia

Siete archivos en `apps/tienda/public/landing/`, ~1,1 MB en total. Todos
**Unsplash License** (uso comercial, sin atribución obligatoria), todos
verificados con `plus: false` y **mirados uno por uno** antes de entrar al repo.

| Archivo | Rol | Autor | Origen |
|---|---|---|---|
| `ambiente.webp` | z0 del héroe y de la selección | Nik | [`K7y1dmkphAk`](https://unsplash.com/photos/K7y1dmkphAk) |
| `rack-v/-h.webp` | z1 del héroe — botellas **acostadas** | Angel Maldonado | [`149rUpUcVfQ`](https://unsplash.com/photos/149rUpUcVfQ) |
| `botella.webp` | z2 del héroe — culo de botella acostada | Mockup Free | [`apLRtSyW2Q4`](https://unsplash.com/photos/apLRtSyW2Q4) |
| `cava-v/-h.webp` | escenario de la custodia | Joao Vitor Marcilio | [`ixVqS-tgSrg`](https://unsplash.com/photos/ixVqS-tgSrg) |
| `mesa-v/-h.webp` | escenario del cierre | Max Griss | [`JE2TskHX4Wc`](https://unsplash.com/photos/JE2TskHX4Wc) |

**Tres recortes son dirigidos, no automáticos**, y por motivos concretos:

- `botella.webp` esquiva la marca de agua `mockupfree.net` que la foto tiene
  sobre la etiqueta. El recorte deja el culo de la botella y nada más.
- `cava-*.webp` corta el tercio derecho, donde se leían las etiquetas de **otra
  bodega**. Una landing que muestra marcas ajenas legibles está diciendo algo
  que no quiso decir.
- La lámpara CSS de esa escena (`--lx: 26%; --ly: 20%`) se apoya **sobre el cono
  de luz que la foto ya trae**. `parallax.md §10.3` advierte que una foto con luz
  propia choca con la lámpara única; acá se resuelve haciéndolas coincidir en
  vez de pelearlas.

⚠️ **Siguen siendo fotos de reemplazo.** El pendiente de licencia de
`_index.md` no se cierra con esto: se cierra cuando existan las propias. Lo que
sí cambió es que ahora hay **un manifiesto con autor y URL por archivo**, que es
lo que faltaba para poder auditarlo.

---

## 7. Cómo se verificó, con sus controles

Todo sobre la página corriendo en `next dev`, con Chrome headless por CDP.

| Afirmación | Cómo se falseó | Resultado |
|---|---|---|
| **"El scrim viaja con el texto"** (`parallax.md §3.2`) | Decodificar el PNG de la captura en 5 puntos del rango de scroll y calcular el contraste real del fondo detrás del `h2` | **13,48 → 13,31:1**, variación **0,17 puntos** |
| *control negativo* | La **misma foto**, mismo scroll, en una franja **sin scrim** | variación **0,46 puntos** — **3× más**. La medición discrimina |
| **"El movimiento existe"** | Leer el `translate` **calculado** en 4 puntos, no que el CSS diga `animation-timeline` | Cambia, y en la proporción exacta de los tokens (§4) |
| **"Tier C apaga el movimiento"** | Emular `prefers-reduced-motion: reduce` y releer el `translate` | `none` en los 4 puntos |
| **"Tier C no deja scroll muerto"** (el peor defecto de `escenas.md §4.3`) | Comparar el `scrollHeight` con y sin movimiento | **5278 px = 5278 px.** No hay geometría atada al movimiento porque **no hay pin** |
| **"La composición estática está completa"** | Contar bloques de texto en el DOM con el movimiento apagado | **55**. No se pierde una sola frase |
| **"La landing no muestra precio"** | `grep` sobre el **texto renderizado**, no sobre el HTML crudo | limpio |
| *control positivo* | *"Cuesta del Sauce"* **tiene** que aparecer | aparece |
| **"Cero Firestore en el cliente"** | `grep` de `firestore.googleapis`, `firebaseio.com`, `initializeApp` en el documento servido | limpio |
| **"Los 8 assets existen"** | HTTP a cada uno | **8 × 200** |
| *control negativo* | Un asset inventado | **404** |
| **"Nadie quedó sin puerta"** | `grep` de cada símbolo nuevo fuera de su propio archivo | los 12 tienen consumidor |
| **"El largo es honesto"** | `scrollHeight / viewport` | **6,00** pantallas en escritorio, **5,88** en móvil (techo: 8) |

⚠️ **El `grep` de precio dio un falso positivo sobre el HTML crudo** y hubo que
corregir la medición: el flight de RSC de Next está lleno de `"$1"` y `"$7"`, y
`charSet` contiene `arS`. **Una verificación que grita cuando no pasa nada es tan
inútil como una que calla cuando sí pasa.** Va sobre `innerText`.

### 7.1 Lo que NO se verificó, y hay que decirlo

- **No se corrió la prueba discriminante de `parallax.md §9.1`** —bloquear el
  hilo principal 3 s y scrollear— que es la única que prueba que el movimiento
  está en el compositor y no en el hilo principal.
- **No se probó en un teléfono real.** Todo lo de arriba es Chrome headless en
  un escritorio. `parallax.md §9.2` es explícito: *"se ve fluido con el mouse"*
  no prueba nada, porque la rueda da saltos discretos y **esconde** el desfase.
- **No se probó en Safari**, donde entre 26.0 y 26.3 los timelines corren en el
  hilo principal.
- **No hay build de producción**, sólo `next dev`.

---

## 8. Presupuesto de lecturas de Firestore

Campo obligatorio de `post-task-doc`.

| Escenario | Lecturas que agrega | Contra los 50.000/día |
|---|---|---|
| Las cuatro escenas como están hoy, con datos horneados en el repo | **0** | 0 % |
| Reemplazar la muestra por la proyección publicada, leída en Cloud Build | **1 por deploy de `tienda`** | No entra en la tabla diaria: son deploys, no visitas |
| Cualquier escena leyendo Firestore desde el navegador | ~1 por visitante | **Rompe [ADR 004](../architecture/decisions/004-frescura-y-lecturas.md). Prohibido** |

Verificado, no razonado: el documento servido **no contiene** `initializeApp` ni
ningún host de Firestore.

---

## 9. Lo que queda abierto, con disparador

| Qué | Quién | Disparador |
|---|---|---|
| ⚠️ **`SELECCION` son datos INVENTADOS** — nombres de vino y de bodega que no existen | — | **Antes de cualquier deploy.** Se chequea con `grep -rn "LA_SELECCION_ES_DE_MUESTRA" apps/tienda/src`: mientras dé `true`, la home no se publica |
| ⚠️ **`/vinos` no existe** — los dos CTA duros apuntan a un 404 | — | Es el paso 5 de ARQUITECTURA §12 y el próximo trabajo. La landing enlaza donde corresponde; lo que falta es el destino |
| **`tokens.md` sigue sin existir** | — | Esta rama adelantó la *implementación* de los tokens porque existe para mirar una composición. **El documento sigue siendo el bloqueo** y los nombres de `tokens.css` son provisorios |
| **`generar_verdad.mjs` cuenta comentarios como call sites** | técnica | Usa `new RegExp('\\b' + nombre + '\\b')` sobre el fuente entero. La palabra `CERO` en un comentario bajó los "sin puerta" de 16 a 15 sin que nadie abriera nada. **Se detectó y se esquivó reformulando el comentario, que es un parche.** Disparador: la próxima vez que el número se mueva sin causa |
| **La puerta de edad (el telón) NO está** | — | Se dejó afuera a propósito: obliga a un clic en cada recarga y eso es exactamente la fricción que impide juzgar una composición mirándola. Está especificada en `parallax.md §10.2` y `voz.md §9.1`. Disparador: antes de publicar el dominio |
| **La segunda dirección de arte de `ambiente` y `botella`** | — | Hoy sirven una sola pieza para las dos formas. Es aceptable en un bokeh y en un recorte; no lo sería en un escenario |
| **Sin promesa de entrega en el pie** | el dueño | `voz.md §6` prohíbe una ventana de entrega sin `Zona` que la garantice. Cuando exista `Zona`, el pie es su lugar |
| **Elegir entre esta composición y `escenas.md`** | **el dueño** | Ahora. **Las dos no se mergean.** La que pierda se archiva en `changelog/`, con el porqué |

---

## 10. Cuándo este documento deja de servir

- **Cuando el dueño elija.** Si gana `escenas.md`, esto pasa al changelog y la
  rama se borra. Si gana esto, `escenas.md` pasa al changelog y este documento
  se vuelve la composición vigente.
- **Cuando exista `/vinos`:** la escena 2 debería **reusar** la tarjeta de la
  ficha en vez de tener la suya.
- **Cuando existan las fotos propias:** §6 cambia entero y hay que revisar que
  cada plano siga cumpliendo el tratamiento de `parallax.md §3.4`.
- **Cuando alguien scrollee esto en un teléfono:** ahí se cierra el pendiente de
  los signos, y `parallax.md §4.1` se corrige o este documento se corrige.
