# ADR 007 — La sección se llama `El oficio`, cubre tres tramos, y el contacto es su cierre

- **Fecha:** 2026-09-09
- **Estado:** aceptada y **aplicada** — `/oficio` existe, `/custodia` se borró y
  `/contacto` redirige. **Sin desplegar**, y a propósito: ver *Consecuencias*
- **Decide:** cómo se llama la sección que explica el oficio, qué cubre, dónde
  vive el contacto, y qué vocabulario decó nuevo entra
- **Toca:** `features/navegacion/secciones.ts` (tres secciones → dos),
  `next.config.ts` (un `redirects()`), y le saca dos de sus cuatro consumidores
  a `shared/ui/PaginaEnObra.tsx`
- **Hace cumplir:** `frontera-features.sh` (que `oficio/` no importe de
  `landing/`), `no-hardcoded-colors` (la hoja nueva), `widget-size-guard` (los
  cuatro componentes) y la constante `EL_CONTACTO_ES_PROVISORIO`, que es un gate
  de deploy y no una nota

## Contexto

`/custodia` y `/contacto` eran dos `PaginaEnObra`: la barra las nombraba desde
`v0.15.0` y ninguna tenía contenido. La segunda además **no se podía escribir**
—su propio archivo decía que no se inventa un canal que no atiende nadie— y
[`voz.md §12`](../../design/voz.md) tiene abierta la decisión de con qué nombre
firma quien contesta.

Y el argumento más fuerte del negocio —*¿por qué a ellos y no al
supermercado?*— vivía enterrado adentro de la tercera escena de la home, sin
URL propia. O sea: sin nada que se pueda mandar por WhatsApp.

La forma se eligió **mirándola renderizada**, no discutiéndola: se maquetaron
dos composiciones con el copy real y los tokens del repo —la etiqueta única y la
carta numerada— y el dueño eligió la segunda.

## Decisión

### 1. La sección se llama `El oficio` y su ruta es `/oficio`

Cubre **tres tramos**: `I Elegir`, `II Guardar`, `III Abrir`. Es la estructura de
[`voz.md §1.2`](../../design/voz.md) —el *antes* del Cuidador, el sorbo entre
paréntesis, el *después* del Amante— y no una ampliación de la home.

### 2. `Custodia` baja de nombre de sección a nombre del tramo `II`

La palabra nombraba **un** tramo —el del medio— mientras la sección terminó
cubriendo los tres. Sigue viva en el léxico de [`voz.md §7.2`](../../design/voz.md)
y como nombre del tramo `II` adentro de la página, que es donde rinde. Lo que
desaparece es su uso como **rótulo de navegación**.

`/custodia` se borra **sin redirección**: nada está desplegado, así que no hay un
solo enlace entrante que preservar. Inventar una redirección para una URL que
nunca existió públicamente es escribir código para un caso que no ocurre.

### 3. `/contacto` no se borra: se pliega como cierre de `/oficio`

El arco de la página termina en *quién es "nosotros"*, y ése es exactamente el
contenido de contacto. El bloque de cierre —el sello, con `id="mostrador"`— vive
al final de `/oficio`, y la URL vieja **redirige con 308** a `/oficio#mostrador`,
declarado en `redirects()` de `next.config.ts`.

Redirige y no muere porque los textos ya escritos en `voz.md §9.3` y `§9.5`
dicen *"escribinos"* y van a necesitar un destino el día que alguien los lea.

**Y no hay formulario.** `voz.md §4.2` dice que del otro lado hay una persona; un
formulario dice lo contrario, porque mete una cola de espera entre el que
pregunta y el que contesta.

### 4. La navegación queda en dos secciones más el carrito

`Vinos · El oficio`, y `CARRITO` sigue declarado aparte: no es una sección del
catálogo, es el estado del comprador. Los nombres son **sustantivos**: un
imperativo suelto (`Escribinos`) adentro de una lista de sustantivos se lee como
un botón perdido entre etiquetas. La voz de la marca vive en el cuerpo de cada
página; la barra es señalética.

### 5. El canal de contacto es provisorio y BLOQUEA EL DEPLOY

`EL_CONTACTO_ES_PROVISORIO = true` en `features/oficio/oficio.ts`. El WhatsApp
publicado es el del **desarrollador** y el mail es la forma que va a tener
cuando exista el dominio.

Es el mismo instrumento que `LA_SELECCION_ES_DE_MUESTRA` con los seis vinos
inventados, con una vuelta más: la constante **también se emite al HTML**, como
`data-contacto-provisorio="true"`. Un `grep` dice qué hay en el código de esta
máquina; `auditor-produccion` audita **producción** con `curl` y no puede
grepear un `.ts`. Se chequea de los dos lados:

```bash
grep -rn "EL_CONTACTO_ES_PROVISORIO" apps/tienda/src
curl -s https://<host>/oficio | grep -o data-contacto-provisorio | wc -l
```

`EscenaSeleccion` ya había resuelto esto igual con `data-muestra`; esto copia el
precedente en vez de inventar otro.

### 6. El vocabulario decó nuevo nace en la feature, y no viola `§5.3`

Tres piezas nuevas, todas en `features/oficio/oficio.css` y ninguna en
`shared/deco/` — ADR 006 regla 1: **nada nace en `shared/`**. Bajan el día que
una segunda feature las importe, y esa bajada es un commit propio.

| Pieza | De qué recurso autorizado sale |
|---|---|
| Los dos **brazos** del filete, con la modulación invertida | La regla de un solo trazo de [`direccion.md §5.1`](../../design/direccion.md) más el **trazo modulado**, que se midió en el isotipo: 1,38:1, p95/p05 sobre 1.313 muestras de cresta |
| La **capitular** del primer párrafo de cada tramo | Tipografía del libro, con la misma Fraunces del sitio. No es una display de época |
| El **numeral hueco** del tramo sin firma | El mismo romano macizo de los otros dos, en contorno |

**Ninguna toca la lista prohibida de `§5.3`:** no hay soles nacientes, zigzags,
galones, abanicos, escalonados tipo rascacielos, plumas, tipografías decó de
display, degradés dorados con biselado ni ornamentos espejados. Los numerales
son la tipografía del sitio; el único degradé del bloque es la **máscara** que
modula el filete, que no pinta oro biselado sino que atenúa el que ya está.

⚠️ **Y el numeral no se apoya sobre la regla: la INTERRUMPE.** Un número apoyado
sobre una línea es una viñeta de lista; uno que la corta es un capítulo. Es el
gesto de una tarjeta impresa de 1925 usado como estructura, no como adorno.

### 7. El corte de dos columnas es `@media`, no `@container`

La maqueta usaba un container query **porque tenía que simular un viewport que
no tenía**. La página real no simula nada: su contenedor *es* el viewport.

Queda escrito acá porque la maqueta tuvo exactamente ese defecto y es fácil
portar el andamio creyendo que era diseño: su conmutador "Móvil 390" achicaba la
caja pero el corte medía el **viewport**, así que el control decía *"estoy
mirando el móvil"* mientras mostraba escritorio. **Nadie —ni el dueño ni yo—
había visto el layout angosto.**

**Corte en 1000 px.** A 1080 de plancha, dos columnas dan ~34ch cada una, que es
la medida de párrafo que `direccion.md §5.1` pide.

### 8. El movimiento es scroll, no reloj, y degrada a página entera

Todo con `animation-timeline: view()`, adentro de
`@supports (animation-timeline: view())` **y**
`@media (prefers-reduced-motion: no-preference)`. Cero JavaScript, cero estado,
cero observers. El estado **base** es la página dibujada entera: filetes a ancho
completo, numerales opacos, títulos visibles. Firefox tiene los timelines detrás
de flag, así que ahí la sección se ve completa y quieta, que es lo correcto.

## Presupuesto de lecturas

**Cero lecturas de Firestore, hoy y por construcción.** El contenido vive en
`features/oficio/oficio.ts`, así que `/oficio` es HTML estático que sólo cambia
cuando cambia el diseño. No hay `Producto`, no hay `Orden`, no entra al circuito
de purga por tag de [ADR 004](004-frescura-y-lecturas.md) y no toca la cuota de
50.000/día.

**Contra la cuota: 0 %.**

Verificado, no supuesto: `grep -rniE "firebase|firestore"` sobre las líneas de
`import` de la feature no da coincidencias, y `next build` la emite como ruta
**estática** (`○`), no como server-rendered on demand. Y el `page.tsx` no tiene
`fetch`, ni `cookies()`, ni `headers()`: nada que la saque de estática sin que
el build lo diga.

⚠️ **La trampa cercana, anotada para el próximo:** el sello es el lugar natural
donde alguien va a querer poner un horario de atención "en vivo" o un estado de
"conectado". Cualquiera de las dos cosas convierte una página estática en una
lectura por visitante, y en el bloque más visitado de la sección.

## Por qué NO las alternativas

| Alternativa | Por qué no |
|---|---|
| Dejar `/custodia` y `/contacto` como dos secciones separadas | Son dos placeholders que se resuelven mejor juntos: el arco termina en quién es "nosotros", y ése es el contenido de contacto. Y `Custodia` nombraba un tramo de tres |
| Reusar `EscenaCustodia` de la home | ADR 006 regla 3 lo prohíbe y `frontera-features.sh` lo mide. Y hay una razón de producto antes que la de arquitectura: quien llega desde un WhatsApp **nunca vio la home**, así que la sección tiene que sostenerse sola |
| La composición de la **etiqueta única** (un anillo octogonal encierra los dos tramos firmados y el tercero cae afuera) | La eligió el dueño mirando las dos: perdió. Queda en el artifact de la maqueta |
| El copy adentro del JSX | `widget-size-guard` bloquea presentación de más de 200 líneas y la sección tiene ~565 palabras: el componente nacería bloqueado. Y las verificaciones de voz son greps, que necesitan **un** archivo al que apuntar |
| MDX para el contenido | Una dependencia y un pipeline para un texto que cambia dos veces por año |
| Una variable de entorno en vez de `EL_CONTACTO_ES_PROVISORIO` | Se olvida de setear, no deja rastro en el diff y no se ve en el HTML servido |
| Bajar los brazos y la capitular a `shared/deco/` ahora | ADR 006 regla 1. Ninguna segunda feature los pidió todavía |

## Consecuencias

- **`PaginaEnObra` pierde dos de sus cuatro consumidores.** Le quedan `/vinos` y
  `/carrito`. No se borra —sigue teniendo call site, verificado— pero su fecha
  de muerte se acercó: el día que esas dos secciones existan, `call-site-guard`
  la va a marcar huérfana, y **ese aviso es la señal de borrarla**, no de
  agregarle una prop.
- **La sección no se despliega.** `EL_CONTACTO_ES_PROVISORIO` es el **quinto**
  gate abierto de la vidriera, junto con la puerta de edad, las seis fichas en
  404, las licencias de los assets y los 391 KB de fuentes de la primera
  pantalla. Todo lo de este ADR está verificado sobre una build de producción
  **local** (`next build` + `next start`), no sobre producción.
- **Dos defectos visuales que ninguna medición mostró**, los dos hallados
  abriendo el PNG, que es la quinta vez en este proyecto:

  1. **Los párrafos salían pegados, en los dos anchos.** El aire estaba en un
     `.tramo__cuerpo p + p` —especificidad (0,1,2)— y el `margin: 0` vivía en
     `.tramo__cuerpo .prosa` —(0,2,0)—, así que **el margen no pintaba nunca**.
     Las columnas, los altos, el `scrollWidth` y el `column-rule` daban todos
     bien mientras la prosa era un muro.
  2. **`break-inside: avoid-column` desbalanceaba las columnas.** Con los
     párrafos atómicos el balanceador no tiene con qué repartir: el tramo `I`
     quedaba con **3 líneas de un lado y 9 del otro**. Se saca, y `orphans: 2` /
     `widows: 2` impiden que el corte deje una línea suelta. Una carta impresa
     parte el párrafo al pie de la columna y lo sigue arriba de la otra: es el
     gesto que la página cita.

- ⚠️ **EL GATE DE DEPLOY NACIÓ ROTO Y SE ARREGLÓ MIDIÉNDOLO.** La primera
  versión emitía el atributo con un ternario:
  `data-contacto-provisorio={CONST ? 'true' : undefined}`. React omite el
  atributo en el DOM —eso funciona—, pero el App Router **serializa el payload
  RSC adentro del mismo HTML**, y ahí la prop viaja igual, como
  `"data-contacto-provisorio":"$undefined"`. O sea que el `curl … | grep`
  encontraba el string **con la constante en `false`**: el gate no distinguía
  nada, y el día que alguien lo bajara habría seguido diciendo "provisorio".

  Se destapó **corriendo el control**, no leyendo el código: se bajó la
  constante, se reconstruyó y el grep siguió dando 1. El arreglo es un **spread
  condicional**, que no deja la clave en el objeto de props:

  ```tsx
  {...(EL_CONTACTO_ES_PROVISORIO ? { 'data-contacto-provisorio': 'true' } : {})}
  ```

  Medido después del arreglo, con la página intacta como control positivo
  (`id="mostrador"` presente en las dos corridas): **`true` → 2 apariciones**
  (el DOM y el payload), **`false` → 0**.

  ⚠️ Y el comando documentado también estaba mal: `grep -c` cuenta **líneas**
  con coincidencia, y el HTML de Next viene en una sola línea, así que devuelve
  1 aunque el atributo aparezca cinco veces. Va `grep -o … | wc -l`.

  **Esto le aplica a `data-muestra` de `EscenaSeleccion` el día que se apague**,
  que es el mismo patrón y todavía no se probó: hoy ese atributo es
  incondicional, así que nadie lo midió apagado.

- ⚠️ **Tres instrumentos de verificación mintieron en esta tarea, y los tres en
  verde.** Están acá porque el próximo los va a usar:

  | Instrumento | Cómo miente |
  |---|---|
  | `grep -i` sobre texto con acentos | Con el locale vacío (`LANG=`, `LC_ALL=`) devuelve **cero coincidencias en silencio** sobre un archivo UTF-8 con tildes — `grep -c` ni siquiera imprime un número. El control positivo con el dialecto de cata insertado daba **0**. Con `LC_ALL=C.UTF-8` encuentra las tres. **Todo grep de copy va con el locale puesto** |
  | `call-site-guard` | Grepea `apps/ packages/ functions/ scripts/` **enteros**, y ahí adentro están `node_modules` y `.next`. Los sourcemaps del build (`*.js.map`) **embeben el fuente**, así que un símbolo que no abre nadie aparece "usado" en cuanto corrió un build: dio verde con `Fragmento` y `Canal` huérfanos. Es la misma familia que `generar_verdad.mjs` contando comentarios como call sites. Y de paso es O(símbolos × repo): sobre un archivo con 8 exports tarda **más de dos minutos** |
  | `frontera-features.sh` (regla 2) | Sólo grepea `from '@/features/`. El **mismo** import escrito relativo —`from '../landing/seleccion'`— **no bloquea**. Medido con los dos controles, uno al lado del otro |

- **La escala tipográfica de la sección pisa la de `tokens.css`**, y es la
  primera feature que lo hace. Está declarada en `.oficio` con su porqué: la
  landing pone tres líneas grandes por pantalla y esta página pone ~565 palabras
  de prosa seguidas. Si mañana una tercera página necesita la misma escala, esto
  deja de ser una excepción de feature y `tokens.md` tiene que hablar de dos
  escalas.

## Lo que hay que medir antes de creerle a este ADR

- **El numeral hueco lo tiene que mirar el dueño.** Yo lo miré renderizado y se
  lee como decisión, no como defecto: el contorno es parejo, y el filete al 50 %
  y el nombre atenuado lo acompañan. Pero el que marcó el riesgo fue él, así que
  la palabra es suya. El plan B está escrito: numeral macizo con el nombre en
  cursiva y el filete al 50 %.
- **El contraste del filete dorado sigue sin medirse** sobre el píxel pintado.
  `direccion.md §2.1` calcula el dorado **puro** sobre tinta en 8,80:1, pero el
  filete se dibuja al 85 % y al 42 %, y la regla entre columnas al **22 %**. Si
  el píxel da menos de 3:1, la regla deja de cumplir la función estructural que
  la justifica. Es el mismo pendiente que ya tenía el cartucho.
- **El corte de 1000 px no se miró entre 1000 y 1440.** A 1440 las dos columnas
  dan ~34ch y a 390 hay una sola, las dos verificadas; el borde exacto donde la
  columna se vuelve angosta no. **Disparador:** la primera vez que alguien abra
  esto en una tablet apaisada.
- **`prefers-reduced-motion` se verificó emulado por CDP**, no con la
  preferencia puesta en el sistema operativo.
