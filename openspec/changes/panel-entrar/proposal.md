## Why

El panel es un andamio que nunca compiló para ninguna plataforma: no hay
`web/`, no hay app registrada en Firebase, Auth no estaba inicializado y no
existe forma de desplegarlo. Ninguna de las 24 historias del hito 1 —cargar el
catálogo real— se puede verificar en producción sin una puerta: entrar, tener
permiso y un camino de publicación. Esta es esa puerta
([EP-01](../../../docs/vault/features/panel/EP-01-entrar-al-panel.md)).

Historias: **HU-01.1 · HU-01.2 · HU-01.3 · HU-01.4 · HU-01.5**, más los
habilitadores **H1 · H2 · H3 · H4** del
[mapa del panel](../../../docs/vault/features/panel/overview.md).

## What Changes

- **Entrar al panel (HU-01.1):** con mail y contraseña o con Google. **El panel
  no ofrece crear cuenta.** "¿No tenés contraseña o te la olvidaste?" manda el
  mail de Firebase, que sirve para crear la primera y para recuperarla.
- **Sin permiso (HU-01.2):** una cuenta sin el claim `rol: admin` ve una
  pantalla que lo dice con su mail, y un botón que fuerza a renovar el token
  para quien lo acaban de habilitar.
- **Dar y quitar acceso (HU-01.3, H4):** `scripts/acceso/acceso.mjs` con
  `dar`, `quitar` y `listar`. Crea la cuenta sin contraseña si no existe, y
  **se niega** a habilitar una cuenta con contraseña y mail sin verificar: es la
  puerta del registro anticipado que encontró la sonda de Auth.
- **Estructura (HU-01.4, HU-01.5):** barra oscura con **Catálogo** y
  **Pedidos**; en teléfono, barra abajo. Las dos secciones salen **vacías y lo
  dicen**: se llenan en EP-02/03 y en el hito 2. Una ruta inventada muestra
  "esa página no existe".
- **Dirección visual del panel (H2):** la mezcla que eligió el dueño —colores
  de la planilla, búsqueda y renglones de la libreta—, con los tokens espejados
  en `lib/theme/`.
- **Firebase conectado (H1):** app web registrada, `firebase_options.dart`,
  `Firebase.initializeApp` y la carpeta `web/`.
- **Publicación (H3):** CI compila la web **sólo a pedido** (alcance `panel`)
  y deja un artifact con su hash; el deploy baja ese artifact, lo sube a un
  canal de preview y lo **promueve** con `hosting:clone`.
- **Dependencias nuevas del panel:** `go_router` y `google_fonts`.

### Lo que este cambio NO hace

- Ninguna pantalla con datos: bodegas, productos, fotos y stock son EP-02 a
  EP-05.
- Android: la APK entra en el hito 2 (H5), con la huella SHA-1 de su clave.
- La pantalla para dar acceso: tiene disparador en HU-01.3.
- El workflow de deploy en GitHub con credenciales: espera al deploy desde tag.

## Capabilities

### New Capabilities
- `panel-acceso`: entrar con mail o con Google, crear o recuperar la
  contraseña por mail, saber que no se tiene permiso, salir.
- `panel-cuentas`: dar, quitar y listar el acceso al panel desde un script con
  baranda de proyecto.
- `panel-estructura`: navegación entre secciones, rutas protegidas por sesión,
  diseño que se adapta de la compu al teléfono, página no encontrada.
- `panel-publicacion`: compilar la web en CI con su hash y publicarla
  promoviendo los mismos bytes que se verificaron.

### Modified Capabilities
<!-- Ninguna: openspec/specs/ está vacío. -->

## Impact

- `apps/admin/`: `lib/` entero (tema, acceso, estructura, rutas, main),
  `web/`, `pubspec.yaml` y su lock, tests de Dart puro.
- `scripts/acceso/`: nuevo, con su test contra el emulador de Auth.
- `scripts/panel/publicar.sh`: nuevo.
- `.github/workflows/ci.yml`: alcance `panel`.
- `firebase.json`: encabezados del hosting del panel (`noindex`).
- Firebase `bouquet-vinos`: la app web registrada y Auth con mail y Google
  (hecho por el usuario el 2026-09-16).
- **Lecturas de Firestore: cero.** El permiso viaja en el token de Auth y
  ninguna pantalla de este cambio lee datos.
- Docs: ADR 011, `design/tokens.md` (el espejo del panel), `_index.md`.
