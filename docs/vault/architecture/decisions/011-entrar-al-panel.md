# ADR 011 — Entrar al panel: las cuentas las crea un script, el permiso viaja en el token, y se publica lo que compiló CI

- **Fecha:** 2026-09-16
- **Estado:** aceptada. Aplicada en el change
  [`panel-entrar`](../../../../openspec/changes/panel-entrar/proposal.md)
  (EP-01 entera, más los habilitadores H1–H4)
- **Decide:** cómo nace una cuenta del panel y cómo se le da el permiso, cómo
  sabe el panel qué pantalla mostrar, con qué dirección visual se construye, y
  por qué camino llega a producción
- **Toca:** [ADR 001](001-stack.md), que decía *Firebase Hosting* sin decir
  cómo se llega; [ARQUITECTURA §9.2](../../../../ARQUITECTURA.md#92-el-rol-va-en-un-custom-claim-no-en-un-documento),
  que pasa a tener quien escribe el claim; y
  [`direccion.md` §12](../../design/direccion.md), que tenía abierto *"cómo se
  aplica esto al panel"*
- **Hace cumplir:** `scripts/acceso/acceso.test.mjs` (contra el emulador de
  Auth, con una mutación que prueba que el caso del registro anticipado
  discrimina), `test/app/destino_test.dart`,
  `test/features/acceso/sesion_test.dart`, y los hooks `layer-boundary`,
  `no-hardcoded-colors`, `one-widget-per-file` y `widget-size-guard`

## Contexto

El panel era un andamio: un `main.dart` placeholder, sin carpetas de
plataforma y sin forma de desplegarse. Y el proyecto `bouquet-vinos` no tenía
**ninguna app registrada** y **Auth sin inicializar**: la API de configuración
devolvía `CONFIGURATION_NOT_FOUND`. Se midió con dos controles: una ruta
inventada devuelve la página HTML de 404 de Google, y un proyecto que sí tiene
Auth devuelve su configuración. El usuario inicializó Auth el mismo día, con
mail y Google, y la protección contra la enumeración de mails quedó prendida.

El dueño pidió las dos formas de entrar, *"creo que ambos"*, y un solo rol para
toda la familia: *"el panel no debe exceder la burocracia"*.

## Decisión

### 1. El panel no crea cuentas. Las crea `scripts/acceso/acceso.mjs`, sin contraseña

`dar <mail>` crea la cuenta **sin contraseña** si no existe y le pone
`rol: admin`, conservando cualquier otro claim. `quitar` saca el rol y revoca
las sesiones. `listar` recorre todas las páginas. El `projectId` es fijo, y
`--emulador` usa `demo-bouquet`.

La persona entra con Google, o toca *"¿No tenés contraseña o te la olvidaste?"*
y recibe el correo de Firebase, que crea la contraseña **y verifica el mail**.

**Lo que midió la sonda** contra el emulador, antes de escribir la pantalla,
como pedía HU-01.1:

| Caso | Resultado |
|---|---|
| Cuenta sin contraseña → correo de restablecimiento | Se fija la contraseña y `emailVerified` pasa a `true` |
| Esa cuenta entra con Google | Mismo uid, conserva `rol`, quedan los dos proveedores |
| Contraseña con el mail **sin verificar**, entra con Google | **La contraseña se desvincula** (`INVALID_PASSWORD`). Es la trampa que anotaba HU-01.1 |
| Control: la misma, con el mail verificado | Quedan las dos formas |

### Por qué existe la negativa del script (NO REVERTIR)

**El registro anticipado.** La API key web es pública, así que cualquiera puede
llamar a `accounts:signUp` con el mail de un familiar y una contraseña propia.
Si después el script le diera `rol: admin` a *"la cuenta de ese mail"*, el
panel quedaría en manos de quien la registró. **El script se niega** a
habilitar una cuenta que tenga proveedor `password` y el mail sin verificar. Lo
encontró la sonda de este ADR, el 2026-09-16, y no estaba en ningún documento.
El test que lo prueba falla si se saca la condición: se comprobó mutándola.

### 2. La sesión es un tipo cerrado, y el permiso sale del token

`Resolviendo | SinSesion | SinPermiso | Inaccesible | Operador`. `sesionDesde`
es Dart puro: `claims['rol'] == 'admin'`. **`Inaccesible` existe para que un
corte de red no se lea como "no tenés permiso"**, que es el reverso de
HU-01.2.

*"Ya me dieron acceso"* renueva el token con `getIdTokenResult(true)` y
después invalida el provider: la suscripción nueva lee el token ya renovado,
sin depender de si Firebase vuelve a emitir.

Lo que diga el token **en el cliente** no protege nada: eso lo hacen las
reglas, que miran el mismo claim. El panel sólo elige la pantalla.

### 3. Las rutas las decide una función pura

`destinoPara(Sesion, Uri)` vive en `lib/app/destino.dart` y se prueba en Dart
puro, un caso por escenario de `specs/panel-estructura`. `go_router` la llama desde `redirect`. Se recuerda a dónde iba cada
uno en `?desde=`, **sólo si es una ruta interna**, y recargar en `/pedidos`
no te tira a Catálogo. Las URLs no llevan `#` (`usePathUrlStrategy`).

### 4. La dirección visual del panel: la mezcla C

El dueño eligió **mirando** tres direcciones en un
[lienzo](https://claude.ai/artifact/1Eie7nobYEDNqQp4Ck6fv7):
*"me gusta el esquema de colores de la B pero me parece más eficiente la
búsqueda de A"*. Quedó así:

- **De la planilla (B):** la banda de tinta con el dorado, y superficies
  blancas sobre papel hondo.
- **De la libreta (A):** el buscador a todo el ancho, los filtros en fichas y
  un renglón por vino.

Archivo para la interfaz, Newsreader sólo para los nombres, y Fraunces no
entra. Los valores y sus contrastes están en
[`tokens.md` §7](../../design/tokens.md).

### 5. Se publica lo que compiló CI

El alcance `panel` de `ci.yml` corre `dart test`, `flutter analyze` y
`flutter build web`, y deja un artifact con el `SHA256SUMS` y el `COMMIT`.
`scripts/panel/publicar.sh` hace tres cosas:

1. **`preview`:** exige que la corrida haya terminado en `success`, con el job
   de build en `success` y no `skipped`. Después verifica cada hash y el
   commit, y lo sube a un canal.
2. **`verificar`:** compara lo que sirve una URL con esos hashes, con un
   control negativo.
3. **`promover`:** hace `hosting:clone` del canal a live.

### 6. La banda del panel va en el slot `appBar` (NO REVERTIR)

`EstructuraDelPanel` es el `builder` de un `ShellRoute`, y un `ShellRoute` mete
un `Navigator` adentro. La barrera modal de la ruta de ese `Navigator` lleva un
`BlockSemantics`, que **borra la semántica de todo lo que se pintó antes que
ella** en el mismo alcance. Con la banda como primer hijo de un `Column`, eso
la incluía.

**Medido el 2026-09-17 sobre el canal de preview**, con la sesión puesta en
`/pedidos` y la semántica prendida:

| Se pinta | Qué tenía el árbol de accesibilidad |
|---|---|
| Banda arriba, primer hijo del `Column` (**antes** del `Navigator`) | Nada: ni `bouquet`, ni las pestañas, ni el mail, ni *Salir*. Siete nodos, todos de la sección |
| Barra inferior a 390 px, slot del `Scaffold` (**después** del body) | `button:Catálogo`, `button:Pedidos` |

Las dos en la misma pantalla y la misma sesión: eso es el control positivo y el
negativo de la explicación, no dos corridas distintas. Un resize que fuerza el
rebuild no cambió nada, así que no eran nodos rancios.

El `Scaffold` agrega sus slots **después** del body, y por eso los salva. La
banda pasó a `appBar` con un `PreferredSize`; el `SafeArea` de la banda sigue
haciéndose cargo de la muesca, así que la altura del slot la suma.

**Lo que se dibuja no prueba que exista para quien no lo ve.** La banda se veía
perfecta en las capturas de 1440 y 390 px —marca, pestaña subrayada en dorado,
mail y *Salir*— mientras era inalcanzable para un lector de pantalla. Lo
destapó que el driver no encontrara la pestaña, no una lectura del código.

## Por qué NO las alternativas

| Alternativa | Por qué no |
|---|---|
| Registro en el panel y aprobación del dueño | Más burocracia de la que pidió el dueño, y deja abierta la trampa de la tercera fila |
| El script pone una contraseña temporal y se manda por WhatsApp | Contraseñas en un chat, y el mail sigue sin verificar |
| Deshabilitar el registro por API en el proyecto | Sólo existe en Identity Platform, que es otro producto con otra facturación |
| El rol en un documento `usuarios/{uid}` | Ya descartado en ARQUITECTURA §9.2: un `get()` por evaluación de regla |
| `Navigator` a mano en vez de `go_router` | En la web las rutas son URLs que se recargan y se comparten; reimplementarlo es escribir mal lo que existe |
| Fuentes `.ttf` variables empaquetadas | En Flutter piden `FontVariation` a mano en cada estilo; `google_fonts` resuelve pesos estáticos |
| Workflow de deploy en GitHub con una cuenta de servicio | Crear esa credencial es otra decisión, y el pendiente *"deploy desde tag"* ya la va a pedir |
| Compilar en la máquina de desarrollo | Prohibido: muere con `0xC0000005` (CLAUDE.md) |

## Presupuesto de lecturas

**Cero.** Entrar, renovar el token y navegar no leen Firestore: el permiso
viaja en el token de Auth y ninguna pantalla de este cambio lee datos. El
número contra los 50.000/día no se mueve.

La primera lectura del panel llega con EP-02 y EP-03: **230 por carga en
frío** del catálogo del MVP (hallazgo 7 del
[mapa](../../features/panel/overview.md)).

## Consecuencias

- **El panel tiene URL pública, y no se indexa:** `noindex` en el HTML y
  `X-Robots-Tag` desde el hosting.
- **Dar acceso pasa por el desarrollador.** El disparador para hacer una
  pantalla está en HU-01.3.
- **Quitar acceso no es instantáneo:** un ID token vigente vale para las reglas
  hasta una hora. El script lo avisa.
- **Google no anda en los canales de preview**, porque sus dominios no están
  autorizados. En preview se verifica con contraseña, y Google en live.
- **`firebase_options.dart` y la API key web están en el repo público.** Son
  públicas por diseño: la key viaja adentro de `main.dart.js`, así que
  guardarla como secret no cambiaría nada —el navegador la necesita en claro—.
  **Restringida por referrer el 2026-09-17**, y eso agrega una obligación al
  ritual de publicar: **el host del canal de preview tiene que estar en la
  lista de la key**, o el recorrido con login falla con un 403 de Auth que
  parece un defecto del panel y no lo es. Hoy están `bouquet-vinos.web.app`,
  `bouquet-vinos.firebaseapp.com` —por donde pasa el handler de Google— y el
  host del canal `panel`. ⚠️ **Un comodín en medio de una etiqueta
  (`bouquet-vinos--*.web.app`) la API lo ACEPTA y no matchea nada**: se guarda
  sin protestar y sigue bloqueando. Se pone el host literal, que además es más
  angosto; la URL de un canal es estable para un mismo sitio y nombre.

## Cuándo esta decisión deja de servir

- Si aparece un rol que no es `admin` (el repartidor, ADR 010 §1): `sesionDesde`
  deja de ser un booleano.
- Si dar acceso deja de ser raro: la pantalla de HU-01.3.
- Si el panel sale en una APK (hito 2): Google en Android pide la huella SHA-1
  de la clave de firma, y una APK no se actualiza sola (H5).
