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
no se cobra nada.** `/vinos`, la ficha, `/carrito` y ahora `/pedido` leen **24
vinos reales** de `bouquet-vinos` desde el 2026-09-30 —con precio y stock inventados,
para corregir desde el panel—; la muestra se borró ([ADR 029](architecture/decisions/029-carga-inicial-del-catalogo.md)). El checkout pide los datos y cotiza el
envío **con un cotizador simulado**; **el de Envíopack está escrito y dormido
hasta las claves** ([ADR 030](architecture/decisions/030-cotizar-con-enviopack.md)). Falta `crearOrden`, la preferencia de
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
entera y HU-03.1**. ~~Pedidos sigue vacío y lo dice: es el hito 2.~~ **Desde el 2026-09-24 se cargan y se ven
pedidos de WhatsApp**, primer tramo del hito 2; **desde el 2026-09-25 se avanzan y se
cancelan** (EP-07, primera entrada de abajo).

~~**Cargar un vino está escrito desde el 2026-09-18 y todavía NO desplegado**~~
**Desplegado el 2026-09-21**: HU-03.2 a HU-03.4, reglas (`0310466f`) y panel
(commit `d871218`). Lo próximo del hito 1 era **publicar** —HU-03.5 a 03.7,
**construidas el 2026-09-22** (entrada de arriba)—; lo que sigue pendiente es
el deploy del panel y que alguien cargue y publique un vino real.

**Y desde el 2026-09-17 está PUBLICADO en
[`bouquet-vinos.web.app`](https://bouquet-vinos.web.app)**, con `noindex` y con
la API key acotada por referrer. **El dueño ya entró con Google y tiene el
permiso**: es la única cuenta de Auth. Falta la lista de mails del resto de la
familia — el permiso lo da el script, no una pantalla.

### El cotizador de Envíopack, escrito y dormido hasta las claves (2026-10-01)

**Desplegado dormido y verificado el 2026-10-01** (v0.52.0, rollout `build-2026-10-01-002`): CI
restada (tienda 43 → 73), la copia idéntica al commit, `preview.sh verificar`, el canario de la
provincia llamando la Server Action (`1425`: `B` → `C`, `1900` sigue `B`, el precio no se movió) y
Chrome por CDP (una cotización por CP, una más al corregir la provincia, cero en reposo). Lo pidió el dueño: *"armemos la estructura para los
envíos, apenas tenga el token lo agregamos"*. Detalle en
[ADR 030](architecture/decisions/030-cotizar-con-enviopack.md).

- **`server/enviopack.ts`**: pide el token, lo guarda 3 h 45, cotiza el **precio** a domicilio
  y se queda con la opción más barata que sea de **este** envío (servicio de entrega, banda de
  peso del pedido). Lo que no se puede leer se descarta y, si no queda nada, va al log con el
  motivo. **A sucursal no**: pide un id de localidad que no se busca por código postal.
- **Contesta según el entorno**: con las dos claves, Envíopack; sin ninguna, el simulado,
  **sólo mientras el checkout no cobre**; con una, nadie.
- **La provincia que viaja es la del comprador**: del 1000 al 1499 es CABA (antes se adivinaba
  Buenos Aires), y corregirla vuelve a cotizar sin cotizar dos veces cada código postal.
- **El "token" son dos claves**, `api-key` y `secret-key`: el token dura cuatro horas y lo pide
  el servidor. Van como secretos de App Hosting; el bloque está **comentado** en
  `apphosting.yaml` con los comandos al lado.
- Workflow D: `revisor-pagos` encontró 11; se arreglaron A1-A3, M1 y los tests de B4, y quedan
  dos con disparador. Cero lecturas.

**Lo que sigue:** las claves, y antes de prenderlas con el dominio publicado, el tope de la Server
Action (M2) y decir *"estimado"* cuando el precio es del simulado (A4). Desde 2026-10-01.

### El +18 se dice en tres lugares, no en cuatro: el pie de la home deja de repetir el telón (2026-10-01)

**Desplegado y verificado el 2026-10-01** (v0.51.8, rollout `build-2026-10-01-001`). Lo pidió el
dueño: *"con la cortina del inicio alcanza, se pone denso"*. Detalle en
[ADR 028 §8](architecture/decisions/028-la-puerta-de-edad.md).

- **Sale la línea del documento del pie de la home**: repetía palabra por palabra la del telón.
  Quedan el telón, la leyenda legal del pie (*"Prohibida su venta a menores de 18 años"*) y la del
  checkout, que dice quién tiene que recibir.
- **Canario discriminante en `/`**: el pie viejo 1 → 0, con el telón (espacio duro) y la leyenda en 1
  como control positivo y la ruta inventada en 0. `preview.sh verificar` en verde y la copia
  desplegada idéntica al commit. Cero lecturas; sólo presentación. **No se miró renderizado**: es
  un párrafo menos, y lo prueba el diff.

**Lo que sigue:** si el dueño quiere bajar más, el candidato es la leyenda del pie, previa
confirmación de que no es obligatoria en el sitio propio. Desde 2026-10-01.

### El ícono del carrito es una bolsa de Heroicons, no un octógono dibujado a mano (2026-09-30)

**Desplegado y verificado el 2026-09-30** (v0.51.6, rollout `build-2026-09-30-008`): el canario
discrimina —el path nuevo 0 → 1, el viejo 1 → 0 en `/`, `/vinos` y `/carrito`—, `preview.sh
verificar` en verde y Chrome por CDP a **1280 y 390** con las capturas miradas. Lo pidió el
dueño: *"no me gusta el carrito o la bolsita esa"*. Detalle y descartes en
[ADR 008 §8](architecture/decisions/008-catalogo-stock-y-carrito.md).

- **La quinta bolsa dibujada a mano se leía como un frasco.** Se bajaron 28 glifos de ocho
  librerías, se renderizaron dentro de la barra real y el dueño eligió `shopping-bag` de
  Heroicons —el análisis había puesto primero `ph-thin-bag`—. Va **copiado como un SVG**,
  sin instalar la librería; el trazo sigue siendo el de la marca.
- **No existe una librería de íconos art déco**, y forzar `miter`/`butt` no endereza las
  esquinas redondeadas: vienen en el path.
- Cero lecturas; sólo presentación.

**Lo que sigue:** que el dueño la mire en su teléfono. A 390 px el glifo mide 16 px, el piso del
`clamp`; en la captura se lee, pero es el tamaño más chico. Desde 2026-09-30.

### La placa de la caja dice la mezcla: nadie compra seis de un vino por error (2026-09-30)

**Desplegado y verificado el 2026-09-30** (v0.51.4, `build-2026-09-30-007`): canarios
discriminantes en la ficha y `/vinos` (viejo 2 → 0, nuevo 0 → 2, cada nota sólo en su lugar) y
Chrome por CDP a 390 y 1280, con el botón tocado. Lo preguntó el usuario mirando
la ficha en producción: *"¿no pueden confundirse y creer que tiene que comprar una caja de 6
de ese vino?"*. Detalle en [ADR 009 §11](architecture/decisions/009-venta-por-caja.md).

- En el teléfono la ficha decía `SE VENDE POR CAJA · 6 botellas` al lado de **un** vino: la
  nota que decía la mezcla está oculta abajo de 480 px. **El rótulo pasa a decirla**: *"Armá
  tu caja con los vinos que quieras"*.
- La ficha y `/vinos` tienen **cada una su nota**; la excepción de las cajas propias queda
  sólo en `/vinos`. El botón de la botella suelta dice **"Agregar una botella"**.
- Curado por `voz`, que cambió dos de las cinco cadenas. Cero lecturas.

**Lo que sigue:** mostrarle la ficha en un teléfono a alguien que no conoce la tienda y
preguntarle cuántas botellas de ese vino tiene que comprar. Desde 2026-09-30.

### El catálogo real: 24 vinos con foto y descripción, y la muestra afuera (2026-09-30)

**Cargado en producción y verificado el 2026-09-30**, a pedido del dueño: pasó la lista de
lo que sabe que tiene —*"es más la mitad"*— y pidió las fichas con fotos y descripciones,
precios y stock inventados. Detalle y descartes en
[ADR 029](architecture/decisions/029-carga-inicial-del-catalogo.md).

- **`scripts/catalogo/cargar.mjs`** da de alta como el panel —sin `muestra`, id igual al
  slug— y **nunca pisa**: lo que el dueño corrija manda, y la segunda mitad entra
  agregándola al JSON y volviendo a correr. La foto pasa por `scripts/seed/foto.mjs`, la
  tubería que ahora comparten los dos scripts y que `tuberia.test.ts` compara con la callable.
- **15 bodegas y 24 vinos** (23 publicados; *Cordero con Piel de Lobo Dulce* es borrador
  hasta confirmar la uva). Se borraron los 20 de muestra, sus 11 bodegas y sus fotos.
- **Cajas sugeridas rearmadas** con vinos reales, **portada elegida** —a pedido del dueño:
  seis vinos de seis bodegas, se cambia desde *Vidriera*— y **los dos vinos de prueba
  borrados** (`ve` y `vino-de-prueba`); el Pedido 1 queda, con su copia del renglón.
- Verificado por contenido: las fotos por SHA-256, `/vinos` y cuatro fichas en vivo con
  canarios que aparecen y desaparecen, y renderizado a 1280 y 390.
- **El segundo párrafo de las 24 descripciones, reescrito el mismo día a pedido del dueño**:
  22 nombraban comida con el mismo molde. Ahora sale de lo que ese vino tiene de propio, sin
  ventana de consumo y con cada hecho chequeado en una fuente. Escrito en Firestore (sólo
  `fichaVino.descripcion`); la regla nueva está en [voz §3.3](design/voz.md) y en el agente
  `voz`, así que la segunda mitad del catálogo no la repite ([ADR 029 §5](architecture/decisions/029-carga-inicial-del-catalogo.md)).

**Tienda desplegada** para que la home se hornee con lo real: `build-2026-09-30-006`,
`preview.sh verificar` en verde. El anterior (005) salió sin `noindex` por la v0.50.0, que
se revirtió ([ADR 017 §4](architecture/decisions/017-preview-cerrada.md)).

**Lo que sigue:** que el dueño corrija precio, stock y las añadas marcadas con la botella en
la mano, y publique el Dulce. Desde 2026-09-30.

### Lo que quedó abierto

| Qué | Por qué | Quién |
|---|---|---|
| ~~⚠️ **La callable `procesarFoto` NO es alcanzable desde el navegador: el preflight da 403, y el panel lo muestra como error de CORS**~~ **RESUELTO el 2026-09-23, por el dueño** | Lo vio usando el panel; medido después con `curl` crudo el 2026-09-22, y el `ACTIVE` de la API de Cloud Functions **no lo veía**. `OPTIONS` con `Origin` y `Access-Control-Request-Method: POST` devolvía **403 Forbidden** de `Google Frontend`, **sin un solo header `Access-Control-Allow-*`**. **Control negativo:** una function inventada daba **404**. **El control que aisló la causa:** un `POST` anónimo devolvía **el mismo 403 HTML**, no el JSON `UNAUTHENTICATED` de la callable — el código nunca corría, lo frenaba IAM antes. Faltaba `allUsers` como `roles/run.invoker`. **No era el bucket** (medido aparte). El clasificador de permisos frenó el otorgamiento dos veces el 2026-09-23 —la segunda con autorización explícita en la conversación—, así que lo corrió **el dueño a mano**. **Verificado con los mismos tres controles:** el preflight ahora da **204** con los headers de CORS, el negativo **sigue en 404**, y el `POST` anónimo ahora da **401 JSON real** (`UNAUTHENTICATED`) en vez del HTML de IAM. Detalle completo en [ADR 015](architecture/decisions/015-fotos-del-panel.md#lo-que-falta). | el dueño + `functions` |
| ✅ **Escrito el 2026-09-23: el formulario del vino usa el espacio de escritorio con dos columnas** (`DisposicionDelFormulario`, ADR 015 §6) — reemplaza el `ConstrainedBox(maxWidth: 640)` fijo. Debajo de 900 px sigue apilado en una columna, igual que antes (celular, y Android). **Desplegado el 2026-09-23** (v0.29.0, bytes verificados con canario), **pero nadie lo miró renderizado.** | Lo vio el dueño mirándolo — CLAUDE.md: compilar, pasar tests y desplegarse son tres cosas distintas de que **alguien lo haya mirado renderizado**, y eso sigue pendiente acá. **Disparador:** que el dueño lo mire renderizado, en escritorio y en Android. Desde 2026-09-22. | el dueño + `admin-presentacion` |
| ✅ **Escrito el 2026-09-23: cargar un vino, sumarle una foto y publicarlo pasan a ser UN gesto** (ADR 015 §5) — se revirtió, sólo para `imagenes` y `publicado`, la exclusión de `AltaDeVino`/`documentoNuevo` que forzaba los tres viajes separados; `stock` y `tipo` siguen sin salir del alta, sin tocar. `SeccionDeFotos` sube con el slug todavía sin guardar (`agregarAlDocumento: false`, sin `arrayUnion` hasta confirmar); `PieDelFormulario` suma el tilde **"Publicar apenas se cargue"**, con default `true`. Medido antes de escribir: ni `procesarFoto`, ni `storage.rules`, ni `firestore.rules` pedían el documento guardado — sólo lo pedía el panel. **Desplegado el 2026-09-23** (v0.29.0, CI verde con la suite de Dart), **todavía sin verificar con el dueño cargando un vino de verdad.** El default `true` del tilde es una decisión de producto, no sólo técnica: queda para que el dueño la confirme o la cambie. | El dueño lo dijo con las palabras del que lo usa: *"no tiene sentido primero cargar el vino, para después subir la foto, para después activar"*. **Disparador:** que el dueño cargue un vino real, con foto, en un solo gesto — y confirme o cambie el default `true` del tilde. Desde 2026-09-22. | el dueño + `admin-presentacion` + `admin-datos` |
| **Falta la lista de mails de la familia** | El **dueño ya entra**: entró con Google el 2026-09-17 y `acceso.mjs dar` le puso el claim —verificado leyendo su registro, `{"rol":"admin"}`, y el listador pasó de 0 a 1—. Es la única cuenta de Auth. Para cada uno de los demás: `node scripts/acceso/acceso.mjs dar <mail>`, y que entre con Google o toque *"¿No tenés contraseña?"*. **El orden importa poco:** si entran antes de tener permiso, caen en `/sin-acceso` y con el botón *"Ya me dieron acceso"* pasan sin volver a escribir nada. **Disparador:** cuando el dueño pase los mails. Desde 2026-09-16. | el dueño |
| ~~**Entrar con Google no está verificado en live por una persona**~~ **VERIFICADO el 2026-09-17: lo hizo el dueño** | Entró con Google en live, se le creó la cuenta —`providers: google.com`, mail verificado, sin claims— y cayó en `/sin-acceso`, que es exactamente lo que el diseño dice que pase. ⚠️ **Queda un hueco chico:** eso fue **antes** de acotar la API key, así que el flujo de Google **con la restricción puesta** no está probado. Lo que sí está probado con la restricción es una llamada real a Auth desde el navegador en live y en el canal. `firebaseapp.com` está en la lista justo porque por ahí pasa el handler de Google, pero eso es un razonamiento, no una medición. **Disparador:** la próxima vez que alguien entre con Google —basta con que el dueño salga y vuelva a entrar—. Desde 2026-09-17. | el dueño |
| ~~**La API key web del panel no está restringida**~~ **RESUELTO el 2026-09-17**, y lo corrió el dueño porque el clasificador del modo auto frena tocar la key (*"Modify Shared Resources"*) | La key es pública por diseño —viaja adentro de `main.dart.js`, así que guardarla como secret no cambia nada: el navegador la necesita en claro—, pero estaba sin acotar: `browserKeyRestrictions` **vacío** y 27 servicios habilitados, `identitytoolkit` entre ellos. Ahora acepta tres hosts: el panel, `firebaseapp.com` —por donde pasa el handler de Google— y el canal `panel`. **Verificado con las dos mitades, y el antes medido:** un `POST` a `accounts:signInWithPassword` con `Referer` inventado daba **400 `INVALID_LOGIN_CREDENTIALS`** (la atendía) y ahora da **403 blocked**, mientras los tres hosts permitidos siguen dando 400, o sea que llegan. Y de punta a punta con un navegador real pidiendo el correo de contraseña desde live y desde el canal: los dos contestan el aviso, sin nada de bloqueo en consola. ⚠️ **La trampa que sólo apareció con el tercer control: un comodín en medio de una etiqueta (`bouquet-vinos--*.web.app`) la API lo ACEPTA y no matchea nada** — se guarda sin protestar y el canal seguía dando 403. Va el host literal. **Ojo con lo que esto NO es:** el `Referer` lo falsifica cualquiera con `curl -H`, así que corta abuso casual y robo de cuota, no a alguien decidido; contra el registro anticipado lo que protege es la negativa del script (ADR 011), y apagar el alta pública está descartado ahí mismo. **Deja una obligación:** un canal con otro nombre no va a poder entrar hasta que su host esté en la lista — anotado en `publicar.sh`. | el dueño |
| **Ningún change de openspec se archivó nunca** | `openspec/specs/` está **vacío** y hay **4** changes en `openspec/changes/` (`panel-entrar`, `cajas-de-seis`, `catalogo-y-carrito`, `seccion-el-oficio`), todos implementados. Sin línea base publicada, un change nuevo no tiene contra qué diferenciarse. `opsx` trae `openspec-bulk-archive-change` justo para esto, pero las skills de terceros no se commitean (`bash scripts/skills_restaurar.sh`). Archivar sólo uno inventaría una línea base que los otros tres no tienen, así que van los cuatro juntos. **Disparador:** la próxima sesión que empiece con las skills restauradas. Desde 2026-09-17. | el usuario |
| ~~**Los tests del script de accesos no corren en CI**~~ **RESUELTO el 2026-09-28**: corren en CI desde [ADR 021](architecture/decisions/021-aviso-de-despacho.md), con piso de 11 desde el 2026-09-29 | Corren contra el emulador de Auth. ~~Igual que los de reglas, que tampoco están en CI~~: **los de reglas y los de las transacciones sí corren en CI desde el 2026-09-25** (job `suite_emulador`, [ADR 019 §8](architecture/decisions/019-preparar-despachar-y-cancelar.md)); éste quedó afuera porque pide el emulador de Auth. Hoy se corren a mano: `firebase emulators:exec --only auth --project demo-bouquet "node --test scripts/acceso/acceso.test.mjs"`. **Disparador:** el mismo que los de reglas, la sesión de `crearOrden`. Desde 2026-09-16. | el usuario |
| ~~⚠️ **Seis preguntas del dueño cambian el backlog del panel**~~ **RESPONDIDAS el 2026-09-16, en dos rondas** | Queda **un dato**: el **número de WhatsApp de la tienda**, que el dueño todavía no tiene y va a pasar. El botón de aviso del panel se activa sólo para quien lo tenga (HU-07.3), y es el mismo número que bloquea `/oficio` (quinto gate, más abajo). El detalle, en [`features/panel/overview.md`](features/panel/overview.md). ~~**Disparador:** cuando el dueño lo pase, y antes de escribir los requerimientos de HU-07.3.~~ **HU-07.3 ya no lo espera** (2026-09-28, [ADR 021](architecture/decisions/021-aviso-de-despacho.md)): el número no entra al código, decide a quién se le da la marca `avisaPorWhatsApp`. **Desde el 2026-09-29 no hay marca**: el botón lo ve todo el que entra (ADR 021, *Revisión*). **Sigue bloqueando `/oficio`.** **Disparador:** cuando el dueño lo pase. Desde 2026-09-16. | el dueño |
| ~~⚠️ **Las reglas nuevas NO están publicadas en `bouquet-vinos`**~~ **RESUELTO el 2026-09-14:** desplegadas con `firebase deploy --only firestore:rules,storage`. Verificado **con la API de Rules**, no con el mensaje del CLI: dos releases con la marca de tiempo del deploy, y el ruleset publicado contiene `cajasSugeridas` (control negativo: una colección inventada da 0). **Las fotos dan 200 `image/webp`.** ⚠️ Al medirlo, la API devolvió **403** por falta de quota project y mi primer script lo leyó como *"ningún release"* — el modo de falla exacto contra el que avisa `CLAUDE.md`. | el dueño |
| ⚠️ **SEXTO GATE: `/pedido` está armado y NO COBRA** | `EL_CHECKOUT_NO_COBRA = true` en `features/carrito/checkout/textos.ts`, y viaja al HTML como `data-checkout-simulado`, así que se chequea con `grep` en el repo **y** con `bash scripts/tienda/preview.sh verificar` en lo desplegado (⚠️ **no** con `curl /pedido | grep`: da 0 con el gate cerrado, ver [ADR 010](architecture/decisions/010-el-checkout.md)). Se apaga **sólo** cuando existan las tres cosas: `crearOrden`, la preferencia de Mercado Pago y su webhook verificando firma. CLAUDE.md: *un "Pagar" que llegue antes que su webhook es una venta que se cobra y no se registra*. ~~**Disparador: bloquea el deploy.**~~ **Desde el 2026-09-30, por decisión del dueño, NO bloquea la publicación**: con el botón deshabilitado no se cobra nada, y `/pedido` manda a WhatsApp. **Bloquea encender el botón**, y Mercado Pago necesita el dominio para existir. Desde 2026-09-15. | el dueño + `functions` |
| ⚠️ **`cajasSugeridas/publicas` de stage quedó VIEJO, y se ve** | El documento sembrado todavía tiene `dos-y-dos` —dos packs de 2 + dos botellas—, que desde [ADR 009 §10](architecture/decisions/009-venta-por-caja.md) no es una caja: el código la descarta y el carril de `/vinos` sirve **3** tarjetas en vez de 4, con el motivo logueado en la build. `dos-de-cada` no existe hasta que corra `node scripts/seed/seed.mjs`. **Disparador:** antes de mirar el carril de stage, y antes del primer deploy. Desde 2026-09-15. | el dueño + `tienda` |
| ⚠️ **El peso y las medidas de una caja de 2 NO están medidos** | El peso sale de `⌈n × 1,118 + 0,6⌉` —la botella la pesó el dueño; el 0,6 del embalaje está **calibrado** para reproducir los 8 kg de la caja de seis, no medido— y el ancho es una proporción de esa caja. Una caja de regalo puede ser más ancha y más chata. **Disparador:** cuando haya una en la mano, y antes de las tarifas reales. Desde 2026-09-15. | el dueño |
| ⚠️ **El glosario quedó DESACTUALIZADO en `Zona` y `Envío`** | Dice que una dirección fuera de toda zona *"no puede comprar"* y que se le avisa antes del carrito, y que el MVP es *"sólo envío a domicilio"*. Con envío a todo el país **eso ya no es cierto**: nadie queda afuera, `Zona` pasa a ser *hasta dónde repartimos nosotros*, y el texto de [`voz.md §9.3`](design/voz.md) queda sin pantalla. No se editó en este cambio a propósito: tocar el glosario adentro de una tarea de feature esconde la decisión adentro del diff de otra cosa. **Disparador:** antes de `crearOrden`, que es quien va a guardar el `Envío`. Desde 2026-09-15. | `vault` |
| **Los precios del cotizador son INVENTADOS** (y los otros dos números ya no) | (a) El **peso** dejó de ser de catálogo: el dueño pesó una botella el 2026-09-15 —**1,118 kg**, o sea 6,666 kg las seis y ~7 kg con caja y relleno—, y se declara **8 del lado seguro**; lo que queda por mirar es **dónde caen los escalones de peso del correo**, porque de eso depende si ese margen cuesta algo. (b) Los **códigos postales de Punilla** dejaron de ser peligrosos al apagarse el reparto propio: hoy sólo prellenan una localidad que el comprador corrige. (c) Los **precios** siguen siendo puro invento y no hay forma de arreglarlos sin tarifas. **Disparador: las tarifas reales del proveedor, antes del primer cobro.** Desde 2026-09-15. | el dueño + `tienda` |
| **El cotizador de Envíopack está escrito y DORMIDO: faltan las dos claves** | `api-key` y `secret-key` de la cuenta de Envíopack. Se cargan con `firebase apphosting:secrets:set`, se descomenta el bloque de `apps/tienda/apphosting.yaml` y se despliega la tienda: los pasos y la tabla de lo que hay que medir están en [ADR 030](architecture/decisions/030-cotizar-con-enviopack.md), *Cómo se prende*. Con las claves, *a sucursal* desaparece del checkout (§2). **Antes de prenderlas con el dominio publicado:** el tope de la Server Action (M2) y el *"estimado"* del simulado (A4) | El dueño (las claves) |
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
| ~~**El numeral hueco del tramo `III` lo tiene que mirar el dueño**~~ **RESUELTO el 2026-09-30: lo miró y eligió el plan B** | Se leía como roto (*"I y II están pintados y III está outline"*). Ahora el numeral es macizo en los tres tramos y la distinción la dicen el nombre —*Abrir* en cursiva de Newsreader, caja baja— y el filete al 50 % ([ADR 007](architecture/decisions/007-seccion-el-oficio.md)). | — |
| ⚠️ **La vidriera NO tiene sitemap, ninguna ruta** | Lo destapó `cazador-de-puertas` cerrando `/oficio`: no existe `sitemap.ts`, `sitemap.xml` ni `robots.ts` en todo el repo, así que hoy la única cobertura de descubribilidad es la barra de navegación. No se escribió acá a propósito: un `sitemap.ts` necesita una URL base y **todavía no hay dominio**, así que saldría apuntando a un host inventado. **Disparador: el día que exista dominio** — el mismo día que se puede medir la purga de Cloudflare y que se resuelve el mail del mostrador. Desde 2026-09-09. | el dueño + `tienda` |
| ⚠️ **`frontera-features.sh` no ve los imports RELATIVOS entre features** | Su regla 2 grepea sólo `from '@/features/`. El **mismo** import escrito `from '../landing/seleccion'` **pasa**, medido con los dos controles uno al lado del otro. ADR 006 regla 3 queda a medias: la mide un hook que se esquiva con una ruta relativa. No se tocó en este cambio para no meter una modificación de enforcement adentro de una tarea de feature. **Disparador:** antes de la próxima feature nueva de la vidriera, o el día que alguien escriba un import relativo entre features. Desde 2026-09-09. | el usuario |
| ⚠️ **`call-site-guard` cuenta los sourcemaps del build como call sites** | Grepea `apps/ packages/ functions/ scripts/` enteros, y ahí adentro están `node_modules` y `.next`. Los `*.js.map` **embeben el fuente**, así que un símbolo que no abre nadie aparece "usado" en cuanto corrió un `next build`: dio verde con dos exports huérfanos que un grep acotado a `src/` sí encontró. Es la misma familia que `generar_verdad.mjs` contando comentarios. Y es O(símbolos × repo): sobre un archivo con 8 exports tarda **más de dos minutos**, así que como PostToolUse frena la escritura. **Disparador:** la próxima vez que el hook tarde o que un huérfano pase. Desde 2026-09-09. | el usuario |
| ~~**La home NO tiene puerta de edad, y es la única pieza legal obligatoria**~~ **Resuelto el 2026-09-30** ([ADR 028](architecture/decisions/028-la-puerta-de-edad.md)): el telón está en el layout raíz, en todas las rutas. Lo de abajo queda como historia | [ARQUITECTURA §9.5](../../ARQUITECTURA.md#95-alcohol-y-edad) la exige, y es requisito de **arquitectura**: no se va con la composición que se descarta. Las composiciones 4 y 6 sí la construyeron (`PuertaDeEdad.tsx` + `puerta.css`, en `home-parallax-c` y `-d`); **la que ganó se escribió antes de que ese requisito bajara a código**. ⚠️ No se copia y pega: su diseño es decisión de composición y el de `-d` está dibujado con el cartucho del libro túnel. **Disparador: bloquea el deploy.** Desde 2026-09-08. | el dueño + `tienda` |
| ~~**La selección de la home la elige una regla, no el dueño**~~ **Resuelto el 2026-09-28** ([ADR 023](architecture/decisions/023-la-portada-la-elige-el-duenio.md)): la elige desde el panel, en *Vidriera*. Lo que queda es que la elija, con el catálogo real | `elegirSeleccion` toma seis por ventas, sin agotados ni cajas y con los tres colores. La escena dice "los elegimos de a uno", y eso pide un dato que el modelo no tiene: que el dueño marque cuáles, con su campo en contratos, reglas y panel. **Disparador:** cuando el dueño cargue su catálogo real. Desde 2026-09-11. | el dueño + `contratos` |
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
| 009 | La botella **suelta** se vende sólo de a 6 — lo que viene en su propia caja **viaja solo** y no cuenta (§10); una caja que ofrece el vendedor **no es un producto**, es un carrito pre-armado; que las seis **se mezclan** lo dice el rótulo, que se ve en el teléfono (§11) | [009](architecture/decisions/009-venta-por-caja.md) |
| 010 | El **código postal** decide cómo viaja el pedido —nadie queda fuera de zona—; se cobra con **Mercado Pago Checkout Pro** y el comprobante **no va por mail** | [010](architecture/decisions/010-el-checkout.md) |
| 011 | Al panel se entra con mail o Google; **las cuentas las crea un script, sin contraseña**, que se niega a habilitar una cuenta sin el mail verificado; el permiso viaja en el token, y se publica **lo que compiló CI** | [011](architecture/decisions/011-entrar-al-panel.md) |
| 018 | Un pedido de WhatsApp se carga por **una callable del panel** que fija el origen; su cobro es **`por_fuera`** (terminal); el documento es su propio marcador; **cada venta deja su movimiento** | [018](architecture/decisions/018-pedidos-de-whatsapp.md) |
| 022 | Lo que dice Mercado Pago entra por **un solo núcleo** (aviso y re-consulta); el marcador es **por hecho** —corrige ADR 003—; lo que movió plata y no se aplicó deja **`alertaDePago`** | [022](architecture/decisions/022-cobro-de-la-vidriera.md) |
| 023 | La portada la elige el dueño: **`seleccion/publica`**, hasta 6 ids en su orden, que el panel escribe directo; sin elección, la regla. Los plazos que dice el panel viven en **`cuando_se_ve.dart`** | [023](architecture/decisions/023-la-portada-la-elige-el-duenio.md) |
| 024 | Las cajas sugeridas se guardan **enteras por la callable `guardarCajasSugeridas`**: el slug lo deriva el servidor, y exige composición, no publicado ni stock | [024](architecture/decisions/024-cajas-sugeridas-desde-el-panel.md) |
| 025 | El panel se entra por **Resumen**: el día con `count()` y `limit(50)`, lo agotado en memoria; la popularidad la **mide un job diario** que recalcula el documento entero, y sin medición no hay ranking | [025](architecture/decisions/025-el-tablero-del-panel.md) |
| 026 | El umbral de la entrega sin cargo vive en **`config/envios`**, lo escribe **sólo `fijarEnvioSinCargo`** con una baranda sobre el valor nuevo que **pregunta**; la vidriera lo muestra, y lo que se cobra lo decide `crearOrden` | [026](architecture/decisions/026-envio-sin-cargo.md) |
| 028 | La puerta de edad es un **telón sobre el sitio entero** montado en el layout raíz, que **no bloquea el render**: un script en línea la esconde antes del primer pintado para quien ya entró, `inert` sale del efecto y no de una prop, y **sin JavaScript no se muestra** | [028](architecture/decisions/028-la-puerta-de-edad.md) |
| 029 | El catálogo real entra por **`scripts/catalogo/cargar.mjs`**, que escribe como el panel (sin `muestra`), **nunca pisa** y pasa la foto por la tubería compartida; el stock inventado nace **sin movimiento** | [029](architecture/decisions/029-carga-inicial-del-catalogo.md) |

---

## Lo que está pendiente y por qué

Cada pendiente lleva **fecha** y **disparador**. §2.9: una nota escrita en el
momento T describe el estado en T, y nadie tiene el trabajo de volver en T+1 —
por eso los "pendiente de deploy" mienten por construcción.

La lista completa está en
[ARQUITECTURA §11](../../ARQUITECTURA.md#11-lo-que-queda-abierto-con-su-disparador).
Los que bloquean algo:

| Pendiente | Disparador | Desde |
|---|---|---|
| Proveedor de pagos | Cuando el dueño quiera cobrar online | 2026-09-01 |
| Requisitos legales de venta de alcohol online | Antes de la primera venta real | 2026-09-01 |
| Deploy desde tag en vez de rama | Antes del primer deploy que incluya cobro | 2026-09-01 |
| **Medir la purga de Cloudflare** — [ADR 005](architecture/decisions/005-hosting-vidriera.md) la razona, no la midió | El día que exista dominio | 2026-09-03 |
| **Licencia de las imágenes de la landing** | Antes de publicar el dominio | 2026-09-03 |
| ⚠️ **La venta por caja Y AHORA EL CHECKOUT viajan de POLIZÓN**: están commiteados y **no desplegados**. Seis gates siguen abiertos — el sexto es `EL_CHECKOUT_NO_COBRA`, arriba — más ~~puerta de edad~~ (resuelta el 2026-09-30, [ADR 028](architecture/decisions/028-la-puerta-de-edad.md)), contacto provisorio, licencias de assets, 391 KB de fuentes y el tramo 4 de Cloudflare. El día que se despliegue `tienda` **se publica también esto**, porque el deploy de front reconstruye desde el HEAD pusheado, no desde el cambio de ese día. Antes de publicar: ~~correr el seed de `cajasSugeridas/publicas`~~ (desde el 2026-09-30 el documento tiene cajas de vinos reales, [ADR 029](architecture/decisions/029-carga-inicial-del-catalogo.md) §6) y verificar con `curl` el aviso y el carril, con control positivo y negativo | El primer deploy de `tienda`, sea por el motivo que sea | 2026-09-14 |
| **HU-04.2 — ordenar las fotos que NO son la principal.** Elegir la principal se construyó el 2026-09-24 ([ADR 015 §7](architecture/decisions/015-fotos-del-panel.md)); la vidriera lee sólo `imagenes[0]`, así que ordenar el resto no cambia nada visible | El día que la ficha muestre más de una foto | 2026-09-22 |
| **El recorte de fondo de una foto de cámara**, con un modelo real — el clasificador por umbral se midió y se refutó (ADR 015 §2) | Que la previsualización resulte insuficiente, mirándola | 2026-09-22 |
| **Los crudos huérfanos en Storage** si `procesarFoto` falla a mitad de camino: no son alcanzables y no rompen nada. Entre el 2026-09-22 y el 2026-09-23 se produjo uno en CADA intento de subida, mientras el preflight de la callable daba 403 — **RESUELTO el CORS el 2026-09-23** ([ADR 015](architecture/decisions/015-fotos-del-panel.md)), vuelve a ser el caso raro original | Cuando pesen, y hay que barrer los que deje un fallo a mitad de camino | 2026-09-22 |
| ⚠️ **El color del papel de la previsualización está copiado entre el panel (Dart, `Tokens.papelVentana`) y la vidriera (CSS, `--papel-ventana`)** — puede desincronizarse, sin nada automático que lo detecte | La próxima vez que alguien toque uno de los dos sistemas de diseño | 2026-09-22 |
| **4.3 — probar `procesarFoto` en producción con un usuario real, bloqueado por el clasificador — pero el 2026-09-23 alguien subió una foto desde el panel a `vino-de-prueba` y se sirve (200 `image/webp`), así que la callable anda en producción; queda la parte de 10.1 de mirarla en la tienda con un vino de verdad** (otorgar `iam.serviceAccountTokenCreator`, aunque temporal y reversible, es "Permission Grant") | Que el usuario autorice el rol temporal, o que el dueño suba una foto real (10.1) — lo que pase primero | 2026-09-22 |
| ⚠️ **`corregir` pisa lo vendido y todavía no despachado** ([ADR 016](architecture/decisions/016-mover-el-stock.md), hallazgo 1): con 2 botellas vendidas sin despachar, el panel muestra 8, el operador cuenta 10 en la estantería y `visto` coincide — quedan 10 y se venden 2 que no existen. Hoy no se puede disparar (no hay órdenes). **Bloquea `crearOrden`**: la hoja tiene que mostrar *"N vendidas sin despachar"* | **Disparador: bloquea el deploy de `crearOrden`.** | 2026-09-23 |
| ⚠️ **Tramo 4 y los plazos que dice el panel**: `apps/admin/lib/core/presentation/cuando_se_ve.dart` promete *"hasta unos 13 minutos"* para el catálogo y *"la próxima vez que se publique la tienda"* para la portada. Con la purga por tag los dos mienten al revés ([ADR 023 §6](architecture/decisions/023-la-portada-la-elige-el-duenio.md)) | Cuando se escriba el tramo 4 | 2026-09-28 |
| ⚠️ **Tramo 4 y `moverStock`**: cada movimiento va a disparar la purga de la vidriera, y si cambia el balde de un vino publicado son **232 lecturas** —no las ~20 de ARQUITECTURA §6.3—; con 200 vinos publicados, hasta el 93 % de la cuota. **Cargar el stock ANTES de publicar lo evita** ([ADR 016](architecture/decisions/016-mover-el-stock.md)) | Cuando se escriba el tramo 4 | 2026-09-23 |
| **Las suites de emulador y de reglas no corren en CI, y hoy son tres**: `moverStock` (19 casos), `crearOrdenDelPanel` (27) y las reglas de `productos` y `ordenes` (83) (hallazgo 8; agrava el 7 de ADR 008). Una de ellas protege plata. ⚠️ **Se corren EN SERIE**: comparten emulador y con dos en paralelo fallaron 8 casos ajenos. **Disparador:** la sesión de `crearOrden` de la vidriera. Desde 2026-09-23. | el usuario |
| **El tope de 5.000 unidades por vino** es una decisión mía, no del dueño ([ADR 016](architecture/decisions/016-mover-el-stock.md) §1) | Que el dueño lo confirme, o el primer vino real que se le acerque | 2026-09-23 |
| **`/favicon.ico` da 404 en la vidriera** (único error de consola de la preview): la tienda no tiene favicon | Antes de publicar de verdad | 2026-09-23 |
| ⚠️ **La cuenta de servicio de la preview tiene `firebase.sdkAdminServiceAgent`**, que incluye escritura y el CLI re-otorga en cada deploy ([ADR 017](architecture/decisions/017-preview-cerrada.md) §6). La vidriera sólo lee | **Antes de publicar de verdad**: una cuenta dedicada con `roles/datastore.viewer` | 2026-09-23 |
| ~~**Basic auth en la preview**~~ **DESCARTADO el 2026-09-30**: la tienda se publica, así que no hay nada que cerrar con contraseña | — | 2026-09-23 |
| ⚠️ **EP-07: despachar y cancelar un pedido.** Sin ella los pedidos se acumulan en `sin_preparar` (ADR 018 §10): la bandeja cuesta 25 lecturas por apertura desde el segundo día, el aviso de stock de la hoja de corrección no es fiable, y un pedido mal cargado no sale. **Lo que sigue** | **Bloquea que el hito 2 sirva.** Empezar por HU-07.6 (cancelar, Workflow D) y HU-07.1/07.2 | 2026-09-24 |
| **Nadie llamó a `crearOrdenDelPanel` como usuario real** ni miró el panel renderizado (ADR 018, *Lo que NO se verificó*) | La primera carga real del dueño; y que la mire con sus ojos, en escritorio y en el teléfono | 2026-09-24 |
| **¿Un pedido de WhatsApp puede ser de un vino que la tienda no muestra?** Se decidió que sí (ADR 018 §5) y el selector lo marca *«no está en la tienda»*; contradice ADR 014, donde despublicar es sacar de la venta | Que el dueño lo confirme o lo cambie (es una línea) | 2026-09-24 |
| **`productoIds[]` en la Orden**, para contar exactas las vendidas sin despachar. Sin despacho, los 50 pedidos del tope se llenan en una semana | Más de 50 pedidos abiertos, o un conteo que el aviso no explique. La salida de fondo es EP-07 | 2026-09-24 |
| **Cada venta escribe `productos.stock`**: con el tramo 4, una venta que cambie el balde de un vino publicado costará 232 lecturas | Cuando se escriba el tramo 4 | 2026-09-24 |
| ⚠️ **Los secretos de Mercado Pago son FALSOS** ([ADR 022 §7](architecture/decisions/022-cobro-de-la-vidriera.md)): `MERCADOPAGO_ACCESS_TOKEN` y `MERCADOPAGO_SECRETO_DE_FIRMA`, etiqueta `valor=falso`. Reemplazarlos con `firebase functions:secrets:set` y **redesplegar `avisoDeMercadoPago` y `revisarPago`**; después, registrar la URL del webhook en Mercado Pago | El dueño pasa las claves | 2026-09-28 |
| ⚠️ **El `noindex` del dominio no tiene mecanismo**: `has: host` no coincide en App Hosting (ADR 017 §4, medido 2026-09-30) y con `PREVIEW_CERRADA=1` el dominio saldría con `noindex` | El día que se conecte el dominio: medir el `Host` que llega antes de elegir | 2026-09-30 |
| **Precio, stock y añada de los 24 vinos son inventados o probables**, y hay cinco líneas que eligió el script ([ADR 029](architecture/decisions/029-carga-inicial-del-catalogo.md), *Lo que NO se resolvió*). *Cordero con Piel de Lobo Dulce* es borrador: la uva no está confirmada y puede no estar en la lista cerrada | Que el dueño los revise con las botellas en la mano, antes de la primera venta | 2026-09-30 |

---

## Antes de creerle a este archivo

- **Un job verde no prueba que compiló; el artifact sí.**
- **Un `Deploy: success` no prueba que publicó; la lista de jobs sí.**
- **Antes de creer que una feature existe, grepeá quién la abre**, no si está
  escrita. Pasó cuatro veces en seis meses en el proyecto anterior.
- **Ante cualquier "¿esto está desplegado?", auditá producción**, no este
  archivo.
