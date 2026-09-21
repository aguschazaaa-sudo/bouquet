# bouquet — estado actual

> **Este archivo es un dashboard, no un log.** Tope: **5 entradas**. La sexta se
> mueve a `changelog/_log.md`.
>
> `DIAGNOSTICO.md` §3: en PadelPunilla este archivo creció a ~15 entradas de 20
> líneas y Claude lo leía **entero en cada sesión** — el archivo más caro del
> repo en tokens, y las entradas 6 a 15 casi nunca cambiaban una decisión. Un
> dashboard que no entra en una pantalla dejó de ser un dashboard.
>
> **Y este archivo documenta la INTENCIÓN.** El comportamiento real sale de
> `_verdad.md`, que se genera desde el código. **La diferencia entre los dos es
> la deuda del proyecto, medida.**

---

## Dónde está el proyecto

**Fase: la vidriera está entera hasta el botón de pagar (2026-09-15). Todavía
no se cobra nada.** `/vinos`, la ficha, `/carrito` y ahora `/pedido` leen 20
vinos de muestra de `bouquet-vinos`. El checkout pide los datos y cotiza el
envío **con un cotizador simulado**; falta `crearOrden`, la preferencia de
Mercado Pago y su webhook.

**Las reglas de Firestore y Storage YA ESTÁN PUBLICADAS** (2026-09-14), medido
por la API de Rules con quota project: dos releases. **Las fotos dan 200
`image/webp`**, así que las ventanas del catálogo y de la home dejaron de estar
vacías.

Existe: `git init` en `main`, `CLAUDE.md`, los 10 hooks con su arnés de 30
casos, `ci.yml`, los ADRs 001-004, y **`packages/contratos`** — la máquina de
estados de Orden, la proyección de los 30 pares, el dinero en centavos, los
tests y el contrato generado.

**El conteo de tests salió de acá a propósito.** Decía **24** y el runner
dice **26** — lo detectó `_verdad.md` en su primera corrida, que es
exactamente para lo que existe. Un número que se puede calcular no se
escribe a mano: está en
[`_verdad.md`](_verdad.md), generado desde el código.

~~No existe todavía `apps/`, `functions/` ni `firestore.rules`.~~ Existen
desde el 2026-09-03 — ver abajo. La línea quedó contradiciendo a su propio
archivo dos entradas más abajo, que es el modo de falla que este dashboard
existe para no tener.

**Node 24 corre TypeScript sin transpilar**, así que el paquete tiene **cero
dependencias de test** (ni jest, ni vitest, ni ts-node). La única dependencia
del repo es `typescript`, para `tsc --noEmit`. En una máquina de 7,9 GB eso no
es un detalle de gusto.

Lo próximo es `crearOrden` y el cobro, con los nueve hallazgos que dejó
`revisor-pagos` en
[ADR 008](architecture/decisions/008-catalogo-stock-y-carrito.md). Y antes del
deploy público con el catálogo real, el tramo 4: Cloudflare con purga por tag.

**El panel tiene plan desde el 2026-09-16, y ese mismo día tuvo puerta**:
EP-01 entera. Se entra con mail o con Google, quien no tiene permiso lo ve
dicho, y las cuentas las da un script.

**Catálogo dejó de estar vacío el 2026-09-17**: se ven todos los vinos
—publicados y no—, se buscan escribiendo, y las bodegas se cargan, se corrigen
y se borran con una baranda que no deja despublicar sin querer. Son **EP-02
entera y HU-03.1**. Pedidos sigue vacío y lo dice: es el hito 2.

**Cargar un vino está escrito desde el 2026-09-18 y todavía NO desplegado**:
HU-03.2 a HU-03.4, con reglas nuevas que van primero. Lo próximo del hito 1,
después de verificarlo, es **publicar** (HU-03.5 a 03.7, dos de ellas por
Workflow D).

**Y desde el 2026-09-17 está PUBLICADO en
[`bouquet-vinos.web.app`](https://bouquet-vinos.web.app)**, con `noindex` y con
la API key acotada por referrer. **El dueño ya entró con Google y tiene el
permiso**: es la única cuenta de Auth. Falta la lista de mails del resto de la
familia — el permiso lo da el script, no una pantalla.

### El producto se endureció, y la ficha lleva descripción (2026-09-21)

**Lo del 18 quedó ENTREGADO**: las reglas de ADR 013 se desplegaron
(ruleset `a4520800` → `0310466f`) y el panel se promovió con `hosting:clone`
(live pasó del commit `3b46a39` al `d871218`). **Falta que alguien cargue un
vino real y lo mire** — 9.6 de `panel-cargar-un-vino`, y sin eso el change no
se archiva.

**Tres agujeros cerrados en `firestore.rules`**, en el change
[`panel-publicar-un-vino`](../../openspec/changes/panel-publicar-un-vino/proposal.md),
con el porqué en [ADR 014](architecture/decisions/014-publicar-un-vino.md):
un producto **no se borra nunca** (`allow delete: if false`), un vino
publicado **tiene precio > 0**, y **cada imagen es una URL `https://`**. Los
dos primeros son los hallazgos 1 y 2 que `revisor-pagos` dejó abiertos en
ADR 008. ⚠️ **Sin desplegar todavía**: el deploy es reglas → panel.

**La ficha del vino lleva descripción**, punta a punta: contrato, reglas,
panel y vidriera. El dueño contestó la pregunta que EP-03 tenía abierta desde
el mapa (hallazgo 14). Tope de **600 caracteres**, que vive en las reglas y no
sólo en el formulario — el catálogo entero viaja al navegador para filtrarse
en memoria, así que cada carácter lo paga todo el que abre `/vinos`.

**Dos cosas se midieron contra el emulador en vez de suponerse.** `matches()`
de las reglas compara **la cadena entera** —`xhttps://…` rebota—, y `size()`
cuenta **caracteres, no bytes**: 600 eñes entran. Si contara bytes, el tope
real en castellano sería la mitad del que dice el formulario, y nadie se
enteraría hasta que un texto normal rebotara.

**Se midió producción ANTES de endurecer nada**, porque una regla nueva puede
dejar atascado un documento que ya existe: **0** publicados con `precio <= 0`
y **0** imágenes sin `https://`, cada uno con su control positivo. Y dos
datos que no se buscaban: `fichaVino` en producción no tenía **ni
`graduacion` ni `descripcion`**, así que el `hasOnly` crece sin rebotar nada;
y **los 20 productos son `muestra: true`**, o sea que todavía no hay un solo
vino real cargado.

**Las reglas se mutaron, de a una.** Cinco mutaciones, cada una rompiendo
exactamente los casos que la prueban. La que más valía: debilitar **sólo el
índice 9** de `imagenValida` rompe **sólo** el test que mira la última
posición — las diez condiciones no son decorativas. Suite de reglas 38 → 53.

⚠️ **Falta la pantalla.** Publicar y despublicar (HU-03.6) y el espejo de la
vidriera (HU-03.7) **no están construidos**; las reglas que los habilitan sí.
Y el campo de la descripción todavía no está en el formulario del panel: el
dominio, el mapeo y los tests sí.

### Cargar un vino: escrito, probado contra el emulador, sin desplegar (2026-09-18)

**HU-03.2 · HU-03.3 · HU-03.4**, en el change
[`panel-cargar-un-vino`](../../openspec/changes/panel-cargar-un-vino/proposal.md).
El porqué está en [ADR 013](architecture/decisions/013-cargar-un-vino.md).
**Toca `firestore.rules`**: el deploy es reglas → panel.

**El id de un producto nuevo es su slug, y las reglas lo exigen.** La unicidad
la da la base, sin `get()`: reemplaza la reserva `slugs/{slug}` que ADR 008
había anotado. **`graduacion` entró** en décimas enteras, entre 50 y 250 — el
piso atrapa un `14` pensado como 14 %.

⚠️ **Se temía que las reglas evaluaran el estado intermedio de un batch, y se
midió que no.** Corregir varietales va con `arrayUnion` y `arrayRemove` en dos
`update` al mismo documento; reemplazar el único varietal pasa por una lista
vacía si las reglas miraran el medio. **Ven el estado final**, en los dos
órdenes. El control —quitar el último solo— se rechaza.

⚠️ **La suite de reglas tenía una trampa que la regla nueva destapó.** Todas
las altas creaban `productos/a` con slug `trumpeter-malbec`: con la regla, los
`assertFails` habrían pasado **por el slug** y no por lo que cada caso dice
probar. Ahora toda alta pasa por `alta()`, con el slug como id.

⚠️ **HU-03.4 nombra "la descripción" y el modelo no la tiene** (hallazgo 14
del [mapa del panel](features/panel/overview.md)). Pregunta para el dueño.

| Qué | Cómo |
|---|---|
| Reglas | 38/38 en el emulador (eran 26). **Mutadas**: sin las tres condiciones nuevas fallan exactamente los 5 casos que las prueban |
| El panel | `dart analyze` sin issues; `dart test` **146/146** (eran 78) |
| La factory | Test contra los `hasAll`/`hasOnly` **leídos de `firestore.rules`**, no contra una lista copiada |
| Tres copias | `auditar_varietales.mjs` compara lista, orden y rango en `contratos`, reglas y panel. Cuatro controles negativos, cada uno sale con 1 |
| Hooks | Los 4 del panel sobre 33 archivos con ruta absoluta: 0 bloqueos. El canario —color literal, dos widgets, import de `data/`— lo bloquean los tres que tienen que bloquearlo |
| Presupuesto | Abrir el formulario, **0**; alta, **2**; corrección, **1**. 200 altas: 0,8 % de un día |

⚠️ **NADIE VIO EL FORMULARIO RENDERIZADO.** El panel no compila en esta
máquina: lo compila CI. Y aun publicado, la única cuenta con permiso es la del
dueño.

### El catálogo se ve y las bodegas se cargan (2026-09-17)

**EP-02 entera (HU-02.1 a 02.4) y HU-03.1**, en el change
[`panel-catalogo-y-bodegas`](../../openspec/changes/panel-catalogo-y-bodegas/proposal.md).
El porqué está en [ADR 012](architecture/decisions/012-el-catalogo-del-panel.md).
**No tocó `firestore.rules`**: `productos` y `bodegas` ya tenían lo que hacía
falta, así que el deploy fue sólo front.

⚠️ **ARQUITECTURA §7 decía que la normalización vivía en `packages/contratos`
"con sus fixtures, un solo lugar". No vivía en ninguno.** Lo único parecido era
un slugify escrito a mano adentro de `PanelDeFiltros.tsx`. Ahora existe
—`normalizar`, `clave`, `aSlug`, `seParecen`— con su espejo en Dart verificado
contra fixtures generadas por el TypeScript, igual que el enum de estados.

⚠️ **Dart no trae normalización Unicode en el SDK.** No hay `String.normalize`,
así que sacar acentos pedía `diacritic` o una tabla de caracteres a mano. Se
eligió la dependencia: una tabla falla **en silencio** con el carácter que
nadie pensó, y "Château" habría dado el slug `ch-teau` sin que nada avisara.

**Y las fixtures encontraron dos cosas que nadie iba a ver leyendo:**

| Lo que se suponía | Lo que se midió |
|---|---|
| `removeDiacritics` de la eszett da `ss` | da **`s`** — el test falló y se corrigió la expectativa, no el código |
| El espacio del precio es la barra espaciadora | es **U+00A0**: `24 a0 31 32 2e 35 30 30 2c 30 30` |

El segundo importa: `$12,500.00` y `$ 12.500,00` no son el mismo número mal
alineado, son dos números. `formatearARS` también se espeja, por fixtures.

**La baranda del borrado tiene dos capas, y ninguna vive en las reglas.**
Contar los vinos de una bodega adentro de `firestore.rules` serían `get()`
facturados por evaluación, invisibles en toda auditoría porque no aparecen en
ninguna query — el costo que ADR 008 evita con el custom claim. Así que: con
vinos, el botón **no existe** (no está apagado: no está); y al confirmar, una
query fresca con `Source.server` que cuesta 1 lectura y cierra la ventana entre
que se abrió la pantalla y se apretó el botón. **Lo que queda abierto está
escrito**: las reglas todavía permiten el `delete`, y el día que haya más de un
rol esto se vuelve a decidir.

⚠️ **`dart analyze` SÍ corre en esta máquina.** Terminó y encontró dos infos
reales (un `<id>` en un doc comment, un parámetro `otro` en vez de `other`).
`CLAUDE.md` prohíbe `flutter analyze`, que es otra cosa — **el panel dejó de
depender sólo de CI para saber si compila**, que era su único ciclo de
feedback.

⚠️ **Y el barrido de hooks mintió una vez, con un verde.** Corrido con rutas
**relativas**, los cuatro hooks daban 0 en un archivo que tenía
`Colors.transparent` adentro: sus `case` piden `*/apps/admin/lib/*`, y una ruta
sin barra inicial no matchea. Con ruta absoluta, `no-hardcoded-colors` bloqueó
en la primera corrida. **Lo salvó el control positivo** —un archivo canario con
un color literal—, que es lo único que distingue "no hay hallazgos" de "no se
midió".

| Qué | Cómo |
|---|---|
| Compila | `dart analyze lib test` → **No issues found** |
| Suites | `dart test` **78/78**; `npm test` verde; `npm run tipos` en 0 |
| El contrato | `auditar_estados.mjs`, ampliado: fixtures de texto y de plata con sus dos controles cada una, y que el panel las espeje. **Se vio fallar** antes de escribir el espejo |
| Sin huérfanos | 39 símbolos nuevos, todos con quien los abra. Control negativo: un símbolo inventado da 0 |
| Las fronteras | `layer-boundary`, `one-widget-per-file`, `widget-size-guard` y `no-hardcoded-colors` sobre los 19 archivos, con ruta absoluta |
| Presupuesto | **230 lecturas** en frío, 1 por alta y 1 por borrado. 10 sesiones = 4,6 % de la cuota |

**El presupuesto de ARQUITECTURA §6.3 estaba optimista y ahora tiene número.**
Decía ~200 *"con caché de sesión"*, suponiendo que sobrevive entre sesiones — y
la de Riverpod muere con la pestaña. **230 es contra lo que hay que medir.**

#### Publicado, y lo que NADIE miró todavía (2026-09-17)

**Live sirve los bytes que compiló CI**: `hosting:clone` del canal a live, sin
recompilar. Mismo `main.dart.js` (`f2a7d72a22b1c297`) en el canal y en live,
mismo commit `3b46a39`, `X-Robots-Tag: noindex` puesto.

**El canario discrimina, y se midió el ANTES.** Antes de promover, live tenía
la cadena vieja y ninguna de las seis nuevas; después, al revés. Los dos
controles —una cadena de Pedidos que no se tocó y una inventada— dieron lo que
tenían que dar en las dos corridas.

⚠️ **Y la primera sonda dio TODO "no", incluida una cadena que sí estaba.**
`dart2js` **escapa los no-ASCII**: "Catálogo" vive en el bundle como
`Catálogo`. Buscar la cadena cruda da cero para todo y se lee como "el
deploy no llegó". **Lo destapó el control positivo con una cadena ASCII pura**
—"Ese mail no parece estar bien escrito"—, que sí apareció.

| Qué se verificó | Cómo |
|---|---|
| Los bytes | `publicar.sh verificar`: 4 hashes, control negativo (un archivo inventado no pasa por `main.dart.js`) y el `noindex` |
| Que la app **arranca** | CDP sobre live: el árbol de semántica lee la pantalla de entrada entera y hay **0 errores de consola**. Una cadena en el bundle no prueba que arranque |
| El router en producción | `/catalogo/bodegas` redirige a `/entrar?desde=/catalogo/bodegas` |
| **La query de HU-02.4** | Corrida de verdad contra Firestore por REST: `fichaVino.bodegaId == muestra-catena-zapata` devuelve 1 documento y una bodega inventada devuelve **0**. Sin índice compuesto |

⚠️ **NADIE MIRÓ EL CATÁLOGO RENDERIZADO CON DATOS.** El panel pide sesión y la
única cuenta con permiso es la del dueño. Lo verificado llega hasta la puerta:
que los bytes son los que se compilaron, que la app arranca y que la query que
usa la pantalla anda. **Lo que falta es exactamente lo que `CLAUDE.md` dice que
hago mal**: desplegarse no es que alguien lo haya mirado. El change
`panel-catalogo-y-bodegas` **queda abierto** hasta que el dueño entre y mire.

⚠️ **Y un chequeo que NO probó lo que parecía.** Que `/catalogo/bodegas`
redirija preservando el `desde` no distingue una ruta real de una inventada:
`/catalogo/ruta-inventada-2026` hace exactamente lo mismo estando deslogueado.
Se corrió el control negativo y por eso se sabe. Lo que sí prueba que la ruta
existe son los canarios del bundle y los 4 casos nuevos de `destino_test.dart`.

### El panel tiene puerta: entrar, sin acceso y la estructura (2026-09-16)

**Nace el panel de verdad**: EP-01 entera (HU-01.1 a 01.5) y los habilitadores
H1 a H4, en el change
[`panel-entrar`](../../openspec/changes/panel-entrar/proposal.md). El porqué
de cada decisión está en
[ADR 011](architecture/decisions/011-entrar-al-panel.md).

⚠️ **El proyecto no tenía Auth.** La API devolvía `CONFIGURATION_NOT_FOUND`,
medido con dos controles: una ruta inventada da un 404 en HTML y un proyecto
con Auth da su configuración. Tampoco había ninguna app registrada. El usuario
inicializó Auth con mail y Google, y la protección contra enumeración de mails
quedó prendida.

**La dirección visual la eligió el dueño mirando tres direcciones**: *"me
gusta el esquema de colores de la B pero me parece más eficiente la búsqueda
de A"*. Nace la **mezcla C**, espejada en
[`tokens.md` §7](design/tokens.md).

⚠️ **La sonda de Auth encontró un agujero que ningún documento tenía: el
registro anticipado.** Con la API key pública, cualquiera registra el mail de
un familiar con una contraseña suya. Si el script le diera el permiso a *"la
cuenta de ese mail"*, el panel quedaría en manos de quien la registró. **El
script se niega**. Su test falla si se saca la condición, y eso se comprobó
mutándola.

**Y confirmó la trampa que anotaba HU-01.1**: con el mail sin verificar,
entrar con Google desvincula la contraseña. El panel no ofrece registrarse, y
la contraseña nace por un correo que verifica el mail, así que no puede pasar.

| Qué | Cómo |
|---|---|
| El script de accesos | Contra el emulador de Auth, cada requisito con un caso aceptado y uno rechazado. **Mutación:** sin la condición del mail verificado, falla exactamente el caso del registro anticipado |
| Sin huérfanos | Ninguna clase nueva sin quien la abra: el control negativo, un símbolo inventado, da 0. Dos tokens sin uso se sacaron |
| Las fronteras | 0 colores literales fuera de `lib/theme/`; el SDK de Firebase sólo en `data/` y `core/firebase/`; ningún widget pasa de 200 líneas; arnés 35/35 |
| Compila | Por el analizador del editor, que ya corría y no marcó nada, y `dart format`. **El build lo contesta CI**: acá no se compila |

⚠️ **`dart test` lo frenó el clasificador del modo auto** en esta máquina, y
eso que `CLAUDE.md` no lo prohíbe (sí prohíbe `flutter test`). La suite de
Dart corre en CI, y ya corrió: `suite_dart` en `success`, no `skipped`.

#### Publicado, y lo que apareció al mirarlo (2026-09-17)

**Vive en [`bouquet-vinos.web.app`](https://bouquet-vinos.web.app)**, con los
bytes que compiló CI: `hosting:clone` del canal a live, **sin recompilar**.

⚠️ **LA BANDA DE ARRIBA SE DIBUJABA PERFECTA Y NO EXISTÍA PARA UN LECTOR DE
PANTALLA.** El `ShellRoute` mete un `Navigator`, y el `BlockSemantics` de su
barrera modal borra la semántica de todo lo pintado **antes** que ella. La
banda era el primer hijo de un `Column`:

| Se pinta | Qué tenía el árbol de accesibilidad |
|---|---|
| Banda arriba, antes del `Navigator` | Nada: ni `bouquet`, ni las pestañas, ni el mail, ni *Salir* |
| Barra inferior a 390 px, slot del `Scaffold`, después del body | `button:Catálogo`, `button:Pedidos` |

Las dos en la misma pantalla y la misma sesión, y un resize que fuerza el
rebuild no cambió nada (no eran nodos rancios). La banda pasó al slot `appBar`,
que el `Scaffold` pinta después. El arreglo **no movió un píxel**: las capturas
de antes y después son iguales. [ADR 011
§6](architecture/decisions/011-entrar-al-panel.md) lo deja con NO REVERTIR.

**Lo destapó que el driver no encontrara la pestaña, no una lectura del
código** — y el código se lee correcto: la banda tiene sus `Semantics`, las
pestañas son `button`, y `Marca` hasta aporta su propia etiqueta. Ninguna
revisión del diff lo iba a agarrar. Octava vez en el proyecto que mirar
encuentra lo que leer no.

⚠️ **Y el instrumento mintió dos veces, en las dos direcciones.** Primero leía
sólo los hijos directos de `flt-semantics` y daba **vacío**; después perdía
**todo título**, porque Flutter emite un encabezado como `<h2>` y no como
`<flt-semantics>`: dos pantallas correctas —*"Esa página no existe"* y *"Tu
cuenta todavía no tiene acceso"*— figuraban como fallas. **Lo que salvó la
medición fue el control negativo**, que siguió dando negativo después de
ensanchar el extractor: sin él, leer el subárbol entero es un sello de goma.

| Qué | Cómo |
|---|---|
| Live sirve lo verificado | Los cuatro hashes de live **iguales** a los del canal, y `main.dart.js` cambió de `62136648…` a `bd1973436526b868` entre los dos builds: el canario discrimina. Antes de promover, `/` y `/COMMIT` daban **404** |
| No se indexa | `X-Robots-Tag: noindex` en live, y control negativo: una ruta inventada la contesta `index.html` y su hash **no** coincide con `main.dart.js` |
| El recorrido, renderizado sobre live | **24 aserciones en verde, 0 en rojo**, con Chrome sin cabeza por CDP y cuentas de control: entrar, contraseña equivocada, volver a `/pedidos` con el `?desde`, recargar, la pestaña, ruta inventada, 390 px sin scroll, salir, sin permiso con su mail, el permiso dado **con la pantalla abierta** sin volver a escribir la contraseña, y el correo a un mail sin cuenta |
| La banda es alcanzable | Las tres interacciones de la banda salieron **por semántica**, sin el clic por píxel que hubo que usar contra el build anterior |
| Mirado | 1440 y 390 px, las dos pantallas y las dos barras |
| Sin cuentas de control | Borradas: `listUsers` devuelve **0 usuarios**, no sólo 0 con permiso, y el mismo listador las mostraba minutos antes |

⚠️ **El recorrido no se puede repetir:** vivía en el scratchpad y dependía de
las cuentas de control, que se borraron. Se reescribe o se promueve a
`scripts/panel/` el día que haga falta.

### El panel tiene plan: 11 épicas, 48 historias, ninguna construida (2026-09-16)

**Nace el backlog de la app de gestión** en
[`features/panel/`](features/panel/overview.md): épicas que agrupan historias
de usuario, cada una con lo que **ya está decidido** y la restringe, enlazado a
su ADR. Son dos capas de tres: los **requerimientos** se escriben historia por
historia, en el change de `/opsx:propose` que la tome. El documento **no tiene
casillas** a propósito: el estado de una historia sale de un `grep` de su ID en
`openspec/changes/`.

**Tres hitos:** cargar el catálogo real —que **no** espera a `crearOrden`—,
atender pedidos —que sí, y cuyos requerimientos se escriben con el spec de
`crearOrden`— y curar la vidriera.

**El dueño contestó en dos rondas el mismo día, y el hito 2 cambió de
orden.** Hay ventas por WhatsApp: la épica que las carga sube al hito 2 y va
**primero**, porque no espera a Mercado Pago, y el panel atiende ventas reales
mientras la vidriera sigue sin cobrar. Lo demás: un solo rol para toda la
familia (*"el panel no debe exceder la burocracia"*), entrar con mail o con
Google, avisos en el teléfono por una APK, y el aviso de despacho con un toque,
activable por persona.

~~Con eso volvía el camino de
[ARQUITECTURA §12](../../ARQUITECTURA.md#12-orden-de-construcción)~~
—`entroEnPagada` estrenado con un pedido marcado pagado a mano—: **no vuelve**.
La segunda ronda lo descartó: el cobro de WhatsApp *"se gestiona por fuera"* y
no se ve en el panel, así que el trigger se estrena con el webhook. Y la regla
de las seis botellas **no aplica** a WhatsApp, lo que convierte el origen del
pedido en una regla de plata: lo fija el servidor, nunca quien llama.

⚠️ **Planificar encontró siete cosas que ningún documento sabía**, y las
respuestas trajeron seis más —la Orden no sabe de dónde vino, y un pedido cuyo
pago no se sigue no tiene `estadoPago` que le calce, entre ellas—. Las tres que
más pesan:

1. **Una foto subida desde el panel llega cruda**, y la vidriera espera WebP
   recortado: hoy ese recorte lo hace sólo el seed, con `sharp`.
2. **Las reglas de `ordenes` no validan la transición de `estadoEntrega`**, y
   no dejan guardar ni el seguimiento ni el motivo de una entrega fallida.
3. **La reposición de stock y `crearOrden` escriben el mismo campo**: se
   diseñan juntas.

| Qué | Cómo |
|---|---|
| El mapa dice la verdad | **48** encabezados `HU-` en las épicas contra los **48** de la tabla, épica por épica y sumados por script sobre la tabla; **0** IDs repetidos (control positivo del `uniq -d` al lado); la única referencia sin encabezado es **HU-10.2**, descartada a propósito |
| Lo que se retractó no quedó suelto | El grep de las frases retiradas da **0**; el mismo patrón sobre el commit anterior da **1** |
| Los enlaces | **375** resuelven, anclas incluidas. **Control negativo:** un ancla inventada en ARQUITECTURA la rechaza el verificador, y la real con tilde pasa |

Son documentos: no se despliega nada.

### Lo que quedó abierto

| Qué | Por qué | Quién |
|---|---|---|
| **Falta la lista de mails de la familia** | El **dueño ya entra**: entró con Google el 2026-09-17 y `acceso.mjs dar` le puso el claim —verificado leyendo su registro, `{"rol":"admin"}`, y el listador pasó de 0 a 1—. Es la única cuenta de Auth. Para cada uno de los demás: `node scripts/acceso/acceso.mjs dar <mail>`, y que entre con Google o toque *"¿No tenés contraseña?"*. **El orden importa poco:** si entran antes de tener permiso, caen en `/sin-acceso` y con el botón *"Ya me dieron acceso"* pasan sin volver a escribir nada. **Disparador:** cuando el dueño pase los mails. Desde 2026-09-16. | el dueño |
| ~~**Entrar con Google no está verificado en live por una persona**~~ **VERIFICADO el 2026-09-17: lo hizo el dueño** | Entró con Google en live, se le creó la cuenta —`providers: google.com`, mail verificado, sin claims— y cayó en `/sin-acceso`, que es exactamente lo que el diseño dice que pase. ⚠️ **Queda un hueco chico:** eso fue **antes** de acotar la API key, así que el flujo de Google **con la restricción puesta** no está probado. Lo que sí está probado con la restricción es una llamada real a Auth desde el navegador en live y en el canal. `firebaseapp.com` está en la lista justo porque por ahí pasa el handler de Google, pero eso es un razonamiento, no una medición. **Disparador:** la próxima vez que alguien entre con Google —basta con que el dueño salga y vuelva a entrar—. Desde 2026-09-17. | el dueño |
| ~~**La API key web del panel no está restringida**~~ **RESUELTO el 2026-09-17**, y lo corrió el dueño porque el clasificador del modo auto frena tocar la key (*"Modify Shared Resources"*) | La key es pública por diseño —viaja adentro de `main.dart.js`, así que guardarla como secret no cambia nada: el navegador la necesita en claro—, pero estaba sin acotar: `browserKeyRestrictions` **vacío** y 27 servicios habilitados, `identitytoolkit` entre ellos. Ahora acepta tres hosts: el panel, `firebaseapp.com` —por donde pasa el handler de Google— y el canal `panel`. **Verificado con las dos mitades, y el antes medido:** un `POST` a `accounts:signInWithPassword` con `Referer` inventado daba **400 `INVALID_LOGIN_CREDENTIALS`** (la atendía) y ahora da **403 blocked**, mientras los tres hosts permitidos siguen dando 400, o sea que llegan. Y de punta a punta con un navegador real pidiendo el correo de contraseña desde live y desde el canal: los dos contestan el aviso, sin nada de bloqueo en consola. ⚠️ **La trampa que sólo apareció con el tercer control: un comodín en medio de una etiqueta (`bouquet-vinos--*.web.app`) la API lo ACEPTA y no matchea nada** — se guarda sin protestar y el canal seguía dando 403. Va el host literal. **Ojo con lo que esto NO es:** el `Referer` lo falsifica cualquiera con `curl -H`, así que corta abuso casual y robo de cuota, no a alguien decidido; contra el registro anticipado lo que protege es la negativa del script (ADR 011), y apagar el alta pública está descartado ahí mismo. **Deja una obligación:** un canal con otro nombre no va a poder entrar hasta que su host esté en la lista — anotado en `publicar.sh`. | el dueño |
| **Ningún change de openspec se archivó nunca** | `openspec/specs/` está **vacío** y hay **4** changes en `openspec/changes/` (`panel-entrar`, `cajas-de-seis`, `catalogo-y-carrito`, `seccion-el-oficio`), todos implementados. Sin línea base publicada, un change nuevo no tiene contra qué diferenciarse. `opsx` trae `openspec-bulk-archive-change` justo para esto, pero las skills de terceros no se commitean (`bash scripts/skills_restaurar.sh`). Archivar sólo uno inventaría una línea base que los otros tres no tienen, así que van los cuatro juntos. **Disparador:** la próxima sesión que empiece con las skills restauradas. Desde 2026-09-17. | el usuario |
| **Los tests del script de accesos no corren en CI** | Corren contra el emulador de Auth, igual que los de reglas, que tampoco están en CI (hallazgo de `revisor-pagos`). Hoy se corren a mano: `firebase emulators:exec --only auth --project demo-bouquet "node --test scripts/acceso/acceso.test.mjs"`. **Disparador:** el mismo que los de reglas, la sesión de `crearOrden`. Desde 2026-09-16. | el usuario |
| ~~⚠️ **Seis preguntas del dueño cambian el backlog del panel**~~ **RESPONDIDAS el 2026-09-16, en dos rondas** | Queda **un dato**: el **número de WhatsApp de la tienda**, que el dueño todavía no tiene y va a pasar. El botón de aviso del panel se activa sólo para quien lo tenga (HU-07.3), y es el mismo número que bloquea `/oficio` (quinto gate, más abajo). El detalle, en [`features/panel/overview.md`](features/panel/overview.md). **Disparador:** cuando el dueño lo pase, y antes de escribir los requerimientos de HU-07.3. Desde 2026-09-16. | el dueño |
| ~~⚠️ **Las reglas nuevas NO están publicadas en `bouquet-vinos`**~~ **RESUELTO el 2026-09-14:** desplegadas con `firebase deploy --only firestore:rules,storage`. Verificado **con la API de Rules**, no con el mensaje del CLI: dos releases con la marca de tiempo del deploy, y el ruleset publicado contiene `cajasSugeridas` (control negativo: una colección inventada da 0). **Las fotos dan 200 `image/webp`.** ⚠️ Al medirlo, la API devolvió **403** por falta de quota project y mi primer script lo leyó como *"ningún release"* — el modo de falla exacto contra el que avisa `CLAUDE.md`. | el dueño |
| ⚠️ **SEXTO GATE: `/pedido` está armado y NO COBRA** | `EL_CHECKOUT_NO_COBRA = true` en `features/carrito/checkout/textos.ts`, y viaja al HTML como `data-checkout-simulado`, así que se chequea con `grep` en el repo **y** con `curl` en producción. Se apaga **sólo** cuando existan las tres cosas: `crearOrden`, la preferencia de Mercado Pago y su webhook verificando firma. CLAUDE.md: *un "Pagar" que llegue antes que su webhook es una venta que se cobra y no se registra*. **Disparador: bloquea el deploy.** Desde 2026-09-15. | el dueño + `functions` |
| ⚠️ **`cajasSugeridas/publicas` de stage quedó VIEJO, y se ve** | El documento sembrado todavía tiene `dos-y-dos` —dos packs de 2 + dos botellas—, que desde [ADR 009 §10](architecture/decisions/009-venta-por-caja.md) no es una caja: el código la descarta y el carril de `/vinos` sirve **3** tarjetas en vez de 4, con el motivo logueado en la build. `dos-de-cada` no existe hasta que corra `node scripts/seed/seed.mjs`. **Disparador:** antes de mirar el carril de stage, y antes del primer deploy. Desde 2026-09-15. | el dueño + `tienda` |
| ⚠️ **El peso y las medidas de una caja de 2 NO están medidos** | El peso sale de `⌈n × 1,118 + 0,6⌉` —la botella la pesó el dueño; el 0,6 del embalaje está **calibrado** para reproducir los 8 kg de la caja de seis, no medido— y el ancho es una proporción de esa caja. Una caja de regalo puede ser más ancha y más chata. **Disparador:** cuando haya una en la mano, y antes de las tarifas reales. Desde 2026-09-15. | el dueño |
| ⚠️ **El glosario quedó DESACTUALIZADO en `Zona` y `Envío`** | Dice que una dirección fuera de toda zona *"no puede comprar"* y que se le avisa antes del carrito, y que el MVP es *"sólo envío a domicilio"*. Con envío a todo el país **eso ya no es cierto**: nadie queda afuera, `Zona` pasa a ser *hasta dónde repartimos nosotros*, y el texto de [`voz.md §9.3`](design/voz.md) queda sin pantalla. No se editó en este cambio a propósito: tocar el glosario adentro de una tarea de feature esconde la decisión adentro del diff de otra cosa. **Disparador:** antes de `crearOrden`, que es quien va a guardar el `Envío`. Desde 2026-09-15. | `vault` |
| **Los precios del cotizador son INVENTADOS** (y los otros dos números ya no) | (a) El **peso** dejó de ser de catálogo: el dueño pesó una botella el 2026-09-15 —**1,118 kg**, o sea 6,666 kg las seis y ~7 kg con caja y relleno—, y se declara **8 del lado seguro**; lo que queda por mirar es **dónde caen los escalones de peso del correo**, porque de eso depende si ese margen cuesta algo. (b) Los **códigos postales de Punilla** dejaron de ser peligrosos al apagarse el reparto propio: hoy sólo prellenan una localidad que el comprador corrige. (c) Los **precios** siguen siendo puro invento y no hay forma de arreglarlos sin tarifas. **Disparador: las tarifas reales del proveedor, antes del primer cobro.** Desde 2026-09-15. | el dueño + `tienda` |
| **El reparto propio en Punilla está APAGADO, y el camino está escrito entero** | `REPARTIMOS_NOSOTROS = false` en `server/envios.ts`, por decisión del dueño (*"de momento no lo vamos a hacer nosotros"*). Prenderlo es una línea, pero **antes** hay que verificar los códigos postales uno por uno con control negativo: con el reparto prendido, un CP mal puesto no falla ruidosamente. **Disparador:** cuando el dueño decida repartir él. Desde 2026-09-15. | el dueño |
| ⚠️ **Nadie confirmó que se pueda despachar alcohol, ni cuánto cobra Mercado Pago** | Ningún correo prohíbe el vino por escrito **y ninguno lo permite por escrito**: es zona gris y se resuelve preguntándole a Envíopack por contacto comercial, no leyendo más documentación. Y la comisión de Mercado Pago no se pudo verificar: las páginas oficiales de costos devuelven **403** y las fuentes de terceros se contradicen entre 2,99 % y 6,99 % + IVA — hay que mirarlo en el panel de la cuenta real. Los dos están en [`proveedores/`](architecture/proveedores/). **Disparador:** antes de contratar y antes de fijar precios. Desde 2026-09-15. | el dueño |
| **El umbral de envío sin cargo no existe, y el lugar donde va ya está** | El dueño lo dejó abierto: *"no sé desde qué monto me conviene"*. Cuando haya tarifas reales, el renglón es el de la entrega más un empujón arriba del total (*"te faltan $X para que el envío salga sin cargo"*). La cuenta ya soporta `precio: 0` y lo dice con palabras, no con un cero. **Disparador:** cuando existan las tarifas del proveedor. Desde 2026-09-15. | el dueño |
| **El comprobante vive en una URL que todavía no existe** | [ADR 010](architecture/decisions/010-el-checkout.md) §6 decide que el comprobante **no va por mail**: va a `/pedido/<numero>` y el link viaja por WhatsApp. Esa ruta no está escrita — hoy no hay número de orden que mostrar. **Disparador:** la sesión de `crearOrden`. Desde 2026-09-15. | `tienda` |
| ⚠️ **`server-only-guard` ofrece una salida que su propia regla no permite** | Su mensaje dice *"Para tipos usá `import type`"*, pero su expresión regular (`import\s+.*['\"]@/server/`) **también bloquea un `import type`**. No molestó en el checkout —la Server Action llega por props, que es mejor—, pero el hook promete algo que no cumple, y eso es exactamente lo que `CLAUDE.md` llama un verde que dice algo falso. Arreglarlo pide un caso nuevo en `probar_hooks.sh`, con su par positivo y negativo. **Disparador:** la próxima vez que alguien necesite un tipo de `server/` en un componente cliente. Desde 2026-09-15. | el usuario |
| **En teléfono, el total del checkout queda abajo de todo el formulario** | La maqueta *el remito* tenía una barra fija con el total y el botón; no se construyó porque hoy el botón está apagado y una barra fija con un botón que no se puede apretar es ruido pegado a la pantalla. **Disparador:** el día que se apague `EL_CHECKOUT_NO_COBRA`. Desde 2026-09-15. | `tienda` |
| ⚠️ **El catálogo real no se despliega sin el tramo 4** | Hasta que Cloudflare cachee con purga por tag, las lecturas escalan con las visitas: con 200 vinos, 115 % de la cuota a 250 visitas/día (ADR 008). Y el tramo 4 tiene que invalidar también la caché de Next, que sirve una página vencida hasta 360 s. Y decidir si la home entra a la purga: hoy envejece hasta el próximo deploy (ADR 008 §7). **Disparador: antes del deploy público.** Desde 2026-09-11. | `functions` + `tienda` |
| **NUEVE hallazgos de `revisor-pagos` para antes de `crearOrden`** | Recrear un producto se saltea la inmutabilidad; precio 0; compuesto sin componentes; `PedidoDeCompra` sin validador; carrito sin tope de líneas; la caché de Next contra la purga; los tests de reglas fuera de CI; reglas y validador que no dicen lo mismo. **El noveno (2026-09-14):** rechazar todo pedido que no sume un múltiplo de `BOTELLAS_POR_CAJA` botellas, recalculado en el servidor ([ADR 009](architecture/decisions/009-venta-por-caja.md)). La tabla está en ADR 008. **Disparador: la sesión de `crearOrden`.** Desde 2026-09-11. | `functions` + `reglas` |
| **El carril de cajas no se miró en un teléfono de verdad** | Se miró a 390 px **emulados** por CDP, que es lo que esta máquina puede: el Chrome headless no baja de 504 px sin emulación. La pista scrollea de lado dentro de su contenedor y eso se juzga con el dedo, no con `scrollWidth`. **Disparador:** la próxima vez que el dueño abra `/vinos` en su teléfono. Desde 2026-09-14. | el dueño |
| ⚠️ **El canal de contacto de `/oficio` es PROVISORIO — quinto gate de deploy** | `EL_CONTACTO_ES_PROVISORIO = true` en `features/oficio/oficio.ts`: el WhatsApp publicado (`+54 9 3548 60-0375`) es el **del desarrollador** y `hola@bouquet.com.ar` no resuelve porque no hay dominio. La constante viaja al HTML como `data-contacto-provisorio`, así que se chequea con `grep` en el repo **y** con `curl` en producción. **Disparador: bloquea el deploy.** Cuando el dueño entregue el WhatsApp real y el dominio: bajar la constante, volver a correr las rutas y el `grep -c` del HTML, y recién ahí desplegar `tienda` — preguntándose antes **qué más se mergeó**, porque el deploy de front reconstruye desde el HEAD pusheado. Desde 2026-09-09. | el dueño + `tienda` |
| ⚠️ **El numeral hueco del tramo `III` lo tiene que mirar el dueño** | Es la tesis de la página dicha con tipografía —"firmamos dos"— y el riesgo lo marcó él: que se lea como que algo se rompió en vez de como una decisión. Yo lo miré renderizado y se lee como decisión (contorno parejo, más el filete al 50 % y el nombre atenuado acompañando), pero la palabra es suya. **Plan B ya escrito** en el design: numeral macizo, nombre en cursiva y filete al 50 %. **Disparador:** abrir `/oficio` y mirarlo. Desde 2026-09-09. | el dueño |
| ⚠️ **La vidriera NO tiene sitemap, ninguna ruta** | Lo destapó `cazador-de-puertas` cerrando `/oficio`: no existe `sitemap.ts`, `sitemap.xml` ni `robots.ts` en todo el repo, así que hoy la única cobertura de descubribilidad es la barra de navegación. No se escribió acá a propósito: un `sitemap.ts` necesita una URL base y **todavía no hay dominio**, así que saldría apuntando a un host inventado. **Disparador: el día que exista dominio** — el mismo día que se puede medir la purga de Cloudflare y que se resuelve el mail del mostrador. Desde 2026-09-09. | el dueño + `tienda` |
| ⚠️ **`frontera-features.sh` no ve los imports RELATIVOS entre features** | Su regla 2 grepea sólo `from '@/features/`. El **mismo** import escrito `from '../landing/seleccion'` **pasa**, medido con los dos controles uno al lado del otro. ADR 006 regla 3 queda a medias: la mide un hook que se esquiva con una ruta relativa. No se tocó en este cambio para no meter una modificación de enforcement adentro de una tarea de feature. **Disparador:** antes de la próxima feature nueva de la vidriera, o el día que alguien escriba un import relativo entre features. Desde 2026-09-09. | el usuario |
| ⚠️ **`call-site-guard` cuenta los sourcemaps del build como call sites** | Grepea `apps/ packages/ functions/ scripts/` enteros, y ahí adentro están `node_modules` y `.next`. Los `*.js.map` **embeben el fuente**, así que un símbolo que no abre nadie aparece "usado" en cuanto corrió un `next build`: dio verde con dos exports huérfanos que un grep acotado a `src/` sí encontró. Es la misma familia que `generar_verdad.mjs` contando comentarios. Y es O(símbolos × repo): sobre un archivo con 8 exports tarda **más de dos minutos**, así que como PostToolUse frena la escritura. **Disparador:** la próxima vez que el hook tarde o que un huérfano pase. Desde 2026-09-09. | el usuario |
| ⚠️ **La home NO tiene puerta de edad, y es la única pieza legal obligatoria** | [ARQUITECTURA §9.5](../../ARQUITECTURA.md#95-alcohol-y-edad) la exige, y es requisito de **arquitectura**: no se va con la composición que se descarta. Las composiciones 4 y 6 sí la construyeron (`PuertaDeEdad.tsx` + `puerta.css`, en `home-parallax-c` y `-d`); **la que ganó se escribió antes de que ese requisito bajara a código**. ⚠️ No se copia y pega: su diseño es decisión de composición y el de `-d` está dibujado con el cartucho del libro túnel. **Disparador: bloquea el deploy.** Desde 2026-09-08. | el dueño + `tienda` |
| **La selección de la home la elige una regla, no el dueño** | `elegirSeleccion` toma seis por ventas, sin agotados ni cajas y con los tres colores. La escena dice "los elegimos de a uno", y eso pide un dato que el modelo no tiene: que el dueño marque cuáles, con su campo en contratos, reglas y panel. **Disparador:** cuando el dueño cargue su catálogo real. Desde 2026-09-11. | el dueño + `contratos` |
| ~~**Las SEIS tarjetas de la home apuntan a fichas que no existen**~~ **Resuelto el 2026-09-11:** salen del catálogo y sus seis fichas dan 200 (ADR 008 §7). | ~~`/vinos` no existe y la home lo apunta dos veces~~ — **resuelto el 2026-09-09**: `/vinos` existe y los dos CTA duros dan 200. Pero contando los `href` del HTML servido aparecieron **seis más**: `/vinos/muestra-01` … `-06`, las tarjetas de `EscenaSeleccion`, todas **404**. El vault decía "dos" y eran **ocho**. No se arreglan con un placeholder: son la ficha, paso 5 de ARQUITECTURA §12, y hacer que `/vinos/<cualquier-cosa>` devuelva 200 es peor que un 404. **Actualizado el 2026-09-11:** `/vinos/[slug]` ya existe, y un slug que no está da 404, que es lo correcto; lo que falta es que las tarjetas apunten a slugs reales. Y sus datos son inventados mientras `LA_SELECCION_ES_DE_MUESTRA` siga en `true`. **Disparador: bloquea el deploy.** Desde 2026-09-09. | el dueño + `tienda` |
| ⚠️ **Los 8 assets están commiteados y no tienen `LICENCIAS.md`** | `ambiente`, `botella`, `cava-h/v`, `mesa-h/v`, `rack-h/v`. La única tabla de licencias verificada que existió es la de los **17 assets de `home-parallax-b`**, y **no cubre a éstos**. De esta misma tanda salió la foto con marca de agua `Unsplash+` tileada, que se descubrió **abriendo el PNG**, no leyendo metadatos. `scripts/assets/traer_landing.py` es la herramienta. **Disparador: antes del deploy.** Desde 2026-09-08. | el dueño |
| **391 KB de `woff2` en la primera pantalla, y son de esta composición** | `parallax.md §8` fija **450 KB** para la primera pantalla en móvil: es el único presupuesto que paga el comprador, y arranca con el **87 % gastado antes de la primera imagen**. Salen de `layout.tsx` (Fraunces con `SOFT`+`WONK`+`opsz`, Newsreader roman e itálica con `opsz`). ⚠️ **Medido el 2026-09-08: el arreglo conocido NO sirve acá.** La composición 6 los bajó a **138 KB** sacando `SOFT` y `opsz`, y ésta usa las dos cosas (`font-variation-settings: 'SOFT' 22` en `sistema.css`, itálica de Newsreader en 4 lugares): sacarlos **cambia el dibujo de la página que se eligió mirando**. La palanca es del dueño. **Disparador: antes del deploy.** Desde 2026-09-08. | el dueño |
| **Los hooks no están vivos todavía** | `.claude/` no existía cuando arrancó la sesión, así que el watcher de settings no lo observa. Hay que abrir `/hooks` una vez, o reiniciar. ~~**Verificado: un Write a `packages/contratos/src/` NO fue bloqueado.**~~ **Resuelto el 2026-09-11:** `vault-precheck` frenó dos escrituras en la sesión del catálogo, así que los hooks corren. | el usuario |
| **`suite_ts` y `suite_dart` nunca corrieron** | Un push a `main` dispara `alcance=rapido`, que **no corre tests**: las dos salen `skipped`. Las suites de `packages/contratos` jamás se ejecutaron en CI. **Disparador:** antes del próximo cambio de lógica, `gh workflow run ci.yml -f alcance=tests`. Desde 2026-09-03. | el usuario |
| **Los signos de `parallax.md §4.1` contradicen a `escenas.md §5`** | La aritmética dice que un plano lento lleva amplitud **positiva**; el snippet del informe la escribe negativa. **Los dos no pueden tener razón, y no lo midió nadie.** No se editó ningún documento a propósito. **Disparador:** scrollear la maqueta con el dedo en un teléfono. Desde 2026-09-03. | el usuario |
| **Hay dos landings y sólo se mergea una** | [`escenas.md`](design/escenas.md) y [`landing-alternativa.md`](design/landing-alternativa.md) resuelven la misma pantalla de dos formas incompatibles. La segunda está construida en `home-parallax`; la primera no está construida. **Disparador:** mirar la rama y elegir. La que pierda se archiva en `changelog/`. Desde 2026-09-04. | el usuario |
| **`generar_verdad.mjs` cuenta comentarios como call sites** | Busca con `new RegExp('\b' + nombre + '\b')` sobre el fuente entero, comentarios incluidos. La palabra `CERO` en un comentario bajó los símbolos "sin puerta" de 16 a 15 **sin que nadie abriera nada**. Se esquivó reformulando el comentario, que es un parche. **Disparador:** la próxima vez que ese número se mueva sin causa. Desde 2026-09-04. | — |
| **El contraste del filete del cartucho no está medido** | `direccion.md §2.1` calcula dorado **puro** sobre tinta en 8,80:1, pero el filete se dibuja al 72 % y al 28 %. Si el píxel renderizado da < 3:1, el cartucho deja de cumplir la función estructural que lo justifica y `escenas.md §2.3` se cae. **Disparador:** junto con `tokens.md`. Desde 2026-09-03. | — |

---

## Decisiones vigentes

| # | Decisión | ADR |
|---|---|---|
| 001 | Vidriera Next.js · panel Flutter en Firebase Hosting · backend Firebase | [001](architecture/decisions/001-stack.md) |
| 002 | La Orden tiene **dos ejes** de estado (pago y entrega), no uno | [002](architecture/decisions/002-estados-de-orden.md) |
| 003 | Proveedor de pagos **diferido**; el contrato del webhook está escrito | [003](architecture/decisions/003-pagos.md) |
| 004 | Frescura por invalidación on-demand · filtrado del catálogo **en memoria** | [004](architecture/decisions/004-frescura-y-lecturas.md) |
| 005 | La vidriera va a **Firebase App Hosting detrás de Cloudflare**; la frescura la da la **purga por tag**, no el ISR | [005](architecture/decisions/005-hosting-vidriera.md) |
| 006 | La vidriera se ordena por **feature**, y `shared/` tiene **cinco reglas** contra el cajón de sastre | [006](architecture/decisions/006-estructura-de-la-tienda.md) |
| 007 | La sección se llama **El oficio**, cubre tres tramos, y el contacto es su cierre | [007](architecture/decisions/007-seccion-el-oficio.md) |
| 008 | El **stock** lo escribe sólo el servidor, en unidades de venta; la vidriera lee **una proyección** por minuto, y el carrito vive en `localStorage` | [008](architecture/decisions/008-catalogo-stock-y-carrito.md) |
| 009 | La botella **suelta** se vende sólo de a 6 — lo que viene en su propia caja **viaja solo** y no cuenta (§10); una caja que ofrece el vendedor **no es un producto**, es un carrito pre-armado | [009](architecture/decisions/009-venta-por-caja.md) |
| 010 | El **código postal** decide cómo viaja el pedido —nadie queda fuera de zona—; se cobra con **Mercado Pago Checkout Pro** y el comprobante **no va por mail** | [010](architecture/decisions/010-el-checkout.md) |
| 011 | Al panel se entra con mail o Google; **las cuentas las crea un script, sin contraseña**, que se niega a habilitar una cuenta sin el mail verificado; el permiso viaja en el token, y se publica **lo que compiló CI** | [011](architecture/decisions/011-entrar-al-panel.md) |

---

## Lo que está pendiente y por qué

Cada pendiente lleva **fecha** y **disparador**. §2.9: una nota escrita en el
momento T describe el estado en T, y nadie tiene el trabajo de volver en T+1 —
por eso los "pendiente de deploy" mienten por construcción.

La lista completa está en
[ARQUITECTURA §11](../../ARQUITECTURA.md#11-lo-que-queda-abierto-con-su-disparador).
Los cuatro que bloquean algo:

| Pendiente | Disparador | Desde |
|---|---|---|
| Proveedor de pagos | Cuando el dueño quiera cobrar online | 2026-09-01 |
| Requisitos legales de venta de alcohol online | Antes de la primera venta real | 2026-09-01 |
| Deploy desde tag en vez de rama | Antes del primer deploy que incluya cobro | 2026-09-01 |
| **Medir la purga de Cloudflare** — [ADR 005](architecture/decisions/005-hosting-vidriera.md) la razona, no la midió | El día que exista dominio | 2026-09-03 |
| **Licencia de las imágenes de la landing** | Antes de publicar el dominio | 2026-09-03 |
| ⚠️ **La venta por caja Y AHORA EL CHECKOUT viajan de POLIZÓN**: están commiteados y **no desplegados**. Seis gates siguen abiertos — el sexto es `EL_CHECKOUT_NO_COBRA`, arriba — más puerta de edad, contacto provisorio, licencias de assets, 391 KB de fuentes y el tramo 4 de Cloudflare. El día que se despliegue `tienda` **se publica también esto**, porque el deploy de front reconstruye desde el HEAD pusheado, no desde el cambio de ese día. Antes de publicar: correr el seed de `cajasSugeridas/publicas` en el proyecto que corresponda —sin ese documento el carril no se renderiza, que es el modo de falla silencioso— y verificar con `curl` el aviso y el carril, con control positivo y negativo | El primer deploy de `tienda`, sea por el motivo que sea | 2026-09-14 |

---

## Antes de creerle a este archivo

- **Un job verde no prueba que compiló; el artifact sí.**
- **Un `Deploy: success` no prueba que publicó; la lista de jobs sí.**
- **Antes de creer que una feature existe, grepeá quién la abre**, no si está
  escrita. Pasó cuatro veces en seis meses en el proyecto anterior.
- **Ante cualquier "¿esto está desplegado?", auditá producción**, no este
  archivo.
