# Dirección visual — bouquet

- **Fecha:** 2026-09-03
- **Estado:** propuesta. Es el **paso 1 de `/disenio`** (dirección, no
  componentes). Los aportes del dueño están integrados; lo que falta decidir
  está en §12 con su disparador.
- **Qué contesta:** qué tiene que sentir alguien que entra, de dónde sale cada
  decisión estética, y cuál es el límite de cada referencia.
- **Qué NO contesta:** los tokens con sus nombres de código. Eso es
  `docs/vault/design/tokens.md`, el paso 2, y no existe todavía.
- **Insumos:** el imagotipo final, la propuesta de Rinowin con sus 6
  variaciones, y el informe de [parallax](parallax.md), que fijó el movimiento
  sin condicionar la estética.
- **Qué material de marca está en el repo:** **uno solo**,
  [`docs/marca/logo-bouquet-rgb.png`](../../marca/logo-bouquet-rgb.png) — el PNG
  RGB gestionado, que es **la fuente de los dos colores de §2** y por lo tanto lo
  único que hace verificable la medición. El resto (el PDF vectorial CMYK, los
  JPG de imprenta, el `.cdr` y el PDF de la propuesta del estudio) **no está
  versionado a propósito**: son ~10 MB en un repo público, y las variantes
  descartadas no deberían quedar en el historial. Los tiene el dueño aparte.
- **Su mitad verbal:** [`voz.md`](voz.md) — la dirección de lenguaje, que corta
  la ceremonia y la transacción **en el mismo lugar** que corta ésta.

---

## 0. La tesis, en una línea

**bouquet no es una tienda oscura: es una cava iluminada.** La diferencia es
que en una cava hay **una** fuente de luz cálida y todo lo demás cae — y lo que
se ilumina es la botella, nunca la interfaz.

Todo lo que sigue sale de ahí, y de un hecho medido: **cada color de la marca
sobrevive en un solo fondo.** Eso no es una preferencia, es aritmética, y está
en §2.

---

## 1. Lo que el material ya decidió — y no se re-propone

Antes de opinar, lo que ya está fijado por el imagotipo entregado.

| Pieza | Qué es | Consecuencia |
|---|---|---|
| **Isotipo** | Copa de trazo **monolineal** dorado, con una voluta que sube como aroma | El trazo es **de grosor constante**. Todo lo dibujado que acompañe —reglas, marcos, íconos— tiene que ser monolineal o pelea con la marca |
| **Logotipo** | `BOUQUET` en serif con serifas **corchetadas y con peso**, versalizado. La `Q` tiene una cola larga que baja | La serif de la marca **tiene cuerpo**. No es un didone de hairlines |
| **Bajada** | `El vino intacto, sabor eterno` en **sans geométrica redondeada** | ⚠️ Es la pieza más débil del conjunto. §4.3 |
| **Paleta** | Exactamente **dos** colores + blanco | §2. Dos colores es una restricción, no una carencia |
| **Concepto** | *Intacto*. Arquetipos: **Amante** (principal), **Cuidador**, **Creador** | El sitio tiene que sentirse **sensorial y cuidado**, no eficiente |

### 1.1 Lo que la propuesta descartada deja igual

La Propuesta 1 (el **sello de lacre** con la `B`) no ganó, pero identificó el
gesto correcto de la marca: **un sello es un cierre que nadie violó.** Es
literalmente "intacto", en un objeto.

> **El lacre vuelve como recurso, no como logo.** Es el remate de una ficha, la
> marca de "reservado", el sello del comprobante de la Orden. Cuesta un SVG y
> dice la promesa entera sin una palabra.

### 1.2 Las tipografías, verificadas en el PDF y no supuestas

Leídas de las fuentes incrustadas en el PDF de la propuesta del estudio
(`PROPUESTA LOGO BOUQUET- CON CORRECCIONES.pdf`, **fuera del repo** — ver
Insumos):

| Dónde | Fuente real | Nota |
|---|---|---|
| Wordmark de la Propuesta 1 | **Addington CF Bold** | Serif con cuerpo. De pago |
| Wordmark de la Propuesta 3 | **Sitka Small** | La que sobrevive en el logo final |
| Todo el resto del PDF | **Poppins** (5 pesos) | Es la plantilla **del estudio**, no de bouquet |

⚠️ **El logo final está vectorizado: no tiene fuentes incrustadas.** Es decir,
el wordmark es arte, no texto — está bien así, pero significa que **la
tipografía del sitio no viene decidida por el logo**, sólo condicionada. Lo que
condiciona es la forma: serifas corchetadas, contraste moderado, peso real.

---

## 2. La medición que decide toda la dirección

Los dos colores, tomados del PNG del logo píxel por píxel — no del PDF ni a ojo:

| Rol | Hex | HSL | Cobertura en el logo |
|---|---|---|---|
| **Borgoña** | `#762D2D` | `hsl(0 45% 32%)` | 4,24 % |
| **Dorado** | `#D2AE6D` | `hsl(39 53% 63%)` | 2,38 % |

### 2.0 ⚠️ El PDF del logo es CMYK. No le saques los colores de ahí.

El PDF del imagotipo (`LOGO ORIGINAL BOUQUET - PDF.pdf`, **fuera del repo** —
ver Insumos) es **vectorial y CMYK**: pinta con el operador `scn` de 4
componentes, no con `rg`.

| Tinta | CMYK del PDF | Conversión ingenua | **Valor de pantalla** |
|---|---|---|---|
| Borgoña | `31 / 100 / 100 / 46` | `#700E0F` ❌ | **`#762D2D`** |
| Dorado | `0 / 20 / 60 / 20` | `#D2AC67` | **`#D2AE6D`** |

Cualquier herramienta que abra ese PDF y convierta CMYK a RGB sin perfil
—Inkscape, un extractor de SVG, un cuentagotas sobre un visor— devuelve
**`#700E0F`**, que está mucho más saturado que el color real. El borgoña
correcto sale del **PNG RGB que exportó el diseñador**, que sí está gestionado.

> **Los dos valores son el mismo color en dos medios.** El PDF manda para
> imprimir; el PNG RGB manda para pantalla. Si alguien "arregla" el token a
> `#700E0F` porque lo sacó del PDF, está pisando el original con una
> aproximación — y de paso rompe los contrastes de §2.1.

El borgoña está en **hue 0 exacto**: es un rojo puro desaturado, sin nada de
azul. No es el borgoña morado de manual — es **ladrillo, tierra, óxido**. Eso
empuja la marca hacia lo cálido y terroso, no hacia lo aristocrático frío.

### 2.1 El contraste, calculado (WCAG 2.1)

| Par | Ratio | Veredicto |
|---|---:|---|
| Borgoña sobre blanco | **9,62:1** | AAA |
| Borgoña sobre marfil `#F5EFE4` | **8,40:1** | AAA |
| **Dorado sobre blanco** | **2,10:1** | ❌ **FALLA** — falla incluso el 3:1 de gráficos |
| **Dorado sobre marfil** | **1,83:1** | ❌ **FALLA** |
| Dorado sobre tinta `#1A1210` | **8,80:1** | AAA |
| Marfil sobre tinta | **16,13:1** | AAA |
| **Borgoña sobre tinta** | **1,92:1** | ❌ **FALLA** |
| Dorado sobre borgoña | **4,59:1** | AA, y **justo**: sirve para títulos, no para párrafos |

### 2.2 La consecuencia, que es la idea central del documento

> **Cada color de marca es tinta en exactamente un fondo, y superficie en el
> otro. No coexisten como texto.**

- Sobre **papel**: el borgoña es la tinta. El dorado **no puede decir nada** —
  es adorno, y si lleva información, esa información no existe para mucha gente.
- Sobre **tinta oscura**: el dorado es la tinta. El borgoña **no puede decir
  nada** — es un panel, un fondo, una superficie.

Y un dato más, que fuerza una decisión de forma: aclarar el borgoña hasta que
sea legible sobre el fondo oscuro exige llegar a `#C76B6B` (L=60 %, 5,05:1).
**Eso ya no es borgoña, es rosa viejo.** No hay ninguna versión del color de
marca que funcione como texto sobre oscuro.

**Un panel borgoña sobre cualquier fondo oscuro plausible da como mucho 2,05:1**
— por debajo del 3:1 que necesita un borde de UI para verse. Es decir: sobre
oscuro, **un bloque borgoña sin una línea dorada que lo delimite no se ve.**

Guardá esa frase. Vuelve en §5 y es lo que hace que el Art Decó acá sea
estructura y no disfraz.

---

## 3. La estructura: la ceremonia es oscura, la transacción es de papel

Dos modos, repartidos **por tarea**, no por preferencia ni por hora del día.

| Pantalla | Modo | Por qué |
|---|---|---|
| Landing | **Cava** (oscuro) | Es ocio. Es donde se seduce |
| `/vinos` | **Cava**, pero calmo | Hay comparación, pero también deseo |
| `/vinos/[slug]` | **Cava** arriba, **papel** abajo | El vino se presenta a media luz; sus datos y su precio, en claro |
| `/bodega/[slug]` | **Cava** | Es narrativa: origen, gente, lugar |
| `/carrito` · `/checkout` | **Papel**. Sin excepción | Hay plata. Cero adorno entre el usuario y el botón |
| `/orden/[numero]` | **Papel**, con lacre | Es un comprobante. Se tiene que poder imprimir |

### 3.1 Por qué esto no es un capricho

Tres razones, y ninguna es estética:

1. **Es la única lectura que sobrevive a §2.1.** El checkout necesita texto
   secundario, mensajes de error, campos deshabilitados, ayudas contextuales —
   toda una escala de grises con información. Sobre tinta oscura, esa escala se
   construye con un solo color legible (el dorado) y todo lo demás es marfil
   apagado. Sobre papel, hay una escala entera.
2. **Coincide, sin haberlo buscado, con el corte del informe de parallax.**
   [§1.1 de parallax.md](parallax.md) prohíbe movimiento exactamente en
   `/carrito` y `/checkout` y lo permite en la landing. **Dos documentos
   escritos por separado cortaron en la misma línea** — eso es señal de que la
   línea existe y no la inventamos.
3. **Un checkout oscuro convierte peor y el motivo es aburrido:** los
   autocompletados del navegador y de los gestores de contraseñas pintan sus
   propios fondos claros dentro de tus campos oscuros. No se puede arreglar
   desde CSS, y queda roto justo donde se cobra.

> **La regla, corta:** *si el usuario está decidiendo, apagá las luces. Si está
> tipeando, prendelas.*

### 3.2 Lo que NO es este split

**No es un theme switcher.** No hay un botón de sol y luna. El modo lo fija la
página, no el usuario. Un toggle de tema en una tienda de vinos es una
confesión de que la dirección visual no se decidió.

⚠️ `prefers-color-scheme` **se ignora a propósito** en el modo cava y **se
respeta** en el modo papel: la landing es un ambiente, el checkout es un
documento. Esa asimetría se anota acá porque si no, alguien la va a "arreglar".

---

## 4. Tipografía — "una serif con cuerpo y personalidad"

El pedido del dueño ya resuelve la mitad del problema. **"Con cuerpo" descarta
una familia entera.**

### 4.1 Lo que "con cuerpo" excluye

Los didones —Bodoni, Didot, Playfair, Prata— y los garaldas finos —Cormorant—
tienen **hairlines**: trazos de 1 px o menos a tamaño de lectura. Sobre fondo
oscuro eso se agrava, porque el texto claro sobre oscuro **adelgaza
ópticamente** (irradiación): la misma fuente se ve más flaca invertida.

> Un didone es la elección obvia para "elegante" y por eso está en todas las
> tiendas de vino del mundo. **Sobre la cava, además, se desintegra.**

Y el logotipo ya votó: sus serifas son **corchetadas y gruesas**, no lineales y
finas. Una display didone al lado del wordmark se ve como otra marca.

### 4.2 La recomendación

| Rol | Familia | Por qué |
|---|---|---|
| **Display** | **Fraunces** (variable, libre) | Old-style con esqueleto sólido y ejes `SOFT` y `WONK` que le dan carácter real, no "elegancia genérica". Es literalmente "serif con cuerpo y personalidad" |
| **Texto** | **Newsreader** (variable, libre) | Dibujada para leer en pantalla, altura de x grande, itálica con personalidad propia. Aguanta el fondo oscuro |
| **Números** | **una** grotesca neutra, sólo cifras tabulares | §4.4 |

**Alternativa si se quiere empujar el glam:** display en **Bodoni Moda**,
restringida a ≥ 40 px y sólo en modo papel. Es más Decó y más riesgosa; es una
decisión del dueño, no técnica. Mi recomendación es Fraunces, por congruencia
con el wordmark.

### 4.3 La bajada del logo es el problema a resolver

`El vino intacto, sabor eterno` está en una **sans geométrica redondeada**
(familia Poppins / Quicksand). Ese dibujo —terminaciones romas, círculos
perfectos, sin tensión— es el vocabulario de **una app**. Es exactamente lo
que el dueño dijo que no quiere.

Y viene del brief, que pedía *"Sans serif: moderna para redes y textos
secundarios"*. **Es la única instrucción del brief que conviene desobedecer**,
y se desobedece sólo en el sitio: el logo entregado no se toca.

**Cómo se resuelve sin tocar el logo:** el imagotipo se usa **sin bajada** en el
sitio (el header lleva isotipo + wordmark), y la frase vive como **texto del
sitio**, compuesta en la serif en versalitas con tracking. Es un uso válido de
un imagotipo — las partes funcionan por separado, que es la definición que el
propio PDF de Rinowin da en su página 7.

### 4.4 Dónde se gana el lugar la sans

**En un solo lado: donde hay un número que no se puede leer mal.**

Precio, cantidad, stock, número de Orden, fecha, CUIT, código postal. Ahí una
grotesca con **cifras tabulares** alinea las columnas y elimina la ambigüedad
`1/l/I` que las old-style figures de una serif introducen.

Todo lo demás —etiquetas, categorías, `MALBEC · 2019 · MENDOZA`, migas de pan,
botones— va en **la serif en versalitas con tracking abierto**. Es lo que hace
una etiqueta de vino, y es la razón por la que una etiqueta de vino no se
parece a un dashboard.

⚠️ Y no: **Inter, Poppins y Montserrat quedan afuera** aunque sean gratis y
cómodas. Las tres son la tipografía por defecto de "software", y este proyecto
está tratando de no parecer software.

### 4.5 Presupuesto tipográfico

| Concepto | Tope | Por qué |
|---|---:|---|
| Familias | **3** | Display, texto, cifras |
| Archivos servidos | **≤ 4** | Variables: una roman + una itálica por familia |
| Pesos estáticos | **0** | Todo variable, o no entra |
| Formato | `woff2` **subseteado a latin** | El español entra entero en `latin` |
| Fuentes de terceros en runtime | **0** | Autohospedadas y precargadas — [parallax §6.3](parallax.md) ya lo exige por LCP |

---

## 5. Dark academia y Art Decó — qué tomar de cada una, y dónde está el límite

El dueño nombró las dos y dudó de la segunda. **La duda está bien fundada: son
dos movimientos que se pelean si se apilan.**

| | Dark academia | Art Decó |
|---|---|---|
| Fecha | Siglo XIX largo, biblioteca | 1925, París, máquina |
| Superficie | **Mate**, gastada, papel y cuero | **Brillante**, laca y latón |
| Composición | **Asimétrica**, acumulada | **Simétrica**, axial |
| Luz | Tungsteno, una fuente, caída larga | Difusa y pareja |
| Tipografía | Old-style, versales, itálicas | Geométrica, versales anchas |
| Ánimo | Íntimo, silencioso, melancólico | Público, sonoro, celebratorio |

Apilarlas produce **fiesta temática**. El repo ya tiene una regla para esto:
*no compongas con genéricos* — y "dark academia + deco" comprado en bloque es
un genérico.

### 5.1 El reparto: una da el fondo, la otra da el marco

> **Dark academia aporta el LUGAR. Art Decó aporta el MARCO. Nunca al revés.**

**De dark academia se toma:**

- El **fondo oscuro cálido** y la caída de luz: gradientes radiales
  descentrados, no paneles planos. La luz viene de algún lado.
- La **textura mate**: grano de papel en el modo papel, grano de película sobre
  el fondo oscuro. §8.
- La **densidad tipográfica de un libro**: párrafos de 60-70 caracteres,
  interlineado generoso, itálicas usadas de verdad.
- El **silencio**: pocos elementos por pantalla, y ninguno pidiendo atención al
  mismo tiempo que otro.

**De Art Decó se toma exactamente tres cosas, y son geométricas:**

1. **La regla de un solo trazo** — línea dorada monolineal, del mismo grosor
   óptico que el isotipo.
2. **El cartucho** — un marco fino que encierra un bloque de tipografía
   centrada. Es la geometría de **una etiqueta de vino**, que es donde el
   comprador ya espera ver un bloque enmarcado.
3. **La esquina achaflanada** — un corte a 45° en lugar de un `border-radius`.
   Un radio de 12 px es la firma visual de una app; un chaflán es la de un
   objeto impreso.

### 5.2 Por qué el Decó acá es estructural y no adorno

Volvé a §2.2: **sobre el fondo oscuro, un bloque borgoña no se despega (2,05:1
como techo).**

La línea dorada que lo enmarca —el cartucho— es lo único que lo hace visible. Es
decir: el recurso Decó **es el que cumple la función de borde de UI**, no un
ornamento encima de un borde.

> **Un recurso decorativo que además resuelve un problema medido deja de ser
> decorativo.** Ese es el único Art Decó que este proyecto se puede permitir.

### 5.3 El límite, explícito

**Prohibido**, porque lleva la marca de 1925 a un disfraz de 1925:

soles nacientes · zigzags y galones · abanicos · escalonados tipo rascacielos ·
plumas · tipografías decó de display (Broadway, Poiret One, Limelight) ·
degradés dorados con biselado · pares de ornamentos espejados · el fondo de
mármol verde con latón.

Ninguna de esas cosas está en el imagotipo, y meterlas es contradecirlo.

---

## 6. La posición anti-tecnología, vuelta mecánica

*"No es una glorificación a la tecnología"* es una instrucción estética con
consecuencias concretas. Traducida a lo que se puede grepear después:

| Lo que hace el software por defecto | Lo que hace bouquet |
|---|---|
| Card con radio 8-12 px y sombra difusa | **Sin card.** Un filete dorado y aire. Si hay borde, chaflán |
| Botón pill con degradé | Rectángulo, borde de 1 px, versalitas trackeadas |
| Íconos por todos lados | **Palabras.** Y los pocos íconos, monolineales como el isotipo |
| Skeleton shimmer al cargar | **Espacio reservado y fundido.** El shimmer es el gesto más "app" que existe |
| Toast que entra rebotando | Una línea de texto que aparece y se queda |
| Sombras para simular elevación | **Luz.** Lo cercano está más iluminado, no más despegado |
| Badge de color chillón ("¡OFERTA!") | Una palabra en versalitas doradas |
| Glassmorphism, neón, degradés de dos tonos | Nada de eso existe acá |
| Contador regresivo, urgencia falsa | El [informe de parallax §10.1](parallax.md) ya lo prohibió: *coquetear es insinuar* |

**La prueba de una pantalla:** si al sacarle el contenido queda algo que podría
ser el panel de administración de cualquier SaaS, la pantalla está mal.

---

## 7. La forma: qué proporciones tiene una tienda de vino

### 7.1 La botella manda el encuadre

Una botella es **alta y angosta**, cerca de 1:4,5. La tarjeta de producto tiene
que seguir esa proporción, no la cuadrada de un catálogo genérico.

> **Por qué las tiendas de vino se ven a supermercado:** usan tiles cuadrados.
> Una botella dentro de un cuadrado obliga a achicarla hasta que el vino es un
> detalle y el espacio vacío es el protagonista.

**La tarjeta es un retrato vertical**, la botella entra casi entera y la
tipografía va abajo, alineada al eje central — la composición de una etiqueta.

### 7.2 Densidad: menos y más grandes

| Ancho | Productos por fila |
|---|---:|
| Móvil | **1** |
| Tablet | 2 |
| Escritorio | **3** — nunca 4 |

Tres es una decisión de posicionamiento, no de layout: **una grilla de 4 o 5
dice "volumen"; una de 3 dice "selección".** El diferenciador declarado en el
brief es *atención personalizada + vinos premium*, y una grilla densa lo
contradice antes de que el usuario lea una palabra.

### 7.3 El eje

**Centrado y simétrico en lo ceremonial** (landing, encabezado de ficha,
`/bodega`) — es lo que aporta el Decó y lo que hace una etiqueta.
**Asimétrico y a bandera en lo que se lee** (prosa, datos, checkout) — es lo que
aporta el libro. Nunca centrar un párrafo largo.

---

## 8. Materia: luz, grano y superficie

- **Una sola fuente de luz por escena**, cálida, fuera de cuadro, y caída larga.
  Un fondo "oscuro" plano es un `#111` de framework; un fondo *iluminado* es un
  gradiente radial descentrado. Cuesta lo mismo.
- **Grano.** Una capa de ruido del 2-3 % sobre los fondos oscuros. Y no es
  nostalgia: **un degradé oscuro en una pantalla de 8 bits hace bandas
  visibles**, y el ruido las disuelve. Otra vez, un recurso estético que paga
  una deuda técnica.
- **Superficies reales** en la fotografía: madera, lino, piedra, vidrio, corcho,
  lacre. Cero superficies de estudio.
- **El dorado nunca es un degradé.** Es un color plano. Un dorado biselado es
  un `<marquee>` con mejor gusto.

### 8.1 Dos registros fotográficos, porque uno solo no alcanza

| Registro | Dónde | Cómo |
|---|---|---|
| **Retrato** | Landing, encabezado de ficha, `/bodega` | Ambientada, sobre fondo oscuro, una luz cálida, caída profunda. Es la que vende |
| **Ficha** | La grilla de `/vinos` | Recorte consistente sobre fondo cálido neutro, misma altura de botella, misma perspectiva. Es la que **deja comparar** |

**La tensión es real y se resuelve separando, no promediando.** Una grilla de
fotos ambientadas es imposible de comparar; una landing de recortes sobre fondo
plano es un catálogo de mayorista. Son dos trabajos distintos sobre el mismo
producto.

Esto se enchufa directo en el manifiesto de assets de
[parallax §10.3](parallax.md): el registro *retrato* cubre los roles
**escenario** y **sujeto**; el registro *ficha* es un rol nuevo que ese informe
no tenía que contemplar porque no hablaba del catálogo.

### 8.2 Movimiento

Lo cuantitativo ya está resuelto en [parallax.md](parallax.md). Lo que agrega la
dirección visual es **el carácter**:

> **El movimiento tiene que leerse como luz y como mirada, nunca como
> interfaz.**

- Revelados largos con `ease-out`, 400-700 ms. Nunca rebote, nunca resorte con
  sobrepaso. **Un rebote es juguetón, y juguetón es app.**
- Lo que se mueve es el encuadre y la luz, no los elementos por su cuenta.
- El telón de la puerta de edad **pesa** ([parallax §10.2](parallax.md)): sube
  como una cortina, no como un modal.

---

## 9. El vocabulario, en cinco palabras

Los adjetivos que tienen que sobrevivir a la implementación. Si una pantalla no
se puede describir con estos, algo se desvió:

**Íntimo · Cuidado · Terroso · Ceremonial · Sin apuro**

Y los tres del arquetipo, que vienen del brief y no se negocian:
*apasionado, sensual, sofisticado* (**Amante**) sobre una base de
*confiable y responsable* (**Cuidador**).

---

## 10. Qué NO es bouquet

| No es | Por qué se aclara |
|---|---|
| **Una app** | Ver §6 entero |
| **Un club de vinos minimalista escandinavo** | Blanco, Helvetica y una botella flotando. Es la estética por defecto del rubro y niega el arquetipo Amante |
| **Un Gatsby temático** | Ver §5.3 |
| **Una bodega institucional** | Escudo, latín, "desde 1898". bouquet **no** es una bodega: vende lo que otros producen. Fingir linaje es mentir |
| **Un e-commerce genérico con tema oscuro** | Un tema oscuro es un `#111` y un acento. Acá el oscuro es un lugar con una luz |
| **Un supermercado** | Ver §7.2 |
| **Terroir francés serio y frío** | El borgoña de la marca está en hue 0: es cálido. La marca es argentina y sensorial, no académica |

---

## 11. Cómo se verifica que esto se cumplió

Porque una dirección visual sin criterio de aceptación es una charla.

| Afirmación | Cómo se falsea |
|---|---|
| "El dorado no lleva información sobre claro" | Grepear el token dorado en el modo papel: sólo puede aparecer en `border`, `stroke` y `fill` de adorno. **Nunca en `color`** |
| "No hay hex fuera de tokens" | El hook `no-hardcoded-colors` ya lo mide en el panel. **Falta el equivalente para la vidriera** — §12 |
| "El checkout es de papel" | Captura de `/checkout` y comparación del fondo contra el token de marfil |
| "3 productos por fila como máximo" | Inspección del grid a 1920 px |
| "Cero fuentes de terceros en runtime" | Pestaña Network filtrada por dominio: `fonts.googleapis.com` tiene que dar **0 pedidos** |
| "El contraste se cumple" | Correr un chequeo automático sobre las combinaciones de §2.1, con **un caso de control que sabemos que falla** (dorado sobre marfil) — si el chequeo lo deja pasar, el chequeo está roto |

⚠️ Ese último control negativo es el que hace útil a la tabla. Sin él, un
verificador que no lee nada informa "todo bien".

---

## 12. Lo que queda abierto, con disparador

| Qué | Quién decide | Disparador |
|---|---|---|
| **Display: Fraunces o Bodoni Moda** | el dueño — es estética, no técnica | Antes de `tokens.md` |
| **Licencia del wordmark** (Sitka / Addington CF) si se quiere componer texto en la fuente del logo | el dueño | Sólo si se quiere ir más allá del logo entregado |
| **Cuál grotesca para las cifras** | técnica, la elijo yo con `tokens.md` | Antes del primer componente con precio |
| **`tokens.md` — el paso 2 de `/disenio`** | — | Ahora. Sin él, `tienda` y `admin-presentacion` no deberían escribir componentes |
| ~~**Cómo se aplica esto al panel** (`apps/admin`)~~ **Decidido el 2026-09-16:** la mezcla C —los colores de la planilla y la búsqueda de la libreta—, elegida por el dueño mirando tres direcciones. Tokens en [`tokens.md` §7](tokens.md), porqué en [ADR 011](../architecture/decisions/011-entrar-al-panel.md) | el dueño | — |
| **Hook de colores para la vidriera** | técnica | Junto con `tokens.md`. Hoy `no-hardcoded-colors` sólo mira Dart |

> ⚠️ **El panel no es la vidriera.** Toda la ceremonia de este documento aplica
> a `apps/tienda`. `apps/admin` toma los dos colores y la tipografía de texto, y
> **nada más**: ahí el requisito es la claridad, no el deseo.
