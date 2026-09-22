## Context

El panel escribe `imagenes: []` una vez, en el alta, y nada la vuelve a tocar.
La vidriera sirve la foto **ya recortada en WebP**, sin `next/image`, y hoy ese
recorte lo hace `scripts/seed/seed.mjs` con `sharp`.

Tres restricciones que no se negocian y que ordenan todo lo demás:

1. **La ventana de la vidriera depende del recorte, no sólo del formato.**
   `VentanaDeBotella.tsx:11-14` iguala la altura con el recorte al borde de la
   botella —*"`object-fit` no sabe dónde está la botella dentro del cuadro"*— y
   `catalogo.css:583` usa `mix-blend-mode: multiply`, que supone el blanco del
   packshot.
2. **El panel no compila en esta máquina** (`CLAUDE.md`). Su único ciclo de
   feedback es CI, así que todo lo que se pueda verificar en Node —la tubería,
   la callable— se verifica ahí, donde el ciclo es de segundos.
3. **Es la primera Cloud Function del proyecto.** `functions/src/index.ts`
   exporta `export {}` y `cloudfunctions.googleapis.com` está **apagada**
   (medido: 403 `SERVICE_DISABLED`).

## Goals / Non-Goals

**Goals:**

- Que una foto elegida en el panel llegue a la vidriera **con exactamente la
  misma forma** que las del seed.
- Que el operador vea, antes de decidir, **cómo se va a ver en la tienda**.
- Que ningún fallo de subida sea invisible.

**Non-Goals:**

- **Reordenar fotos y elegir la principal** (HU-04.2). Disparador: el primer
  vino con dos fotos.
- **Quitar el fondo de una foto de cámara.** Disparador: que la
  previsualización resulte insuficiente **mirándola**.
- **Borrar archivos de Storage.**
- Tocar reglas, la vidriera o `packages/contratos` más allá de tres constantes.

## Decisions

### 1. Una callable, no un trigger de Storage

Un `onObjectFinalized` es la forma canónica y es la **equivocada acá**. Es
asincrónico: el panel sube, el trigger corre en otro lado, y el único canal de
error es un log que el operador no lee. Eso reconstruye el bug de PadelPunilla
que HU-04.4 existe para no repetir — *spinner, vuelta al botón, nada*.

Una callable es sincrónica: el error vuelve a la pantalla con el nombre del
archivo. **HU-04.4 sale gratis del transporte**, en vez de necesitar una
máquina de estados de subida.

**Alternativa descartada:** trigger + un campo de estado en el documento que el
panel escucha. Es más piezas para un resultado peor.

**Costo de esta elección:** hay que habilitar `cloudfunctions`. Un trigger
habría necesitado además `eventarc`, así que la callable también es la opción
barata.

### 2. El crudo va a Storage primero; la callable recibe la ruta, no los bytes

Mandar los bytes en el payload evitaría un viaje, pero una foto de 5 MB en
base64 son ~6,7 MB de request, sin barra de progreso y sin reanudación. Storage
da las dos cosas.

**Consecuencia que hay que aceptar:** existe una ventana con un archivo crudo
en un prefijo de lectura pública. No es alcanzable —su URL no está en
`imagenes[]` y el nombre es un UUID— y la callable lo borra al terminar.

### 3. La extensión sale de los bytes mágicos, no del `mimeType` ni del path

[ARQUITECTURA §5.4](../../../ARQUITECTURA.md#54-fotos-de-producto-la-regla-de-la-extensión)
regla 1 pide una lista cerrada derivada del `mimeType` y **nunca** del path.
Acá se va un paso más allá, y por un motivo medido en el terreno: en web el
`XFile` trae `mimeType` del `File` del navegador, pero **en Android puede venir
`null`**, y la tentación en ese caso es caer al path — que es justo lo
prohibido.

Leer los primeros bytes resuelve las dos plataformas con un solo camino, no
depende de que el selector informe bien, y es **más estricto** que la regla,
no menos: un PDF renombrado `foto.jpg` se detecta antes de subir.

`mimeType`, cuando viene, se usa como control cruzado.

### 4. Los tres números viven en `packages/contratos`; las tres llamadas a `sharp`, no

La tubería es `trim({threshold: 12})` → `resize({height: 1200,
withoutEnlargement: true})` → `webp({quality: 82})`. La tienen que aplicar el
seed y la function.

`contratos` **no puede depender de `sharp`**: su cero-dependencias es una
decisión del proyecto en una máquina de 7,9 GB. Así que lo compartido son **los
números**, no el código:

```
packages/contratos/src/foto.ts   →   TUBERIA_DE_FOTO = { umbralRecorte, alto, calidadWebp }
```

Las tres llamadas quedan duplicadas —tres líneas en cada lado— y **lo que
impide que diverjan no es la disciplina, es un test**: procesar la misma
fixture por los dos caminos y exigir el mismo SHA-256. Si alguien agrega un
`.sharpen()` de un lado, el test se pone rojo.

**Alternativa descartada:** un paquete `packages/fotos` con `sharp` adentro.
Más limpio en el papel, pero agrega un workspace y un `node_modules` nativo
para compartir tres líneas.

### 5. El `arrayUnion` lo hace el panel, no la callable

La callable corre con el Admin SDK y **saltea las reglas por diseño**. Si
escribiera `imagenes`, `firestore.rules` dejaría de ser la puerta de ese campo.

Dejándolo en el panel, la callable queda como una función pura de bytes —fácil
de testear, sin permisos sobre Firestore— y la regla sigue siendo la última
palabra.

### 6. El nombre del archivo sale del hash del contenido

`{sha256(webp).slice(0,16)}.webp`, igual que el seed. Hace la operación
**idempotente**: la misma foto subida dos veces da la misma URL y `arrayUnion`
no duplica. Y el nombre original —que puede traer barras, espacios o acentos—
nunca toca la ruta.

### 7. La previsualización multiplica contra el tono del papel, no contra el degradé

En Flutter, `Image(color: papel, colorBlendMode: BlendMode.multiply)` da
exactamente `imagen × color`, que es lo que hace `mix-blend-mode: multiply`
sobre un fondo sólido.

**El fondo real no es sólido:** `catalogo.css` lo dibuja con un
`radial-gradient` entre `--papel-ventana` y ese mismo papel mezclado al 82 %
con tinta — *"el papel con su lámpara"*. La previsualización lo aproxima con el
tono del centro.

Se acepta la aproximación porque **la pregunta que contesta la previsualización
es binaria**: ¿el fondo desaparece o queda un rectángulo? Un ±5 % de brillo no
la cambia. Replicar el degradé exacto pediría una capa de blend aislada
—`saveLayer` a mano— para una diferencia que no altera ninguna decisión.

⚠️ **Esto copia un color de la vidriera al panel**, que son dos sistemas de
diseño distintos (H2 nunca corrió). Va como constante con nombre y con el
comentario apuntando al token CSS. **Puede desincronizarse**, y por eso queda
anotado acá y no escondido en un widget.

### 8. `sharp` se declara donde se usa

Hallazgo de esta sesión: **`sharp` no está declarado en ningún `package.json`
del repo.**

```
$ npm ls sharp
bouquet@0.27.1
`-- @bouquet/tienda@0.1.0 -> .\apps\tienda
  `-- next@16.3.4
    `-- sharp@0.35.4
```

El seed lo importa y funciona **porque Next lo arrastra y npm lo iza a la raíz**.
El día que Next deje de traerlo, el seed se rompe sin que nadie haya tocado el
seed. `functions/package.json` lo declara explícito, y el seed gana su
declaración en la raíz — es una línea, y sin ella este change construye sobre
el mismo accidente.

## Risks / Trade-offs

⚠️ **Descubierto durante el apply, en dos capas — la primera resuelta, la segunda sigue abierta.**

**Capa 1, resuelta:** `functions/tsconfig.json` no traía `allowImportingTsExtensions` ni `rewriteRelativeImportExtensions` — sólo `contratos` los tenía. Medido: Node **no** resuelve un especificador `./x.js` contra un archivo `x.ts` (`ERR_MODULE_NOT_FOUND`); el único que corre nativo es el que termina en `.ts`. Se alineó `functions/tsconfig.json` con `contratos` para que **autorar** use `.ts` en los imports (así `node --test` corre los `.ts` de `test/` directo, sin build). Pero a diferencia de `contratos`, `functions/` sí tiene un destino que necesita JS real: se agregó `tsconfig.build.json` (mismas banderas + `noEmit: false`, `outDir: lib`) y un script `construir`. `rewriteRelativeImportExtensions` reescribe los `.ts` a `.js` en el emitido — **medido**: los cinco archivos de `lib/*.js` importan con `.js`, sin tocar una sola línea de `src/`. `main` volvió a `lib/index.js`, con un hook `predeploy` en `firebase.json` que corre `construir` antes de empaquetar.

**Capa 2, abierta:** con `lib/index.js` ya compilado, el emulador de Functions local sigue dando *"Cannot determine backend specification. Timeout after 10000"*. Aislado con medición, no es el código ni el `.ts`: el mismo `lib/index.js`, cargado como archivo real (no `node -e`, que tiene sus propias rarezas con imports dinámicos — medido aparte), resuelve en **1,2 s**. El cuello de botella está en el *discovery* del emulador en esta máquina, no en el módulo. Por indicación del usuario, no se sigue depurando acá: **la verificación real pasa al deploy (4.1) contra el runtime `nodejs24` real**, que es la autoridad de todos modos. El test de emulador (`procesar_foto.emulador.mjs`) queda escrito para cuando el emulador local o CI lo permitan.

**Capa 3, encontrada recién EN el deploy real (4.1), y la más cara de las tres:**
el primer `firebase deploy --only functions` completó con **exit 0** y
`functions:list` mostró `procesarFoto` — los dos son el "no le creas al color"
de `CLAUDE.md` en carne propia. La API cruda (`cloudfunctions.googleapis.com/v2/.../functions/procesarFoto`)
decía otra cosa: `"state": "FAILED"`, `CloudRunServiceNotFound`. El log
completo, no el resumen, tenía la causa: `npm error 404 ... @bouquet%2fcontratos
- Not found`. **Cloud Build sólo ve lo que se empaqueta** —`firebase.json`
declara `"source": "functions"`, así que sube 19,73 KB, sin `packages/` ni el
`node_modules` hoisteado del workspace— y `@bouquet/contratos` nunca se
publicó a npm: es un symlink de workspace que sólo existe en esta máquina.

**Arreglado con un bundle, no con un parche de un archivo.** Se evaluó copiar
a mano el único símbolo que hace falta (`TUBERIA_DE_FOTO`) en un predeploy,
pero **esto va a repetirse**: `functions/src/index.ts` ya declara que
`crearOrden` y `entroEnPagada` —las próximas dos functions del proyecto—
necesitan la máquina de estados entera de `contratos`, mucho más que tres
números. Se instaló `esbuild` (devDependency de `functions/`) y `construir`
pasó de `tsc --project tsconfig.build.json` a
`esbuild src/index.ts --bundle --platform=node --format=esm --target=node24
--outfile=lib/index.js` con `firebase-admin`, `firebase-functions` y `sharp`
como `--external` —son paquetes reales, Cloud Build sí los resuelve— y
`@bouquet/contratos` **sin** externalizar, así que esbuild lo empaqueta.
**Verificado, no supuesto:** `lib/index.js` (12 KB) tiene los tres imports
externos intactos, **cero** apariciones de `@bouquet/contratos`, y los tres
números de `TUBERIA_DE_FOTO` (12, 1200, 82) embebidos como código — y carga en
1,6 s como archivo real. `tsc --noEmit` sigue siendo quien tipa; esbuild no
chequea tipos, sólo empaqueta. `tsconfig.build.json` se borró: ya no lo usa
nadie.

**El bundle NO alcanzó solo — hicieron falta dos intentos más, y el segundo
enseñó algo que el primero no.** Con `@bouquet/contratos` todavía listado en
`dependencies`, el redeploy dio el **mismo E404**: el bundle sacó el import del
código, pero Cloud Build instala por lo que dice `package.json`, no por lo que
el bundle realmente usa. Se lo pasó a `devDependencies` —razonando que un
install de producción las omite— y **dio el mismo 404 una tercera vez**.
Medido: el paquete subido no lleva `package-lock.json` propio (sólo existe en
la raíz del workspace, y no viaja), así que el `npm install` de Cloud Build
corre **sin lockfile, aislado, sin contexto de workspace**, y sin lockfile
`npm install` instala `dependencies` y `devDependencies` por igual —no hay
`--omit=dev` implícito—. La única `.json` que no intenta resolverlo es una
que **no lo nombra en ningún lado**. Se sacó de los dos bloques. Local sigue
resolviendo porque `packages/contratos` es un workspace del repo: npm lo
symlinkea en la raíz para todos los workspaces lo declaren o no —verificado
con `tsc --noEmit`, el build y los 17 tests, los tres en verde sin la entrada
en `package.json`—. Documentado en `tuberia.ts`, al lado del único import que
lo usa, para que no se lea como un olvido.

| Riesgo | Mitigación |
|---|---|
| **Un paquete del workspace (`@bouquet/contratos`) no resuelve en Cloud Build**, porque nunca se publicó a npm y sólo `functions/` se sube | Resuelto con `esbuild`: lo empaqueta en el bundle, deja los paquetes reales como `--external`. Vuelve a aplicar sin cambios cuando `crearOrden` importe más de `contratos` |
| **El emulador de Functions local no completa el *discovery*** (capa 2 de arriba) | No bloquea: la verificación de HU-04.1/04.4 pasa al deploy real (4.1-4.3), con los mismos controles que iba a correr el emulador |
| **`sharp` trae binarios por plataforma.** Acá se instala `win32-x64`; la function necesita `linux-x64` | Lo resuelve el `npm ci` de Cloud Build, que corre en Linux. **Se verifica en el primer deploy, no se supone** |
| **Arranque en frío.** `sharp` es un módulo nativo grande; la primera subida después de un rato va a tardar | Se acepta. El panel lo usa a ráfagas al cargar el catálogo, así que la segunda foto en adelante encuentra la instancia caliente |
| **Una callable es un endpoint HTTPS público.** Las reglas no la protegen | Chequeo del claim `rol: admin` como primera línea, y validación de que la ruta sea `productos/{productoId}/{archivo}` con el id que vino en el argumento. Los dos, con test |
| **Una foto de teléfono pasa los 5 MB** y `storage.rules` la rechaza con `unauthorized`, que parece un problema de permisos | El panel mide el peso **antes** de subir y lo dice con el número. Es el primer error que va a ver quien suba desde el teléfono |
| **La previsualización aproxima el degradé** | Aceptado y escrito arriba. Lo valida el dueño mirándolo, que es el único juez posible |
| **Un crudo queda en Storage si la callable falla** | No es alcanzable y no rompe nada. Se limpia con un script el día que pesen |
| **El deploy de `panel` arrastra todo lo mergeado** (`CLAUDE.md`) | El HEAD sólo tiene EP-01..03, ya desplegadas y verificadas el 2026-09-22. **No hay polizón de vidriera**: este change no toca `apps/tienda` |

## Migration Plan

**Orden: functions → panel.** Sin reglas —no cambian— y sin tienda.

1. Habilitar `cloudfunctions.googleapis.com`. ⚠️ **Puede necesitar al dueño**:
   tocar recursos compartidos del proyecto es lo que frenó el clasificador con
   la API key el 2026-09-17.
2. `npm run tipos` y los tests de la tubería en local (Node, segundos).
3. Desplegar `functions`. **Verificar con `functions:list`**, que hoy devuelve
   403 — o sea que hay control negativo antes de empezar.
4. Probar la callable **contra producción**, con los tres controles: un
   packshot (recorta ~83 %), una foto con fondo (recorta 0 % y **igual sube**),
   y un PDF renombrado (rechaza).
5. Recién ahí, CI `alcance=panel` → `publicar.sh preview` → verificar el canal
   → `promover`.
6. Verificar en live con un canario nuevo y discriminante.

**Rollback:** la function se borra con `firebase functions:delete`; el panel
vuelve con `hosting:clone` desde la release anterior. Los dos son
independientes: un panel viejo con la function puesta simplemente no la llama.

## Open Questions

- **¿Habilitar la API la puedo hacer yo o la hace el dueño?** Se resuelve
  intentándolo, no discutiéndolo.
- **¿El alto de 1200 sigue sirviendo para la ficha en un teléfono?** El seed lo
  fijó para el catálogo. No lo abre este change: cambiarlo cambiaría también
  las 20 fotos de muestra.
- **¿La previsualización le resulta clara al dueño?** Es la única pregunta que
  no puedo contestar desde acá, y decide si alguna vez hace falta el recorte de
  fondo.
