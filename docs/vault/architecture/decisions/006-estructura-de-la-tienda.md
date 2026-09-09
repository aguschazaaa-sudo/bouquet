# ADR 006 — La vidriera se organiza por lo que hace, y `shared/` tiene reglas o se convierte en cajón

- **Fecha:** 2026-09-09
- **Estado:** aceptada y **aplicada** — `apps/tienda/src` ya está movido, y el
  hook que mide la frontera corre desde este commit
- **Decide:** cómo se ordenan los archivos de `apps/tienda`, y qué impide que
  `shared/` se llene
- **Toca:** la línea *Estructura: feature-first, no por capas en la raíz* de
  `CLAUDE.md`, que estaba tomada para el panel y **no se había aplicado a la
  vidriera**
- **Hace cumplir:** `scripts/hooks/frontera-features.sh` (regla 3), más
  `widget-size-guard`, `no-hardcoded-colors` y `server-only-guard`, que ya
  existían y a los que esta mudanza **les cambió las rutas**

## Contexto

Hasta este commit `apps/tienda/src` estaba organizado por **capa técnica**:

```
components/   estilos/   contenido/   tokens/   server/   app/
```

Eso contradice una decisión que `CLAUDE.md` ya tenía tomada —*"Feature-first,
no por capas en la raíz"*— y que se había aplicado sólo al panel. Así que esto
no re-propone nada: **aplica a la vidriera lo que ya estaba decidido.**

El síntoma concreto, y no es estético. `estilos/sistema.css` tenía 509 líneas y
adentro había **tres cosas sin relación**: el motor de parallax, las cuatro
clases de tipografía y el botón. Nadie las había juntado por una razón: se
juntaron porque el archivo se llamaba *sistema*, que es un nombre que acepta
cualquier cosa. Ese es el mecanismo exacto del cajón de sastre, y no empieza
con una carpeta llamada `utils/`: **empieza con un nombre que no se puede
falsear.**

El pedido del dueño fue explícito: arquitectura *screaming*, pero con `shared/`
organizada para no terminar en cajón. La segunda mitad es la difícil. La
primera se resuelve con una lista de carpetas; la segunda **no se resuelve con
nombres, se resuelve con reglas**, porque un cajón no se llena de golpe: se
llena de a una decisión razonable por vez.

## Decisión

### 1. La forma

```
apps/tienda/src/
  app/            # el router de Next y NADA más: rutas, layouts, metadata,
                  # sitemap. Ningún componente propio vive acá.
  features/
    landing/      # las cuatro escenas de la home
    navegacion/   # la barra principal y sus secciones
    ...           # catalogo/ ficha/ carrito/ checkout/ edad/ cuando existan
  shared/
    marca/        # la copa, el wordmark — la identidad
    deco/         # el vocabulario: cartucho, filete, grano
    movimiento/   # el motor de parallax: Escena, Plano, su hoja
    ui/           # primitivas sin dominio: tipografía, botón
    tokens/       # colores.ts, tokens.css
  server/         # la frontera de credenciales — la vigila server-only-guard
```

**Una feature es plana hasta que no entra en una pantalla.** `landing/` tiene
nueve archivos sueltos y está bien; el día que tenga veinte, crece subcarpetas.
Es el mismo instrumento que el tope de cinco entradas de `_index.md`: un límite
que obliga a decidir en vez de acumular.

**`features/` no existe vacía.** Las carpetas del catálogo, la ficha y el
carrito **no** se crearon en este commit. Un andamio de carpetas vacías es la
versión en disco de documentar la intención en vez del comportamiento.

### 2. Las cinco reglas de `shared/`

Ésta es la parte que importa. Sin ellas la lista de arriba dura tres semanas.

| # | Regla | Qué modo de falla corta |
|---|---|---|
| **1** | **Nada nace en `shared/`.** Toda pieza nace adentro de la feature que la necesita. Baja a `shared/` cuando una **segunda** feature la importa, y la bajada es un commit propio | Un cajón se llena de cosas puestas *"por las dudas"*. Esta regla hace que "por las dudas" no tenga dónde escribirse |
| **2** | **Ninguna carpeta de `shared/` se llama por su categoría.** Prohibidos: `utils`, `helpers`, `common`, `lib`, `core`, `misc`. Cada carpeta nombra **una cosa** | El nombre es el filtro. `deco` rechaza un formateador de fechas; `utils` lo acepta, y acepta todo lo que venga después |
| **3** | **`shared/` no importa de `features/`, y las features no se importan entre sí** | Es la única direccional y la única que se viola en una línea. El día que `shared/` conoce una feature, dejó de ser compartida: es esa feature con la puerta abierta |
| **4** | **Tope de carpetas en `shared/`: siete.** La octava no se agrega — obliga a decidir cuál absorbe | Convierte *"¿dónde pongo esto?"* de un encogimiento de hombros en una conversación. Hoy hay **cinco** |
| **5** | **`shared/` no sabe de vino.** Nada ahí adentro conoce `Producto`, `Bodega` ni `Orden`; eso vive en la feature o en `packages/contratos` | Es el test más rápido de los cinco. Si una pieza de `shared/` menciona un varietal, no es shared: es la app con otro nombre |

**El test de la regla 2, escrito para poder aplicarlo sin discutir:** si no
podés completar *"esto es el/la ___ de bouquet"* con el nombre de la carpeta,
es un cajón. *"Esto es la **deco** de bouquet"* cierra. *"Esto es la **utils**
de bouquet"* no significa nada, y por eso entra cualquier cosa.

### 3. La regla 3 la mide un hook, no este documento

`scripts/hooks/frontera-features.sh`, HARD, en `PostToolUse`. Bloquea las dos
direcciones y deja pasar los dos casos legítimos que un hook ingenuo rompería:
una feature importándose a sí misma por el alias absoluto, y `app/` componiendo
features distintas —que es su trabajo—. Cinco casos en
`scripts/hooks/probar_hooks.sh`, cada uno con su par.

**Las reglas 1 y 4 NO las mide nadie, y se dice acá para que no se suponga.**
Son de criterio: las aplica una persona leyendo el diff. Fingir que un hook las
cubre sería peor que no tenerlo, porque el verde diría algo falso.

### 4. El orden de los `@import` es cascada, no gusto

`app/globals.css` importa en un orden que **es** la especificidad: tokens →
motor → ui → marca → deco → feature. La feature va última porque es la única
con derecho a pisar a `shared/`. Mover una línea de ahí cambia la página aunque
ningún otro archivo cambie, y por eso el archivo lo dice arriba.

## Por qué

### Por qué screaming y no por capas

Una raíz que dice `components/ estilos/ contenido/` describe **con qué está
hecho** el sitio. Una que dice `landing/ navegacion/ catalogo/` describe **qué
hace**. La diferencia se cobra al borrar: cuando el catálogo cambie de forma,
la versión por capas obliga a tocar cuatro carpetas y a adivinar qué pedazo de
`components/` era suyo. En la versión por features, la feature se borra entera
y lo que quede huérfano en `shared/` lo delata `call-site-guard`.

### Por qué el problema real era `shared/` y no `features/`

Porque `features/` se defiende sola: una carpeta llamada `carrito` rechaza
cualquier cosa que no sea del carrito. `shared/` no tiene esa defensa —su
criterio de admisión es *"se usa en más de un lado"*, que es verdad de casi
todo—. Por eso las cinco reglas son todas sobre `shared/` y ninguna sobre
`features/`.

## Por qué NO las alternativas

| Alternativa | Por qué no |
|---|---|
| Dejar `components/` y sólo agregar subcarpetas | Es el estado que produjo `sistema.css` con tres cosas adentro. Más profundidad en un árbol mal cortado da un árbol mal cortado más profundo |
| Un paquete npm por feature | Tres paquetes TS ya son el techo que [ARQUITECTURA §2](../../../../ARQUITECTURA.md#2-la-forma-del-repo) fijó sin orquestador. Un workspace por feature compra aislamiento y paga con builds y `package.json` que nadie va a mantener |
| `shared/utils/` con subcarpetas adentro | Es el cajón con separadores. El nombre de arriba sigue aceptando todo |
| Confiar en el `tools:` del frontmatter de los agentes | `CLAUDE.md` es explícito: *"las fronteras por ruta las miden los hooks, no el frontmatter"*. En PadelPunilla un widget importó `cloud_firestore` desde el commit inicial pese a que el agente lo prohibía en su texto |

## Presupuesto de lecturas

**Cero lecturas de Firestore, hoy y por construcción.** Es un cambio de
estructura de archivos y una barra de navegación que no consulta nada: la lista
de secciones es una constante en `features/navegacion/secciones.ts`.

**Y el campo no es una formalidad acá, porque hay una trampa cerca.** Una barra
de navegación es el lugar natural donde alguien pone un contador de ítems del
carrito, y un contador así en el layout se ejecuta **en todas las rutas y en
todas las visitas** — que es exactamente la forma de gasto que
[ADR 004](004-frescura-y-lecturas.md) fue a evitar. Cuando el carrito exista,
ese número sale de `localStorage`
([ARQUITECTURA §4.4](../../../../ARQUITECTURA.md#44-el-carrito-no-es-un-documento):
no hay colección `carritos`), así que sigue costando cero. Queda escrito acá
para que la próxima persona no tenga que deducirlo.

Contra la cuota de 50.000/día: **0 %**.

## Consecuencias

- **Dos hooks estaban rotos y se arreglaron en este commit.**
  `widget-size-guard` medía `src/components/*.tsx` y **dejó de medir nada** al
  mudarse la carpeta; `no-hardcoded-colors` exceptuaba `src/tokens/*` y habría
  **bloqueado el propio archivo de tokens**. El primero es el peor de los dos:
  un hook que no aplica no falla, **pasa** — y un verde que no midió nada es
  indistinguible de un verde que midió. El glob nuevo es
  `*/apps/tienda/src/*.tsx`, que cubre las tres carpetas y sobrevive a la
  próxima.
- `.cartucho-deco` se partió en anillo y `--trazado`. La animación de trazado
  usa `animation-timeline: view()`, y un elemento `position: fixed` nunca se
  mueve dentro del scrollport: la barra habría heredado un progreso clavado y
  el marco podía quedar **enmascarado entero, sin un error en consola**.
- [`landing-alternativa.md`](../../design/landing-alternativa.md) apuntaba a
  cinco rutas que ya no existen. Actualizado.
- Un `import` cruzado entre features ahora **bloquea**. Es la consecuencia
  buscada, y va a doler la primera vez que el catálogo quiera una pieza de la
  landing. La salida correcta está escrita en el mensaje del hook.

## Lo que hay que medir antes de creerle a este ADR

| Qué | Por qué | Disparador |
|---|---|---|
| **Que toda ruta esté enlazada o en el sitemap** | [ARQUITECTURA §8](../../../../ARQUITECTURA.md#8-fronteras-y-qué-hook-mide-cada-una) lo exige y **el verificador no existe**: iba a `scripts/ci/` y nunca se escribió. Hoy las cuatro rutas nuevas están enlazadas desde la barra, verificado a mano — que es justo lo que no escala | Cuando aparezca la quinta ruta |
| **El tope de siete carpetas en `shared/`** | Hoy hay cinco. El tope no lo mide nadie, y un tope que nadie mide es una intención | Cuando se proponga la sexta |
