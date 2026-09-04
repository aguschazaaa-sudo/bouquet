# Las cinco escenas de la landing — bouquet

- **Fecha:** 2026-09-03
- **Estado:** vigente. Es el **paso 3 de `/disenio`** (la composición, después de la
  dirección). Las cinco decisiones de §1.2 están tomadas por el dueño.
- **Qué contesta:** qué se muestra en cada escena, cómo se ve, qué dice y qué
  hace. Plano por plano, con su copy y su asset.
- **Qué NO contesta:** los tokens con sus nombres de código —eso sigue siendo
  `design/tokens.md`, que **no existe** y bloquea el primer componente— ni
  los textos legales, que no los escribe esta dirección.
- **Insumos:** [`direccion.md`](direccion.md) (visual), [`voz.md`](voz.md)
  (lenguaje), [`parallax.md`](parallax.md) (movimiento), y una maqueta navegable
  que se construyó para poder mirar esto en un teléfono en vez de leerlo.

---

## 0. La tesis, en una línea

**El scroll no te lleva por cinco lugares: te lleva desde una puerta hasta una
lámpara.**

`parallax.md` ya había fijado que las velocidades salen de **una sola cámara**.
Lo que faltaba es que la atmósfera necesita el mismo tratamiento: **una sola
lámpara**, con una posición declarada por escena, de la que se derivan el lado
iluminado del sujeto, la caída de la viñeta y qué filo del cartucho engancha luz.

Un número por escena, igual que un `--amplitud` por plano. Si eso funciona, las
cinco escenas son un lugar. Si no, son cinco slides.

---

## 1. De dónde sale este documento

### 1.1 El método

Cinco agentes en paralelo, uno por escena, con los tres documentos de dirección y
la maqueta como insumo, y una grilla de juicio declarada de antemano:
**cohesión · viabilidad técnica · originalidad · afinidad con la marca.**

⚠️ **El valor no estuvo en las propuestas: estuvo en los defectos.** Tres de los
cinco encontraron fallas reales en la maqueta, y **dos de ellas las encontraron
por separado** — §4. Un agente que sólo propone es un generador de opciones; uno
que además audita lo que ya existe paga su costo.

Y hubo una clase de problema que **ninguno podía ver**, porque cada uno miraba su
escena: los conflictos entre escenas. Están resueltos en §3 y anotados como
tales.

### 1.2 Las cinco decisiones, tomadas

| # | Decisión | Lo decidido |
|---|---|---|
| 1 | **¿La escena 4 muestra precio?** | **No.** La landing queda 100 % estática y fuera del circuito de purga por tag de [ADR 005](../architecture/decisions/005-hosting-vidriera.md) |
| 2 | **¿Dónde va el único pin?** | **Escena 3.** Es el único lugar donde el movimiento enseña en vez de decorar |
| 3 | **¿Qué enseña la escena 3?** | **La edad por el borde de la copa.** Un hecho óptico, no una nota de cata |
| 4 | **¿La escena 2 es lugar o lámina?** | **Lámina enmarcada.** El marco excusa la foto de banco |
| 5 | **¿Se produce el par de copas?** | **No hace falta: son SVG.** §3.3 |

---

## 2. El sistema que comparten las cinco

### 2.1 El ritmo — lugar · objeto · lugar · objeto · lugar

`direccion.md §8.1` declara dos registros fotográficos y dice que la tensión *se
resuelve separando, no promediando*. Lo aplicó al catálogo. **También resuelve la
landing.**

| Escena | Registro | Qué es para el lector | Rango de `v` |
|---|---|---|---|
| 1 · el umbral | retrato | **lugar** — estás adentro | amplio `0.40 → 1.15` |
| 2 · el origen | ficha | **objeto** — te muestran una imagen | comprimido `0.85 / 1.00 / 1.15` |
| 3 · el sorbo | retrato | **lugar** | amplio |
| 4 · la vitrina | ficha | **objeto** | comprimido |
| 5 · la mesa | retrato | **lugar** | amplio, con sólo 2 planos |

> **La lámina tiene menos profundidad que el lugar. Por eso se lee como objeto y
> no como mundo.** Misma ecuación, misma separación mínima de 0,15, mismo
> timeline. Cambia sólo la **apertura del rango**.

⚠️ Si la separación de 0,15 no se percibe en dispositivo —`parallax.md §2.2` la
marca como heurística—, las láminas se aplanan, **que es lo que son**. La falla
es a favor. Y el ritmo tiene un portador que no es movimiento: **el cartucho**,
que sigue estando en Tier C.

### 2.2 La lámpara

Una por escena. Tres números: azimut, altura y radio. La luz **viene de donde la
página va**.

| Escena | `--lx` | `--ly` | `--lr` | Carácter |
|---|---:|---:|---:|---|
| 1 · umbral | 64 % | 44 % | 24 % | lejos, chica, al fondo. Mirás hacia adentro |
| 2 · origen | 50 % | 26 % | 74 % | pareja, de museo, alta y frontal |
| 3 · sorbo | 50 % | 40 % | 46 % | encima del sujeto, y **barre** durante el pin |
| 4 · vitrina | 50 % | 48 % | 92 % | pareja, de vitrina, sin drama |
| 5 · mesa | 16 % | 86 % | 98 % | de tu lado, baja, grande. Ya estás adentro |

El radio va `24 → 74 → 46 → 92 → 98`: la luz se acerca. La única contracción es
la escena 3, y es deliberada — es el foco.

### 2.3 El cartucho, como sistema

Es el recurso Art Decó que `direccion.md §5.2` habilita porque **hace trabajo
estructural**: sobre fondo oscuro un panel borgoña llega a 2,05:1 y sólo la línea
dorada lo hace visible.

| Elemento | Regla |
|---|---|
| Chaflán | **Dos esquinas opuestas**, nunca cuatro. Cuatro es un `border-radius` con otro nombre |
| Proporción de chaflán | **2:1 entre niveles anidados.** Telón 18 → marco 16 → ventana 8 → filete de botón 9 |
| Grosor del filete | **1 px, constante.** La jerarquía se marca con **opacidad**, nunca con grosor: es el trazo monolineal del isotipo |
| Proporción de la ventana | **La fija el sujeto, no el sistema.** Paisaje → 4:3 (escena 2). Botella → **~9:16** (escena 4), porque `direccion.md §7.1` dice que la botella es 1:4,5 y el tile cuadrado es el error de supermercado |
| Ancho | `min(88vw, 440px)`. Techo en 440: nunca se vuelve heroico. Es un plano de museo, no un afiche |
| Recorte | `overflow: hidden` + `clip-path` de polígono. **No `mask-image`** — el recorte rectangular es una primitiva de pintado; la máscara se reserva para formas con degradé real |

⚠️ **La opacidad del filete no está medida.** `direccion.md §2.1` calcula dorado
puro sobre tinta en 8,80:1, pero el filete se dibuja al 72 % (marco) y 28 %
(ventana). **Si el renderizado real cae por debajo de 3:1, el cartucho deja de
cumplir la función que lo justifica.** Se mide con cuentagotas sobre el píxel
pintado, no sobre el valor CSS. Ver §8.

### 2.4 El scrim viaja con el texto

`parallax.md §3.2` lo exige y la maqueta lo violaba en dos escenas (§4.1).

> **Todo lo que tenga que ser legible viaja junto a su fondo.** El scrim
> pertenece a z3 y se mueve a `v = 1.00`, igual que el texto que protege.

Y es **una placa de color plano dentro de `plano--contenido`**, no la viñeta de
ambiente. La viñeta oscurece bordes de pantalla; el scrim garantiza un contraste
que no cambia mientras scrolleás. Son dos cosas distintas y la maqueta las
confundía.

### 2.5 Los rótulos

**Las escenas de lugar (1, 3, 5) no llevan rótulo. Las de objeto (2, 4) sí.**

Un rótulo es una cartela de museo: pertenece a algo que se exhibe, no a algo que
se habita. Tres agentes llegaron a esta regla por separado, sin que se les
pidiera — por eso está acá y no en la cabeza de nadie.

### 2.6 Una sola animación discreta en toda la página

`parallax.md §4.2` separa lo **continuo** (atado al scroll, se deshace exacto) de
lo **discreto** (cruza un umbral, no vuelve). Mezclarlas es lo que se siente
nervioso.

La página es **enteramente continua**, con **una** excepción, y está en la
escena 1: la lámpara sube de brillo al entrar. Es la vista acostumbrándose a la
oscuridad de una cava — nadie ve todo de golpe al abrir esa puerta.

Es la única, y se gastó ahí a propósito: pasa junto al telón, que ya es una
animación por tiempo, así que no introduce una clase nueva en medio de la página.

---

## 3. Las cinco escenas

⚠️ **Todo el copy de acá pasa por el agente [`voz`](../../../.claude/agents/voz.md)
antes de llegar a un componente.** Está escrito contra `voz.md §8` pero no está
curado.

### 3.1 Escena 1 — El umbral

**Lugar · 5 planos · rango amplio · es la capa del LCP.**

**Contenido:**

> **El aroma lo trae la uva. El bouquet lo gana esperando.**
>
> Entre la bodega y tu mesa hay meses. Ese tramo es nuestro.

La primera línea es la tesis de `voz.md §1` puesta literalmente en la puerta: en
enología *aroma* es lo que el vino trae de la uva y *bouquet* es lo que gana
mientras está guardado. **Es el único lugar de todo el sitio donde la palabra se
usa como término**; `voz.md §1` prohíbe gastarla como jerga en cualquier otro
lado.

La segunda planta **"tu mesa"**, que la escena 5 cobra al final. Y reclama
custodia con el único "nosotros" que `voz.md §5` licencia.

> ⚠️ **Conflicto entre escenas, resuelto.** La fórmula *acostado, a temperatura
> pareja, sin luz* **sale de la landing**. Estaba en la escena 1 y en la 5, y
> decía lo mismo dos veces. Su lugar es la ficha del vino, donde `voz.md §10.1`
> ya la tiene curada por botella.

| Plano | `v` | Amplitud | Qué contiene | Tratamiento | Ocluye |
|---|---:|---:|---|---|---|
| z0 ambiente | 0.40 | **+18vh** | Textura cálida detrás de la lámpara | mínimo · mínima · difusa | nada |
| z1 escenario | 0.55 | **+13,5vh** | Hilera de botellas **acostadas** en rack, perdiéndose | bajo · baja · suave | al ambiente |
| z2 sujeto | 0.85 | **+4,5vh** | **Cuello y hombro** de una botella acostada, recorte con alfa | **máximo · máxima · nítida** | al escenario |
| z3 contenido | 1.00 | 0 | Texto **+ su scrim** | color plano | al sujeto donde cruza |
| z4 detalle | 1.15 | **−4,5vh** | Borde de copa vacía desenfocado, esquina inferior | medio · media · **desenfocada** | al sujeto y al escenario |

**Por qué el cuello y no una botella entera:** un cuello recortado no llega al
área de etiqueta. Una botella entera obliga a elegir entre mostrar una marca
ajena o taparla con sombra — y taparla rompe la nitidez máxima que `parallax.md
§3.4` le exige a z2. **Se resuelve por recorte, no por desenfoque.**

**Funcionamiento:** todo continuo salvo el brillo de la lámpara (§2.6). El texto
**no tiene revelado**: es la capa del LCP y `parallax.md §6.3` prohíbe fundir
desde `opacity: 0`. Tier B cae a ambiente + sujeto + contenido. Landscape de
teléfono → Tier B por regla.

### 3.2 Escena 2 — El origen

**Objeto · 3 planos · rango comprimido.**

**Contenido:**

> `Valle de Uco`
>
> Viñedos a mil doscientos metros. Dieciséis grados entre el mediodía y la
> noche. El suelo es de piedra: no retiene nada.

Tres frases enteramente nominales — *sustantivos, no adjetivos* (`voz.md §7.2`)
llevado al extremo. El sujeto tácito es **la región**, no la marca: bouquet no
produce, así que jamás puede decir *"nuestros viñedos"*.

⚠️ **Las tres cifras hay que verificarlas contra una fuente citable antes de
publicar.** Si terminan saliendo de una bodega puntual, pasan a ser dato de
bodega y necesitan cita en pantalla (`voz.md §3.2`). Disparador en §10.

**Cero CTA**, que es lo que `parallax.md §10.1` fija para esta escena.

> **Decisión: la escena 2 NO se acopla al vino de la escena 4.** Describe la
> región en general. Si el copy tuviera que cambiar cada vez que rota la
> selección, dejaría de ser un asset horneado en build y la landing perdería su
> garantía de estática.

| Plano | `v` | Amplitud | Qué contiene |
|---|---:|---:|---|
| ambiente | 0.85 | **+4,5vh** | El resplandor de la lámpara de museo. **CSS puro, cero bytes** |
| contenido | 1.00 | 0 | **El marco entero**: cartucho + ventana + pie. Es un objeto en tu espacio |
| detalle | 1.15 | **−4,5vh** | La viñeta de caída. CSS puro |

**La ventana** es la de `parallax.md §3.5` — máscara quieta, contenido derivando
detrás: el efecto más caro a la vista y el más barato de renderizar. La foto de
adentro deriva a **`+4,5vh`**.

> ⚠️ **Conflicto resuelto: el signo.** A través de una ventana, lo lejano se
> mueve **más lento** que el marco. La foto va en positivo, no en negativo. Un
> valor negativo la pondría *delante* del marco, que es geométricamente
> imposible.

**Funcionamiento:** nada discreto. Al scrollear hacia arriba se deshace exacto —
el marco nunca se movió. Landscape: el marco se dimensiona **por alto de
viewport**, `min(60vh, 320px)`, no por ancho.

### 3.3 Escena 3 — El sorbo

**Lugar · 3 planos · rango amplio · el ÚNICO pin de la página · contraste máximo.**

Es la escena que `parallax.md §10.1` define como *"la que enseña, la que hace que
vuelvan"* — y es la que `voz.md §3.2` no deja escribir, porque bouquet no puede
firmar una descripción sensorial de un líquido que no probó.

> **La salida: no enseña sobre el vino, enseña sobre el tiempo.** Una copa a
> contraluz muestra la edad en el borde, y eso es un **hecho óptico**, no una
> nota de cata. Violeta en el menisco = joven. Teja = guardó años.

**Contenido:**

> **El borde dice el tiempo.**
>
> Violeta es joven. Teja ya guardó años. `Cómo se guarda cada añada`

La densidad de texto **más baja de las cinco**. Acá la marca se calla: es el
paréntesis de `voz.md §1.2`.

| Se afirma | Con qué autoridad |
|---|---|
| El color del menisco correlaciona con el tiempo en botella | Química del vino: polimerización de antocianinas. **Se ve, no se degusta** |
| Violeta = joven · teja = años | El mismo hecho, verificable con dos vinos de añada conocida |

⚠️ **Se descartó *"todavía tiene tiempo"*.** Predice el futuro del vino, y eso es
una opinión de cata disfrazada de dato. **bouquet habla del tiempo que ya pasó,
nunca del que falta.** Es la misma frontera que `voz.md §1.2` traza entre el
antes y el sorbo: la escena mira la copa desde afuera.

| Plano | `v` | Amplitud | Qué contiene |
|---|---:|---:|---|
| ambiente | 0.40 | **+18vh** | Resplandor + caída a negro |
| sujeto | 0.85 | **+4,5vh** | Las dos copas — **hoy no está envuelto en un plano y no deriva: es un bug** |
| contenido | 1.00 | 0 | Título + cuerpo + CTA blando, **con su scrim** |

**El barrido** no es un cuarto plano: es el sistema de luz. Va en **z1, detrás de
las copas**, para que el sujeto quede literalmente *a contraluz*.

**Los assets: SVG monolineal, cero archivos raster.**

> El par apareado —misma copa, misma posición, misma luz, dos edades— **no existe
> como stock**, y conseguirlo real exige una producción fotográfica con retoque
> para igualar exposición entre las dos tomas. La ilustración monolineal no lo
> mitiga: **lo elimina.** Y es más coherente con `direccion.md §1`, que exige que
> todo lo dibujado sea monolineal como el isotipo.

**Funcionamiento:**

| Concepto | Valor |
|---|---|
| Altura total | **240svh** — corregido desde 262 (§4.2) |
| Pin real | **140svh**, bajo el techo de 150 (1,5 viewport) de `parallax.md §4.5` |
| Rango del barrido | `contain 8% contain 92%` — las zonas muertas de §4.4 |
| Tier C | **El pin se desarma**: `min-height: auto` y `position: relative`. Ver §4.3 |

**La composición Tier C, descrita como la única que existe:** fondo cava con un
resplandor parejo, dos copas lado a lado en línea dorada, la izquierda violeta
hasta el borde, la derecha teja. Debajo de cada una, en versalitas: *joven* / *de
guarda*. Al pie, el título y la línea con el enlace. **Nada se mueve y nada
falta** — la comparación está completa en el cuadro fijo.

**Si alguien scrollea rápido:** el brillo ambiente base tiene que iluminar los dos
meniscos lo suficiente para leer el mensaje **sin** el barrido. Si el mensaje sólo
se entiende cuando la luz pasa por encima, la escena falla el criterio que la
habilitó a tener el único pin.

### 3.4 Escena 4 — La vitrina

**Objeto · 3 planos · rango comprimido · la única que toca el catálogo · CTA duro.**

**Contenido:**

> `En la vitrina`
>
> **‹nombre del vino›**
> ‹Bodega› · ‹Varietal› · ‹Añada› · ‹Región›
>
> Llegó acostada, como todas. Se queda hasta que alguien la elige.
>
> `Ver el vino`

⚠️ **Los campos entre ‹› salen de la proyección publicada. No se inventan acá.**
Un nombre de bodega escrito a mano en un documento de diseño es exactamente por
donde entra un hecho falso a producción.

La línea no describe la copa: describe **la escena de estar guardada y ser
elegida** (`voz.md §3.1`), y por eso no necesita firma. `Ver el vino` usa el
glosario §7.3 —al cliente nunca se le dice *producto*— y empareja con el
`Ver todos los vinos` de la escena 5: singular y plural, los dos únicos CTA duros
de la página.

| Plano | `v` | Amplitud | Qué contiene |
|---|---:|---:|---|
| sujeto | 0.85 | **+4,5vh** | El cartucho con ventana **~9:16** y la foto de la botella |
| contenido | 1.00 | 0 | Rótulo, nombre, dato, línea, CTA. **Fuera del cartucho, sobre tinta lisa** |
| detalle | 1.15 | **−4,5vh** | Viñeta de caída |

El texto **nunca se superpone a la foto**, y por eso es la única escena donde el
scrim no hace falta: no hay contraste variable que proteger.

**Cómo se cambia el vino ofertado — sin romper la landing estática:**

1. Un archivo versionado en `apps/tienda` guarda **un solo campo**: el `slug`.
2. En **Cloud Build**, un script lee ese `slug` contra la proyección publicada
   **una vez**, y trae `nombre`, `bodega`, `varietal`, `añada`, `región` e
   `imagen`. **Nunca `precio` ni `stock`, ni para descartarlos después.**
3. Se hornea en el HTML estático. **Cero fetch en runtime.**
4. Lo edita quien administra el catálogo, cambiando el `slug`. Se despliega con
   el deploy de `tienda`.

> **La defensa contra la fuga de precio no es CSS: es que el build nunca lea el
> campo.** Si la escena reutiliza la tarjeta del listado y sólo *oculta* el precio
> por estilo, un cambio futuro en el componente base puede destaparlo sin que
> nada se rompa visualmente — y ahí la garantía de "nunca se invalida" ya es
> falsa y nadie se enteró.

⚠️ **El script tiene que fallar el build** si el `slug` no está publicado en el
momento de hornear. Si no, la landing queda con un CTA duro apuntando a un 404.

**La trampa a evitar:** es la escena con más riesgo de caer en `direccion.md §6`,
porque es la única con producto y con botón. Un `border-radius`, una sombra de
elevación, un badge en pill o el dorado en degradé la convierten en la card de
cualquier SaaS.

### 3.5 Escena 5 — La mesa

**Lugar · 2 planos · el mínimo posible, a propósito · CTA duro.**

Es el **después** de `voz.md §1.2`: lo que queda cuando la botella está vacía. Y
es **la escena 1 del otro lado** — misma botella, acostada y esperando en la
oscuridad, ahora abierta en una mesa con luz cálida.

**Contenido:**

> **Lo que queda.**
>
> La botella, abierta. Dos copas, una silla corrida, el vidrio todavía empañado.
> Así llegó, por fin, a tu mesa.
>
> `Ver todos los vinos`

*"Lo que queda"* es la definición literal que `voz.md §1.2` da del después.
*"tu mesa"* cobra lo que la escena 1 plantó. Y *"el vidrio todavía empañado"* es
la condensación: **la única foto posible de "temperatura pareja"**, que es
exactamente lo que la marca vende.

**Qué NO se dice acá, y por qué:**

| No se dice | Por qué |
|---|---|
| Varietal, añada, precio | Es el trabajo de la escena 4. Repetirlo rompe el ritmo lugar/objeto |
| *Acostado, a temperatura pareja, sin luz* | Es la frase del **antes**. Reusarla borra la diferencia entre los dos tiempos, que es la tesis entera |
| Quién está en la mesa | *Cero caras* se extiende al texto. **"Quién más" es del lector** |
| La hora | La luz cálida y baja ya la dice. Escribirla es el instinto de precisión que `voz.md` marca como voz de software |
| *Descubrí*, *viví*, *disfrutá* | El registro es cava: describe, no empuja. El único imperativo es el botón |
| *Nosotros* | `voz.md §5` lo restringe a custodia. Acá no hay custodia: hay memoria |

| Plano | `v` | Amplitud | Qué contiene |
|---|---:|---:|---|
| escenario | 0.55 | **+13,5vh** | La mesa entera. **La oclusión se hornea dentro de la foto**: un borde de copa o el cuello de la botella recortando el primer plano |
| contenido | 1.00 | 0 | Texto + CTA **+ su scrim** |

**Los objetos sobre la mesa, y qué dice cada uno:**

| Objeto | Qué dice |
|---|---|
| **La botella, abierta**, apoyada — no de pie rígida | **La única botella abierta de toda la página.** El resto está cerrada; acá es donde bouquet deja de hablar |
| **El corcho, suelto al lado** | Sin él, podría estar recién comprada. Es lo que prueba que se abrió |
| **Copa uno**, primer plano, **con condensación visible** | La escena es tuya, y la condensación es la prueba de la temperatura |
| **Copa dos**, más atrás, con un resto | Hubo alguien más. Una copa es bodegón; dos son una historia |
| **Silla corrida** en el borde, desenfocada | Alguien se acaba de levantar. Sonido implícito sin audio ni cara |
| **Un saco en el respaldo** | Evidencia de gente, no gente |

⚠️ **Cero caras es un requisito duro, no una preferencia.** Se descarta cualquier
candidata con una cara visible, aunque sea de espaldas o borrosa.

⚠️ **Con 2 planos, un asset flojo carga solo.** Con 5 se disimula entre otros.
Acá más que en ninguna otra escena, conviene **foto propia** —celular, 19:30
real— antes que un banco genérico.

**Cómo termina la página:** después del CTA no hay más ceremonia. Un pie mínimo,
con filete dorado arriba, wordmark chico, dos o tres enlaces y el mínimo legal.
**Nada de un segundo CTA ni de una oferta.** El cierre es una exhalación, no otra
insistencia.

---

## 4. Los tres defectos que la maqueta destapó

**Ninguno de estos se veía leyendo los documentos.** Aparecieron porque hubo algo
que mirar. Ese es el argumento entero a favor de maquetar antes de especificar.

### 4.1 El scrim viajaba en el plano equivocado — en dos escenas

La viñeta que protege el contraste del texto vivía en `plano--detalle`
(`v = 1.15`) en la escena 1 y en `plano--escenario` (`v = 0.55`) en la escena 5.
El texto vive en `v = 1.00`. **El contraste cambiaba mientras se scrolleaba**, que
es exactamente lo que `parallax.md §3.2` existe para prohibir.

Es el defecto que ninguna herramienta estática detecta: en el momento de la
captura, el contraste está bien.

### 4.2 El pin se pasaba del presupuesto

`min-height: 262svh` con un sticky de `100svh` da **162svh de pin**. El techo de
`parallax.md §4.5` son **150svh**. Se pasaba por 12. Corregido a 240svh → 140 de
pin, con margen para el desajuste de la barra de direcciones de iOS que la propia
§5.4 advierte.

### 4.3 El pin sobrevivía a apagar el movimiento — y es el peor de los tres

Con `prefers-reduced-motion`, la regla global apagaba las animaciones **pero no
tocaba la altura ni el sticky**. Resultado: alguien con movimiento reducido
scrollea **1,4 pantallas sin que cambie nada**.

> Eso no es una composición estática que se ve peor: **es un scroll que no hace
> nada, y parece que la página se colgó.** Falla justo la cohorte que Tier C
> existe para proteger.

La corrección desarma el pin entero bajo esas condiciones:

```css
.escena--sorbo { min-height: auto }
.fijo { position: relative; height: auto; min-height: 100svh }
```

**Cómo se detecta:** con *Reducir movimiento* activado, medir cuánto scroll pasa
entre que el título aparece y que empieza la escena siguiente. Si es más de un
viewport y no cambió nada en el medio, el defecto está.

---

## 5. La corrección a `parallax.md §4.1` — los signos están invertidos

Con el snippet tal como está escrito ahí —`animation-range: cover 0% cover 100%`
y `to { translate: 0 var(--amplitud) }`— una amplitud **negativa** en el plano de
ambiente lo hace moverse **más** que el contenido, no menos. **La profundidad se
lee al revés.**

Sale de la aritmética: sobre el rango `cover`, el contenedor recorre
`(alto de viewport + alto del elemento)` hacia arriba. Para que un plano recorra
**menos**, hay que **sumarle** desplazamiento hacia abajo. **Lento → positivo.**

| Plano | `v` | §4.1 dice | Correcto |
|---|---:|---:|---:|
| ambiente | 0.40 | `-18vh` | **`+18vh`** |
| escenario | 0.55 | `-12vh` | **`+13,5vh`** |
| sujeto | 0.85 | `-4vh` | **`+4,5vh`** |
| contenido | 1.00 | `0` | `0` |
| detalle | 1.15 | `4vh` | **`-4,5vh`** |

Las **magnitudes** del documento están bien como atenuación deliberada: los
valores corregidos son exactamente proporcionales a `(1 − v)` con una escala de
30vh, que es la fuerza de parallax que el documento eligió. Lo que estaba mal era
sólo el signo.

⚠️ **No se da por confirmado desde el escritorio.** Se confirma scrolleando con
el dedo en un teléfono: si el fondo se siente adelantado o pegado, ahí está la
respuesta. **Hasta entonces, `parallax.md §4.1` no se edita.**

---

## 6. El manifiesto de assets, consolidado

**16 planos, pero sólo 7 necesitan un archivo.** El resto es CSS —resplandores,
viñetas, marcos, chaflanes— o SVG propio.

| Escena | Rol | Vertical | Horizontal | Formato | Qué buscar |
|---|---|---|---|---|---|
| 1 | ambiente | 1600×2400 (**se sirve a la mitad**) | 2400×1350 | AVIF | Bokeh cálido, niebla, pared oscura. Sin sujeto reconocible |
| 1 | escenario | 1600×2400 | 2560×1440 | AVIF | Hilera de botellas **acostadas** en rack. **Sin fuente de luz propia visible** |
| 1 | sujeto | ≤1200×1600 lado mayor — **una pieza para las dos direcciones** | | **AVIF con alfa** | Cuello y hombro, recorte ajustado, **sin llegar a la etiqueta** |
| 1 | detalle | ≤800 lado mayor — una pieza | | **AVIF con alfa** | Borde de copa vacía, desenfocado |
| 2 | lámina | 1600×2400 | 2560×1440 | AVIF | Hileras de vid sobre suelo rocoso, relieve al fondo que sugiera altura. **Documental, no lifestyle** |
| 3 | las dos copas | — | — | **SVG inline** | **Producción propia. Cero licencia** |
| 4 | botella | ≤1200×1600 lado mayor | | **AVIF con alfa** | **Foto propia.** Es el único plano donde la foto ES el producto |
| 5 | escenario | 1600×2400 | 2560×1440 | AVIF | Mesa a hora dorada. **Descartar cualquier resultado con cara visible** |

> ⚠️ **Una foto de banco con su propia luz choca con la lámpara única.** El
> sistema depende de que cada escena tenga **una** fuente en una posición
> declarada. Antes de aceptar una candidata: muestrear luminancia en grilla; si
> hay un segundo máximo local lejos del punto de la lámpara, **se descarta o se
> recorta fuera de encuadre — no se arregla con más blur.**

---

## 7. El orden de construcción

**Tier C primero.** No es una preferencia: la composición estática hay que
construirla igual para `prefers-reduced-motion`, para el primer render, para el
buscador y para la gama baja. **Cuatro problemas, un artefacto.**

| Fase | Qué | Por qué antes que lo siguiente |
|---|---|---|
| **0** | **`design/tokens.md`** · display definido (Fraunces o Bodoni Moda) · hook de colores para la vidriera | `direccion.md §12`: sin esto, `tienda` no debería escribir componentes |
| **1** | **El sistema, no las escenas**: el cartucho como componente, la lámpara como tres tokens, el scrim en z3, el motor de deriva (un `@keyframes`, un timeline, un token por plano) | Si las escenas se construyen primero, cada una inventa su versión del cartucho |
| **2** | **Las cinco escenas en Tier C**, estáticas y completas, con copy real curado por `voz` | Es el fallback y el 60 % del trabajo. Si acá no es hermoso, el movimiento estaba cargando el mensaje |
| **3** | **El movimiento**, detrás de `@supports (animation-timeline: view())` | Enriquecimiento puro. Se agrega, no se integra |
| **4** | **El pin de la escena 3** | Es lo único que se puede cortar entero sin romper nada |
| **5** | **Los assets definitivos**, reemplazando placeholders | `parallax.md §12`: cada foto definitiva obliga a revisar el contraste de la tabla de §3.4 |

⚠️ **La landing es el paso 5 de [ARQUITECTURA §12](../../../ARQUITECTURA.md#12-orden-de-construcción)**,
después de la ficha y del listado. Cuando toque maquetarla, **la tarjeta de ficha
ya existe** — la escena 4 reusa, no inventa.

---

## 8. Cómo se verifica

Campo obligatorio: cada afirmación con su forma de falsearla, y con control
positivo.

| Afirmación | Cómo se falsea |
|---|---|
| "El scrim viaja con el texto" | Cuentagotas sobre el píxel real detrás del `h2` en **tres puntos del rango** (0 %, 50 %, 100 %). Si el ratio cae de 4,5:1 en alguno, está en el plano equivocado |
| "El pin entra en el presupuesto" | `scrollHeight` de la escena menos el alto del sticky ≤ 150svh |
| "Tier C no tiene scroll muerto" | Con *Reducir movimiento*, medir el scroll entre que aparece el título y que empieza la escena siguiente |
| "El cartucho hace trabajo estructural" | Contraste del filete **renderizado** (no el valor CSS) contra el fondo. **Debe dar ≥ 3:1.** Control negativo: el mismo dorado al 20 % **tiene que fallar** |
| "La landing es 100 % estática" | `grep` de símbolo de moneda y de atributos de precio en el HTML servido de la home. **Control positivo:** el precio **sí** tiene que aparecer en la ficha |
| "El movimiento está en el compositor" | La prueba de `parallax.md §9.1` — bloquear el hilo principal 3 s y scrollear. **Control negativo:** la misma prueba sobre una versión en JS **tiene que congelarse** |
| "La banda de color del menisco se ve" | Capturar a 375 px de ancho y medir la altura en px de la franja de color. **Menos de ~6-8 px y la escena 3 no comunica nada** en el dispositivo donde está la mayoría del tráfico |
| "Cero caras en los assets" | Revisión manual, una por una. **No se automatiza** |
| "El copy no tiene dialecto de cata" | `voz.md §11`, con su control positivo: una cita firmada de bodega **tiene** que aparecer y **no** contar como falla |

---

## 9. Presupuesto de lecturas de Firestore

Campo obligatorio según `post-task-doc`.

| Escenario | Lecturas que agrega | Contra los 50.000/día |
|---|---|---|
| Escenas 1, 2, 3 y 5 — marca pura | **0** | 0 % |
| Escena 4, horneando el vino ofertado en build | **1 por deploy de `tienda`**, no por visita | **No entra en la tabla diaria**: son deploys, no visitas |
| Cualquier escena leyendo Firestore desde el navegador | ~1 por visitante | **Rompe [ADR 004](../architecture/decisions/004-frescura-y-lecturas.md). Prohibido** |

**La landing no entra al circuito de purga por tag `catalogo`**, y eso se sostiene
por una sola razón: **el build lee una vez y el runtime no lee nunca.** El día que
la escena 4 muestre precio, esta línea cambia — y con ella el ADR 005.

---

## 10. Lo que queda abierto, con disparador

| Qué | Quién decide | Disparador |
|---|---|---|
| **`tokens.md`** — el paso 2 de `/disenio` | — | **Ahora.** Bloquea el primer componente |
| **Display: Fraunces o Bodoni Moda** | el dueño | Antes de `tokens.md` |
| **Verificar los signos de §5 en un teléfono** | — | Antes de corregir `parallax.md §4.1` |
| **Medir el contraste del filete del cartucho** | — | Junto con `tokens.md`. Si da < 3:1, §2.3 se cae |
| **Las tres cifras del Valle de Uco** (altura, amplitud, suelo) | el dueño, con fuente | Antes de publicar el dominio |
| **Licencia de las 6 fotos** de §6 | el dueño | Antes de publicar el dominio. Ya estaba abierto desde 2026-09-03 |
| **La foto propia de la botella de la escena 4** | el dueño | Antes de la escena 4. Es el único plano donde la foto ES el producto |
| **El texto del pie** y el mínimo legal | **no lo escribe esta dirección** | `voz.md §12` — un texto legal se copia de quien corresponda |

---

## 11. Cuándo este documento deja de servir

- **Cuando la escena 4 muestre precio:** §9 cambia entero y la landing entra al
  circuito de purga.
- **Cuando las fotos de reemplazo se cambien por definitivas:** hay que revisar
  que cada plano siga cumpliendo su rol y su tratamiento de `parallax.md §3.4`.
- **Cuando `tokens.md` exista:** las opacidades y proporciones de §2.3 dejan de
  vivir acá y pasan a ser tokens con nombre.
- **Cuando alguien mida los signos de §5:** o se corrige `parallax.md §4.1`, o se
  corrige este documento. **Los dos no pueden tener razón.**
