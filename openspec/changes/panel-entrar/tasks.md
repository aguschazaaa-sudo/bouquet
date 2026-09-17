## 1. Habilitadores (H1, H2)

- [x] 1.1 Registrar la app web en `bouquet-vinos` y escribir
      `lib/firebase_options.dart` con su configuración.
- [x] 1.2 Generar `web/` con `flutter create --platforms=web`, sacar lo que no
      va (test de ejemplo, README, `.idea`) y ajustar `index.html` y
      `manifest.json`: idioma, título, `noindex`, colores e íconos de la marca.
- [x] 1.3 Sumar `go_router` y `google_fonts` al `pubspec.yaml` con su lock.
- [x] 1.4 `lib/theme/tokens.dart` y `lib/theme/tema.dart`: los colores del
      papel y la banda, con los valores resueltos de `tokens.css`, y el
      `ThemeData` de la mezcla C.

## 2. Cuentas (HU-01.3, H4)

- [x] 2.1 `scripts/acceso/acceso.mjs` con `dar`, `quitar` y `listar`, la
      baranda de proyecto y `--emulador`.
- [x] 2.2 `scripts/acceso/acceso.test.mjs` contra el emulador de Auth: un caso
      aceptado y uno rechazado por requisito de `specs/panel-cuentas`.

## 3. Acceso — domain y data (HU-01.1, HU-01.2)

- [x] 3.1 `domain/sesion.dart`: el tipo cerrado y `sesionDesde`.
- [x] 3.2 `domain/repositorio_de_sesion.dart`: la interfaz y `FalloDeEntrada`.
- [x] 3.3 `data/codigos_de_auth.dart`: de código de Firebase a
      `ErrorDeEntrada`, con la ventana cerrada como "no es error".
- [x] 3.4 `data/repositorio_de_sesion_firebase.dart` y `acceso_providers.dart`.
- [x] 3.5 Tests en Dart puro de `sesionDesde` y de los códigos.

## 4. Rutas

- [x] 4.1 `app/rutas.dart` y `app/destino.dart`, con su test en Dart puro.
- [x] 4.2 `app/enrutador.dart`: `GoRouter` con `redirect`, `refreshListenable`
      y `errorBuilder`.

## 5. Pantallas (bottom-up)

- [x] 5.1 `core/presentation/`: la marca y el aviso.
- [x] 5.2 Acceso: el botón de Google, el formulario de entrada, el de
      contraseña, la pantalla de entrada y la de acceso denegado.
- [x] 5.3 Estructura: la espera, la sección vacía, la página no encontrada, la
      banda, la barra y la estructura que elige entre las dos por ancho.
- [x] 5.4 Catálogo y Pedidos vacíos.
- [x] 5.5 `main.dart`: `Firebase.initializeApp` y `MaterialApp.router`.
- [x] 5.6 `dart format` sobre todo `lib/` y `test/`, y los hooks en verde.

## 6. Publicación (H3)

- [x] 6.1 Alcance `panel` en `ci.yml`, con el job en el veredicto.
- [x] 6.2 `scripts/panel/publicar.sh` (`preview` y `promover`), con la
      verificación de hashes y de la conclusión de la corrida.
- [x] 6.3 `firebase.json`: `X-Robots-Tag: noindex` en el hosting del panel.

## 7. Cierre

- [x] 7.1 Buscar quién abre cada cosa nueva: toda pantalla tiene una ruta, toda
      ruta está en la navegación o en una redirección.
- [x] 7.2 ADR 011, `design/tokens.md` (el espejo del panel) y `_index.md`.
- [x] 7.3 Commit leyendo el diff, y push.
- [x] 7.4 CI con `alcance=panel`: leer la lista de jobs, no el color.
- [x] 7.5 Cuentas de control en producción: una con permiso y otra sin.
- [x] 7.6 Publicar al canal de preview y verificar con contraseña: entrar, sin
      acceso, ruta inventada, recargar en `/pedidos`, 1440 y 390 px.
- [x] 7.7 Promover a live y verificar: hash de `main.dart.js` igual al del
      canal, `X-Robots-Tag`, entrar con contraseña; Google lo prueba el usuario.
- [x] 7.8 Borrar las cuentas de control y comprobar que no quedan.
- [x] 7.9 Cerrar el vault. **El archivado quedó pendiente**: `/opsx:archive`
      no está en esta sesión (las skills de terceros no se commitean) y
      `openspec/specs/` está VACÍO — ningún change de este repo se archivó
      nunca, así que archivar sólo éste inventaría una línea base que los otros
      tres no tienen. Anotado en `_index.md` con disparador.
