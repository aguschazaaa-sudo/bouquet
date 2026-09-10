## ADDED Requirements

### Requirement: La sección se sirve en `/oficio` y se sostiene sola

La vidriera SHALL servir la sección en la ruta `/oficio` como página estática, y
esa página MUST ser legible sin haber visto ninguna otra del sitio: llega gente
por un enlace mandado a mano, sin pasar por la portada.

#### Scenario: La ruta responde

- **WHEN** se pide `GET /oficio` sobre una build de producción
- **THEN** la respuesta es 200 y su HTML contiene los tres nombres de tramo:
  `Elegir`, `Guardar` y `Abrir`

#### Scenario: Control negativo de la verificación anterior

- **WHEN** se pide `GET /ruta-inventada-de-control`
- **THEN** la respuesta es 404, lo que prueba que el 200 de `/oficio` no viene
  de un catch-all

#### Scenario: La ruta es estática

- **WHEN** se corre `next build`
- **THEN** `/oficio` aparece en la lista de rutas como estática, no como
  dinámica ni como server-rendered on demand

### Requirement: La sección no depende de ninguna otra feature

La feature `oficio` MUST NOT importar de otra feature, y en particular MUST NOT
importar de `landing`. La sección dice cosas que la home también dice; las dice
con su propio texto y sus propios componentes.

#### Scenario: La frontera se mide, no se promete

- **WHEN** se corre `grep -rn "features/landing" apps/tienda/src/features/oficio/`
- **THEN** no hay coincidencias

#### Scenario: El hook la hace cumplir

- **WHEN** se escribe en `apps/tienda/src/features/oficio/` un import desde
  `@/features/landing/...`
- **THEN** `frontera-features.sh` bloquea la escritura

### Requirement: Tres tramos, y el tercero se marca como no firmado

La página SHALL presentar tres tramos numerados —`I Elegir`, `II Guardar`,
`III Abrir`— y MUST distinguir visualmente el tercero como el tramo que la marca
no firma, porque es la tesis de la página y no una nota al pie.

#### Scenario: La distinción es estructural, no textual

- **WHEN** se inspecciona el tramo `III` en el DOM
- **THEN** su contenedor lleva el modificador que lo marca como no firmado, y su
  numeral se pinta en contorno y no macizo

#### Scenario: El título de la página lo declara

- **WHEN** se lee el `h1` de la página
- **THEN** dice cuántos tramos hay y cuántos firma la marca

### Requirement: La sección no afirma nada sobre el gusto de un vino

Ningún texto de la sección SHALL emitir un juicio sensorial sobre un vino.
La sección MAY explicar mecanismos verificables —altura y amplitud térmica,
paso por roble, temperatura de servicio, aireación— porque son hechos que
cualquiera puede comprobar en un manual y no opiniones de un catador sin nombre.

Es [`voz.md §3.2`](../../../../../docs/vault/design/voz.md) aplicado: *bouquet
nunca firma una descripción sensorial del líquido que no probó.*

#### Scenario: El dialecto de cata no aparece

- **WHEN** se corre un `grep -i` de las expresiones de `voz.md §7.1` sobre el
  contenido de la sección — *notas de*, *en boca*, *taninos*, *final largo*,
  *cuerpo medio*, *maridaje*, *buqué*
- **THEN** no hay coincidencias

#### Scenario: Control positivo del grep anterior

- **WHEN** se inserta temporalmente una de esas expresiones en el contenido y se
  vuelve a correr el grep
- **THEN** el grep la encuentra, lo que prueba que estaba mirando el archivo
  correcto

#### Scenario: Los topes contables de la voz

- **WHEN** se cuentan sobre el contenido de la sección los signos de
  exclamación, los emoji y las apariciones de `tú`, `usted`, `tienes` o `puedes`
- **THEN** todos dan cero

### Requirement: El cierre nombra a la persona que atiende

La página SHALL terminar en un bloque de contacto con `id="mostrador"`, en voz
de mostrador, que ofrezca al menos un canal directo y MUST NOT ofrecer un
formulario: [`voz.md §4.2`](../../../../../docs/vault/design/voz.md) dice que
del otro lado hay una persona, y un formulario dice lo contrario.

#### Scenario: El ancla existe

- **WHEN** se pide `GET /oficio` y se busca `id="mostrador"` en el HTML servido
- **THEN** aparece exactamente una vez

#### Scenario: No hay formulario

- **WHEN** se busca `<form` en el HTML de la sección
- **THEN** no aparece

### Requirement: Un canal de contacto provisorio bloquea el deploy

El módulo de contenido MUST exportar `EL_CONTACTO_ES_PROVISORIO` en `true`
mientras el WhatsApp o el mail publicados no sean los del negocio, y con esa
constante en `true` la sección MUST NOT publicarse.

Es el mismo instrumento que `LA_SELECCION_ES_DE_MUESTRA` ya usa con los seis
vinos inventados: una constante greppable, no una nota en un documento que nadie
relee.

#### Scenario: La constante existe y es legible desde afuera

- **WHEN** se corre `grep -rn "EL_CONTACTO_ES_PROVISORIO" apps/tienda/src/`
- **THEN** aparece su declaración y da `true`

#### Scenario: El deploy se detiene

- **WHEN** se va a desplegar la vidriera y la constante da `true`
- **THEN** el deploy no se hace, y el motivo se dice en voz alta

### Requirement: `/custodia` desaparece y `/contacto` sobrevive redirigiendo

`/custodia` MUST dejar de existir. `/contacto` MUST responder con una
redirección permanente a `/oficio#mostrador`, porque los textos ya escritos en
`voz.md §9.3` y `§9.5` mandan al lector a escribir y necesitan un destino.

#### Scenario: La ruta vieja se fue

- **WHEN** se pide `GET /custodia`
- **THEN** la respuesta es 404

#### Scenario: El contacto sigue llegando a alguien

- **WHEN** se pide `GET /contacto` sin seguir redirecciones
- **THEN** la respuesta es 308 y su `Location` es `/oficio#mostrador`

### Requirement: Cero lecturas de Firestore por visitante

La sección MUST NOT leer Firestore. Su contenido vive en el módulo y sólo cambia
cuando cambia el diseño, así que no entra al circuito de purga por tag del
ADR 004 ni toca la cuota de 50.000 lecturas/día.

#### Scenario: No hay import de Firestore en la feature

- **WHEN** se corre `grep -rniE "firebase|firestore" apps/tienda/src/features/oficio/`
- **THEN** no hay coincidencias

### Requirement: La página se lee entera sin movimiento

Todo el movimiento de la sección SHALL ir atado al scroll mediante
`animation-timeline: view()`, sin JavaScript y sin estado. Donde ese motor no
exista, o cuando el visitante pida `prefers-reduced-motion: reduce`, la página
MUST quedar dibujada entera: ningún texto puede depender de una animación para
ser visible.

#### Scenario: Sin el motor, la página está completa

- **WHEN** se desactiva el soporte de timelines de scroll
- **THEN** los filetes se ven a ancho completo, los numerales opacos y los
  títulos visibles

#### Scenario: Con movimiento reducido

- **WHEN** el visitante tiene `prefers-reduced-motion: reduce`
- **THEN** no corre ninguna animación ni transición, y el `scrollHeight` de la
  página es el mismo que sin la preferencia

### Requirement: La prosa va a una sola columna en pantalla angosta

La prosa de cada tramo SHALL ir a dos columnas sólo cuando haya ancho para
sostener las dos medidas de lectura, y MUST caer a una sola columna por debajo
de ese corte.

⚠️ Este requisito existe porque la primera maqueta **no lo verificó**: su
conmutador de ancho achicaba la caja pero el corte era una media query, que mide
el viewport y no el contenedor. El control daba verde con el móvil sin mirar.

#### Scenario: Móvil

- **WHEN** se mira la sección a 390 px de ancho
- **THEN** cada tramo tiene una sola columna de prosa y no hay regla vertical
  entre columnas

#### Scenario: Escritorio

- **WHEN** se mira la sección a 1440 px de ancho
- **THEN** cada tramo tiene dos columnas de prosa separadas por una regla dorada

#### Scenario: El ancho de la página no desborda

- **WHEN** se mide el `scrollWidth` del `body` a 390 px
- **THEN** no supera al `clientWidth`

### Requirement: El vocabulario decó nuevo no usa ornamento prohibido

Toda pieza decorativa que este cambio introduzca MUST derivarse de un recurso
que [`direccion.md §5.1`](../../../../../docs/vault/design/direccion.md)
autoriza, y MUST NOT incluir nada de la lista prohibida de `§5.3`. Las tres
piezas nuevas son el numeral que interrumpe la regla, la capitular del primer
párrafo y el trazado de los brazos del filete.

#### Scenario: La lista prohibida no aparece

- **WHEN** se revisa la hoja de estilo de la sección buscando soles nacientes,
  zigzags, galones, abanicos, escalonados, plumas, tipografías decó de display,
  degradés dorados con biselado u ornamentos espejados
- **THEN** no hay ninguno

#### Scenario: Los colores salen de los tokens

- **WHEN** se corre el hook `no-hardcoded-colors` sobre la hoja de la sección
- **THEN** no bloquea: no hay hex, `rgb()` ni `hsl()` fuera de `tokens.css`
