## Context

`apps/admin` tiene tres archivos de `lib/`: un `main.dart` placeholder, los
enums espejados de la Orden y un `firestoreProvider` que nadie usa. No tiene
carpetas de plataforma. El proyecto `bouquet-vinos` no tenía apps registradas y
**Auth no estaba inicializado** (`CONFIGURATION_NOT_FOUND`, medido con un
proyecto con Auth como control positivo y una ruta inventada como negativo). El
usuario lo habilitó el 2026-09-16 con mail y Google, y la protección contra
enumeración de mails quedó prendida.

**El panel no compila en esta máquina** (`CLAUDE.md`): cada vuelta de build es
una corrida de CI. Eso ordena todo el diseño: la lógica que se puede probar va
en Dart puro (`dart test`), y los widgets se escriben contra APIs leídas en el
pub cache, no recordadas.

Quién lo usa: la familia, gente no técnica, desde la compu y el teléfono. Un
solo rol ([overview](../../../docs/vault/features/panel/overview.md)).

## Goals / Non-Goals

**Goals:**
- Que sólo una cuenta con `rol: admin` vea una sección, y que quien no lo tiene
  sepa por qué.
- Que dar acceso sea un comando, y que no se pueda regalar el panel a una
  cuenta registrada por un tercero.
- Que el panel quede publicado en `bouquet-vinos.web.app` por un camino que
  publica los bytes verificados.
- La dirección visual fijada en tokens antes de la primera pantalla con datos.

**Non-Goals:**
- Pantallas con datos (EP-02 a EP-05), Android (hito 2), una pantalla para dar
  acceso, deploy automatizado con credenciales en GitHub.

## Decisions

### 1. El panel no crea cuentas; las crea el script, sin contraseña

La sonda contra el emulador de Auth (2026-09-16, descartable) midió cuatro
cosas:

| Caso | Resultado |
|---|---|
| Cuenta creada por el Admin SDK sin contraseña → correo de restablecimiento | Se fija la contraseña **y el mail queda verificado** |
| Esa cuenta entra después con Google | Mismo uid, conserva `rol`, quedan los dos proveedores |
| Cuenta con contraseña y mail **sin verificar** entra con Google | **La contraseña se desvincula**: la vieja da `INVALID_PASSWORD` |
| Control: la misma con el mail verificado | Quedan las dos formas |

Con el script creando la cuenta sin contraseña, la trampa no puede pasar: la
contraseña nace por un correo que verifica el mail.

⚠️ **Y apareció un agujero que ningún documento tenía: el registro
anticipado.** La API key web es pública, así que cualquiera puede llamar a
`accounts:signUp` con el mail de un familiar y una contraseña suya. Si después
el script le da `rol: admin` a "la cuenta de ese mail", el panel queda en manos
de quien la registró. **El script se niega** a habilitar una cuenta con
proveedor `password` y `emailVerified: false`, y le dice a quien lo corre que
la borre primero.

**Alternativas descartadas:**
- *Registro en el panel y aprobación del dueño*: más burocracia de la que pidió
  el dueño, y abre la trampa de la tercera fila.
- *El script pone una contraseña temporal y se manda por WhatsApp*: contraseñas
  en un chat, y el mail sigue sin verificar.
- *Deshabilitar el registro por API en el proyecto*: sólo existe con Identity
  Platform, que es otro producto y otra facturación.

### 2. La sesión es un tipo cerrado, y el permiso sale del token

```
Sesion = Resolviendo | SinSesion | SinPermiso(mail) | Inaccesible(mail) | Operador(mail)
```

- `sesionDesde(mail, claims)` es Dart puro: `claims['rol'] == 'admin'` →
  `Operador`. Cualquier otro valor, o ninguno, → `SinPermiso`.
- `Inaccesible` es el token que no se pudo leer (sin red). Existe para que un
  corte **no se lea como "no tenés permiso"**, que es el reverso de HU-01.2.
- La data escucha `idTokenChanges()`. "Ya me dieron acceso" llama a
  `getIdTokenResult(true)` y después **invalida el provider**: la suscripción
  nueva lee el token ya renovado. No depende de si la web vuelve a emitir tras
  un refresco forzado.
- Los claims del cliente no son una defensa: la defensa son las reglas, que
  miran el mismo claim. El panel sólo decide **qué pantalla mostrar**.

### 3. Las rutas: una función pura decide, go_router ejecuta

`destinoPara(Sesion, Uri) → String?` vive en `lib/app/destino.dart`, sin
Flutter, y se prueba con `dart test`. `go_router` la llama desde `redirect`, y
un `ValueNotifier<Sesion>` alimentado por `ref.listen` es su
`refreshListenable`.

- Sin sesión → `/entrar?desde=<sección>`; al entrar vuelve a `desde`, **sólo si
  es una sección conocida** (nada de redirecciones abiertas).
- Resolviendo → `/espera?desde=…`: recargar en `/pedidos` no te tira a
  Catálogo.
- Una ruta desconocida la resuelve `errorBuilder`: "Esa página no existe".

**Por qué `go_router`:** el panel es web, y en la web las rutas son URLs que se
recargan, se comparten y responden al botón de atrás. `Navigator` a mano
reimplementa eso mal. (Memoria del proyecto: *preferir la dependencia a la
implementación propia*.)

### 4. Las capas, y dónde se cablea

```
lib/
  theme/                    tokens.dart (los únicos literales de color), tema.dart
  app/                      rutas.dart · destino.dart (puros) · enrutador.dart
  core/presentation/        marca, aviso — piezas que usan dos features
  features/acceso/
    domain/                 sesion.dart · repositorio_de_sesion.dart (interfaz + errores)
    data/                   codigos_de_auth.dart (puro) · repositorio_de_sesion_firebase.dart
    acceso_providers.dart   el único que conoce la implementación
    presentation/           entrada, contraseña, Google, sin acceso
  features/estructura/presentation/   banda, barra, espera, no encontrada, sección vacía
  features/catalogo/presentation/     pantalla_del_catalogo.dart (vacía)
  features/pedidos/presentation/      pantalla_de_pedidos.dart (vacía)
```

`layer-boundary` prohíbe que `presentation/` importe `data/`: el provider que
elige la implementación vive **al lado** de las capas, y la pantalla pide el
provider. `app/enrutador.dart` es la raíz de composición: conoce las pantallas
de todas las features.

### 5. La dirección visual: la mezcla C

El dueño eligió mirando el lienzo
([maquetas](https://claude.ai/artifact/1Eie7nobYEDNqQp4Ck6fv7)): **los colores
de la planilla** —banda de tinta con el dorado, superficies blancas sobre
papel hondo— **con la búsqueda y los renglones de la libreta**. En este cambio
sólo se construyen la banda, la barra, la entrada y el acceso denegado; los
renglones quedan fijados en tokens para EP-03.

- Tipografía: **Archivo** para toda la interfaz y las cifras (con
  `tabularFigures`); **Newsreader** sólo para nombres (la marca y, después, los
  vinos). Fraunces no entra: es ceremonia (`direccion.md §12`).
- Los estados se dicen con **palabras**, no con colores nuevos: la paleta sigue
  siendo dos colores más blanco.
- `google_fonts` baja las fuentes en tiempo de ejecución desde
  `fonts.gstatic.com`. Alternativa descartada: empaquetar los `.ttf` variables,
  que en Flutter piden `FontVariation` a mano en cada estilo.

Contrastes calculados con la fórmula de WCAG 2.1 (controles: negro/blanco
21,00; dorado/tinta 8,80):

| Par | Ratio |
|---|---:|
| `tinta3` sobre blanco / sobre papel hondo | 6,03 / 5,04 |
| borgoña sobre blanco / blanco sobre borgoña | 9,62 / 9,62 |
| `marfil2` sobre la banda / dorado sobre la banda | 9,59 / 8,80 |
| `filetePapel` sobre blanco (borde de control) | 3,86 |

### 6. Publicar: CI compila, esta máquina promueve

- `ci.yml` gana el alcance `panel`: `dart test`, `flutter analyze
  --no-fatal-infos`, `flutter build web --release`, `SHA256SUMS` y `COMMIT`, y
  `actions/upload-artifact`. Sólo corre en `workflow_dispatch` con ese alcance.
- `scripts/panel/publicar.sh preview <run-id>` exige que la corrida sea
  `success` (leído con `gh run view --json conclusion`, no con el exit code de
  `gh run watch`), baja el artifact, verifica cada hash y hace
  `firebase hosting:channel:deploy`.
- `scripts/panel/publicar.sh promover <canal>` hace `hosting:clone` del canal a
  `live`.

**Alternativa descartada:** un workflow de deploy con una cuenta de servicio en
los secretos de GitHub. Crear esa credencial es una decisión aparte, y el
pendiente *"deploy desde tag"* ya la va a pedir.

### 7. Presupuesto de lecturas: cero

Entrar, renovar el token y navegar no leen Firestore. `firestoreProvider` sigue
sin usarse. El número contra la cuota de 50.000/día no se mueve.

## Risks / Trade-offs

- **[Google no anda en el dominio del canal de preview]** Los canales son
  subdominios que no están en los dominios autorizados → Google se verifica en
  live; en preview se verifica con contraseña.
- **[Un token con el claim viejo vale hasta una hora]** Quitar acceso revoca
  los refresh tokens, pero el ID token vigente sigue sirviendo a las reglas
  hasta que vence → el script lo dice al quitar.
- **[El panel no se probó compilando antes del push]** Cada error es una vuelta
  de CI → APIs leídas del pub cache, `dart format` como chequeo sintáctico, y la
  lógica en Dart puro.
- **[`google_fonts` depende de la red del teléfono]** Sin red la interfaz cae en
  la fuente del sistema, no se rompe.
- **[La API key web está en el repo público]** Es pública por diseño; restringirla
  por referrer queda como pendiente.

## Migration Plan

Nada que migrar: no hay datos ni usuarios. Orden de publicación: no hay reglas
ni functions en este cambio, así que es sólo el front del panel. El hosting del
panel no comparte bytes con la vidriera (`firebase.json`, target `admin`), así
que publicar no arrastra la tienda.

Rollback: `firebase hosting:rollback` o volver a clonar la versión anterior.

## Open Questions

- La marca *"puede avisar por WhatsApp"* (HU-07.3): si termina siendo un claim,
  la pone este mismo script. Se decide con HU-07.3.
