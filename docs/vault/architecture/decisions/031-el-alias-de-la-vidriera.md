# ADR 031 — El alias `bouquet-tienda.web.app`: un sitio de Hosting que reenvía a la vidriera

- **Fecha:** 2026-10-05
- **Estado:** aceptada; **publicada y verificada el 2026-10-05**. **Provisoria**: se borra el día
  que exista el dominio (ver *Cuándo deja de servir*)
- **Decide:** con qué link se muestra la tienda mientras no hay dominio, y qué se abre para
  conseguirlo
- **Toca:** [ADR 017](017-preview-cerrada.md) (la URL de App Hosting deja de ser la única puerta, y
  el servicio de Cloud Run queda abierto) y [ADR 005](005-hosting-vidriera.md) §4 (suma una caché de
  HTML que no se purga por tag: por qué acá se acepta y hasta cuándo)
- **Hace cumplir:** `bash scripts/tienda/preview.sh verificar`, paso 6
- **Sin openspec:** es infraestructura, no toca `apps/tienda`

## Contexto

La tienda vive en `bouquet-tienda--bouquet-vinos.us-east4.hosted.app`. Ese formato lo arma App
Hosting con el nombre del backend, el del proyecto y la región, y **no se puede cambiar**. Lo pidió
el usuario: *"podemos dejar la tienda en un link mas limpio? aun no compro el dominio pero me sirve
para mostrarle a otro futuro cliente"*.

`bouquet-vinos.web.app`, el nombre más limpio del proyecto, es el panel.

## Decisión

### 1. Un sitio de Firebase Hosting sin archivos, con una sola reescritura

El sitio `bouquet-tienda` reenvía `**` al servicio de Cloud Run `bouquet-tienda` de `us-east4`, que
es el que App Hosting crea para el backend. No hay segundo build ni segundo deploy de la tienda: es
el mismo servidor por otra puerta.

Su configuración **vive en `preview.sh`** (`publicar_alias`) y se arma en `.deploy/alias`, no en el
`firebase.json` de la raíz. Ese archivo es el del panel, que se promueve y no se republica: con los
dos sitios ahí, un `--only hosting` sin destino publicaría los dos.

`public` va **vacío a propósito**: en Hosting un archivo estático le gana a la reescritura, y un
`index.html` taparía la home.

### 2. El servicio de Cloud Run queda abierto a llamadas públicas

`allUsers` como `roles/run.invoker` en el servicio `bouquet-tienda`. **Hosting no se autentica contra
Cloud Run**: medido, con el servicio cerrado el alias contestaba el mismo 403 de `Google Frontend`
que un pedido directo. El clasificador de permisos frenó el otorgamiento y **lo corrió el usuario a
mano**:

```bash
gcloud run services add-iam-policy-binding bouquet-tienda --region us-east4 \
  --project bouquet-vinos --member=allUsers --role=roles/run.invoker
```

Lo que eso abre: las dos URLs `run.app` del servicio pasan a contestar, **sin CDN adelante**. La
tienda ya era pública por la URL de App Hosting, así que no se expone nada nuevo; lo que cambia es
que hay un camino que llega siempre a la instancia. Llevan `noindex` porque lo pone Next, no el
borde. El tope sigue siendo `maxInstances: 1` (ADR 017 §5).

### 3. Publicar el alias es purgarlo, y va después de cada rollout

Hosting cachea lo que le contesta Cloud Run según su `Cache-Control`. La home y `/oficio` salen con
`s-maxage=31536000` y Hosting las guarda (medido: `X-Cache: HIT` en la segunda pedida). **Lo único
que vacía esa caché es una publicación del sitio.** Sin eso, después de un rollout el alias sigue
sirviendo el HTML del build anterior, que pide chunks que el build nuevo ya no tiene.

Por eso `desplegar` llama a `publicar_alias` después del rollout, y `verificar` compara `/` y
`/oficio` por los dos caminos: son estáticas y salen byte a byte iguales.

### 4. El alias lleva `noindex`, y no se toca

Es un link para mostrar, no para Google. `PREVIEW_CERRADA=1` lo pone Next en toda respuesta, así que
viaja por cualquier puerta. `verificar` lo usa además como prueba de que el 404 lo contestó la
tienda: el 404 propio de Hosting no lo trae.

## Por qué NO las alternativas

| Alternativa | Por qué no |
|---|---|
| Un `web.app` que **redirige** a la URL larga | El link queda limpio en el mensaje y la barra del navegador muestra la larga apenas abre. No resuelve lo pedido |
| Un **subdominio de un dominio propio**, por los dominios personalizados de App Hosting | Es el camino soportado y ensayaría el día del dominio (qué `Host` le llega a Next, ADR 017 §4). Se ofreció y el usuario eligió ésta. **Si aparece un dominio, reemplaza a este alias** |
| Darle `bouquet-vinos.web.app` a la tienda y mudar el panel | Rompe el marcador de la familia, los referrers de la API key y la URL de vuelta del correo de acceso ([ADR 011](011-entrar-al-panel.md)) |
| Un Worker de Cloudflare en `workers.dev` | Cuenta y herramienta nuevas, y el `Origin` no coincidiría con el host que ve Next: las Server Actions se rechazan salvo que el Worker reescriba cabeceras. Es código nuestro en el camino de todas las páginas |
| Una Cloud Function que haga de proxy | Lo mismo: código nuestro en el camino, y un salto más |
| El sitio como destino en el `firebase.json` de la raíz | §1 |
| Apagar el chequeo de IAM del servicio (`invokerIamDisabled`) en vez de la política | Vive en la especificación del servicio, que App Hosting reescribe en cada rollout. **Razonado, no medido** |

## Presupuesto de lecturas

Campo obligatorio, contra los 50.000/día. **Cero lecturas nuevas.** Es el mismo servicio, la misma
instancia única y la misma caché de Next: una puerta más no agrega reconstrucciones del catálogo.
El techo de [ADR 017](017-preview-cerrada.md) —una reconstrucción por minuto, ~49.000 lecturas si
alguien la martilla las 24 h— lo fija `maxInstances: 1`, no la cantidad de puertas.

El egress del alias lo cobra Hosting: 10 GB/mes sin cargo y después US$ 0,15/GB, los mismos números
que App Hosting en [ADR 005](005-hosting-vidriera.md). Para un link de muestra no se acerca.

## Verificación (2026-10-05)

| Qué | Cómo |
|---|---|
| El antes | Directo a las dos URLs `run.app`: **403** en 6 pedidos. Por el alias recién publicado: **403** con `Server: Google Frontend` — Hosting llega y Cloud Run rechaza |
| Las rutas | Después del permiso: `/`, `/vinos`, `/oficio`, `/carrito` y `/pedido` dan 200 con el telón; dos rutas inventadas dan 404. `noindex` en las siete |
| Que es el mismo build | `/` y `/oficio` con el mismo SHA-256 por el alias y por la URL larga |
| La caché de Hosting | `X-Cache: HIT` en la segunda pedida de `/`, servida desde el borde de Buenos Aires (`EZE`) |
| La navegación del cliente | Un pedido RSC da el mismo 307 por los dos caminos y, siguiéndolo, `text/x-component` |
| El cotizador (Server Action) | `cotizarEnvio` por el alias con su origen: `1425` → `C`, `1900` → `B`, idéntico a la URL larga. **Control negativo:** con un `Origin` ajeno da **500** — el chequeo de origen de Next corre y el alias lo pasa por la razón correcta. Un código postal inválido da `ok: false` |
| Los archivos | Un chunk, una hoja de estilo y una fuente dan 200 por el alias; un archivo inventado, 404. Las fotos no pasan por el alias: son URLs absolutas de Storage, 200 `image/webp` |
| Que el paso 6 discrimina | `preview.sh verificar` dio **rojo** con el 403 antes del permiso y **verde** después, con los cinco pasos de la tienda en verde las dos veces |

### Lo que NO se verificó

- **Nadie lo miró renderizado.** El HTML es byte a byte el de la URL larga y los archivos dan 200:
  es un razonamiento, no una captura. **Disparador:** que el usuario lo abra en su teléfono antes
  de mandarlo. Desde 2026-10-05.
- **Si un rollout de App Hosting pisa el permiso de §2.** La política de IAM no es parte de la
  especificación del servicio, pero no se midió. **Disparador:** el próximo `desplegar`; el paso 6
  lo dice con el 403 y el comando. Desde 2026-10-05.
- **La rama *"otro build"* del paso 6 no se vio en rojo**: haría falta un rollout sin publicar el
  alias. **Disparador:** el mismo.

## Cuándo esta decisión deja de servir

- **El día que exista el dominio, el alias se borra entero.** Con Cloudflare adelante, esta capa
  sería una caché de HTML que no se purga por tag: lo que [ADR 005 §4](005-hosting-vidriera.md)
  dice que hay que evitar. Son cuatro cosas: borrar el sitio (`firebase hosting:sites:delete
  bouquet-tienda`), **sacar `allUsers` del servicio** (`gcloud run services
  remove-iam-policy-binding`, mismos argumentos de §2), y quitar `publicar_alias` y el paso 6 de
  `preview.sh`.
- **Si el link se difunde más allá de una muestra:** vigilar el uso, por el techo de lecturas de
  ADR 017.
