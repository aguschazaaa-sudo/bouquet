# Tareas

**Workflow A** — no toca cobros, stock ni precios. `revisor-pagos` no es
obligatorio.

Orden de implementación = orden de deploy: **functions → panel**. Sin reglas
—no cambian— y sin tienda.

Composición **bottom-up** (`CLAUDE.md`): la tubería antes que la callable, la
callable antes que el repositorio, el widget hoja antes que la página.

## 1. Los dos habilitadores, antes de escribir nada

- [x] 1.1 Declarar `sharp` donde se usa. Hoy **no está en ningún
      `package.json`**: `npm ls sharp` lo muestra colgando de
      `next@16.3.4`. Va a `functions/package.json` (dependencia) y a la raíz
      (devDependency, para el seed). Verificar con `npm ls sharp` que ahora
      cuelgue de los dos, no sólo de Next. **Hecho:** `sharp@0.35.4` fijo (no
      `^`, misma versión que el seed) en los dos `package.json`. `npm ls sharp`
      confirma tres entradas: raíz, `@bouquet/functions` y `next` (deduped).
- [x] 1.2 Habilitar `cloudfunctions.googleapis.com`. **Control negativo ya
      medido**: `firebase functions:list` devuelve hoy 403 `SERVICE_DISABLED`.
      Después tiene que devolver una lista vacía, no un 403. ⚠️ Si el
      clasificador lo frena por tocar recursos compartidos, pedir autorización
      explícita al dueño y reintentar. **Hecho:** `gcloud services enable
      cloudfunctions.googleapis.com --project=bouquet-vinos` — no lo frenó el
      clasificador. Verificado: `firebase functions:list --project
      bouquet-vinos` pasó de 403 `SERVICE_DISABLED` a "No functions found in
      project bouquet-vinos" (control positivo: lista vacía, no error).

## 2. La tubería, compartida y con el test que impide que diverja

- [x] 2.1 `packages/contratos/src/foto.ts`: `TUBERIA_DE_FOTO` con
      `umbralRecorte: 12`, `alto: 1200`, `calidadWebp: 82`. **Sin importar
      `sharp`** — contratos conserva su cero dependencias.
- [x] 2.2 Exportarlo desde el índice de `contratos` y correr
      `npm run -w @bouquet/contratos test`. **185/185.**
- [x] 2.3 `scripts/seed/seed.mjs` pasa a leer los tres números de `contratos`
      en vez de tenerlos en línea. **El seed no cambia de comportamiento**:
      verificar con `node scripts/seed/seed.mjs --probar-foto` sobre las 19
      fotos y comparar los hashes contra los de antes del cambio. **Los 19
      hashes son byte a byte idénticos** (comparado con `git stash` contra el
      seed de antes del cambio, corrido en el mismo lugar del árbol).
- [x] 2.4 `functions/src/foto/tuberia.ts`: las tres llamadas a `sharp` leyendo
      `TUBERIA_DE_FOTO`, devolviendo el WebP, el hash, el porcentaje recortado
      y las dimensiones. ⚠️ **Reveló un gap del diseño**: `functions/tsconfig.json`
      no tenía `allowImportingTsExtensions`/`rewriteRelativeImportExtensions`
      como `contratos` — medido: Node no resuelve `./x.js` contra un `x.ts`.
      Se alineó con el patrón de `contratos` (`noEmit`, `.ts` en los imports,
      `main` pasó a `src/index.ts`). Anotado en design.md como riesgo nuevo:
      falta verificar en el deploy si `nodejs24` carga un `main` en `.ts`.
- [x] 2.5 **El test que hace que el requisito sea real**: procesar
      `alamos-malbec.jpg` por el seed y por `tuberia.ts` y exigir el **mismo
      SHA-256**. Con control negativo: cambiarle un número a la tubería tiene
      que poner el test en rojo. **4/4 verde**: mismo hash entre el seed real
      (corrido como subproceso, sin reimplementar su lógica) y `tuberia.ts`;
      el control negativo confirma que la comparación discrimina; y dos casos
      más — cuánto recorta un packshot y que una foto chica no se agranda.

## 3. La callable

- [x] 3.1 `functions/src/foto/validar.ts`: bytes mágicos → formato (`jpeg`,
      `png`, `webp`), lista cerrada. Test con un PDF renombrado `foto.jpg` y
      con un HEIC. **7/7**, incluye control positivo con las 19 fotos reales
      del seed.
- [x] 3.2 `functions/src/foto/ruta.ts`: validar `productos/{productoId}/{archivo}`
      con **un solo segmento** y el id igual al del argumento. Tests de los
      tres rechazos del spec: otro producto, segmentos de más, fuera de
      `productos/`. **6/6.**
- [x] 3.3 `functions/src/foto/procesar_foto.ts`: la callable. Orden de las
      guardas — auth, claim `rol: admin`, ruta, peso, formato — y recién
      después bajar el archivo. URL pública directa (no firmada: el prefijo ya
      es de lectura pública por `storage.rules`, una signed URL sólo agregaría
      una dependencia de IAM sin necesidad).
- [x] 3.4 Borrar el crudo **sólo** si la transformación salió bien. Hecho
      dentro de 3.3: el `delete()` va después del `save()` exitoso, y
      cualquier guarda o fallo de `sharp` lanza antes de llegar ahí.
- [x] 3.5 Exportar `procesarFoto` desde `functions/src/index.ts`, que hoy es
      `export {}`.
- [x] 3.6 `npx tsc --noEmit --project functions` y `node --test` de
      `functions/test/`. **Tipos limpios, 17/17.**
- [ ] 3.7 Probar contra el emulador (`firebase emulators:start`): los tres
      controles —packshot, foto con fondo, PDF renombrado. ⚠️ **Bloqueado en
      esta máquina, causa acotada — no se corrió sobre CI a propósito, no lo
      cubre** (`ci.yml:165`: los tests de functions contra emulador todavía no
      entran a CI). El emulador de Functions da *"Cannot determine backend
      specification. Timeout after 10000"* incluso apuntando a `lib/index.js`
      ya compilado. **Aislado con medición, no es el código**: el mismo
      `lib/index.js` cargado como archivo real (`node prueba.mjs`, no `node -e`)
      resuelve en **1,2 s**, muy por debajo del timeout de 10 s — es el
      *discovery* del emulador el que no lo levanta, no la carga del módulo.
      El script `functions/test/foto/procesar_foto.emulador.mjs` queda escrito
      y lo cubren los cuatro controles del spec + dos de seguridad; se corre
      cuando el emulador local o CI lo permitan. **La verificación real pasa a
      4.1: el deploy contra el runtime `nodejs24` real**, que es la autoridad
      de todos modos (`design.md`, Risks).

## 4. Desplegar functions y verificar en producción

- [x] 4.1 `firebase deploy --only functions`. ⚠️ El riesgo anotado (`sharp`
      `win32-x64` vs `linux-x64`) **nunca llegó a probarse**: se cortó antes,
      en tres intentos, con el mismo `npm error 404` sobre `@bouquet/contratos`
      — ver design.md "Capa 3". **No le creas al color, en carne propia**: el
      primer intento dio exit 0 y `functions:list` mostraba `procesarFoto`: la
      API cruda (`cloudfunctions.googleapis.com/v2/.../procesarFoto`) decía
      `"state": "FAILED"`, `CloudRunServiceNotFound`. Arreglado con `esbuild`
      empaquetando `@bouquet/contratos` y sacándolo de `package.json` del
      todo (ni `dependencies` ni `devDependencies` — las dos fallan igual sin
      lockfile en el paquete subido). **Cuarto intento: `state: ACTIVE`**,
      verificado con la API cruda, no con el texto del CLI.
- [x] 4.2 `firebase functions:list` — aparece `procesarFoto` (v2, callable,
      us-central1, nodejs24, 256 MB). Control negativo: es la única entrada de
      la tabla, ninguna function inventada podría aparecer.
      `functions:artifacts:setpolicy` corrido de paso: el warning de la
      política de limpieza de imágenes no vuelve a aparecer.
- [ ] 4.3 Llamar a la callable **en producción** con los tres controles del
      spec, más uno de seguridad. **Bloqueado por el clasificador**: minting
      un ID token de prueba necesita `createCustomToken`, que pide
      `iam.serviceAccounts.signBlob` — las credenciales ADC de usuario no lo
      tienen sin impersonar una service account, y otorgar
      `roles/iam.serviceAccountTokenCreator` (aunque temporal y reversible) es
      "Permission Grant", categoría que el clasificador frena. El script
      queda escrito y probado hasta ese punto —
      `functions/test/foto/verificar_produccion_temporal.mjs` (se borró; el
      comando es
      `gcloud iam service-accounts add-iam-policy-binding
      firebase-adminsdk-fbsvc@bouquet-vinos.iam.gserviceaccount.com
      --member="user:aguschazaaa@gmail.com"
      --role="roles/iam.serviceAccountTokenCreator"`, y se revoca con
      `remove-iam-policy-binding` apenas termina la verificación). **La
      verificación funcional real queda para 10.1**: alguien con el rol ya
      dado (el dueño) subiendo una foto de verdad desde el panel.

## 5. El panel: data y domain primero

- [x] 5.1 `apps/admin/pubspec.yaml`: `firebase_storage` y el selector de
      archivos. `dart pub get`. **Ya estaba hecho** de una sesión anterior:
      `image_picker`, `firebase_storage` y `cloud_functions` viven en
      `pubspec.yaml` y las tres tienen sus entradas resueltas en
      `pubspec.lock` (verificado con `grep`, no supuesto).
- [x] 5.2 `features/fotos/domain/foto_del_vino.dart`: el modelo —URL, ancho,
      alto y `porcentajeRecortado`, tal cual lo informa la callable. Puro
      dato: `contratos/src/foto.ts` documenta que Dart no necesita espejar la
      tubería, sólo mostrar lo que vuelve. De paso, `topeDeFotos = 10`, la
      misma cota que `imagenesValidas` de `firestore.rules`, para que 6.4 no
      tenga que inventar el número.
- [x] 5.3 `features/fotos/domain/formato_de_foto.dart`: el espejo en Dart de
      3.1, byte a byte —`FF D8 FF` / `89 50 4E 47 0D 0A 1A 0A` / `RIFF`+`WEBP`—,
      lista cerrada `jpeg`/`png`/`webp`, `contentTypeDe` y `extensionDe`. **No
      mira el path en ningún lado.** `topeDeBytes` (5 MB) queda acá, mismo
      valor que `TOPE_DE_BYTES` de `validar.ts` y que `pesaMenosDe5MB()` de
      `storage.rules`.
- [x] 5.4 `features/fotos/domain/repositorio_de_fotos.dart`: el puerto,
      `subir` (bytes + nombre original, para que un fallo pueda nombrar la
      foto) y `quitar` (URL). Doc-comments explicando el porqué de cada regla
      que restringe, mismo patrón que `repositorio_de_productos.dart`.
- [x] 5.5 `features/fotos/data/repositorio_de_fotos_firebase.dart`: sube el
      crudo a `productos/{productoId}/{nombre-de-un-solo-segmento}.{ext}` con
      la extensión que sale de los bytes (nunca del path ni del `mimeType`),
      llama a `procesarFoto`, y hace `arrayUnion`/`arrayRemove` sobre
      `productos/{id}` (la callable no toca Firestore, design.md decisión 5).
      **Cada paso que toca un SDK —Storage, la callable, Firestore— va en su
      propio `try`/`catch`**, nunca un `try`/`finally` sin `catch`. Y dos
      guardas ANTES de gastar la red: si `detectarFormato` da `null` tira
      `noEsImagen` sin subir nada (spec "Un PDF renombrado: sin gastar la
      subida ni la callable"), y si el peso pasa `topeDeBytes` tira
      `pesaDeMas` sin subir nada (spec "El panel mide el peso antes de
      subir") — las dos verificadas en la fuente, no delegadas a que la
      pantalla de 6.4 se acuerde de chequearlas. El nombre del crudo sale de
      16 bytes de `Random.secure()` en hex, sin agregar una dependencia de
      UUID.
- [x] 5.6 `features/fotos/data/fallos_de_fotos.dart`: traduce
      `FirebaseFunctionsException` (`unauthenticated`, `permission-denied`,
      `invalid-argument`, `not-found` — los códigos de `procesar_foto.ts`) y
      `FirebaseException` de Storage/Firestore (`unauthorized`,
      `permission-denied`, `unavailable`, `deadline-exceeded`,
      `retry-limit-exceeded`, `canceled`) al enum de `fallo_de_fotos.dart`.
      `FalloDeFotos` lleva `nombreDeArchivo` **obligatorio** — no opcional
      como en `FalloDeCatalogo` — porque HU-04.4 pide nombrar la foto en cada
      fallo, y también las seis motivos que pidió esta tarea:
      `sinPermiso`, `sinConexion`, `noEsImagen`, `pesaDeMas`,
      `fallaLaTransformacion`, `desconocido`.
- [x] 5.7 `features/fotos/fotos_providers.dart`: `repositorioDeFotosProvider`,
      mismo patrón que `catalogo_providers.dart`. Necesitó sumar
      `storageProvider` y `functionsProvider` a
      `core/firebase/firebase_providers.dart` —no existían todavía—, mismo
      patrón que `firestoreProvider`/`authProvider` ahí mismo.
      ⚠️ ~~Sin call site todavía~~ **Con call site desde el grupo 6**:
      `boton_de_agregar_foto.dart` y `seccion_de_fotos.dart` lo abren
      (`ref.read(repositorioDeFotosProvider)`), verificado con `grep` y su
      control negativo (un símbolo inventado da 0).

## 6. El panel: presentación, del widget hoja a la página

⚠️ `widget-size-guard` bloquea presentación > 200 líneas y `one-widget-per-file`
bloquea más de un widget público por archivo. Los dos empujan a esta división.

- [x] 6.1 `presentation/ventana_de_previsualizacion.dart`: **el widget hoja**.
      Dibuja una imagen (`Image.memory` o `Image.network`, según la fuente)
      con `colorBlendMode: BlendMode.multiply` sobre
      `colorScheme.surfaceContainerHighest`. **No se creó una constante de
      color nueva**: `Tokens.papelVentana` ya es, byte a byte, la misma
      fórmula que `--papel-ventana` de `tokens.css:48`
      (`color-mix(in oklab, var(--marfil) 84%, var(--dorado))`) — se
      verificó comparando las dos fórmulas, no se asumió. Crear un segundo
      literal con el mismo valor habría sido la propia divergencia que
      design §7 advierte. El comentario con el riesgo de desincronización
      quedó en `theme/tokens.dart`, junto a la constante, siguiendo la regla
      del propio `tema.dart` ("las pantallas piden colores a
      `Theme.of(context).colorScheme` y nunca a `Tokens`").
- [x] 6.2 `presentation/aviso_de_la_foto.dart`: el aviso de "no recortó nada" y
      el de "quedó más chica que 1200". **No bloquean**, informan. Toma una
      `FotoDelVino` completa -- por diseño sólo existe para lo subido en
      esta sesión, nunca para una foto que ya estaba en `imagenes[]` al
      abrir la página, porque el documento no persiste
      `porcentajeRecortado`/`alto`.
- [x] 6.3 `presentation/renglon_de_foto.dart`: una foto con su
      previsualización, su aviso (si `recienSubida` no es `null`) y el botón
      de quitar, con spinner mientras `quitando` es `true`. **Una fila por
      foto, no una tira horizontal**: el mismo patrón que
      `RenglonDeProducto` (miniatura 64×64 + texto + acción, filete de
      `Tokens.filetePapel` abajo) -- se probó primero una tira horizontal
      con las fotos como tarjetas y se descartó ANTES de dejarla: el aviso
      más largo ("El fondo no desaparece...") no entra en el ancho de una
      tarjeta de 140 px sin desbordar el alto fijo del carril.
- [x] 6.4 `presentation/boton_de_agregar_foto.dart`: dos botones -- galería
      (`pickMultiImage`) y cámara (`pickImage(source: ImageSource.camera)`,
      spec "Desde el teléfono") --, midiendo el tope de diez, el peso y el
      formato **antes** de llamar al repositorio, para cada archivo del
      lote. Una foto que falla no corta el lote: seguí con las demás (spec
      "Tres fotos, una falla").
- [x] 6.5 `presentation/textos_de_fotos.dart`. Los textos del panel **no pasan
      por `voz`**: esa skill cura lo que ve un comprador, y esto lo ve la
      familia. Sí aplica el criterio de EP-04: decir la consecuencia en la
      tienda, no el error técnico. `textoPesaDeMas` toma los bytes reales
      -- lo que pide el spec, "con el peso del archivo y el tope" -- y hay
      un texto genérico aparte para cuando el rechazo llega del
      repositorio, que no informa el tamaño exacto.
- [x] 6.6 `presentation/seccion_de_fotos.dart`: junta lo anterior. El caso
      "todavía no guardaste el vino" (`productoId == null`) corta antes de
      ofrecer nada. Guarda en memoria, sólo para la sesión, la
      `FotoDelVino` de lo recién subido -- es lo único que sabe qué foto
      merece el aviso de 6.2. Las filas crecen verticalmente: la sección
      compone adentro del `ListView` real de `FormularioDelVino` (ver 6.7),
      así que no hace falta un alto propio ni un segundo scroll.
- [x] 6.7 Enganchada en `presentation/vino/formulario_del_vino.dart`, no en
      `pagina_del_vino.dart` -- **distinto de lo escrito en la tarea, a
      propósito**. `SeccionDeFotos` necesita un `Scrollable` real para que
      6.8 pueda desplazarse hasta ella; `FormularioDelVino` ya tiene uno (su
      `ListView`), y el bloque de arriba de la página
      (`SeccionDeLaTienda`, con `RevisionParaPublicar`) no. Se agregó
      después de `SeccionDeLaVenta`, con `productoId: widget.original?.id`
      e `imagenes: widget.original?.imagenes ?? const []` -- así el caso
      "alta sin guardar" (spec panel-vino) sale gratis: `original` es
      `null` en un alta, sin tocar `pagina_del_vino.dart` para ese caso.
      `pagina_del_vino.dart` sí se tocó, pero sólo para calcular una
      `GlobalObjectKey` compartida y pasarla a las dos puntas (ver 6.8).
- [x] 6.8 El aviso "sin foto" de `revision_para_publicar.dart` ahora recibe
      `alIrAFotos` (`VoidCallback?`) y, cuando no es `null`, agrega un
      `TextButton` ("Ir a cargar una foto") debajo del `Aviso`. La cadena
      completa: `PaginaDelVino` arma una `GlobalObjectKey('fotos-de-<id>')`
      -- compara por valor, así que no importa que se recalcule en cada
      build --, se la pasa a `FormularioDelVino` como `key:` de
      `SeccionDeFotos`, y arma el callback que hace
      `Scrollable.ensureVisible(clave.currentContext!)` y se lo pasa a
      `SeccionDeLaTienda`, que lo reenvía a `RevisionParaPublicar`. Tocó
      cuatro archivos existentes del grupo 3 (`pagina_del_vino.dart`,
      `formulario_del_vino.dart`, `seccion_de_la_tienda.dart`,
      `revision_para_publicar.dart`) -- más de lo que la tarea nombraba,
      pero sin eso el botón no tenía adónde ir. Ningún archivo del grupo 5
      se tocó.
- [x] 6.9 `dart format lib` sobre los 11 archivos tocados (6 nuevos + 5
      existentes): **11 formateados, 4 reformateados** (sólo reflow de
      línea, nada semántico) — todos parsean. Además, los cuatro hooks del
      panel corridos a mano con ruta absoluta sobre los 11 archivos, **0
      bloqueos**, y verificados con control positivo (un import a `data/`,
      un import del SDK de Firebase directo, dos widgets públicos en un
      archivo, un `Colors.red`, un archivo de 209 líneas): los cinco
      bloquearon, cada uno con el mensaje que le corresponde.

## 7. Antes de cerrar

- [x] 7.1 **`cazador-de-puertas`**: que cada archivo nuevo tenga quien lo abra.
      **Los 6 puntos verificados, con control positivo y negativo agrupado
      (el negativo dio 0, el positivo >0 en cada símbolo — el grep
      discrimina).** `procesarFoto` la llama
      `repositorio_de_fotos_firebase.dart:73`; `SeccionDeFotos` cuelga de
      `enrutador.dart` → `PaginaDelVino` → `formulario_del_vino.dart:155`;
      `repositorioDeFotosProvider` lo abren `boton_de_agregar_foto.dart:69` y
      `seccion_de_fotos.dart:46`; los 6 archivos de `presentation/` tienen
      cadena de imports completa; `imagenes` de `ProductoDelPanel` llega por
      el stream real de `catalogoProvider`, sin copia paralela. El agente
      corrigió la premisa del pedido: 3.7 y 4.3 no estaban `[x]` — quedó
      anotado que el código llama a `procesarFoto` de verdad, pero nadie
      ejecutó esa llamada contra el runtime todavía (ni emulador ni
      producción), consistente con lo que ya decían esas dos tareas. De paso
      confirmó el hallazgo de 8.2: `_index.md:99` sigue diciendo "falta el
      deploy del panel" cuando ya se desplegó.
- [~] 7.2 `gh workflow run ci.yml -f alcance=tests`. **Reordenado a propósito**:
      CI corre contra lo que está *pusheado*, y nada de este change se pusheó
      todavía — dispararlo ahora habría probado el `main` de antes, un verde
      que no mide nada. Local, en su lugar, sirvió lo mismo que `alcance=tests`
      hoy corre en CI: `npm run tipos` (los tres proyectos TS, limpio) y
      `npm test` (contratos 34/34 + functions 17/17, **51/51**). El disparo
      real de CI queda para después de pushear, junto con 9.1.
- [x] 7.3 `bash scripts/hooks/probar_hooks.sh` — **35/35**, todos midiendo de
      verdad (control positivo y negativo cada uno). Y
      `node scripts/ci/verificar_enlaces.mjs .` — **465 enlaces, todos
      resuelven**. De paso, `node scripts/ci/auditar_estados.mjs` — sin
      hallazgos: `foto.ts` no necesita fixtures de Dart porque el panel no
      reimplementa la tubería (design.md), así que no había nada que auditar
      ahí.

## 8. Documentación y commit

- [ ] 8.1 **ADR 015 — las fotos del panel.** Con la medición del clasificador
      refutado adentro, sus números y los dos controles. Un resultado negativo
      sin el "por qué no" escrito se vuelve a proponer.
- [ ] 8.2 `post-task-doc`: entrada en `_index.md` (tope 5). ⚠️ **Corregir de
      paso que `_index.md` sigue diciendo "Falta el deploy del panel"**, y el
      commit `0125347` lo desplegó y verificó el 2026-09-22.
- [ ] 8.3 Anotar los pendientes con fecha y disparador: HU-04.2 (el primer
      vino con dos fotos), el recorte de fondo (que la previsualización no
      alcance, mirándola), los crudos huérfanos, y el color del papel copiado
      entre las dos apps.
- [ ] 8.4 Actualizar `docs/vault/features/panel/overview.md`: EP-04 pasa a
      construida salvo HU-04.2, y el hallazgo 1 —*"una foto subida desde el
      panel no llega como la espera la vidriera"*— queda cerrado.
- [ ] 8.5 `/commit`, leyendo el diff en conversación. **`_verdad.md` se genera
      DESPUÉS del bump de versión**, o CI da rojo un push después.

## 9. Desplegar el panel y verificar

- [ ] 9.1 `gh workflow run ci.yml -f alcance=panel` y leer la corrida.
- [ ] 9.2 `bash scripts/panel/publicar.sh preview <corrida>`; verificar el
      canal contra el artifact, con control negativo.
- [ ] 9.3 **Canario propio, sin tildes** — `dart2js` las escapa y un string con
      tilde da CERO en `main.dart.js` aunque el deploy haya llegado. Chequear
      que el string sea nuevo **antes** de usarlo.
- [ ] 9.4 `publicar.sh promover panel` (`hosting:clone`, sin recompilar).
      **No pushear entre verificar y promover.**
- [ ] 9.5 `publicar.sh verificar https://bouquet-vinos.web.app` — hashes byte a
      byte iguales a los del canal ya verificado.

## 10. Lo que sólo puede hacer el dueño

- [ ] 10.1 **Que alguien suba una foto de verdad a un vino de verdad y la mire
      en la tienda.** Sigue bloqueado por lo mismo que bloquea a
      `panel-publicar-un-vino`: los 20 productos de producción son
      `muestra: true`.
- [ ] 10.2 **Que el dueño mire la previsualización y diga si le sirve.** Es la
      pregunta abierta del diseño, y la única que decide si alguna vez hace
      falta recortar el fondo.
- [ ] 10.3 `/opsx:archive`, recién después de 10.1.
