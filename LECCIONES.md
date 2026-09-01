# Lecciones de PadelPunilla, portadas a una tienda digital de vinos

> **Qué es esto.** Destilado de ~37.000 palabras de post-mortems reales de
> PadelPunilla (Flutter + Firebase + Riverpod, marzo–septiembre 2026, en
> producción con clientes reales). No es teoría: cada lección abajo costó una
> corrida de CI, un deploy fallido, un bug en producción o una afirmación falsa.
>
> **Cómo leerlo.** Cada lección tiene tres partes: la **regla**, la **evidencia**
> (qué pasó de verdad) y **en la tienda de vinos** (cómo se traduce). Cuando algo
> es extrapolación mía y no experiencia vivida, lo digo explícitamente con
> ⚠️ **EXTRAPOLADO**.
>
> **Contexto del destino:** tienda de vinos, panel de administración en Flutter,
> vidriera en Flutter o React (a decidir), pagos con Mercado Pago o Ualá.

---

## Índice

1. [La decisión que hay que tomar primero: Flutter o React para la vidriera](#1-la-decisión-que-hay-que-tomar-primero)
2. [Verificación: la familia de lecciones más valiosa](#2-verificación)
3. [Deploy y CI/CD](#3-deploy-y-cicd)
4. [Firestore: costo, índices, reglas](#4-firestore-costo-índices-reglas)
5. [Cloud Functions, estados y pagos](#5-cloud-functions-estados-y-pagos)
6. [El modo de falla más caro: la feature sin puerta](#6-la-feature-sin-puerta)
7. [Presentación, UI y copy](#7-presentación-ui-y-copy)
8. [Argentina: teléfonos, plata y datos reales](#8-argentina)
9. [Trabajar con Claude: lo que hay que saber antes de la primera corrida](#9-trabajar-con-claude)

---

## 1. La decisión que hay que tomar primero

### 1.1 Flutter web es invisible para los buscadores, y ya no hay palanca que tocar

**Regla:** Flutter web dibuja todo dentro de un `<canvas>`. Un rastreador ejecuta
el JavaScript, arranca la app y lo que encuentra son **píxeles**: cero nodos de
texto, cero encabezados, **cero `<a href>`**.

**Evidencia.** Medido en producción el 2026-08-26, antes del prerender:

| URL | Estado | Bytes | Qué era |
|---|---:|---:|---|
| `/` | 200 | 14.714 | el shell |
| `/clubs/padel-nueve` | 200 | 14.715 | **el mismo shell** |
| `/clubs/no-existe-xyz` | 200 | 14.715 | soft 404 |
| `/sitemap.xml` | 200 | 14.715 | el shell, servido como `text/html` |

Un club real y un club inventado se diferenciaban en **cero bytes**. Una búsqueda
`site:padelpunilla.com.ar` no devolvía **ninguna** página.

**Y el consejo que circula por internet ya no se puede seguir.** Todo artículo de
"Flutter SEO" dice *usá el renderer HTML*. **Ese renderer se eliminó en Flutter
3.29**, junto con el flag `--web-renderer`. Quedan CanvasKit y skwasm, los dos
sobre canvas. `--wasm` mejora el rendimiento y **no cambia nada** de
indexabilidad. No hay flag. No hay configuración. No hay workaround del lado de
Flutter.

**Lo que falta más que el texto son los enlaces.** Sin `href` no hay grafo de
rastreo: Google no tiene por dónde descubrir que `/clubs/padel-nueve` existe. No
llega ni a la página que no puede leer.

**La solución costó un subsistema entero.** `scripts/prerender/` genera HTML real
en tiempo de build, un archivo por página, con `<title>`, `meta description`,
Open Graph, `canonical`, JSON-LD y enlaces cruzados. Funciona — pero mirá la
tabla de la decisión que se tomó:

| | Generador en build (elegido) | Cloud Function |
|---|---|---|
| Costo por visita | cero | invocación + arranque en frío |
| Frescura | hasta el próximo deploy | siempre |
| 404 real en slug inexistente | **no puede** | sí |

Se eligió el generador en build **porque el catálogo eran 3 clubes y 9 URLs**. La
nota del vault dice literalmente cuándo deja de servir: *"se migra a Cloud
Function cuando pase lo primero de: el catálogo deje de caber cómodamente en un
deploy, o los clubes empiecen a editar datos que tienen que verse el mismo día."*

**En la tienda de vinos.** Las dos condiciones de migración **se cumplen el día
uno**:

- Un catálogo de vinos no son 9 URLs. Son N productos × bodegas × varietales ×
  regiones × rangos de precio. El sitemap de una vinoteca chica ya son cientos de
  URLs; el de una mediana, miles.
- **El precio y el stock cambian el mismo día.** Prerenderizar en build significa
  que la página del producto miente hasta el próximo deploy. En una cancha de
  pádel eso es tolerable (el club cambia de dirección una vez por año); en una
  tienda es el dato que decide la compra.

Y hay un tercero que PadelPunilla no tuvo: **el `<meta>` de producto y el JSON-LD
`Product`/`Offer` con `price` y `availability` son lo que arma el resultado
enriquecido de Google Shopping.** Un precio prerenderizado viejo no es sólo una
página desactualizada: es una discrepancia entre el structured data y la página,
que Google penaliza.

> **Recomendación, y es la única de este documento que doy sin que me la pidan:**
> **vidriera en React (Next.js con SSR/ISR), panel de administración en Flutter.**
>
> El costo de esa separación es real —dos front-ends, dos build pipelines— pero
> es un costo **conocido y acotado**. El costo de la alternativa es un subsistema
> de prerender que hay que reescribir como Cloud Function, mantener sincronizado
> con el catálogo, y que igual sirve markup de segunda categoría. PadelPunilla
> pudo pagarlo porque su SEO es un extra: **la gente reserva la cancha que ya
> conoce**. Una tienda de vinos que no aparece en Google no tiene negocio.
>
> **Si igual se hace todo en Flutter**, aceptalo como decisión de producto tomada
> con los ojos abiertos y presupuestá el prerender como Cloud Function desde el
> día uno, no como una tarea de "después". Ver §1.2 para las trampas que ya están
> resueltas y no hay que redescubrir.

**El panel de admin en Flutter, en cambio, es la elección correcta y no tiene
peros:** nadie googlea un panel de administración, y ahí Flutter da lo que
promete (una base de código para Android, iOS y web).

### 1.2 Si igual va Flutter web: las trampas del prerender ya están pagadas

Estas costaron una iteración cada una. Guardalas para no redescubrirlas.

- **El mismo HTML para bots y para personas.** Nada de detección de user-agent:
  servir contenido distinto según quién pregunta es riesgo de *cloaking*, y
  Google desaconsejó el *dynamic rendering* como solución de largo plazo.
- **El contenido va visible, no en `display:none`.** Un buscador descuenta el
  texto oculto. En PadelPunilla el `<div id="pp-seo">` se renderiza en flujo
  normal y queda **tapado** por el splash (`position: fixed`, z-index máximo).
  Los dos se retiran juntos en el evento `flutter-first-frame`.
- **`flutter-first-frame` es el único momento honesto para sacar el splash** — se
  emite cuando Flutter ya dibujó, no cuando terminó de bajar. **Sin timeout de
  rescate a propósito:** si Flutter nunca arranca, quedarse en la marca es mejor
  que volver al blanco, que es el estado que se lee como roto.
- **Escribir `{ruta}/index.html` hace que Hosting redirija 301 desde la forma sin
  barra.** Los rastreadores lo siguen, pero deja el `canonical` apuntando a una
  URL que redirige de vuelta. Se corrige con `"trailingSlash": false` en el bloque
  `hosting` de `firebase.json`.
- **`main.dart.js` NO se cachea largo.** No lleva hash en el nombre, así que un
  cache anual deja a la gente clavada en un bundle viejo. `canvaskit/**` sí, que
  va versionado por la ruta.
- **El escape no es opcional y tiene tres sumideros distintos.** Nombre,
  descripción y dirección los escribe el dueño del negocio: atributo HTML, cuerpo
  del documento, y `</script>` dentro del JSON-LD. Cada uno necesita su escape.
  ⚠️ En una tienda esto es peor: la descripción del vino la carga el proveedor.
- **`og:image:width` / `og:image:height` no son opcionales.** Sin ellas el
  rastreador de Facebook tiene que bajar la imagen entera antes de decidir el
  tamaño de la tarjeta, y en el **primer** scrapeo —justo cuando alguien
  comparte— se ve sin foto. Y si no podés medir la imagen, **omití las
  etiquetas**: declarar un tamaño equivocado es peor que no declarar ninguno.
- **WhatsApp no ejecuta JavaScript** para armar la vista previa: lee el HTML
  crudo. Es el efecto más visible del prerender y el que un usuario nota. En una
  tienda donde el canal de venta es WhatsApp, esto no es SEO — es conversión.
- **Un formato de hora inválido tira el bloque de schema.org ENTERO.** `24:00` y
  `7:30` hacían que Google descartara `openingHoursSpecification` completo, no
  ese campo. Normalizá, y lo que no puedas normalizar, **reportalo**.
- **Todo reemplazo de plantilla tiene que explotar si el ancla no aparece
  exactamente una vez.** El modo de falla natural de un prerender es quedarse
  callado y publicar la página sin título — y eso no se nota hasta que alguien
  mira el resultado de búsqueda tres semanas después.
- **La política de bots de IA no vive en `robots.txt`.** `robots.txt` es una
  recomendación; el bloqueo real lo aplica Cloudflare en el borde con un 403.
  Decisión razonable: abrir los que recuperan para responder (`OAI-SearchBot`,
  `ChatGPT-User`, `Claude-SearchBot`, `PerplexityBot`) y cerrar los de
  entrenamiento (`GPTBot`, `ClaudeBot`, `CCBot`, `Bytespider`). Ojo:
  `Google-Extended` **no afecta el ranking** — bloquearlo saca el sitio de las
  respuestas generadas, no de la búsqueda.

### 1.3 El arranque en frío en web: mirá qué hay en el `<head>` antes de culpar al framework

**Regla:** antes de agregar algo que tiene que verse temprano, mirá qué hay
arriba en el `<head>` bloqueándolo.

**Evidencia.** Reporte: *"en web la carga en frío da unos segundos en blanco"*.
La causa parecía obvia (Flutter tarda en bajar 5,1 MB de `main.dart.js`) y era
**la mitad del problema**. La otra mitad: el `<link>` y el `<script>` de
cropperjs estaban **sin `defer` ni carga diferida**. Un `<script>` común en el
`<head>` **frena el parseo del `<body>`**, y un `<link rel=stylesheet>` **frena el
primer pintado**. La página no pintaba un píxel hasta que respondiera un CDN de
terceros — y cualquier splash que hubiéramos agregado habría quedado detrás de la
misma barrera.

Dos detalles que costaron aparte:

- **El color del splash va `surface`, no el color de marca.** La app corre en
  `ThemeMode.system`, así que un splash con el teal de marca cambiaba un destello
  blanco por uno teal. Y hace falta `<meta name="color-scheme" content="light
  dark">`: sin eso el canvas por defecto del navegador es **blanco incluso en
  modo oscuro**, antes de que se aplique el `<style>`.
- **`var()` dentro de un atributo de presentación SVG (`fill="var(--x)"`) no está
  soportado de forma pareja.** Los colores van por regla CSS.

**En la tienda de vinos.** Todo script de terceros que una tienda acumula
—analytics, píxel de Meta, chat de soporte, widget de reseñas, el SDK de Mercado
Pago— es un candidato a bloquear el primer pintado. Auditá el `<head>` como parte
del checklist de release, no cuando alguien se queje.

---

## 2. Verificación

Esta es la familia de lecciones más valiosa del proyecto y la que viaja **a
cualquier stack**. El patrón subyacente: *un verificador que no puede fallar
ruidosamente confirma cualquier hipótesis.*

### 2.1 Un job verde no prueba que compiló

**Evidencia.** Los jobs de build de PadelPunilla, si falta su secret, avisan, se
saltean y reportan `success`. **Lo que prueba que compiló es el artifact**, no el
color.

Y tiene una segunda ropa: **un run de `Deploy` en `success` no prueba que se
desplegó lo que creías.** Una corrida con `objetivo=functions` cierra verde con
`Build web: skipped` y `Hosting → PRODUCCIÓN: skipped`.

```bash
# Lo único que vale:
gh run view <id> --json conclusion,jobs \
  --jq '"run: \(.conclusion)", (.jobs[] | "  \(.name): \(.conclusion // "-")")'
```

### 2.2 `gh run watch --exit-status` devuelve 0 cuando la corrida fue CANCELADA

**Evidencia.** Se reportó "CI verde" sobre una corrida cuyo `Análisis estático`
decía `cancelled`. **El exit code de `gh run watch` no es el veredicto.**

Peor: un `workflow_dispatch` **cancela** la corrida del push, porque el grupo de
concurrencia es `ci-${{ github.ref }}` con `cancel-in-progress: true` **sin
discriminar por evento**. Disparar los tests a mano mató el análisis automático,
y `gh run watch` devolvió 0 igual.

### 2.3 `gh workflow run` corre contra el HEAD **pusheado**, no contra tu working tree

**Evidencia.** Costó una corrida entera. Disparar CI con cambios sin commitear
**no verifica esos cambios**: el runner hace `checkout` del HEAD que hay en
GitHub. La corrida sale verde o roja sobre código viejo y parece que validó lo
tuyo. Peor todavía si el remoto está atrasado.

**Orden correcto:** commitear → pushear → recién ahí disparar.

### 2.4 Verificá el recurso real, con control positivo

**Regla:** una verificación necesita **un control positivo** — algo que sabés que
tiene que aparecer. Sin él, una lista vacía por error de lectura "confirma"
cualquier cosa.

**Evidencia.** Para probar que una Cloud Function **no** se había desplegado:
`firebase functions:list` sin `borrarCuenta` **pero con `cambiarSlugClub`**. El
segundo es el control positivo: prueba que el comando funcionó y que la ausencia
del primero es real.

**Y el control negativo también.** Pedir una ruta nueva a Hosting devuelve
**200**… pero `/rutaQueNoExisteJamas` **también** — el rewrite del SPA manda todo
a `index.html`. **Un 200 no prueba que la ruta exista.** Hace falta pedir una ruta
inventada al lado para darse cuenta.

### 2.5 El canario tiene que ser un PAR discriminante, y tiene que ser nuevo

**Regla:** para probar que un cambio salió a producción, buscá en el bundle
servido un string que **no existía antes** y que **desapareció otro**.

**Evidencia.** El mejor ejemplo del repo: al cambiar el rótulo "Pendiente" por
"Confirmando…", la verificación fue que `Confirmando` pasó de **0 a 1** y
`Pendiente` de **11 a 10** — uno menos, no once menos. Eso prueba que fue un
**reemplazo** y no un agregado, y que ningún otro "Pendiente" de la app se llevó
por delante. Dos controles que no debían moverse (`Esperando club`, `Buscando
rival`) siguieron en 1.

**Tres trampas del canario:**

1. **Un string que ya existía NO es canario.** "Ponerle un nombre" parecía el
   canario obvio de una ronda y **ya estaba en el release anterior**: verificar
   con eso habría dado verde sin probar nada. Chequeá que la cadena sea nueva
   **antes** de usarla.
2. **dart2js escapa los acentos.** `'Tocá para cambiarle el nombre'` en el bundle
   está como `"Toc\xe1 para cambiarle el nombre"`. Grepeá el fragmento **sin
   acentos**, o elegí canarios ASCII a propósito.
3. **Un string interpolado se parte en fragmentos**, así que la frase entera nunca
   aparece junta.

### 2.6 Verificá por hash de contenido, no por HTTP 200

**Evidencia.** Un release quedó atascado en producción (2026-06-23) y el
diagnóstico correcto salió de **medir producción**, no de leer notas. Comparar el
**hash del contenido** de live contra el canal, no pedir un `200` — un 200 lo
devuelve igual la versión vieja.

**Dos trampas de la infraestructura de por medio:**

- El dominio propio va por **Cloudflare** (caché + ETag débil): pedir con
  `?cb=<guid>` para saltearlo.
- **Comparar los dos hosts por tamaño da un falso negativo garantizado**: el
  dominio propio sirve **1601 bytes más** de `index.html` que `.web.app`, porque
  Cloudflare inyecta su `beacon.min.js` después del bootstrap.

**Y el caso invertido, que es igual de válido:** en el cambio del splash el hash
salió **idéntico** al release anterior, **y eso era la prueba** — un cambio que no
toca `lib/` no debe mover el bundle.

### 2.7 Un índice `READY` puede no servir: verificá corriendo la query

Está en §4.2, pero es de esta familia. **Chequear que algo existe no verifica
nada.**

### 2.8 La aritmética distingue lo que el color no

**Regla:** *"la suite pasó"* no distingue entre un test verde y **un archivo que
ni se ejecutó**.

**Evidencia.** El control correcto es la resta: la corrida anterior cerró en 1998
tests y esta en 2003, que son **exactamente los 5 tests que se agregaron**. Otra
ronda: 1929 − 1909 = 20, exactamente los 20 agregados en dos rondas (8 de
dominio, 5 del tile, 4 de la lista, 3 de la personal).

**El número del vault no sirve de baseline** — decía 1929 y quedó viejo hacía 6
versiones. Hay que comparar contra la **última corrida real**.

Variante barata: contar cuántas veces aparece el nombre de la suite nueva en el
log. `flutter_test` imprime cada nombre al empezar y al terminar, así que 5 tests
nuevos son 10 apariciones.

### 2.9 Auditá la realidad, no el documento que dice cómo debería estar

**Regla:** ante cualquier pregunta de *"¿esto está funcionando / desplegado?"*,
auditá el proyecto real antes de responder.

**Evidencia.** Las secciones "Pendiente de deploy" del vault **mienten seguido**:
registran lo que faltaba cuando se escribió la nota, y cuando el trabajo se hace
en una sesión posterior nadie vuelve a tacharlas. El 2026-08-03 la nota de
suscripciones daba por pendientes tres cosas que estaban hechas desde el
2026-06-29 — y el bloqueante **real** no estaba anotado en ningún lado.

Comandos que funcionan (Firebase/GCP, con `gcloud` autenticado):

```bash
firebase functions:list                                    # funciones desplegadas
gcloud run services describe <nombre-minusculas> --region us-central1 \
  --format="value(spec.template.spec.containers[0].env)"   # env de la revisión viva
gcloud firestore indexes composite list --format="value(state,fields)"
gcloud scheduler jobs list --location=us-central1 --format="value(name,schedule,state)"
gcloud logging read 'resource.labels.service_name="<nombre>"' \
  --limit 25 --freshness=45m --format="value(timestamp,severity,textPayload)"
```

---

## 3. Deploy y CI/CD

### 3.1 Commitear no es entregar

**Regla:** un cambio commiteado no es un cambio entregado. Mientras no corra el
workflow de deploy, producción sigue sirviendo la versión anterior — por muchos
commits verdes que haya en `master`.

**Evidencia, y es la lección de proceso más importante del repo.** Los workflows
documentados en `CLAUDE.md` terminaban en "Commit", así que desplegar dependía de
que alguien se acordara de pedirlo. **Las secciones "pendiente de deploy" que se
acumulaban en el vault no eran un descuido: eran la consecuencia estructural de
eso.** Si el último paso escrito es "commit", el sistema produce commits sin
deploys, de forma fiable.

**En la tienda de vinos:** el workflow escrito tiene que terminar en *deploy +
verificación*, no en *commit*. Un proceso produce exactamente lo que su último
paso dice.

### 3.2 El orden reglas → functions → hosting no es negociable, y hay que sostenerlo ENTRE corridas

**Regla:** las reglas primero porque son el control de acceso (si el código nuevo
escribe un campo que las reglas viejas rechazan, el deploy queda a medias), y el
front último porque expone la UI (si sale antes que su backend, el usuario ve una
pantalla que llama a algo que no existe).

**Evidencia — el corolario grave.** El deploy de hosting **reconstruye desde el
HEAD pusheado**, así que publica **toda la UI mergeada en `master`**, no sólo la
del cambio que motivó el release. El aislamiento por objetivo protege reglas y
functions; **a la UI no la protege nadie**.

Pasó de verdad: un release de UI salió con reglas y functions en `skipped`, y en
el mismo bundle viajó de polizón la UI de "borrar cuenta" mergeada días antes.
Resultado: **el botón "Borrar mi cuenta" en producción llamando a una Cloud
Function que no existía** — y encima en el flujo que Google Play exige.

**Antes de un deploy de front, preguntate qué MÁS se mergeó desde el último**, no
sólo qué vas a publicar a propósito.

**En la tienda de vinos** esto es directamente plata: un botón "Pagar" que llegue
a producción antes que su webhook es una venta que se cobra y no se registra, o
una que no se cobra y se despacha.

### 3.3 Promové, no republiques

**Regla:** el deploy a producción hace `hosting:clone` del canal de preview a
live — publica **exactamente los bytes que ya verificaste**, sin recompilar.

**Evidencia.** `firebase deploy --only hosting` está prohibido en el repo: fue lo
que dejó un release atascado el 2026-06-23.

**Pero ojo con la sutileza:** el workflow hace *build → publica al canal →
verifica → clona a live*, así que live queda idéntico al canal **de esa misma
corrida**, no al preview que miraste antes. Medido: el preview revisado a ojo
daba 17.595 bytes; después de promover, live daba 17.459. Si entre mirar el
preview y promover hubo commits, **lo que revisaste no es lo que quedó
publicado.** Para que "verifiqué y promoví" sea cierto, no pushear nada entre los
dos pasos.

### 3.4 Un `environment:` de GitHub sin reviewers no gatea nada

**Evidencia.** `CLAUDE.md` y los comentarios del workflow decían que los deploys a
live *"pasan por el environment `production`, donde podés"* frenarlos. **Es
falso.** El job declaraba `environment: name: production`, pero
`gh api repos/<owner>/<repo>/environments` devolvía `protection_rules: []`. Un
environment sin reviewers configurados **sólo agrupa secrets y registra el
despliegue**. La corrida pasó de canal a producción sin detenerse.

**Lo peligroso no es la falta de la red: es creer que hay una red que no está.**
Alguien que dispara el deploy "para ver el preview y después decidir" ya publicó.

Son dos caminos y hay que elegir uno: **configurar Required reviewers de verdad**,
o **sacar la palabra "aprobación" de la documentación**.

### 3.5 Verificá un deploy de functions por nombre, y la lista no son las que editaste

**Regla:** la lista de funciones a chequear no es "las que edité", es **toda
función que enlace el helper que toqué**.

**Evidencia.** Un cambio parecía ser una callable nueva más tres editadas. Pero
también arreglaba un helper que comparten los **tres crons**. Verificar sólo la
callable nueva habría dado verde con el bug **vivo en producción, en el camino que
más corre**.

```bash
# Armá la lista bien: partí del diff, y por cada archivo que NO sea handler,
# grepeá quién lo importa — transitivamente.
git diff --name-only HEAD~1 -- functions/src/

gh run view <id> --log > deploy.log
grep "functions\[<nombre>(" deploy.log      # "Successful create/update operation."
grep -c "Successful \(create\|update\) operation" deploy.log   # segunda señal barata
```

**Dos trampas al leer ese log:**

- `grep -i error` matchea las **plantillas** `::error::` de los `if` que **no** se
  dispararon, y un `DeprecationWarning` de Node. Hay que leerlas, no contarlas.
- Un `⚠ failed to update function` seguido de reintentos que cierran en
  `Successful update operation` **no es una falla**. Grepear `failed` sin mirar si
  después hubo éxito da un falso rojo. (Pasó con dos 429 de *"Quota exceeded for
  quota metric 'Per project mutation requests'"*.)
- **Cero `create` puede ser la evidencia correcta.** Si tocaste un helper
  compartido y no exportaste nada nuevo, un `create` que aparezca significa que
  algo se exportó de más.

### 3.6 Disciplina de cuota: elegí el alcance más chico que conteste la pregunta

**Evidencia.** La capa gratuita son 2000 min/mes y el repo es privado. Antes de la
disciplina, cada push costaba ~21 min (~95 pushes/mes); después, ~4 min (~500/mes).

Las reglas, en orden de importancia:

1. **No dispares builds** salvo pedido explícito de binario o deploy. Son la mitad
   del costo y casi nunca son lo que se está verificando. **iOS cuesta ×10**
   (runner macOS).
2. **No re-dispares para verificar una sola cosa.** Si ya hay una corrida, leela.
   Disparar de nuevo cuesta lo mismo que la primera vez.
3. **Elegí el alcance más chico.** Si tocaste sólo el backend, el alcance rápido
   alcanza.
4. Cambios sólo de documentación **no disparan nada** (`paths-ignore`).
5. Un push ya dispara el alcance rápido solo. **No encimes otra corrida.**

**⚠️ El alcance rápido saltea los tests, y eso casi cuesta un deploy.** En un
cambio de **lógica pura** (normalizar un teléfono a E.164), toda la evidencia de
que funcionaba vivía en 19 tests nuevos que el alcance rápido **no ejecuta**.
*"Análisis estático: success"* sólo dice que **compila**.

> **Regla: si el cambio es lógica y no UI, dispará los tests a mano antes de tocar
> producción**, aunque el push ya haya dejado un análisis verde.

### 3.7 El baseline de tests rojos: por nombre, nunca por cantidad

**Regla:** un gate siempre rojo deja de mirarse. Si hay fallos tolerados, ponelos
en un archivo de baseline y **fallá sólo ante fallos nuevos**.

**Evidencia.** `scripts/ci/check_test_baseline.mjs` compara contra
`.github/known_test_failures.txt` **por test, no por cantidad**, así que un fallo
nuevo en un archivo ya listado rompe el build igual. Dos reglas que no se
negocian: **un error de carga/compilación nunca se tolera** aunque esté listado, y
las entradas obsoletas se denuncian (el CI avisa cuando una dejó de fallar).

**Ningún shard emite veredicto.** Los 3 shards terminan verdes con rojos adentro y
suben su reporte; el job de veredicto exige **los 3** — porque sin esa cuenta un
shard muerto en silencio pasa por suite verde.

**Trampa de lectura:** un `-N` en el log de un shard **no contradice** un job en
`success`; el reporter acumula el contador de fallos en cada línea posterior a la
primera. Para ver los fallos reales, filtrar por `[E]`, nunca por `-\d`.

**Y la lección de fondo: un CI nuevo encuentra bugs VIEJOS, no nuevos.** La
primera corrida buena destapó un test que fallaba desde hacía meses, invisible
porque nadie corría la suite. Otro caso: dos tests que "aparecían rotos" por un
cambio de routing eran **un solo bug** — un `RenderFlex overflowed by 24 pixels`
en un archivo que no se tocaba desde hacía dos meses, causado por un cambio de
métricas de texto entre versiones de Flutter.

> **Dos tests que fallan juntos no comparten causa por defecto** — pero cuando la
> comparten, arreglar uno arregla los dos. Leé la excepción, no el nombre del test.

### 3.8 Trampas sueltas de CI que cuestan una corrida cada una

- **`--fatal-infos` viene ACTIVADO por defecto** en `flutter analyze`. Con 1105
  archivos, un `avoid_print` olvidado frena un deploy. El CI corre
  `--no-fatal-infos`; errores y warnings sí bloquean.
- **Java 21 para el emulador de Firebase, 17 para Android.** No son el mismo
  número y el mensaje de error no lo aclara.
- **`storeFile` de `key.properties` es relativo a `android/app/`, no a
  `android/`.** Bug latente que **sólo podía aparecer la primera vez que el secret
  existiera**. Y lo peligroso es **dónde** aparece: el paso "preparar keystore" da
  **verde** (sólo decodifica base64 y escribe un archivo, dos cosas que salen bien
  con una ruta equivocada); el error sale **7 minutos después**, adentro de
  Gradle, con otro nombre.
- **Verificar un binario firmado son DOS herramientas distintas.**
  `keytool -printcert -jarfile` funciona sobre un AAB (firma v1 en `META-INF`)
  pero sobre un APK moderno **devuelve vacío** — parece que no está firmado y es
  mentira. Para APK hace falta `apksigner verify --print-certs`.
- **Descartá credenciales antes de gastar una corrida.** `keytool -list` sólo abre
  la caja; **no prueba que la contraseña de la clave sirva**. Lo que la prueba es
  una operación que use la clave privada: `keytool -certreq -alias <a> -keystore
  <k> -storepass "$SP" -keypass "$KP" > /dev/null` (exit 0 = la password sirve).
- **El repo no siempre está quieto.** Otra sesión puede commitear en paralelo y su
  push **cancela tu corrida**. Antes de dar por bueno un estado, revalidá
  `git log --oneline -1` local **y** el del remoto.

---

## 4. Firestore: costo, índices, reglas

### 4.1 Batchear NO abarata

**Regla:** Firestore factura **por documento devuelto**, no por query. 84 uids son
84 lecturas vengan en 84 `get` o en 3 `whereIn`. El lote compra *round trips* y
que los datos aparezcan juntos, nada más. **No lo vendas como ahorro.**

**Las 9 reglas de costo, tal cual salieron:**

1. Batchear no abarata (arriba).
2. **Buscá primero el dato que ya está en memoria.** En una ronda, media solución
   costaba cero: el valor ya venía como argumento de la función y no se usaba.
3. **No pidas lo que no mostrás.** Filtrá *antes* de la query, con la misma
   precedencia que usa la UI — y un test que las mantenga sincronizadas.
4. **Lo caro suele ser `autoDispose`, no el volumen.** Descartar providers hace
   releer lo mismo en cada navegación. Una caché de sesión sin `autoDispose`
   converge a ~0 cuando el dato se repite.
5. **Desnormalizar es la única vía a cero lecturas reales**, pero cuesta todos los
   caminos de escritura + backfill + fan-out + deploy. Evalualo explícitamente y
   decí por qué sí o por qué no.
6. **En un cron, el multiplicador es la cadencia, no el volumen.** Un `.get()` de
   más adentro del loop de un cron de 30 min son **48 lecturas/día por ítem** sin
   que nadie abra la app. Contá: `lecturas por ítem × ítems × corridas/día`.
7. **Encuadralo contra la cuota gratuita de 50k/día, no contra dólares.** A escala
   MVP los dólares no asustan y la cuota sí.
8. **Si la query cara codifica una garantía, no se achica — se separa por
   cadencia.** Dos pasadas: caliente (30 min, ventana corta) y fría (24 h,
   horizonte completo). Se cambia la **latencia** de la red de seguridad, no su
   cobertura.
9. **Ojo con el verde por vacío al acotar una query.** Los tests de un cron tenían
   el fixture **afuera** de la ventana nueva: pasaban sin ejercitar nada
   ("sigue pendiente" se cumple si el cron ni lo mira). **Un test que pasa por
   omisión es peor que un rojo.**

**En la tienda de vinos.** El catálogo es el caso peor: una grilla de productos
con filtros relee en cada navegación. Empezá por §4.1.4 (`autoDispose`) antes que
por cualquier otra optimización, y presupuestá las lecturas de la **home** y del
**listado filtrado** como número explícito en el ADR de la feature.

### 4.2 Un índice `READY` puede no servir

**Regla:** chequear que un índice existe no verifica nada. La verificación válida
es **correr la query**.

**Evidencia.** Una pantalla tiraba `failed-precondition` y se dio por resuelto
verificando con `gcloud` que el índice existía y estaba `READY`. Las dos cosas
eran ciertas e **irrelevantes**: estaba declarado `[clubId, canchaId, fecha,
estado]` con `fecha` filtrado por **rango**, y en un índice compuesto los campos
de igualdad van *todos* antes que el de rango. Se construyó perfecto y no servía
para ninguna query. Al preguntar bien aparecieron **7 índices faltantes, no 1** —
incluido un cron tirando `FAILED_PRECONDITION` cada 30 minutos sin que nadie lo
notara.

**Las 4 reglas de forma, todas verificadas empíricamente:**

1. Igualdades primero, después el rango, al final los `orderBy`.
2. `in` / `whereIn` cuenta como **igualdad**, no como rango.
3. **No hay prefix matching**: `[a, b, c]` no sirve para `a== b[rango]`.
4. `collectionGroup()` necesita índice propio **aunque filtre un solo campo** —
   los de campo único que Firestore crea solo son `COLLECTION`; hay que
   declararlos en `fieldOverrides`.

**Trampa aparte:** declarar un `fieldOverride` **reemplaza** los índices por
defecto del campo, no los agrega. Si listás sólo `COLLECTION_GROUP`, rompés en
silencio cualquier query que filtre ese campo dentro de una subcolección.

**Y la otra mitad: arreglar un índice puede ARMAR un bug dormido.** Ese
`FAILED_PRECONDITION` cada 30 minutos estaba **tapando un P0** en el cuerpo del
cron, que nunca se había ejecutado. Al agregar el `fieldOverride` el cron empezó a
correr — y a cancelar toda ocurrencia sana.

> **Cuando un cron o una query lleva tiempo muerto por un índice, leé el código
> que va a correr por primera vez ANTES de desbloquearlo.** Un componente que
> nunca ejecutó no tiene evidencia de funcionar, aunque sus tests estén verdes.

**Un índice declarado y no consultado es costo de ESCRITURA.** En una ronda había
un índice `COLLECTION_GROUP` declarado que ninguna query leía: se escribía en cada
documento sirviendo a nadie. **Antes de proponer un índice nuevo, grepeá si el
campo aparece en algún `.where()`** — puede que el arreglo sea gratis.

**En la tienda de vinos** esto muerde el día uno: un listado de catálogo es
`bodega == X && varietal == Y && precio >= A && precio <= B` con
`orderBy('precio')`. Es exactamente la forma que rompe la regla 1 si la armás por
intuición. Escribí un `auditar_indices.js` que **corra** cada forma de query del
catálogo y salga con exit 1 si falta alguna — antes de tener el catálogo cargado.

### 4.3 Un `where` no devuelve los documentos donde el campo no existe

**Evidencia.** El flag `publica` arranca en `false` en el modelo, pero los
documentos viejos no tenían el campo. Un `where('publica','==',true)` **escondía
clubes viejos en silencio**. El prerender terminó filtrando **en memoria** para
poder reportar el motivo de cada descarte.

**En la tienda de vinos:** cada campo booleano que agregues después del primer
producto (`destacado`, `enOferta`, `agotado`) tiene esta trampa. O backfill, o
filtro en memoria, o `!=` invertido — pero decidilo, no lo descubras.

### 4.4 Nunca dejes que un string externo entre en una ruta de Storage

**Evidencia — un bug que vivió desde el commit inicial sin un solo reporte.** La
edición de foto de perfil no funcionaba **en web**. Causa: **en web `XFile.path`
NO es una ruta de archivo, es un blob URL** (`blob:https://host/<uuid>`). El
código sacaba la extensión con `path.split('.').last` — en móvil eso da `jpg`, en
web da **`app/<uuid>`, con una barra adentro** (el punto que encuentra es el de
`web.app`).

**La barra convierte el archivo en subcarpeta y la regla deja de aplicar.** El
objeto se iba a `.../profile/<uuid>.app/<uuid>`: **dos segmentos** donde
`storage.rules` declara uno solo. En reglas de Firebase `{x}` es **un** segmento y
`{x=**}` son varios — no matcheaba nada, caía en el `deny-all` final y Storage
devolvía `unauthorized`.

> **Regla: lista cerrada de extensiones derivada del `mimeType`, nunca derivación
> del path.**

**Fallaba callado, y por eso vivió tanto:** el bloque era `try/finally` **sin
`catch`**; la excepción se perdía como error async no manejado. Spinner, vuelta al
botón, nada. **Un fallo invisible no genera reportes, genera la sensación de que
"no anda".**

**Lo que confirmó el diagnóstico fue un contraste, no leer el código propio:** las
fotos de club **sí** funcionaban en web porque su servicio **hardcodea `.jpg`** y
nunca toca `path`. **Cuando algo falla en una feature y anda en otra parecida,
comparar las dos implementaciones ubica la causa más rápido que leer la que
falla.**

**Tres defectos de la misma familia, encontrados de paso:**

- **El `contentType` mentía.** Se mandaba siempre `image/jpeg`, pero el resizer
  web hace `canvas.toBlob(…, originalFile.mimeType)` — **conserva el tipo de
  origen**, y `imageQuality` *sólo* aplica a jpeg/webp. Un PNG se guardaba
  etiquetado JPEG. **Leé el código del plugin, no supongas que `imageQuality`
  reencodea.**
- **Había DOS campos `photoUrl`** — uno anidado que leía un solo consumidor y uno
  en la raíz que leía casi toda la app. Aun con la subida arreglada, la foto nueva
  no se habría visto en ningún otro lado, **para siempre**. Meses después, al
  revocar una foto moderada, el mismo par causó URLs colgadas.
- **`arrayUnion`/`arrayRemove` en vez de reescribir el array entero.** El sheet
  viejo mandaba el array completo: dos personas editando a la vez hacían que **el
  segundo en guardar borrara lo que subió el primero**.

**En la tienda de vinos:** las fotos de producto son el corazón de la tienda y las
carga gente no técnica desde el navegador. Las cuatro trampas de arriba aplican
tal cual.

---

## 5. Cloud Functions, estados y pagos

### 5.1 Un documento puede NACER en el estado final

**Regla, y es la más transferible de esta sección:** cualquier trigger que espere
la transición `A → B` **nunca se dispara** para los documentos que nacen en `B`. Y
no falla: simplemente **no corre**.

**Evidencia.** Una Reserva podía llegar a `confirmada` por **5 rutas distintas**,
y **dos de ellas la creaban ya confirmada**. Un agregado social construido sobre
`onDocumentUpdated` habría ignorado justo el caso más fuerte —el turno fijo, o sea
el grupo con el que jugás **todas las semanas**— y el ranking **habría parecido
funcionar**.

La condición correcta es **`después === "B" && antes !== "B"` sobre
`onDocumentWritten`**, no `onDocumentUpdated`. Vive en un helper compartido porque
es un hecho del **ciclo de vida de la entidad**, no de un flujo.

**La consecuencia que salió del mismo análisis:** cuando el club reservaba a
nombre de un jugador, **el jugador no se enteraba**. La cadena: la función escribe
la Reserva ya `confirmada` y no tiene una línea de notificación; el trigger de
aprobación es `onDocumentCreated` **con `estado === "pendiente"`** → se saltea; y
el trigger de notificación es **`onDocumentUpdated`**, que ni siquiera se dispara
ante un create.

> **Antes de ensanchar un trigger, buscá quién MÁS emite por ese hecho.** Al pasar
> el trigger a `onDocumentWritten`, la mitad importante del fix fue **excluir** el
> caso que ya mandaba su propio aviso — con fingerprint distinto, así que la
> deduplicación no lo habría frenado y el grupo habría recibido **dos avisos por
> semana con dos textos**.

**En la tienda de vinos**, traducción directa: una **Orden** puede nacer `pagada`
(pago en un clic, link de pago pre-aprobado, carga manual desde el panel). Todo
trigger de "se pagó una orden" —descontar stock, mandar el mail, avisar al
depósito, facturar— tiene que ser `onDocumentWritten` con la condición
`entróEnPagada`, en un helper compartido. Escribilo el día que crees la colección,
no cuando aparezca la segunda ruta.

### 5.2 Los triggers son at-least-once: idempotencia por marcador, en la misma transacción

**Evidencia.** Un agregado que hacía 12 `increment` los protegió con un **marcador
de idempotencia en la MISMA transacción** que los increments. Sin eso, un
`increment` repetido **infla en silencio** — el peor modo de falla, porque el dato
queda mal sin error.

**En la tienda de vinos: esto es EL contrato del webhook de pagos.** ⚠️
**EXTRAPOLADO** — PadelPunilla no integró pagos (la decisión se difirió
explícitamente: *"MVP recomendado: pagos on-site, la app es la agenda"*). Pero el
mecanismo es idéntico y lo que aprendieron sobre triggers aplica sin cambios:

- Mercado Pago reintenta los webhooks. **Asumí entrega múltiple y fuera de
  orden**, no "probablemente una vez".
- El marcador va en la misma transacción que el efecto (descontar stock, marcar
  pagada, generar el número de orden). Si el efecto y el marcador no son atómicos,
  la ventana entre los dos es exactamente donde ocurre el doble descuento.
- **La fuente de verdad del pago es la consulta a la API del proveedor con el
  `payment_id`, no el cuerpo del webhook.** El webhook es una notificación de que
  algo pasó, no la prueba de qué pasó.
- Verificá la firma del webhook. Un endpoint público que descuenta stock a pedido
  es un vector de abuso, no un bug.

### 5.3 Un helper compartido no es una función nueva, y eso cambia cómo se verifica

Ver §3.5. **Cero `create` en el log de deploy puede ser la evidencia correcta.**

### 5.4 Cuando dos cosas reaccionan al mismo evento, nombralas por lo que MANTIENEN

**Evidencia.** Al agregar un segundo trigger sobre "reserva confirmada", el nombre
obvio ya existía. Lo descubrió `tsc` con un `TS2308` de export duplicado, no una
búsqueda — el `index.ts` hace `export *` de cada flujo, así que **dos flujos no
pueden exportar el mismo nombre**.

> Regla: la primera puede llamarse por el evento (`onOrdenPagada`); las siguientes
> se nombran por **lo que mantienen** (`onStockDescontado`,
> `onFacturaGenerada`), no `onOrdenPagadaAlgo`.

### 5.5 Un trigger que mantiene una proyección crítica no comparte destino con uno accesorio

**Evidencia.** Se decidió un **trigger propio** en vez de una rama del que ya
existía: aquel mantiene la proyección de **ocupación** de la que depende poder
reservar, y **un fallo escribiendo contadores sociales no puede tumbar la
disponibilidad del club**.

**En la tienda de vinos:** el trigger que descuenta **stock** no comparte función
con el que actualiza "los más vendidos". Si el segundo tira, el primero tiene que
seguir corriendo.

### 5.6 El arranque en frío cae donde no lo esperás

**Evidencia.** Reporte: *"a veces reservar demora un toque en confirmar"*. Pero
reservar **no llamaba a ninguna callable**: el cliente escribe directo y un
trigger confirma. Como Firestore pinta el documento local al toque, **el arranque
en frío cae DESPUÉS de que la UI celebró y navegó**. El síntoma no es "la pantalla
tarda" sino **"mi reserva figura sin confirmar" durante 3-5 s**.

Se resolvió con `minInstances: 1` en **exactamente dos** funciones: la del camino
crítico, y la dueña de la proyección de ocupación —porque en frío **el turno recién
tomado se sigue viendo libre para todos los demás**. Costo medido: ~USD 1,7/mes
cada una (una instancia idle cobra memoria + **10 % de CPU**).

**Y la otra mitad del arreglo fue copy, no infraestructura.** El estado transitorio
decía "Pendiente" — la misma palabra con la que se lee una espera de **días** que
depende de una persona. Quien caía en aprobación manual **no podía distinguir su
orden detenida de una que estaba por confirmarse en dos segundos**. Ahora dice
"Confirmando…". **Esto sobrevive al `minInstances`:** el estado existe siempre,
aunque dure 300 ms.

**En la tienda de vinos:** el estado entre "apreté pagar" y "el webhook llegó" es
exactamente este caso, y ahí la confianza vale plata. Nombralo distinto de
"pendiente de revisión manual".

### 5.7 Cuidado con los triggers al escribir en producción a mano

**Evidencia.** Antes de escribir un documento de configuración en producción hubo
que leer qué trigger `onDocumentWritten` se dispara con ese path: uno **re-preciaba
a todos los suscriptores activos**, y su baranda anti fat-finger **se desactivaba
en una creación** (exigía `montoAntes > 0`, y en un create no hay "antes").

**En la tienda de vinos** esto es una lista de precios. Una baranda que sólo mira
el valor anterior **no protege la primera escritura** — que es exactamente cuando
más se equivoca uno.

### 5.8 Tests de integración de functions: siempre `--runInBand`

**Evidencia.** En paralelo, los timeouts se disfrazan de fallos de lógica y perdés
la tarde buscando un bug que no existe.

**Y una trampa de Jest que da rojos ajenos:** si el proyecto tiene un `lib/`
compilado, **un `lib/` stale le gana al mock de `src/`**. Buscá "duplicate manual
mock" en la salida antes de culpar a tu cambio.

**El chequeo local más barato para TypeScript:** `./functions/node_modules/.bin/tsc
--noEmit` termina en **segundos** y atrapa imports faltantes y exports duplicados
sin gastar una corrida de CI.

---

## 6. La feature sin puerta

**Este es el modo de falla más caro y más repetido del proyecto: pasó TRES veces
en seis meses.** Merece sección propia.

### 6.1 Una feature puede estar 100 % escrita y 0 % alcanzable

**Caso 1 — fotos del club.** `EditCoverSheet` existía con **la cadena completa**:
sheet → provider → dos use cases → métodos del repositorio. **Cero call sites.**
El ícono de cámara siempre abrió otro sheet. Código muerto de **tres capas de
profundidad**. **Y el vault lo documentaba como entregado** — además listaba un
widget que **nunca se escribió**. O sea: el vault registraba **la propuesta**, no
lo implementado.

**Caso 2 — nombre del turno fijo.** La Cloud Function estaba desplegada, el sheet
escrito, el tile presente. Faltaba **la puerta**, y la causa era **aritmética, no
un bug**: el sheet sólo se abría desde un menú `⋮` que **no se dibuja en la home**
(decisión deliberada), y el otro `⋮` vivía detrás de un "Ver N más" que se dibuja
**sólo si hay 3 turnos fijos o más**. Con 1 o 2 —el caso normal— **no había camino
salvo una notificación push**.

**Caso 3 — los seguidos.** El sistema de seguir jugadores existía entero y **no
había un solo `read` de la subcolección desde ningún picker**. Las 6 superficies
que suman gente iban todas a la búsqueda global — exactamente la búsqueda que
seguir a alguien tendría que ahorrar. Reporte del usuario: *"está diseñado para que
me sea más fácil buscar a alguien… sin embargo no surge ese efecto"*. **No era un
ranking mal calibrado: no había cable.**

Bonus: la subcolección que sí leía un provider **era una colección fantasma**. El
código leía `follows`; la función escribe `following`/`followers` y las reglas
**sólo declaran esas dos**. El string `'follows'` aparecía **una sola vez en todo
el repo** → read denegado por default-deny → el error moría en un `?? {}` → set
vacío siempre.

**Y un cuarto, del panel de admin:** una página estaba **huérfana** —definida sin
ruta ni navegación— mientras el vault marcaba su feature como *"59/59 completa"*.

### 6.2 Cómo se detecta, y es barato

```bash
# Ante "X no se puede hacer": grepeá la clase que debería hacerlo,
# EXCLUYENDO su propio archivo. Si el único hit es su definición, está muerta.
grep -rn "EditCoverSheet" lib/ test/ | grep -v "edit_cover_sheet.dart:"
```

**Regla general: cuando una capacidad no se descubre, buscá primero si tiene
puerta — grepeá quién la abre, no si existe.**

### 6.3 La salida no siempre es agregar el botón

**Evidencia.** En el caso del nombre del turno, mover el menú a la home habría
arrastrado "renunciar al turno" al lado del botón semanal — justo lo que la
decisión anterior evitaba. **La salida fue sacar la acción del menú:** el rótulo
del nombre **es** el botón. Al vivir dentro de la card, aparece en las **dos**
superficies de una vez.

Y otra del mismo espíritu: el arreglo obvio para un preview roto en web era
`kIsWeb ? Image.network : Image.file`. **No fue lo que se hizo.** La pantalla nueva
sube apenas recorta, así que la única imagen que dibuja es la URL de Storage: **no
existe preview local, y por lo tanto no hay rama por plataforma que pueda
equivocarse.** *Eliminar la condición es mejor que escribirla bien.*

### 6.4 Duplicación semántica: mejorar una copia no mejora la app

**Evidencia.** Había **TRES implementaciones copiadas** de la misma búsqueda por
trigramas, idénticas hasta en una clase privada interna. Y **ninguna de las tres**
usaba los prefijos de 2 caracteres que el generador de tokens **sí indexaba** en
cada documento: una búsqueda de 2 letras habría funcionado ese mismo día si el
cliente los generara.

**En la tienda de vinos:** el buscador del catálogo, el del panel y el del carrito
son la misma búsqueda. Escribila una vez.

---

## 7. Presentación, UI y copy

### 7.1 Responsive con tolerancia cero

Regla del repo, sin excepciones ni siquiera para arreglos chicos:

- `SafeArea` en todas las páginas.
- **Ancho máximo de contenido**: `Center` + `ConstrainedBox(maxWidth: 700)`, para
  que el contenido no se estire de borde a borde en tablet/desktop.
- **Cambio de layout con `LayoutBuilder`**: `< 560px` → columna simple;
  `≥ 560px` → grilla de 2 columnas (`mainAxisExtent` cuando la altura es fija).
- **Chequeo mental antes de cerrar cualquier tarea de UI:** teléfono 360 px ·
  teléfono grande 430 px · tablet 768 px. Si se rompe en alguno, no está listo.

**Dato de test:** la superficie de `flutter_test` mide **800 px** y recorta al
`SizedBox`. Un widget que "anda" en el test puede overflowear en el teléfono.

### 7.2 `InkWell(onTap: null)` NO absorbe el toque

**Evidencia.** Deja de ser hit-testable y **el gesto sube al ancestro**. Un
arreglo de color que se detiene en el borde de su widget deja el defecto vivo al
lado.

Y la contraparte: **`Material(type: transparency)` para un `InkWell` sobre una
imagen** — sin él, el splash pinta sobre el `Material` del `Scaffold`, o sea
**debajo** de la foto, y el toque no devuelve ninguna señal.

### 7.3 "Cargando" no es ni `null` ni error

**Evidencia.** Un fondo generativo no aparecía nunca porque el estado de carga no
lo alcanzaba ninguna rama del `else`. **El fondo va de piso, no en una rama.**

Corolario de Riverpod: `when()` con `skipLoadingOnRefresh: true` (default en
Riverpod 2) evita que la página parpadee a esqueleto después de cada
`ref.invalidate`. Y un provider **sin `autoDispose`** sobrevive la navegación
entre dos páginas de la misma entidad — sin esqueleto al entrar.

### 7.4 Copy que alterna: determinístico, sembrado con la identidad del ítem

**Regla:** si el mismo texto se repite en tarjetas apiladas y molesta, alterná
redacciones — pero **jamás con `Random()`**.

**Evidencia.** `Random()` en un `build` es un bug, no una decisión de estilo:
cualquier widget que observe streams se reconstruye a cada tick, así que la frase
**cambiaría sola delante del ojo** mientras el usuario lee, y ningún test de widget
podría afirmar qué dice. Semilla `<idDelItem>|<fecha>` → la variedad aparece
**entre** tarjetas y desaparece **dentro** de una.

**Hash explícito (FNV-1a 32 bits), no `String.hashCode`**: el de Dart es estable
dentro de una corrida pero **no es contrato entre versiones ni plataformas**, y un
test que fije una frase se rompería sin que nadie tocara la copy.

**Y la regla que importa más: ninguna redacción del pool puede afirmar más que sus
hermanas.** *"Último turno disponible a las 19:00"* **no es sinónimo** de *"sólo
queda 19:00"* — es verdad únicamente si además no queda ningún turno después, ni
siquiera tomado. **Si una redacción dice algo que las otras no sostienen, no es una
variante: es otro caso**, y le toca su propia rama con su condición en el dominio.
El pool vive en presentación, la condición en el dominio.

**En la tienda de vinos:** *"Últimas 3 botellas"* vs *"Poco stock"* — la primera
afirma un número exacto. Si el pool las mezcla, mentís en la mitad de los casos.

### 7.5 No expongas data que el usuario no puede accionar

**Regla:** si filtraste por compatibilidad, permisos o disponibilidad, **ocultá el
ítem — no lo muestres deshabilitado ni como teaser**.

**Por qué:** mostrar ítems inutilizables expone superficies de leak que no conocés
de antemano. Que la data sea "pública" en Firestore no significa que mostrarla en
una UI **agregada** esté libre de riesgo — la agregación + presentación crea
contexto nuevo. Si el usuario no puede accionar, mostrarlo sólo agrega vector de
exposición sin valor funcional.

- Empty states por filtro → **no** ofrecer "ver todos" / "ver sin filtros".
  Tratarlo como vacío genuino.
- Ante la duda entre "mostrar deshabilitado" y "no mostrar": **no mostrar**.

### 7.6 Una herramienta de seguridad que se cree más fuerte de lo que es es peor que no tenerla

**Evidencia.** El bloqueo entre jugadores **no limita a la otra persona**: filtra
lo que yo veo. No le impide reservar, seguirme ni sumarme a un partido, porque su
picker usa **su** lista. La página lo declara arriba de todo.

**Y un caso peor del mismo espíritu:** el bloqueo existía desde la primera versión
y **nunca se pudo deshacer** — sus tres consumidores eran **filtros**, ninguna
vista lo listaba, y el botón de desbloquear vivía en el perfil de la otra persona,
**el único lugar al que ya no se llega después de esconderla de tus búsquedas**.

### 7.7 Detalles de UI que costaron una iteración

- **Un `.snapshots()` sin `orderBy` ordena por id autogenerado** — o sea, al azar
  desde el punto de vista del usuario.
- **`find.byIcon` global es ambiguo** en cards compuestas.
- **`pumpAndSettle` cuelga hasta el timeout** ante cualquier animación infinita
  (un punto que late, un shimmer). **El error no se parece a la causa.**
- **`FilledButton` mide 40 px en web** y 48 en móvil; un test de altura que pasa en
  uno falla en el otro.
- **`dart format` es un chequeo de sintaxis gratis.** Si formatea el archivo,
  parsea. No reemplaza al analizador, pero atrapa paréntesis desbalanceados en
  segundos.

---

## 8. Argentina

### 8.1 `wa.me` SIEMPRE lee los dígitos como E.164 completo

**Regla:** un número escrito como se disca en Argentina **nunca fue "un número al
que le falta el prefijo"** — para WhatsApp es el país `3`. **Y no falla
ruidosamente: abre un chat con un desconocido**, que es peor que un error.

**Tres cosas no obvias del normalizador que salió de ahí:**

1. **El `+` es dato, no ruido.** Limpiar los no-dígitos *antes* de mirarlo borra la
   única señal que separa un `+56` chileno de un `3548…` local. Leelo primero y
   devolvé `(dígitos, esInternacional)`. Un número que declara su país y no es 54
   sale **intacto**.
2. **El `15` se ubica SIN tabla de códigos de área.** Con 12 dígitos el `15` sólo
   puede estar en la posición 2, 3 o 4, y las tres **se contradicen entre sí**. El
   único área de 2 dígitos es el `11`, así que esa se prueba sólo ahí. Bucle de 3
   iteraciones, **exacto y no heurístico**.
3. **`0`, `15` y `9` son notación de CÓMO discar según desde dónde llames**, no
   partes del número. Se sacan los tres y el `9` se repone al componer. Ningún
   código de área argentino empieza con `0` ni con `9`, así que los recortes nunca
   se comen un dígito real.

**Decisión con costo, tomada explícitamente:** a un `+54…` de 12 dígitos se le
**agrega** el `9` de móvil. Rompe un WhatsApp Business dado de alta sobre línea
fija (existe, es raro) para arreglar el móvil sin `9` (común).

**En la tienda de vinos** esto es infraestructura de venta: el "Consultar por
WhatsApp" de cada producto y el aviso de despacho.

### 8.2 Datos de demo: rotulalos y no los toques a ciegas

**Evidencia.** Los 3 clubes en producción eran **data de demo curada, ficticia a
propósito**, para mostrarle el producto a clientes. Y tenía una trampa real:
**cambiar la duración del turno desalinea los turnos fijos existentes y no avisa
nadie**.

**En la tienda de vinos** el catálogo de demo tiene el mismo riesgo: cambiar la
unidad de precio, el IVA o el formato de la botella después de sembrar deja
órdenes viejas que ya no se pueden interpretar.

### 8.3 Un backfill no siempre vale la pena

**Evidencia.** Un backfill de agregados **no se corrió, por decisión del
usuario**: todo lo que había en producción era data de demo, sembrarlo era gasto
sin valor. El diseño se hizo coherente con eso: el agregado arranca vacío, el
picker cae en la señal de relleno, y **el rótulo cambia** para no afirmar una
medición que no se hizo. El script quedó listo, sin correr.

> **Prometer "los que más compraste" sobre datos que no medís es mentirle al
> usuario.** Rótulo condicional: medido vs. declarado.

---

## 9. Trabajar con Claude

Ver `SETUP-PRIMERA-CORRIDA.md` para el paso a paso. Acá van las lecciones
transversales.

### 9.1 Nunca escribas git desde un hook ni desde un proceso de fondo

**Evidencia — la peor pérdida del proyecto.** Había un watcher de auto-commit
cableado como hook `Stop`. Una sesión se cortó a mitad de escritura y dejó **dos
archivos de git en NUL (0x00)**: `.git/refs/heads/master` (41 bytes de ceros) y
`.git/index` ("bad signature 0x00000000"). Desde ahí **todos los auto-commits
siguientes fallaron en silencio**, así que **~5 días de trabajo quedaron sin
commitear**.

Reparación, por si vuelve a pasar: backup del working tree → reescribir el SHA
bueno directo en el archivo de la ref (`git update-ref` se niega con una ref
"broken") → `rm .git/index && git reset --mixed HEAD` (no toca el working tree).

**El reemplazo es el patrón correcto:** una **skill `commit`** que Claude ejecuta
**en conversación** como último paso —lee el diff, decide el bump semver, escribe
el mensaje— más un hook `Stop` **read-only** que sólo **avisa** si el árbol está
sucio y **nunca escribe git**.

### 9.2 Los hooks bloqueantes miden de verdad — creeles

**Evidencia.** El límite de 200 líneas bloqueó un archivo con **208** y lo dejó
pasar con **197**. El de fronteras de capa bloqueó un provider por importar la
capa de datos, correctamente.

**Dos cosas operativas:**

1. **El mensaje del hook va por stdout**, y la consola dice *"No stderr output"*.
   Un bloqueo que no dice por qué es indistinguible de un hook roto — y la
   reacción natural (quedarse quieto) es exactamente la que no lo destraba.
   **Si un hook bloquea, abrí el `.sh` y leé su regla.**
2. **El límite es `> 200`, no `>= 200`.** Aun así, dejá margen: quedar clavado en
   el límite hace que cualquier edición futura rompa el gate.

### 9.3 Una regla escrita en un prompt no es una regla ejecutada

**Evidencia — el agujero real.** El hook de fronteras de capa bloquea que
presentación importe `*/data/*`, **pero no bloquea el SDK de Firebase directo en un
widget**. Por eso un widget convivía con `cloud_firestore` + `firebase_storage`
**desde el commit inicial**, pese a que el agente de presentación lo prohíbe en su
texto.

> **Lo que no está en un hook, no está.** Un prompt describe la intención; un hook
> mide el resultado. Si una regla importa, escribila como hook.

### 9.4 En esta máquina no se corre nada pesado — y la causa es RAM

**Evidencia.** La prohibición existía por síntomas (`flutter analyze` >20 min sin
terminar, un solo archivo de test sin completar en 7). **La causa medida son 7,9 GB
de RAM totales con 0,4 GB libres.** La máquina no es lenta: está sin memoria y todo
va a paginación.

Un build local falla con `exit code -1073741819` = `0xC0000005` =
**ACCESS_VIOLATION**: es el generador de snapshots quedándose sin memoria haciendo
el AOT. **Un `0xC0000005` en una herramienta de build casi nunca es culpa del
código.**

Quién se come la RAM (medido): el analysis server de Dart **1,4 GB** (¡y no hace
falta para compilar!), el editor 1,15 GB, Chrome 761 MB, el daemon de Gradle 596 MB
**que queda vivo después de un build fallido**, Claude 823 MB.

**Trampa:** cerrar el editor mata la sesión de Claude Code, porque corre como
extensión adentro.

**Los dos chequeos locales que SÍ valen la pena:** `dart format` (parseo, segundos)
y `tsc --noEmit` (tipos de TypeScript, segundos).

### 9.5 Fricciones de edición por script en Windows

- **El vault es CRLF y el código LF.** Un script que lee con `newline=''` y busca
  `\n` encuentra **0 coincidencias** y falla sin decir por qué.
- **Los heredocs de Bash de esta máquina se comen los backslashes.** Un `\\1`
  llegó como `\1`, y **`\1` en un string de Python es un escape OCTAL**: quedó un
  `chr(1)` invisible en medio de un archivo de CI. **No se ve con `cat`; se ve con
  `cat -A`** (aparece como `^A`). **Escribí los scripts de parcheo como archivo y
  corrélos**, no por heredoc.
- **Escribir con `newline=None` en Windows** traduce cada `\n` a `\r\n` y puede
  dejar `\r\r\n`.
- **Un `.pyc` trackeado en git** ensucia el árbol cada vez que importás el módulo.

### 9.6 Un componente que nunca ejecutó no tiene evidencia de funcionar

Es el hilo que conecta §4.2 (el índice que destapó un P0 dormido), §6 (la feature
sin puerta) y §3.7 (el CI nuevo que encuentra bugs viejos). Vale como principio
general:

> **Tests verdes sobre código que nunca corrió en producción prueban que el código
> hace lo que el test dice, no que el sistema funcione.**

---

## Apéndice: las 12 que me llevaría si sólo pudiera llevarme 12

1. Un job verde no prueba que compiló; el artifact sí. Un run de deploy verde no
   prueba que publicó; la lista de jobs sí.
2. Toda verificación necesita un **control positivo**. Sin él, confirma cualquier
   cosa.
3. El canario tiene que ser **nuevo** y **discriminante** (uno aparece, otro
   desaparece).
4. Commitear no es entregar. El último paso del workflow escrito es lo que el
   sistema produce.
5. Un documento puede **nacer** en el estado final: usá `onDocumentWritten` con
   `entró en B`, nunca `onDocumentUpdated`.
6. Los triggers y los webhooks son **at-least-once**: idempotencia por marcador,
   en la misma transacción que el efecto.
7. Un índice `READY` puede no servir. Verificá **corriendo la query**.
8. Batchear no abarata: Firestore cobra por documento. Lo caro suele ser
   `autoDispose`.
9. Antes de creer que una feature existe, **grepeá quién la abre**, no si está
   escrita.
10. Lo que no está en un hook, no está. Un prompt describe; un hook mide.
11. Nunca escribas git desde un hook o un proceso de fondo.
12. Un componente que nunca ejecutó no tiene evidencia de funcionar.
