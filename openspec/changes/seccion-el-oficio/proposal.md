## Why

`/custodia` es hoy un `PaginaEnObra`: la barra nombra una sección cuyo contenido
la marca nunca escribió. Y el argumento más fuerte que tiene el negocio —*por
qué a ellos y no al supermercado*— vive enterrado adentro de la tercera escena
de la home, sin URL propia, o sea sin nada que se pueda mandar por WhatsApp.

Al mismo tiempo `/contacto` es un placeholder que **no se puede escribir**: su
propio archivo dice que no se inventa un canal que no atiende nadie, y
[`voz.md §12`](../../../docs/vault/design/voz.md) tiene abierta la decisión de
con qué nombre firma el WhatsApp. Son dos secciones vacías que se resuelven
mejor juntas que separadas: el arco de la página termina en *quién es
"nosotros"*, y ése es exactamente el contenido de contacto.

El dueño eligió la forma mirándola renderizada, no leyéndola: se maquetaron dos
composiciones —la etiqueta única y la carta numerada— y ganó la segunda.

## What Changes

- **Nace `apps/tienda/src/features/oficio/`**, la sección que explica el oficio
  completo en tres tramos: **elegir · guardar · abrir**. Es la estructura de
  [`voz.md §1.2`](../../../docs/vault/design/voz.md) (el *antes* del Cuidador,
  el sorbo entre paréntesis, el *después* del Amante), no una ampliación de la
  home: ADR 006 regla 3 prohíbe que una feature importe de otra, y alguien que
  llega desde WhatsApp nunca vio la home.
- **La sección se llama `El oficio`** y su ruta es **`/oficio`**. "Custodia"
  nombraba sólo el tramo del medio; pasa a ser el nombre de ese tramo adentro
  de la página, que es donde la palabra rinde.
- **BREAKING** — **`/custodia` deja de existir.** Nada está desplegado todavía,
  así que no hay enlaces entrantes que romper.
- **BREAKING** — **`/contacto` deja de ser una sección** y se pliega como cierre
  de `/oficio`. La URL sobrevive **redirigiendo** a `/oficio#mostrador`, porque
  los textos ya escritos de [`voz.md §9.3` y `§9.5`](../../../docs/vault/design/voz.md)
  dicen *"escribinos"* y van a necesitar un destino.
- **La navegación pasa de tres secciones a dos** más el carrito:
  `Vinos · El oficio` + `Carrito`.
- **El canal de contacto es provisorio y bloquea el deploy.** Entra detrás de
  una constante `EL_CONTACTO_ES_PROVISORIO`, el mismo instrumento que hoy usa
  `LA_SELECCION_ES_DE_MUESTRA` con los seis vinos inventados: mientras dé
  `true`, esto no se publica.
- **Vocabulario decó nuevo, todo derivado de lo que ya existe** — ninguno de los
  ornamentos que [`direccion.md §5.3`](../../../docs/vault/design/direccion.md)
  prohíbe: el numeral romano que **interrumpe** la regla en vez de apoyarse
  sobre ella, la capitular del primer párrafo de cada tramo, y el trazado de los
  brazos del filete atado al scroll.
- **`PaginaEnObra` pierde dos de sus cuatro consumidores.** No se borra todavía
  —`/vinos` y `/carrito` la siguen usando—, pero su fecha de muerte se acerca y
  el ADR lo deja anotado.

### Lo que este cambio NO hace

- No toca la home. Las cuatro escenas quedan como están, `EscenaCustodia`
  incluida: las dos piezas pueden decir lo mismo con palabras distintas, y
  ninguna importa de la otra.
- No resuelve la puerta de edad, las seis fichas en 404 ni las licencias de los
  assets. Los tres siguen bloqueando el deploy por su cuenta.
- No toca plata. No es Workflow D.

## Capabilities

### New Capabilities

- `vidriera-oficio`: la sección `/oficio` — los tres tramos, qué puede y qué no
  puede afirmar cada uno, el bloque de cierre con el canal de contacto, y la
  constante que bloquea el deploy mientras ese canal sea provisorio.
- `vidriera-navegacion`: qué secciones nombra la barra principal y con qué
  reglas (sustantivos, señalética, el carrito aparte). Existe en código desde
  `v0.15.0` y hasta hoy no tenía spec; este cambio la modifica, así que la
  escribe.

### Modified Capabilities

Ninguna. `openspec/specs/` está vacío: éste es el primer cambio que escribe
specs en el proyecto.

## Impact

**Código**

| Ruta | Qué le pasa |
|---|---|
| `apps/tienda/src/features/oficio/` | **nueva** — componentes, contenido y hoja de estilo |
| `apps/tienda/src/app/oficio/page.tsx` | **nueva** — la ruta |
| `apps/tienda/src/app/custodia/page.tsx` | **se borra** |
| `apps/tienda/src/app/contacto/page.tsx` | **se borra**; la redirección va en `next.config` |
| `apps/tienda/src/features/navegacion/secciones.ts` | tres secciones → dos |
| `apps/tienda/src/shared/ui/PaginaEnObra.tsx` | queda, con dos consumidores menos |

**Presupuesto de lecturas de Firestore: cero, y es cero por construcción.** La
página es HTML estático con el contenido en el módulo, igual que la home
(`page.tsx`: *"Cero lecturas de Firestore por visitante"*). No hay `Producto`,
no hay `Orden`, no entra al circuito de purga por tag del ADR 004 y no toca la
cuota de 50.000/día. No se corrió el agente `presupuesto-lecturas` porque no hay
nada que contar: la ausencia de un import de Firestore se verifica con un grep,
y ese grep es una tarea de este cambio.

**Presupuesto de peso:** la sección no trae imágenes. Las dos familias
tipográficas ya las carga `layout.tsx` para toda la vidriera, así que el costo
marginal de esta página es sólo su HTML y su CSS.

**Hooks que van a medir esto:** `no-hardcoded-colors` (la hoja nueva),
`frontera-features.sh` (que `oficio/` no importe de `landing/`),
`call-site-guard` (que alguien abra lo que se escriba) y `vault-precheck`.

**Documentación:** ADR nuevo con el nombre de la sección, la fusión de contacto
y el porqué de que el vocabulario decó nuevo no viole `direccion.md §5.3`. Más
la entrada en `_index.md`, con tope de cinco.

## Supuestos registrados

Ninguno bloquea; se anotan para que se puedan corregir sin releer la
conversación.

1. **La ruta es `/oficio`, sin artículo**, como `/vinos` y `/carrito`. La barra
   dice `El oficio`.
2. **El WhatsApp `+54 9 3548 60-0375` es del desarrollador, no del cliente**, y
   se reemplaza antes de publicar. El código de país y el `9` móvil se asumen
   argentinos.
3. **El mail se deriva del dominio y hoy no existe.** Se escribe la forma
   (`hola@<dominio>`) detrás de la misma constante; se confirma cuando haya
   dominio.
4. **Córdoba está confirmada por el dueño** como la plaza del negocio, y por eso
   la amplitud térmica local entra como dato en el tramo *guardar*.
