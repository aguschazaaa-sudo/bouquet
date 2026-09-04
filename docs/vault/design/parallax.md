# Informe — parallax scroll en la vidriera

- **Fecha:** 2026-09-03
- **Estado:** vigente. **Las seis decisiones de §10 están tomadas** por el
  dueño el 2026-09-03; el hosting salió de acá y se fue a su propio
  [ADR 005](../architecture/decisions/005-hosting-vidriera.md). La dirección
  visual que este informe declaraba faltante **ya existe**:
  [`direccion.md`](direccion.md).
- **Qué contesta:** cuántas capas, qué va en cada una, cómo se coordinan, con
  qué técnica, a qué costo y cómo se verifica.
- **Qué NO contesta:** paleta, tipografía, ilustración, fotografía. Eso es
  `/disenio`, y este informe está escrito para no condicionarlo.

---

## 0. La tesis, en una línea

**El parallax deja de ser un capricho cuando las velocidades se derivan de una
sola cámara en vez de elegirse capa por capa.**

Un parallax barato tiene un número mágico por capa (`0.3`, `0.7`, `1.2`,
"probé hasta que quedó lindo"). Un parallax premium tiene **una** ecuación y
cada capa sólo aporta su profundidad. La diferencia no se ve en una captura:
se siente al scrollear rápido, cuando las capas del primero se desarman y las
del segundo se mantienen como un mismo espacio.

Todo lo demás en este documento sale de esa frase.

---

## 1. Qué dice la evidencia — el parallax puede salir mal, y sale mal seguido

Antes de diseñar nada, los tres hallazgos que hay que respetar o el efecto
juega en contra.

| Hallazgo | Fuente | Qué obliga |
|---|---|---|
| Los usuarios scrollean rápido y **se comen pantallas en blanco**: los elementos animados no llegaron a renderizar | NN/g, *What Parallax Lacks* | El estado final tiene que ser alcanzable **antes** de que la escena salga |
| Al preguntarles dicen *"qué copado"*; **mirándolos trabajar, lo ignoran o se traban** | NN/g, mismo estudio | El efecto no puede ser el argumento de venta. Es el marco, no el cuadro |
| El parallax de iOS 7 produjo **vértigo, náusea y mareo** en cantidad suficiente para que Apple agregara *Reduce Motion* | NN/g · WCAG 2.3.3 | `prefers-reduced-motion` no es una casilla de accesibilidad: hay ~35 % de adultos mayores de 40 con algún trastorno vestibular |

Y el hallazgo hermano, sobre **scrolljacking** (cambiar el ritmo o la dirección
del scroll): NN/g lo mide como amenaza directa a control del usuario,
descubribilidad, atención, eficiencia y éxito de tarea. La gente tiene un
modelo mental fuerte — *scrolleo vertical, a la velocidad de mi dedo*.

> **La regla que sale de acá:** el scroll es del usuario. Nosotros movemos lo
> que hay adentro del scroll, nunca el scroll.

### 1.1 Dónde va el parallax en bouquet

| Pantalla | Movimiento | Por qué |
|---|---|---|
| Home / landing | **Sí**, el sistema completo | Es navegación de ocio, sin tarea |
| `/vinos` (catálogo) | Nada. A lo sumo entrada de tarjetas, una vez | Hay tarea: comparar y filtrar |
| `/vinos/[slug]` (ficha) | Nada | Hay decisión de compra. El precio y el stock no se mueven |
| `/carrito`, `/checkout` | **Prohibido** | Hay plata. Cero adorno entre el usuario y el botón |
| `/orden/[numero]` | Nada | Es un comprobante |

**La ceremonia va donde no hay tarea.** Es la regla más importante del informe
y la única que no depende de la dirección visual.

---

## 2. El modelo: una cámara, no un efecto

### 2.1 La ecuación

Se piensa la escena como planos a distancia `z` de una cámara que se desplaza
con el scroll. La velocidad aparente de cada plano es:

```
v(z) = 1 − z / D        z = profundidad del plano      D = distancia al fondo
```

- `v = 1.0` → el plano viaja con el scroll. Es el **plano de contenido**.
- `v = 0.4` → el plano de fondo recorre el 40 % de lo que recorre el texto.
- `v > 1.0` → planos **delante** de la cámara: pasan más rápido y salen antes.

Nadie elige `0.62`. Se elige "este objeto está lejos" y el número sale de la
ecuación. Eso es lo que hace que cinco capas se lean como **un** lugar.

### 2.2 Por qué hay un techo de capas, y es bajo

Dos límites independientes, y el más chico gana.

**Límite perceptual.** Entre dos planos con velocidades `0.95` y `1.00`, en una
pantalla de teléfono de ~850 px de alto, scrollear una pantalla entera produce
**~42 px** de desplazamiento relativo. Eso no se lee como profundidad: se lee
como que algo se corrió. Para que el cerebro lo interprete como distancia hace
falta separación de **≥ 0,15** entre planos vecinos.

> ⚠️ **Heurística, no constante medida.** El 0,15 sale de la aritmética de
> arriba, no de un estudio psicofísico. Se valida en dispositivo en el primer
> prototipo, con el método de §9.

**Límite de memoria.** Una capa compositada a pantalla completa en un teléfono
de DPR 3 (1179 × 2556 px) ocupa **~12 MB** de memoria de GPU, sin contar la
imagen decodificada que la pinta. Cinco capas son ~60 MB sólo en superficies.

Con el rango útil acotado entre `0.4` y `1.15`, y separación mínima de 0,15:

```
0.40    0.55    0.70    0.85    1.00    1.15
 └───────┴───────┴───────┴───────┴───────┘
        seis posiciones posibles — usamos cinco
```

**El techo son 5 planos, y sólo en el héroe.** No es una preferencia estética:
es lo que entra en el rango antes de que dos capas digan lo mismo.

---

## 3. Las capas: cuántas y qué va en cada una

### 3.1 El stack

| # | Plano | `v` | Qué va | Qué NUNCA va |
|---|---|---|---|---|
| z0 | **Ambiente** | 0.40 | Textura, gradiente, atmósfera. Bajo contraste | Texto. Nada informativo |
| z1 | **Escenario** | 0.55 | El lugar: bodega, viñedo, mesa. Contexto | Nada que haya que leer |
| z2 | **Sujeto** | 0.85 | La botella. El foco de la escena | Precio, CTA |
| z3 | **Contenido** | **1.00** | Título, bajada, precio, botón — **y su scrim** | Movimiento propio |
| z4 | **Detalle** | 1.15 | Oclusores chicos: borde de copa, hoja, grano | Área grande. Tapar texto |
| — | **UI** | fija | Nav, carrito, puerta de edad | Parallax de cualquier tipo |

Y la regla de higiene inversa, que es la que evita el stack inflado:

> **Tantos planos como significados tenga la escena. Si dos capas dicen lo
> mismo, son una capa.** Un plano que no cambia lo que la escena comunica es
> 12 MB y un asset más para producir, mantener y descargar.

**Sólo el héroe usa los cinco.** Las escenas siguientes usan 2 o 3 — la
profundidad ya se estableció; repetirla completa la vuelve decorado.

### 3.2 La regla que casi nadie aplica: el texto y su fondo comparten plano

Un texto sobre una capa fotográfica que se mueve **cambia de contraste mientras
scrolleás**. Arranca sobre una zona oscura y termina sobre una clara: el mismo
texto es legible al entrar e ilegible al salir. Es un defecto de accesibilidad
que ninguna herramienta estática detecta, porque en el momento de la captura el
contraste está bien.

> **Todo lo que tenga que ser legible viaja junto a su fondo.** El scrim,
> gradiente o placa que garantiza el contraste pertenece a z3 y se mueve a
> `v = 1.00`, igual que el texto que protege. La foto se mueve **debajo** del
> par, no debajo del texto solo.

### 3.3 La oclusión vale más que el movimiento

De las señales de profundidad que usa el sistema visual, la **oclusión** —que
algo tape a otra cosa— es más fuerte e inmediata que el paralaje de
movimiento. Consecuencias prácticas:

- **z4 es la capa que más profundidad compra por peso.** Un borde de copa
  desenfocado que ocupa el 8 % de la pantalla y tapa parcialmente la botella
  hace más por la sensación de espacio que un fondo de 2 MB moviéndose lento.
- La composición tiene que estar armada para que **siempre haya algo tapando
  algo**. Cinco planos que nunca se superponen son cinco stickers deslizándose.
- Y funciona **quieta**: es la única señal de profundidad que sobrevive intacta
  en Tier C (§7).

### 3.4 Perspectiva atmosférica: la coherencia que evita el collage

Un plano lejano que se mueve lento pero tiene el mismo contraste y saturación
que el sujeto **contradice su propia velocidad**. El cerebro recibe "esto está
lejos" del movimiento y "esto está cerca" del color, y resuelve el conflicto
del lado peor: lee capas pegoteadas, no espacio.

| Plano | Contraste | Saturación | Nitidez |
|---|---|---|---|
| z0 ambiente | mínimo | mínima | difusa |
| z1 escenario | bajo | baja | suave |
| z2 sujeto | **máximo** | **máxima** | **nítida** |
| z4 detalle | medio | media | **desenfocada** (está *demasiado* cerca) |

Los valores exactos los fija `/disenio`. La **monotonía** de la tabla es
estructural y no se negocia: el contraste crece hacia el sujeto y cae hacia los
dos extremos.

### 3.5 Transparencias y formas: dónde está el costo

- **El desenfoque va horneado en el asset, nunca en un `filter` animado.**
  Animar `blur()` sobre una superficie grande repinta cada frame y es la forma
  más rápida de que un teléfono de gama media caiga a 20 fps.
- **Como máximo dos capas translúcidas a pantalla completa.** Las GPU móviles
  están limitadas por *fill rate*: cada píxel pintado dos, tres y cuatro veces
  se paga entero. Un gradiente horneado en el asset del plano cuesta cero.
- **Preferir `mask-image` a apilar alfa.** Una máscara estática con una capa
  moviéndose detrás —"la ventana"— da el efecto más caro a la vista y el más
  barato de renderizar: la máscara no cambia, sólo se desplaza el contenido.
- **`clip-path` estático sí, animado no** sobre áreas grandes: reevalúa el
  recorte y repinta.

---

## 4. Coordinación: cómo dicen lo mismo moviéndose distinto

Esta es la pregunta del encargo, y tiene una respuesta técnica exacta.

### 4.1 Un rango, muchas amplitudes

Lo que desincroniza el mensaje **no es la velocidad distinta**: es que cada capa
arranque y termine su animación en un punto de scroll distinto. Ahí sí el fondo
dice una cosa mientras el sujeto dice otra.

> **Todos los planos de una escena comparten el mismo rango de scroll y la
> misma curva. Difieren sólo en la amplitud.**

En CSS eso se escribe con un **timeline con nombre**, declarado una vez en el
contenedor de la escena, del que cuelgan todas las capas:

```css
.escena {
  view-timeline-name: --escena;
  view-timeline-axis: block;
}

@keyframes deriva {
  to { translate: 0 var(--amplitud); }
}

.plano {
  animation: deriva linear both;
  animation-timeline: --escena;          /* el MISMO reloj para todas */
  animation-range: cover 0% cover 100%;  /* el MISMO rango para todas */
  will-change: translate;
}

.plano--ambiente  { --amplitud: -18vh; }  /* v = 0.40 */
.plano--escenario { --amplitud: -12vh; }  /* v = 0.55 */
.plano--sujeto    { --amplitud:  -4vh; }  /* v = 0.85 */
.plano--contenido { --amplitud:   0;   }  /* v = 1.00 */
.plano--detalle   { --amplitud:   4vh; }  /* v = 1.15 */
```

Cinco capas, **una** regla de movimiento y un número por capa. No hay ningún
lugar donde una capa pueda desincronizarse de las otras, porque no existe el
parámetro con el que hacerlo. Si el timeline no está en un ancestro directo, se
publica con `timeline-scope: --escena` en el ancestro común.

### 4.2 Dos clases de movimiento, y mezclarlas es lo que se siente nervioso

| | **Continuo** (parallax) | **Discreto** (revelado) |
|---|---|---|
| Atado a | posición de scroll | un cruce de umbral |
| Al scrollear para arriba | **se deshace exacto** | **no vuelve** |
| Se implementa con | `animation-timeline` | `IntersectionObserver`, una vez |
| Ejemplo | la botella derivando | el título apareciendo |

El texto que aparece y desaparece cada vez que pasás por la sección es tedioso
—NN/g lo señala explícitamente— y el fondo que **no** vuelve al scrollear hacia
arriba está roto. Son reglas opuestas: hay que saber cuál se está escribiendo.
Un elemento pertenece a una clase o a la otra, nunca a las dos.

### 4.3 La curva: lineal para el scroll, easing para el tiempo

En una animación atada al scroll **la velocidad la pone el dedo del usuario**.
Meterle `ease-in-out` significa que el contenido se mueve más lento que el dedo
en los extremos del rango: se siente pegajoso, como si la página tuviera
fricción. Es el mismo defecto que el scrolljacking, en chiquito.

- **Movimiento continuo atado al scroll → `linear`. Siempre.**
- **Transiciones en el tiempo** (hover, tap, revelado, entrada de una tarjeta)
  → easing, y ahí sí con criterio.

Y una nota de dominio: **el vino pesa. Nada rebota.** Sin overshoot, sin
spring, sin bounce en ninguna de las dos clases. La sensación buscada es masa y
asentamiento — y eso es independiente de la paleta que elija `/disenio`.

### 4.4 La estructura de una escena

Cada escena es **un** mensaje y **un** foco. Su rango de scroll se reparte:

```
0 %        20 %                          80 %        100 %
├───────────┼──────────────────────────────┼───────────┤
   entrada            sostenimiento            salida
```

- La **zona muerta** del 20-80 % es lo que hace que el que scrollea rápido vea
  el estado asentado y no un frame intermedio. Es la respuesta directa al
  hallazgo de las pantallas en blanco de NN/g.
- **Nunca animar a lo largo del 100 % del rango.** Si la animación termina
  justo cuando la escena sale, nadie la vio terminada.

### 4.5 Presupuesto de largo

| Concepto | Tope |
|---|---|
| Escenas en la landing | **5**, incluida la de cierre con CTA |
| Scroll por escena | ≤ 1,5 alturas de viewport |
| Largo total de la home en móvil | ≤ **8 pantallas** |
| Pinning (escena fija mientras se scrollea) | ≤ 1,5 viewport, y **una sola** en toda la página |

Una barra de scroll que promete tres pantallas y entrega doce es el problema de
la *ilusión de completitud*: la gente cree que terminó y se va, o siente que la
engañaron. El largo tiene que ser honesto.

---

## 5. Fluidez: por qué esto se siente barato en un teléfono

### 5.1 La causa raíz, que es una sola

En un teléfono el scroll **no lo maneja el hilo principal**: lo maneja el hilo
compositor. Un parallax hecho en JavaScript hace esto:

```
dedo → compositor mueve la página ──────────────▶ pinta el frame N
                     │
                     └─ evento scroll → hilo principal lee scrollY,
                        escribe transform ─────────▶ aparece en el frame N+1
```

**El fondo llega un frame tarde, siempre.** A 60 Hz son 16 ms; con el hilo
principal ocupado (hidratación de React, una imagen decodificando, un
`IntersectionObserver` gordo) son tres o cuatro frames. Eso es exactamente la
sensación de "cada capa va por su lado" que hace que un parallax parezca de
plantilla. **No es un problema de diseño: es de arquitectura de hilos, y no se
arregla afinando números.**

La solución es que la animación **viva donde vive el scroll**: en el
compositor. Eso hoy se consigue con animaciones CSS atadas a un scroll
timeline.

### 5.2 El soporte real, medido — no el del blog

Verificado contra `mdn/browser-compat-data`, no contra artículos:

| Motor | `animation-timeline` · `scroll()` · `view()` |
|---|---|
| Chrome / Edge (y Chrome Android) | **115** — jul-2023 |
| Safari / iOS Safari | **26** — sep-2025 |
| Firefox | **detrás del flag** `layout.css.scroll-driven-animations.enabled` a la fecha (FF 152, jun-2026). Prioridad declarada de Interop 2026 |

MDN marca la feature como **"Limited availability"** — *no* Baseline —
justamente por Firefox. Los artículos que dicen "soporte universal en 2026"
están equivocados, y el dato está a un clic de la tabla de compatibilidad.

Dos matices que importan más que la tabla:

- **Safari 26.0 las shipeó corriendo en el hilo principal.** Recién **Safari
  26.4** las movió al compositor. En iOS 26.0-26.3 el efecto existe y puede
  tener el mismo desfase que la versión en JS.
- **iOS anterior a 26 no las tiene.** Es un porcentaje real de iPhones, no un
  caso de borde.

### 5.3 La estrategia que sale de eso

**Tier C primero; el movimiento, enriquecimiento puro.**

```
@supports (animation-timeline: view())  → movimiento
sin soporte                             → la composición estática, completa
```

No se construye un fallback aparte: **el fallback es la composición estática,
que hay que construir igual** para `prefers-reduced-motion`, para el primer
render, para el buscador y para los teléfonos de gama baja. Cuatro problemas
distintos con un solo artefacto.

> **No usar una librería de smooth scroll (Lenis y familia).** Interpolan el
> scroll para que el parallax se vea más suave, pero: hijackean el scroll
> (NN/g), agregan trabajo al hilo principal —el hilo que justamente queremos
> vacío—, rompen `find-in-page` y la navegación por teclado, y anulan la
> ventaja de tener las animaciones en el compositor. En 2018 era la respuesta.
> En 2026 es el problema.

La versión en JS del parallax se escribe **sólo si la medición de tráfico real
lo justifica**, y entonces afecta al héroe y a nada más. Mantener dos sistemas
de movimiento duplica la superficie de bugs, y el que se duplica es el malo.

### 5.4 Prohibiciones, con su motivo

| Prohibido | Por qué |
|---|---|
| `background-attachment: fixed` | No funciona en iOS Safari ni en varios Firefox móviles, y donde funciona se rompe cuando la barra de direcciones colapsa. Está desactivado **a propósito** por performance. Se reemplaza con un elemento `position: fixed` detrás del contenido |
| Animar `top`, `height`, `margin`, `width` | Disparan layout. Sólo se anima `translate`, `scale`, `rotate` y `opacity` |
| Animar `filter: blur()` sobre área grande | Repinta cada frame |
| Escuchar `scroll` y escribir estilos sin `rAF` | Un write por evento; en iOS los eventos llegan en ráfagas |
| `will-change` puesto "por las dudas" | Cada promoción son ~12 MB. Va sobre las capas que **efectivamente** se animan, y nada más |
| `scroll-snap` en la landing | Pelea contra el timeline continuo y en iOS produce artefactos de rebote |
| `100vh` en una escena fija | La barra de direcciones de iOS cambia el viewport a mitad de scroll: salto visible. Usar `svh` y dejar sangrar el fondo |

### 5.5 120 Hz

Los iPhone Pro y buena parte de la gama alta Android van a 120 Hz: el
presupuesto por frame baja de 16,7 ms a **8,3 ms**. Una animación en el
compositor sigue a 120 Hz sin tocar el hilo principal. Una en JS con `rAF` casi
nunca llega — y el resultado es peor que a 60 Hz, porque la irregularidad se
nota más. **En las pantallas más caras es donde el parallax en JS se ve más
barato**, que es exactamente al revés de lo que se busca.

---

## 6. Imágenes: el costo real es el decode, no el archivo

### 6.1 El número que sorprende

Una imagen ocupa en memoria `ancho × alto × 4 bytes`, **sin importar cuánto
pesa el archivo**. Un AVIF de 2400 × 1600 que pesa 250 KB ocupa:

```
2400 × 1600 × 4 = 15,4 MB de RAM
```

Cinco capas así son **~77 MB de imágenes decodificadas**, más ~60 MB de
superficies compositadas. En un teléfono de gama media eso es el punto donde
Safari o Chrome descartan la pestaña y el usuario ve la página recargarse sola.

> **El presupuesto de imágenes de un parallax no se mide en KB, se mide en
> megapíxeles.** Servir una capa el doble de grande de lo que se ve no "carga
> un poco más lento": cuadruplica la memoria.

**La regla:** cada capa se sirve al tamaño en que se muestra, con `srcset` y
`sizes` reales por breakpoint. Y las capas de ambiente —que están difusas por
diseño (§3.4)— **se sirven a la mitad de resolución y se escalan**: nadie puede
distinguirlo y la memoria cae a la cuarta parte.

### 6.2 Formatos

| Uso | Formato |
|---|---|
| Capas fotográficas sin transparencia | **AVIF**, WebP de respaldo |
| Recortes con alfa (botella, hojas, copa) | **AVIF con alfa**. PNG sólo si el recorte tiene bordes duros y el AVIF los ensucia |
| Texturas, granos, viñetas | CSS: gradientes y `mask-image`. **Cero bytes** |

### 6.3 Fluidez de carga: que no aparezca a los pedazos

- **La capa del LCP no se funde desde `opacity: 0`.** Un elemento totalmente
  transparente no cuenta como pintado: una entrada de 600 ms le suma 600 ms al
  LCP. La primera pantalla se pinta ya compuesta; el movimiento arranca cuando
  el usuario scrollea, no al cargar.
- **Escenas 1 y 2 con carga ansiosa; de la 3 en adelante, `lazy` y
  `fetchpriority="low"`.** Una capa a pantalla completa que aparece a mitad del
  scroll es la peor forma de pop-in que existe.
- **Placeholder plano, no blur-up.** El desenfoque de un placeholder a pantalla
  completa cuesta un repintado grande justo en el momento más cargado. Un color
  o un gradiente de dos paradas hace el mismo trabajo por cero.
- **Reserva de espacio siempre** (`aspect-ratio` o contenedor dimensionado).
  Una capa que empuja el layout al llegar es CLS, y en un héroe es CLS visible.
- **La tipografía es parte de la fluidez.** Un swap de fuente en el titular del
  héroe es lo más barato que puede parecer un sitio caro. Fuente propia,
  precargada, `font-display: optional` o `swap` con fallback de métricas
  ajustadas (`size-adjust`, `ascent-override`).
- **`content-visibility: auto` + `contain-intrinsic-size`** en las escenas de
  abajo baja mucho el costo de render en gama baja. ⚠️ **Verificar que no
  desajuste los `view-timeline`** de las escenas salteadas: es un riesgo real y
  se mide, no se supone.

### 6.4 Dónde viven los assets, y qué cuesta en Firebase

**Los planos decorativos son assets de diseño, no datos de catálogo.** Viven en
el repo, versionados junto a los tokens y la dirección visual, se hornean en
build y se sirven estáticos con hash en el nombre y `Cache-Control: immutable`.
**No** pasan por Firebase Storage (que es para fotos de producto, ARQUITECTURA
§5.4) ni por el optimizador de imágenes en runtime.

El motivo, con el stack de [ADR 005](../architecture/decisions/005-hosting-vidriera.md)
—App Hosting detrás de Cloudflare— son dos:

**1. En App Hosting, `next/image` optimiza en Cloud Run.** No hay una línea de
factura llamada "transformación": hay **CPU y memoria de Cloud Run**, con caché
en disco efímero que se pierde en cada revisión nueva y no se comparte entre
instancias. Una capa a pantalla completa optimizada en runtime es CPU pagada
muchas veces por una imagen que **nunca cambia**. Hornearla en build la mueve a
Cloud Build, que tiene 2.500 minutos/mes sin cargo.

**2. El ancho de banda del origen se factura y el del borde no.** Los tramos sin
cargo de App Hosting son **10 GiB/mes cacheados y 10 GiB sin cachear**, después
US$ 0,15-0,20/GiB. Con una landing de ~1,2 MB por visita nueva:

| | Visitas/mes dentro del tramo sin cargo |
|---|---:|
| App Hosting solo | ~8.700 |
| Con Cloudflare adelante (~90 % de aciertos) | **~87.000** |

Diez veces más margen, y es el mismo proveedor que aporta la purga de la que
depende la frescura del precio. ⚠️ La política de uso de Cloudflare restringe
servir **video y archivos grandes no-HTML**: imágenes de producto y capas de
parallax entran; una videoteca no.

> **La regla operativa, corta:** todo lo que no cambia se hornea, se le pone
> hash y se cachea para siempre. El optimizador en runtime queda para las fotos
> de producto, que sí cambian y son pocas por página.

### 6.5 Adaptación a la forma de la pantalla

- Un arte compuesto para 9:19,5 (teléfono vertical) recortado a 4:3 (tablet) o
  a 21:9 (desktop ancho) pierde la composición. **Cada plano se produce con
  sangrado generoso y un punto focal declarado** (`object-position`), no
  centrado a ciegas.
- **Dos direcciones de arte, no una responsive:** vertical y horizontal.
  Elegidas con `<picture>` + `media`, que además evita descargar la que no se
  usa.
- **Landscape en teléfono es el caso que rompe todo:** 400 px de alto útil, el
  texto ocupa todo y no queda lugar para profundidad. Ahí se degrada a Tier B
  aunque el dispositivo dé de sobra.

---

## 7. La escalera de degradación

### 7.1 Las señales, y cuáles mienten

| Señal | Sirve para | Cuidado |
|---|---|---|
| `prefers-reduced-motion` | **Corte duro**. No es una preferencia estética | Es lo primero que se implementa, no lo último |
| `prefers-reduced-data` / `Save-Data` | Bajar a Tier B | Soporte parcial |
| `navigator.deviceMemory` | Descartar equipos de ≤ 2 GB | Sólo Chromium, y redondea a 0,25/0,5/1/2/4/8 |
| `navigator.hardwareConcurrency` | Poco: núcleos ≠ potencia | Un teléfono de 8 núcleos lentos miente feo |
| `(update: slow)` | e-ink y pantallas lentas | Raro, pero gratis |
| **Medir frames reales** | **Lo único que no miente** | Ver §9 |

### 7.2 Los tres tiers

| Tier | Cuándo | Qué corre |
|---|---|---|
| **A** | Soporte de scroll timelines + sin `reduced-motion` + memoria OK | 5 planos en el héroe, 2-3 en el resto |
| **B** | Gama baja detectada, `Save-Data`, o landscape en teléfono | 3 planos, sin translúcidos superpuestos, capas de ambiente a media resolución |
| **C** | `prefers-reduced-motion`, sin soporte, o degradación medida | **Composición estática completa. Cero movimiento** |

### 7.3 La prueba que decide si el diseño es premium o es un truco

> **Si la composición estática no es hermosa y no comunica el mensaje completo,
> el movimiento estaba cargando el mensaje — y para el usuario con
> `reduced-motion` la página está rota.**

Por eso Tier C se construye **primero**. El movimiento se agrega después, y si
al apagarlo no se pierde información, está bien puesto.

Aclaración que suele hacer falta: `prefers-reduced-motion` **no es "sin
animación"**. Un fade de 150 ms, un cambio de color, un subrayado: todo eso
sigue permitido. Lo que se elimina es el **desplazamiento grande**, que es
justamente el paralaje.

---

## 8. Los presupuestos, para que después sea falsable

Números para que la implementación se pueda medir contra algo en vez de
discutirse.

| Concepto | Tope | Se mide con |
|---|---|---|
| Planos en el héroe | 5 | contar |
| Planos en escenas siguientes | 3 | contar |
| Separación de velocidad entre planos vecinos | ≥ 0,15 | los tokens |
| Capas translúcidas a pantalla completa | ≤ 2 | inspección |
| Elementos con `will-change` simultáneos | ≤ 6 | DevTools → Layers |
| Megapíxeles totales de la primera pantalla | ≤ 12 MP | suma de `naturalWidth × naturalHeight` |
| Bytes de la primera pantalla en móvil (todo) | ≤ 450 KB | Network, throttling 4G |
| LCP (p75, móvil) | ≤ 2,5 s | Lighthouse / CrUX |
| INP (p75) | ≤ 200 ms | idem |
| CLS | ≤ 0,1 | idem |
| Frames perdidos en un scroll completo, gama media | ≤ 5 % | §9 |
| Largo de la home en móvil | ≤ 8 pantallas | scroll height / viewport |

---

## 9. Cómo se verifica — con control positivo y negativo

Lo de siempre en este repo: **que se vea bien en esta máquina no prueba nada.**
Y menos acá: 7,9 GB y 4 núcleos con el editor abierto es una gama media
razonable, pero un desktop de 60 Hz no dice nada de un iPhone de 120 Hz.

### 9.1 La prueba discriminante: bloquear el hilo principal

La única forma barata de saber si el parallax **realmente** está en el
compositor:

```js
// pegar en la consola y scrollear durante los 3 segundos
const fin = performance.now() + 3000;
while (performance.now() < fin) {}
```

| Resultado | Qué significa |
|---|---|
| Las capas **siguen moviéndose parejas** | Está en el compositor. ✅ |
| Las capas **se congelan** y saltan al soltar | Está en el hilo principal, aunque el CSS diga `animation-timeline` |

- **Control positivo:** un elemento con `position: fixed` sigue quieto y
  correcto — si eso también se rompe, el que está mal es el experimento.
- **Control negativo:** la misma prueba sobre una versión con parallax en JS
  **tiene que congelarse**. Si no se congela, no estás midiendo lo que creés.

Vale la pena correrla en **Safari 26.0-26.3** aparte: ahí la respuesta esperada
es "se congela" (§5.2), y esa es la evidencia para decidir si hace falta bajar
esas versiones a Tier B.

### 9.2 Lo que no prueba nada

| No prueba nada | Lo que sí prueba |
|---|---|
| Un Lighthouse verde en desktop | El p75 de campo, o un run con CPU 4× throttled |
| "Se ve fluido" scrolleando con el mouse | Scroll con el dedo en un teléfono real: la rueda da saltos discretos y **esconde** el desfase |
| Un GIF de la animación | Un scroll rápido de arriba a abajo y de vuelta |
| Que el CSS tenga `animation-timeline` | La prueba de §9.1 |
| Que la página cargue rápido con caché | Recarga dura con throttling 4G |

### 9.3 Qué revisar sí o sí antes de dar por hecha una escena

1. Scrollear **rápido** de punta a punta: ¿algún estado intermedio quedó
   visible como si fuera el final? (§4.4)
2. Scrollear **hacia arriba**: ¿todo lo continuo se deshizo exacto y nada de lo
   discreto volvió a animarse? (§4.2)
3. Activar *Reducir movimiento* en el sistema: ¿se sigue entendiendo y sigue
   siendo linda? (§7.3)
4. Pasar el texto del héroe por un chequeo de contraste **en tres puntos del
   rango de scroll**, no en uno. (§3.2)
5. Girar el teléfono a horizontal. (§6.5)
6. Con el telón puesto: ¿la escena de atrás no consumió su animación? (§10.2)

---

## 10. La landing de bouquet: las decisiones, tomadas

Respondidas por el dueño el **2026-09-03**. Lo que sigue ya no es una propuesta.

| # | Decisión | Lo decidido | Qué fija |
|---|---|---|---|
| 1 | Escenas | **De marca**, con lugar para un vino ofertado | Assets estáticos en el repo. Una sola escena toca el catálogo |
| 2 | Fotos | **No hay todavía.** Se hace una recopilación de internet | §10.3. Los planos se especifican por **rol**, no por foto |
| 3 | Tono | **Persuade, coquetea.** Experiencia, información, cultura, expresión que sostenga algunos CTA | 5 escenas, CTA duro sólo dos veces |
| 4 | Puerta de edad | **El telón que se levanta** | §10.2 |
| 5 | Arte | **Dos direcciones**, vertical y horizontal | §6.5 pasa de recomendación a requisito. 32 assets |
| 6 | Hosting | **Firebase, con Cloudflare adelante** — no Vercel | §6.4 reescrita. [ADR 005](../architecture/decisions/005-hosting-vidriera.md) |

### 10.1 Las cinco escenas

*Coquetear es insinuar, no gritar.* La consecuencia de diseño es concreta: el
CTA duro aparece **dos veces en toda la página**, y nunca hay modal, popup ni
cartel de descuento. Lo que sostiene el interés hasta el CTA es que las escenas
2 y 3 **enseñan algo verdadero**.

| # | Escena | Qué dice | Planos | CTA |
|---|---|---|---|---|
| 1 | **El telón / la promesa** | Quiénes somos, en una frase. Cero producto | **5** | blando: la invitación a bajar |
| 2 | **Origen** | De dónde viene: región, altura, suelo. Información verificable | 3 | ninguno |
| 3 | **Expresión** | Cómo se lee lo que hay en la copa: varietal, crianza, guarda. **La escena que enseña** — la que hace que vuelvan | 3 | blando, dentro de la prosa |
| 4 | **La selección** | Lo único que toca el catálogo. Acá entra el vino que se quiera ofertar | 3 | **duro**: ver el vino |
| 5 | **Cierre** | Cómo llega, desde dónde, la promesa de servicio | 2 | **duro**: ver todos los vinos |

Total: **16 planos**, dentro del presupuesto de §4.5 (5 escenas, ≤ 8 pantallas).

> **La palanca que conviene conocer antes de maquetar:** si la escena 4 **no
> muestra precio** —"la selección de esta semana" con un enlace— la landing es
> 100 % estática y no necesita nada de la maquinaria de frescura de
> [ADR 005](../architecture/decisions/005-hosting-vidriera.md). Si muestra
> precio, la home entra en el circuito de purga por tag `catalogo`. Las dos
> opciones son válidas; la diferencia es una etiqueta `Cache-Tag`, y conviene
> decidirla a propósito y no descubrirla.

### 10.2 El telón

La puerta de edad **es** la primera pieza de la experiencia, no un trámite
delante de ella. Se levanta.

Cinco requisitos, y ninguno es estético:

1. **El contenido va en el HTML, siempre.** El telón es un overlay encima
   (ARQUITECTURA §9.5). Si bloquea el render, Google no ve nada y la vidriera
   vuelve a ser invisible — el problema que ADR 001 vino a resolver.
2. **Sin parpadeo para el que vuelve.** La marca de "ya acepté" se lee en un
   script inline **antes del primer paint**; si se lee después, el que ya entró
   ve el telón un frame. Es el mismo patrón que evitar el flash de tema.
3. **Bloquear el scroll sin `overflow: hidden` en el `body`.** En iOS eso
   pierde la posición de scroll. Va `inert` en el contenido + overlay fijo +
   `overscroll-behavior: contain`.
4. **El levantamiento es la única animación grande por tiempo de la página**
   (§4.3): 700-900 ms, ease-out, **sin rebote** — el telón pesa. Con
   `prefers-reduced-motion`, un fundido de 150 ms.
5. **Se guarda un booleano y una fecha en `localStorage`**, misma decisión que
   el carrito. No se pide ni se guarda fecha de nacimiento. Y el copy dice que
   **se exige documento en la entrega**, que es el requisito real (§9.5).

**Y la ventaja estructural, que es la que hace que la idea sea buena y no sólo
linda:** con el telón puesto la página está en `scrollTop 0`, y como todo el
movimiento está **atado al scroll** (§4.2), *ninguna animación se consumió*. El
héroe se estrena entero en el primer gesto del usuario. Con animaciones por
tiempo, el que tarda tres segundos en aceptar se pierde la entrada.

### 10.3 El manifiesto de assets, para que la recopilación sea dirigida

**Se especifica el hueco, no la foto.** Como las imágenes son de reemplazo, lo
que no puede cambiar es el **rol** de cada plano: si cada slot tiene rol, forma
y medida, cambiar la foto después cuesta reemplazar un archivo. Si no, cuesta
rediseñar la escena.

**16 planos × 2 direcciones de arte = 32 assets.**

| Rol | Medida (vertical / horizontal) | Formato | Qué buscar |
|---|---|---|---|
| **Ambiente** | 1600×2400 / 2400×1350 — **se sirve a media resolución** (§6.1) | AVIF, sin alfa | Textura, bokeh, niebla, pared, luz de vela. Bajo contraste, sin sujeto reconocible |
| **Escenario** | 1600×2400 / 2560×1440 | AVIF, sin alfa | Viñedo, hilera, bodega, barricas, mesa servida. Profundidad real en la foto |
| **Sujeto** | ≤ 1200×1600, lado mayor | **AVIF con alfa** | Botella o copa **recortada**. Es el asset más difícil de conseguir y el que más rinde |
| **Detalle** | ≤ 800 px lado mayor | **AVIF con alfa** | Hoja de vid, borde de copa, corcho, racimo. Chico y desenfocado |
| **Contenido** | — | — | No es imagen: es texto y su scrim (§3.2) |

**Dónde buscar, con licencia clara y sin costo:** Unsplash, Pexels y Pixabay
—permiten uso comercial y no exigen atribución—, Wikimedia Commons y Openverse
—licencia **por archivo**, hay que mirarla una por una— y el dominio público de
Rawpixel. Cubren ambiente y escenario de sobra.

**Los recortes con alfa casi nunca se encuentran hechos.** Se sacan de una foto
con fondo plano y se recortan (`rembg` local, o cualquier quita-fondos). Vale la
pena que las botellas de la escena 4 sean **fotos propias** cuando existan: es
el único plano donde la foto es el producto.

> ⚠️ **Pendiente, con disparador.** Para prototipar sirve cualquier imagen. Para
> un sitio comercial publicado, una foto sin licencia es exposición legal real,
> y además **cada foto de reemplazo condiciona la composición**: cuanto más
> tarde se cambie, más caro sale. **Disparador: antes de publicar el dominio.**
> Desde 2026-09-03.

---

## 11. Presupuesto de lecturas de Firestore

Campo obligatorio, según `post-task-doc`.

| Escenario | Lecturas/día que agrega | Contra los 50.000 |
|---|---|---|
| Escenas de marca, estáticas en el repo — **lo decidido** | **0** | 0 % |
| Escena 4 mostrando el vino ofertado, servida desde la proyección publicada | **0 adicionales** — ya se leen para el catálogo (ADR 004) | 0 % |
| Cualquier escena leyendo Firestore desde el navegador | ~1 por visitante | **Rompe el ADR 004.** Prohibido |

El parallax es presentación: **no agrega ni una lectura** mientras el contenido
salga del mismo artefacto de proyección publicada que ya usan el listado, los
filtros y la búsqueda (ARQUITECTURA §6.4). Lo que sí agrega es **peso de
transferencia y memoria de cliente**, presupuestados en §8.

Con [ADR 005](../architecture/decisions/005-hosting-vidriera.md) la home entra
al circuito de purga **sólo si la escena 4 muestra precio** (§10.1). Si no lo
muestra, la landing no se invalida nunca: es HTML que sólo cambia cuando cambia
el diseño.

---

## 12. Cuándo este informe deja de servir

Escrito hoy para no discutirlo después. Se revisa cuando pase lo primero de:

- **Firefox habilita las scroll-driven animations por defecto** (Interop 2026):
  desaparece la mitad del argumento de §5.3 y `@supports` deja de ser el punto
  de corte principal.
- **La adopción de iOS 26.4+ supera el 90 %** en el tráfico real del sitio:
  desaparece la excepción de Safari con timelines en el hilo principal.
- **El p75 de LCP de campo supera 2,5 s** durante dos semanas: el parallax pasa
  a ser sospechoso número uno y se baja el héroe a Tier B por defecto hasta
  probar lo contrario.
- **Las fotos de reemplazo se cambian por definitivas:** hay que revisar que
  cada plano siga cumpliendo su rol de §10.3, sobre todo el contraste de la
  tabla de §3.4.
- **Cambia el hosting otra vez:** §6.4 depende de que el borde sea Cloudflare y
  el origen Firebase ([ADR 005](../architecture/decisions/005-hosting-vidriera.md)).

---

## Fuentes

- [What Parallax Lacks — Nielsen Norman Group](https://www.nngroup.com/articles/parallax-usability/)
- [Scrolljacking 101 — Nielsen Norman Group](https://www.nngroup.com/articles/scrolljacking-101/)
- [Understanding SC 2.3.3: Animation from Interactions — W3C WAI](https://www.w3.org/WAI/WCAG21/Understanding/animation-from-interactions.html)
- [CSS scroll-driven animations — MDN](https://developer.mozilla.org/en-US/docs/Web/CSS/Guides/Scroll-driven_animations)
- [`animation-timeline` — MDN](https://developer.mozilla.org/en-US/docs/Web/CSS/animation-timeline) · datos de versión desde [`mdn/browser-compat-data`](https://raw.githubusercontent.com/mdn/browser-compat-data/main/css/properties/animation-timeline.json)
- [A guide to Scroll-driven Animations with just CSS — WebKit](https://webkit.org/blog/17101/a-guide-to-scroll-driven-animations-with-just-css/)
- [WebKit Features in Safari 26.0](https://webkit.org/blog/17333/webkit-features-in-safari-26-0/) · [26.4, animaciones en el compositor](https://webkit.org/blog/17862/webkit-features-for-safari-26-4/) · [26.5, correcciones](https://webkit.org/blog/17938/webkit-features-for-safari-26-5/)
- [Bug 1817303 — Enable scroll-driven animations, Bugzilla](https://bugzilla.mozilla.org/show_bug.cgi?id=1817303)
- [Firebase App Hosting — costos](https://firebase.google.com/docs/app-hosting/costs) · [caché y CDN](https://firebase.google.com/docs/app-hosting/optimize-cache)
- [Cloudflare — purge cache, métodos y límites por plan](https://developers.cloudflare.com/cache/how-to/purge-cache/)
- [The Fixed Background Attachment Hack — CSS-Tricks](https://css-tricks.com/the-fixed-background-attachment-hack/)
