# ADR 028 — La puerta de edad: un telón sobre el sitio entero, que no bloquea el render

- **Fecha:** 2026-09-30
- **Estado:** aceptada; **escrita y en la preview** — ver *Verificación*
- **Decide:** cómo se construye la puerta de edad que exigen
  [ARQUITECTURA §9.5](../../../../ARQUITECTURA.md#95-alcohol-y-edad) y
  [parallax.md §10.2](../../design/parallax.md): dónde se monta, qué guarda, cómo bloquea
  el scroll y qué pasa sin JavaScript
- **Toca:** [ADR 017](017-preview-cerrada.md) (la preview tenía como gate abierto *"Puerta
  de edad: no existe"*), [ADR 006](006-estructura-de-la-tienda.md) (estrena
  `features/edad/`, que ya figuraba como feature futura)
- **Hace cumplir:** `apps/tienda/test/edad.test.ts` (lo que guarda el telón es lo que acepta
  el script en línea, con controles negativos) y `bash scripts/tienda/preview.sh verificar`
  paso 5 (telón en cuatro rutas, script **antes** del telón, fichas debajo, control negativo)
- **Cierra:** el pendiente *"La home NO tiene puerta de edad, y es la única pieza legal
  obligatoria"* (desde 2026-09-08)
- **Sin openspec:** el diseño ya estaba decidido y escrito (parallax §10.2, voz §9.1,
  ARQUITECTURA §9.5); esto es su construcción

## Decisión

### 1. Va en el layout raíz y envuelve al sitio

`<PuertaDeEdad sello={<Copa/>}>{barra, página, aviso}</PuertaDeEdad>` en `app/layout.tsx`.
En la raíz y no en la home, porque §9.5 pide la puerta *al entrar al sitio*, y al sitio
se entra también por una ficha que alguien compartió.

**Envuelve, pero no condiciona:** `children` se renderiza siempre, con el telón puesto o
no. El telón es un overlay fijo encima. Es la restricción dura de §9.5: si el contenido no
está en el HTML, Google no lo ve.

### 2. Qué se guarda

`localStorage['bouquet.edad'] = {"mayor":true,"fecha":"<ISO>"}`: un booleano y una fecha,
como fija §10.2. **No se pide ni se guarda la fecha de nacimiento.** La verificación real es
el documento en la entrega, y el telón lo dice (voz §9.1).

La clave, el formato y el script viven en `features/edad/edad.ts`, un módulo **neutro**:
`PuertaDeEdad` es `'use client'`, y lo que exporta un módulo de cliente le llega al servidor
como referencia, no como valor. El layout necesita la cadena de verdad para el script.

### 3. Sin parpadeo para el que vuelve

Un `<script>` en línea, **primer hijo del `<body>`**, lee la marca y pone
`data-edad="ok"` en `<html>` antes de que el navegador llegue al telón.
`[data-edad='ok'] .puerta { display: none }` lo esconde sin un solo frame. El `<html>` lleva
`suppressHydrationWarning` por ese atributo, y sólo por ese.

### 4. El scroll: `inert` + el telón como contenedor de scroll

§10.2 prohíbe `overflow: hidden` en el `body` (en iOS pierde la posición). Entonces:

- **`inert` en el envoltorio del sitio**, puesto **desde el efecto** al hidratar. Con eso,
  el teclado sólo recorre el telón. El foco va al botón principal.
- **El telón es un contenedor de scroll** con `overscroll-behavior: contain`, y su
  escenario mide `100% + 1px`. ⚠️ `contain` sólo retiene el gesto si el contenedor **puede**
  scrollear: uno que no desborda no entra en la cadena, y la rueda le llega a la página. El
  píxel de más lo convierte en un scroller de verdad. En un teléfono acostado, donde la placa
  no entra, ese mismo scroll es el que deja llegar al botón.

La página queda en `scrollTop 0` y ninguna animación atada al scroll se consume antes de
entrar. Es la ventaja estructural que §10.2 le vio al telón.

### 5. Se levanta: 800 ms, ease-out, sin rebote

`translate: 0 -100%` con `--ease-caida`. Con `prefers-reduced-motion`, un fundido de 150 ms
(§7.3). El sitio se libera **al empezar a subir**, no al terminar. El desmontaje lo dispara
`transitionend` del telón mismo (`target === currentTarget`: el color de un botón también
dispara uno). Una red de 1,5 s cubre la transición que nunca llega.

### 6. `Todavía no` tiene respuesta, y vuelve

*"Entonces, todavía no. / Volvé cuando cumplas 18. Vamos a seguir acá."* y un solo camino
de vuelta, `Me equivoqué`. No redirige a ningún lado ni recuerda la negativa. Lo revisó
`voz` y quedó en [voz.md §9.1](../../design/voz.md).

### 7. Sin JavaScript, el telón no se muestra

`<noscript><style>.puerta{display:none}</style></noscript>`. Sin JavaScript el telón no se
puede levantar ni recordar: mostrarlo sería una puerta que no abre. **Y nadie compra sin
pasar por él**: el carrito vive en `localStorage` y el pedido lo arma un componente de
cliente. Sin JavaScript se puede mirar el catálogo, no comprar.

## Por qué NO las alternativas

| Alternativa | Por qué no |
|---|---|
| `inert` como prop de React | El servidor no sabe quién ya entró, así que lo pondría en **todas** las respuestas: quien vuelve tendría la página muerta hasta que hidrate, y sin JavaScript **para siempre**, porque un `<noscript>` esconde el telón pero no le saca un atributo al contenido |
| Leer la marca en un `useEffect` | Corre después del primer pintado: quien ya entró vería el telón parpadear en cada carga (§10.2, requisito 2) |
| `overflow: hidden` en `html` o `body` | Prohibido por §10.2. Además saca la barra de scroll, y el contenido salta 15 px al volver en plena cortina |
| Ponerle `inert` a los hermanos del telón en el `body` | Next inyecta sus propios nodos ahí, y una navegación de cliente puede meter uno nuevo que nace sin `inert`. Un envoltorio es un solo elemento |
| El telón sólo en la home | Se entra por cualquier ruta (§9.5) |
| Copiar `PuertaDeEdad.tsx` de `home-parallax-c` | Su mecánica es buena y se reusó: script en línea, `try`, red de seguridad, `noscript`. Pero dibujaba con el `Cartucho` de esa composición. Éste usa el vocabulario que quedó: `.cartucho-deco`, `.boton`, `Copa` |
| Guardar fecha de nacimiento | No verifica nada que el documento en la entrega no verifique, y es un dato personal más |
| `<dialog>` con `showModal()` | Necesita JavaScript para abrirse, así que antes de hidratar el telón no taparía nada. Y el `Esc` lo cierra por defecto |

## Presupuesto de lecturas

**Cero, por construcción.** El telón lee `localStorage` en el navegador y no toca Firestore
ni el servidor. No cambia la caché de ninguna ruta: el HTML es el mismo para todos los
visitantes (el telón va siempre, y lo esconde el script en el cliente), así que la purga por
tag de [ADR 005](005-hosting-vidriera.md) no se entera. Contra los 50.000/día: 0 %.

## Lo que NO resuelve

- **Arrastrar la barra de scroll de la página con el mouse**, en escritorio, la mueve
  debajo del telón. La barra queda fuera del overlay (el viewport no la incluye). Es el
  único camino que no bloquea, y consume animaciones de una página que no se ve. Se acepta.
- **Antes de hidratar, el tabulador** puede llegar al contenido de abajo: el `inert` lo
  pone el efecto. El telón ya tapa todo con el puntero.
- **Los requisitos legales reales** (habilitación, INV, la Ley 3361 de CABA con documento y
  franja horaria en la entrega) siguen en
  [ARQUITECTURA §11](../../../../ARQUITECTURA.md#11-lo-que-queda-abierto-con-su-disparador).
  Un telón de autodeclaración no los reemplaza.

## Verificación (2026-09-30)

**En la preview**, rollouts `build-2026-09-30-001` (v0.49.0) y `-002` (v0.49.1), los dos
`SUCCEEDED` con el 100 % del tráfico **por la API cruda**, no por el "complete" del CLI.

| Qué | Cómo |
|---|---|
| Las suites | CI `36731529614` (`alcance=tests`) sobre `245b5ea`: los 4 casos de `edad.test.ts` **por nombre** en el log, y la tienda **39 → 43, +4 exactos**, restada contra la corrida `36646226469` |
| El HTML servido | `preview.sh verificar`, paso 5 nuevo: telón en `/`, `/vinos`, `/oficio`, `/carrito`; el script **antes** del telón (por byte); las 21 fichas de `/vinos` debajo; control negativo en 0 |
| Que llegó este deploy | Canario de v0.49.1: *"ley, y también"* con espacio normal **desaparece** y con espacio duro **aparece** en `/vinos` y `/oficio`. En `/` queda uno con espacio normal y es del pie de la landing, que ya repetía la frase |
| Renderizado | Chrome del sistema por CDP, perfil vacío, a 1280 y a 390 (`innerWidth` medido: 390). **20/20**, capturas miradas: la placa, *"Todavía no"* y su vuelta, la subida a los 350 ms, y adentro |
| El scroll, con su par | La misma rueda de 900 px: **`scrollY = 0`** con el telón puesto, **`900`** después de entrar |
| Sin parpadeo, con su par | Un contador por frame desde el inicio del documento. Primera visita: **0 frames** con el sitio pintado sin telón (11 y 23 observados). Quien ya entró: **0 frames** con el telón pintado. **Repetido con la red estrangulada** a 150 KB/s y 300 ms: 338 y 436 frames, los dos en 0 |
| Lo demás | `inert` puesto y sacado, el foco en el botón que corresponde, `localStorage` con `{mayor, fecha}`, `data-edad="ok"`, fundido con *reducir movimiento*, sin desborde a 390, **cero errores y avisos en la consola**, sin aviso de hidratación incluido |

### Lo que la verificación encontró

- **La "y" huérfana.** Mirando las capturas, a 1280 y a 390 la línea terminaba en *"Es la ley,
  y"*. En v0.49.1 va un espacio duro después de la conjunción, y ahora corta en la coma. No lo
  habría encontrado ningún test.
- ⚠️ **Una sonda que mentía, y lo que midió de verdad.** La primera versión miraba sólo el
  **primer** frame y dio *"sin telón"* en una corrida. Parecía que el telón, que va al final del
  `<body>` y llega por streaming, dejaba ver la página un instante. Pero en ese frame **no había
  sitio tampoco**: medía "todavía no llegó nada". Con un contador por frame que exige que el
  sitio exista, da 0 incluso con la red estrangulada. **Por qué da 0:** el CSS del `<head>`
  bloquea el render, y para cuando llega ya llegó el HTML entero. **Deja de ser cierto** si una
  página crece hasta que su HTML llegue después que el CSS. El arreglo sería mover el telón
  **antes** del sitio en `PuertaDeEdad`, que no cuesta nada. Disparador: que esta sonda dé un
  frame distinto de 0.

**Nadie lo miró en un teléfono de verdad**: los 390 son emulados. Lo mira el dueño.
