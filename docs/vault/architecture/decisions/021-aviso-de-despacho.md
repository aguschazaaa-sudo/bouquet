# ADR 021 — El aviso de que un pedido salió, por WhatsApp y con un toque

- **Fecha:** 2026-09-28
- **Estado:** aceptada; **desplegada y verificada por bytes el 2026-09-28** (v0.39.0, `fde0b38`). Nadie la miró renderizada: ver *Verificación*, al final.
  **Revisada el 2026-09-29 a pedido del dueño**: la marca por persona (§3) se sacó, y el
  botón lo ve todo el que entra, en cualquier estado del pedido. Ver *Revisión*, al final
- **Decide:** cómo se le avisa al comprador que su pedido salió, quién lo avisa y
  dónde vive esa marca
- **Historia:** HU-07.3 ([EP-07](../../features/panel/EP-07-preparar-y-entregar.md)),
  **recortada**: sin el link al comprobante. **Cuarto tramo del hito 2**
- **Toca:** [ADR 010 §6](010-el-checkout.md) (el comprobante en `/pedido/<numero>`,
  que no se enlaza todavía), [ADR 011](011-entrar-al-panel.md) (los claims y el
  script de accesos), [ADR 019](019-preparar-despachar-y-cancelar.md) (`despacho`,
  de donde sale el correo y el seguimiento) y [voz.md §12](../../design/voz.md)
- **Hace cumplir:** `apps/admin/test/features/pedidos/aviso_de_despacho_test.dart`,
  `apps/admin/test/features/acceso/sesion_test.dart` (grupo *HU-07.3*) y
  `scripts/acceso/acceso.test.mjs` (bloque *avisa*), que **entra a CI** con este cambio
- **Sin openspec, a pedido del dueño** (2026-09-28): este ADR y la épica son la
  especificación

## Contexto

HU-07.3 figuraba **bloqueada** por dos cosas: el número de WhatsApp de la tienda,
que no existe, y la ruta `/pedido/<numero>` de la vidriera, que tampoco. Mirando
qué pide cada una, ninguna bloquea el código:

- **El número de la tienda no aparece en el código.** El aviso sale del WhatsApp
  del teléfono que toca el botón; el número decide **a quién** se le prende el
  botón, y eso lo hace el script. Mientras la tienda no tenga número, lo prende
  el dueño para quien él diga.
- **El link sólo lo necesita un pedido de la vidriera**, y hoy no hay ninguno: los
  pedidos que existen son de WhatsApp, donde el comprador ya habla con la tienda.
  Lo que le sirve es *por dónde salió* y *el seguimiento*.

**Qué quedó afuera del hito 2, y por qué:** HU-06.5 (no hay carpeta `android/` en el
panel: pide la APK, FCM y un trigger, y su caso fuerte es la vidriera) y EP-08
entera (espera a `crearOrden` y Mercado Pago).

## Decisión

### 1. Un enlace `wa.me`, sin registro de que se avisó

El detalle de un pedido **despachado** muestra *"Avisarle por WhatsApp que salió"*.
El botón abre `https://wa.me/<dígitos>?text=<texto>` y la persona aprieta enviar
desde su WhatsApp: es la decisión del dueño (*"con un toque"*), y descarta la API de
WhatsApp Business. Aparece también al **volver a despachar** una entrega fallida:
el correo o el seguimiento pueden ser otros.

**No se guarda que se avisó** (`avisadoEn`): sería una escritura por aviso, un campo
en `contratos` y en las reglas, y no evita ninguna pérdida concreta (criterio 2 de
*poca burocracia*): el registro es el chat. **Cero lecturas y cero escrituras.** No
toca reglas, contratos ni functions: el deploy es sólo el panel.

### 2. Un teléfono que no es E.164 no arma el enlace

`wa.me` lee los dígitos como el número completo, y uno mal armado **abre el chat de
otra persona sin fallar** (glosario). El teléfono ya se guardó normalizado por
`crearOrdenDelPanel`; el panel **no lo vuelve a arreglar**: si no es E.164, dice que
el aviso no se puede armar y que se avise a mano.

El texto va con `encodeComponent`: el espacio como `%20` (no `+`, que un query de
formulario lee como espacio pero `wa.me` puede dejar literal) y el `#` del número
como `%23`, que sin escapar cortaría el texto ahí.

### 3. La marca es un claim, `avisaPorWhatsApp: true`, que pone el script

> ⚠️ **Revocada el 2026-09-29** (*Revisión*, al final): el dueño no encontraba el botón,
> porque la marca no la tenía nadie. Queda escrita porque explica el porqué de lo que se sacó.

Lo que la épica dejó abierto: **un claim al lado de `rol`, o un documento por
persona.** Va el claim:

| | Claim | Documento |
|---|---|---|
| Lecturas | **0** | 1 por sesión |
| Quién la cambia | `acceso.mjs avisa <mail>` / `no-avisa <mail>` | Una pantalla nueva |
| Cuánto cambia | Tan poco como el rol | — |

`avisa` **se niega si la cuenta no tiene el rol**: la marca sola no abre el panel, y
ponerla le haría creer a quien corre el script que esa persona ya puede avisar. No
revoca sesiones —no quita nada—, así que **llega cuando el token se renueva**: que
la persona salga y vuelva a entrar, o hasta una hora. `listar` dice quién avisa. El
nombre del claim lo leen dos lugares (`CLAIM_DEL_AVISO` en el script, `claimDelAviso`
en `sesion.dart`), y **un test del script lee la constante del archivo Dart**, no un
literal. Vale sólo si es exactamente `true`.

**No es un permiso sobre los datos**: el rol sigue siendo uno. Lo que el cliente lea
del token no protege nada, y acá no hay nada que proteger: el enlace no escribe.

### 4. El texto es de mostrador y no firma

Lo lee el comprador, así que pasó por `voz` ([voz.md §4](../../design/voz.md)): corto,
con el dato, sin exclamaciones. Un solo cambio sobre el borrador: el seguimiento en
su propio renglón (mostrador: 1 a 2 frases por párrafo).

```text
Hola, Marta. Tu pedido #1184 ya salió por Andreani.

El número de seguimiento es AR123.

Si necesitás algo, escribinos por acá.
```

`en_mano` dice *"te lo llevamos nosotros"*; `otro` no nombra un correo; sin nombre,
*"Hola."* (§4.2: *"Nombre, o nada"*). **No firma**: [voz.md §12](../../design/voz.md)
deja el nombre con el que firma la tienda al dueño *"antes del primer aviso
automático"*, y éste no lo es — lo manda una persona que puede sumar su nombre
antes de enviar.

### 5. `url_launcher`, el paquete oficial

Abre una pestaña en la web y la app de WhatsApp en Android
(`LaunchMode.externalApplication`). Si el navegador bloquea la ventana, `launchUrl`
devuelve `false` o tira, y **se dice**: un botón que no hace nada es un fallo
invisible.

## Por qué NO las alternativas

- **Esperar el número de la tienda** — no cambia una línea de código: cambia a quién
  se marca.
- **Esperar `/pedido/<numero>`** — los pedidos que existen no lo necesitan, y esa
  ruta es de la sesión de `crearOrden`.
- **Un documento por persona** — una lectura por sesión y una pantalla, para algo que
  cambia tan poco como el rol.
- **Guardar `avisadoEn`** — escritura, contrato y regla nuevos para un dato que el chat
  ya tiene.
- ~~**Mostrar el botón a todos** — el comprador recibiría mensajes de números distintos,
  que es lo que el dueño pidió evitar.~~ **Es lo que se eligió el 2026-09-29**: el dueño
  acepta ese costo (ver *Revisión*).

## Presupuesto de lecturas

Cuota: **50.000 lecturas/día y 20.000 escrituras/día**.

| Operación | Lecturas | Escrituras |
|---|---:|---:|
| Mostrar el botón | **0**: la marca viene en el token, que el panel ya lee para el rol | 0 |
| Avisar | **0**: abre un enlace | 0 |

**Propio de este cambio: 0.** El acumulado del panel no cambia: ~5.934/día, **11,9 %**
([ADR 020](020-accion-busqueda-y-notas.md)).

## Lo que este ADR deja abierto, con su disparador

| Qué | Disparador |
|---|---|
| ~~**Quién avisa**: hoy nadie tiene la marca~~ **Cerrado el 2026-09-29**: todos (*Revisión*) | — |
| **El link al comprobante** (`/pedido/<numero>`) | La sesión de `crearOrden`, cuando la ruta exista y haya pedidos de la vidriera |
| **El nombre con el que firma la tienda** | [voz.md §12](../../design/voz.md): antes del primer aviso automático |
| ~~**Una pantalla para marcar a quién avisa**~~ **Cerrado el 2026-09-29**: no hay marca | — |
| **En la compu, el aviso sale del WhatsApp Web que esté abierto** | Que alguien avise desde un WhatsApp que no era |

## Verificación (2026-09-28)

Cada fila dice **cómo**; un job verde no prueba nada. Sale en el mismo build que
[ADR 020](020-accion-busqueda-y-notas.md), que estaba en `main` sin desplegar.

| Qué | Cómo |
|---|---|
| Las suites | CI `alcance=tests`, corrida `36466563334` sobre `ba62c5e`, **restadas contra la de ADR 020**: Dart 432 → **450 (+18 exactos**: 13 del aviso, 5 de la sesión**)**; `acceso.test.mjs` **17/17 con 0 fallidos, la primera vez que corre en CI** (los 6 casos de `avisa` leídos uno por uno en el log); emulador de Firestore 162 → 162 (reglas sin tocar). `guardas` cayó por `_verdad.md` sin regenerar, corregido en `fde0b38` |
| Compila | CI `alcance=panel`, corrida `36467004226` sobre `fde0b38`: *"No issues found!"*, build web de 35 archivos, `main.dart.js` `5bd8c39e…` |
| Sin huérfanos | 13 símbolos nuevos grepeados, cada uno con call site fuera de su definición; control inventado: 0. Cadena `enrutador → PaginaDelPedido → DetalleDelPedido → BotonDeAviso`; las tres funciones del script las llama su `principal()` |
| El canario | Contra live antes del deploy, **seis cadenas ASCII nuevas 0 → 1** en el canal (`avisaPorWhatsApp`, `https://wa.me/`, *"Avisarle por WhatsApp que sali"* y tres de ADR 020); control positivo *"Por preparar"* 1 → 1; inventada 0 → 0; `COMMIT` `f066c56` → `fde0b38` |
| El deploy | `publicar.sh preview` (hash de los 35 archivos contra el artifact) → canario → `promover` → live con **los 4 hashes iguales al build**, control negativo, `noindex`, `commit publicado: fde0b38` |

### Lo que NO se verificó

- ⚠️ **Nadie lo miró renderizado, y hoy no se puede**: el botón pide la marca, que no tiene
  nadie, y un pedido despachado, y en producción hay 0 pedidos. Lo prueba el primer aviso real.
- **Que `wa.me` abra el chat con el texto entero** se probó sobre el enlace (el texto vuelve
  idéntico al decodificarlo, con `#`, `&` y saltos), no abriendo WhatsApp.
- **Un navegador que bloquea la pestaña**: el aviso de *"No se pudo abrir WhatsApp"* está
  escrito pero no se vio.
- **Android**: no existe `android/` en el panel (H5); `LaunchMode.externalApplication` es lo que
  abriría la app, sin probar.
- **Sin mutaciones**: no toca plata ni reglas. La marca y el enlace tienen control positivo y
  negativo en cada test.

## Revisión (2026-09-29): el botón lo ve todo el que entra, en cualquier estado

**Por qué.** El dueño, usando *Pedidos*: *"no encuentro el botón para mandar un mensaje vía
WhatsApp al cliente"*. Tenía **dos cerrojos**: la marca, que **no la tenía nadie** (§3, y la
tabla de abiertos lo decía), y el estado —sólo en un pedido despachado—. Y aunque la hubiera
tenido, **no había forma de escribirle al cliente por otra cosa** que el aviso de que salió.
Es la primera pieza de *pedidos sin burocracia*; las otras dos (la carga y los estados)
quedaron aprobadas en la misma conversación y van por su cuenta (Workflow D, en `_index.md`).

**Decisión del dueño: lo ve todo el que entra al panel.** Acepta el costo que §3 quería
evitar —que el comprador reciba mensajes de números distintos—: en la práctica arma y
despacha una sola persona.

- **Un solo botón, en cualquier estado.** En un pedido despachado (`sePuedeAvisar`) dice
  *"Avisarle por WhatsApp que salió"* y abre el chat con el aviso de §4, sin cambios; en
  cualquier otro, *"Escribirle por WhatsApp"* y abre el chat **vacío** (`wa.me/<dígitos>`, sin
  `?text=`). El teléfono que no es E.164 sigue sin armar el enlace (§2).
- **Arriba del detalle, debajo del estado.** Al final de la página —donde estaba el
  contacto— en un teléfono no se encontraba.
- **La marca se saca entera**: `Operador.avisaPorWhatsapp`, `claimDelAviso`,
  `avisaPorWhatsappProvider`, y en `acceso.mjs` los comandos `avisa`/`no-avisa`,
  `darAviso`, `quitarAviso` y `listarQuienesAvisan`. **Una cuenta que conserve el claim no
  cambia nada** (lo prueba `sesion_test.dart`). El paso del script en CI se queda —`dar` y
  `quitar` escriben el claim que abre el panel— con el piso de **17 a 11**.

### Qué se descartó

- **Dejar la marca y dársela a todos** — configuración que alguien tiene que acordarse de dar
  a cada cuenta nueva: el próximo de la familia que entre no vería el botón, que es este mismo
  problema otra vez.
- **Dos botones, *escribir* y *avisar*** — obligan a elegir entre dos parecidos, y el texto
  igual se edita antes de enviar.
- **Un saludo escrito en el chat general** (*"Hola, Marta. Te escribo por tu pedido #1184"*) —
  sería texto nuevo que lee el comprador (pasa por `voz`), con un número de pedido que un
  comprador de WhatsApp nunca recibió. Con el chat que ya tienen, vacío alcanza.

### Lecturas de la revisión

**0 lecturas y 0 escrituras**, igual que antes: abrir un enlace no lee nada, y el botón ya no
mira el token. Sólo se publica el panel.

### Cómo se verificó la revisión (2026-09-29)

| Qué | Cómo |
|---|---|
| Las suites | CI `alcance=tests`, corrida `36638688670` sobre `f7cb95d`, **restadas** contra la de EP-11 (`36607938982`): Dart 534 → **533 (−1 exacto**: sesión −3, enlace +2**)**; `acceso.test.mjs` 17 → **11**, 0 fallidos; emulador 235 → 235 (reglas sin tocar); contratos 309 y functions 76, iguales. `guardas` cayó por un enlace de la entrada movida al changelog, corregido en `951fb43` |
| Compila | CI `alcance=panel`, corrida `36639192917` sobre `df1304b`: *"No issues found!"*, build de 35 archivos, `main.dart.js` `87b9427d…` |
| Sin huérfanos | `enrutador → PaginaDelPedido → DetalleDelPedido → BotonDeWhatsapp → enlaceDeWhatsapp / sePuedeAvisar`; ninguna referencia a `BotonDeAviso`, `avisaPorWhatsapp` ni `claimDelAviso` en `lib/` ni `test/`; control inventado 0 |
| El canario | Contra live antes del deploy y sobre el canal: *"Escribirle por WhatsApp"* y *"Buscalo a mano en tu WhatsApp"* **0 → 1**; `avisaPorWhatsApp` y el texto viejo (*"puede armar. Avisale a mano"*) **1 → 0**; control positivo *"Avisarle por WhatsApp que sali"* 1 → 1; inventada 0 → 0. Todas ASCII: dart2js escapa las tildes |
| El deploy | `publicar.sh preview` (35 hashes contra el artifact) → canario → `promover` → live con **los 4 hashes iguales al build**, control negativo, `noindex`, `commit publicado: df1304b`. **Arrastró la v0.45.0** (el panel a ancho de teléfono), sólo presentación |

**Lo que NO se verificó:** que el botón **se vea arriba y abra el chat**. Pide entrar al
panel, y en esta máquina no hay credenciales, a propósito. Lo prueba el dueño abriendo un
pedido.
