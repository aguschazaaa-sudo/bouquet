# ADR 030 — Cotizar con Envíopack: el adaptador escrito y dormido hasta las claves

- **Fecha:** 2026-10-01
- **Estado:** aceptada; **desplegada DORMIDA y verificada el 2026-10-01** (v0.52.0, `822a9fc`,
  rollout `build-2026-10-01-002`). El adaptador está en producción y tiene tests, pero sin
  `ENVIOPACK_API_KEY` y `ENVIOPACK_SECRET_KEY` en el entorno la vidriera sigue cotizando con
  el simulado. Se prende con los secretos (ver *Cómo se prende*). Lo que sí cambió en
  producción es la provincia (§7): ver *Verificación*
- **Decide:** que Envíopack es el proveedor de envío por correo; qué endpoint se usa para
  mostrarle un precio al comprador; cómo se guarda y se renueva el token; qué se hace con una
  respuesta que no se puede leer; y quién contesta mientras no hay claves
- **Toca:** [ADR 010](010-el-checkout.md) §3 (el puerto y el simulado: ahora son dos
  cotizadores), [ADR 026](026-envio-sin-cargo.md) (el sin cargo sigue siendo de bouquet, no de
  la tarifa del proveedor), [ADR 008](008-catalogo-stock-y-carrito.md) (suma el hallazgo 11 a
  la lista de `crearOrden`) y [`proveedores/enviopack.md`](../proveedores/enviopack.md), que
  deja de ser una evaluación
- **Hace cumplir:** `apps/tienda/test/enviopack.test.ts` (23 casos: el adaptador contra un
  Envíopack falso que contesta los ejemplos de la doc) y siete casos nuevos de
  `apps/tienda/test/envios.test.ts` (quién contesta según el entorno, y qué provincia viaja)
- **Sin openspec:** el diseño ya estaba escrito en ADR 010 §3 y en `enviopack.md` §11. Esto
  lo ejecuta. **Toca plata: Workflow D**, `revisor-pagos` antes del commit

## Contexto

El 2026-10-01 el dueño pidió *"armar la estructura para los envíos, apenas tenga el token lo
agregamos"*, con la página de cotización de Envíopack. El puerto `ProveedorDeEnvio` y el
`CotizadorSimulado` existen desde ADR 010; la investigación del proveedor, desde
[`enviopack.md`](../proveedores/enviopack.md). Faltaba lo que los une.

⚠️ **"El token" no es un token.** Envíopack entrega una `api-key` y una `secret-key`; el
`access_token` sale de cambiarlas en `POST /auth` y dura cuatro horas. Lo que hay que guardar
como secreto son **las dos claves**, no un token, que vencería antes del primer pedido.

## Decisión

### 1. Se cotiza el PRECIO, no el COSTO

Envíopack tiene dos familias de endpoints: `/cotizar/costo` (lo que paga bouquet) y
`/cotizar/precio/*` (lo que paga el comprador, según las tarifas que el dueño fija en el
panel de Envíopack, *Correos y Tarifas*). La vidriera usa **precio**: mostrar el costo es
regalar el margen que el dueño haya puesto ahí, y fijarlo desde su panel es lo que el
proveedor ya ofrece.

### 2. Sólo a domicilio, y una sola opción

`/cotizar/precio/a-sucursal` pide el **id de localidad de Envíopack**, que no se busca por
código postal (`GET /localidades` filtra por provincia, nada más), y devuelve **una lista de
sucursales**: el comprador tendría que elegir una, y eso es otra pantalla cuya forma depende
de respuestas que nadie vio todavía.

⚠️ **Consecuencia que se ve:** con las claves puestas, la opción *"A una sucursal cerca"*
**desaparece** del checkout. Hoy la muestra el simulado, con un precio inventado. Se acepta:
una opción con precio real vale más que dos con una inventada.

De lo que vuelve a domicilio se ofrece **la más barata**; a igual precio, la que tarda menos.
Elegir entre servicios es trabajo del agregador, no del comprador (ADR 010: no se muestra el
nombre del correo). Pero "la más barata" se lleva cualquier fila que esté de más, así que
compite sólo lo que es **este** envío:

- **Servicio `N`, `P` o `X`** (estándar, prioritario, express). La doc lista también `R`,
  **devoluciones**: una tarifa de devolución más barata que la estándar no es un envío.
- **La banda de peso contiene lo declarado**, con los dos bordes adentro. Una fila de 1 a
  2 kg para un pedido de 16 es la tarifa de otro paquete. Sin banda en la fila, no hay nada
  que comparar y vale.

### 3. Quién contesta lo decide el entorno, y la mitad es un error

| `ENVIOPACK_API_KEY` | `ENVIOPACK_SECRET_KEY` | Contesta |
|---|---|---|
| — | — | El simulado (hoy) |
| ✓ | ✓ | Envíopack |
| ✓ | — o al revés | **Nadie**: *"No pudimos calcular el envío ahora"* + WhatsApp, y el motivo al log |
| — | — y **el checkout cobra** | **Nadie**, igual que arriba |

Una sola clave **no** cae al simulado: eso es mostrar en producción un precio inventado
porque faltó un secreto, que es el error más caro que este archivo puede cometer y el más
silencioso. Caído se nota en la pantalla y en el log.

**Y sin ninguna, el simulado sólo vale mientras `EL_CHECKOUT_NO_COBRA` esté en `true`**
(hallazgo A2 de `revisor-pagos`). Con las claves ya puestas, un deploy desde un árbol donde el
bloque de `apphosting.yaml` sigue comentado —un worktree viejo, un revert; el deploy de la
tienda sale del árbol, no de HEAD— vuelve al simulado **sin una línea de log**. Con el cobro
prendido eso es cobrar un envío inventado en cada venta. Se ata al gate y no a una variable
del yaml porque **un árbol viejo trae las dos cosas juntas**: el simulado y el checkout que no
cobra.

### 4. El token, en memoria y renovado antes de vencer

- Un `access_token` por instancia del servidor, renovado a las **3 h 45** (la doc dice 4 h).
  Uno que vence en el medio de una cotización es un *proveedor caído* que no lo es.
- Dos cotizaciones que llegan juntas con el token vencido **esperan la misma** autenticación.
- Un **401 o 403** al cotizar tira el token, se autentica de nuevo y **reintenta una vez**. Dos
  rechazos seguidos ya no son el token: es *proveedor caído*.
- **No se usa `/token/refresh`**: la doc no muestra la forma de la respuesta de `/auth` (si
  trae `refresh_token`, ni cómo se llama), y volver a autenticar con las claves hace lo
  mismo sin depender de un campo que nadie vio.
- No se guarda en Firestore: costaría una lectura por cotización para ahorrar un `POST` cada
  casi cuatro horas.

### 5. Una fila que no se puede leer se descarta, no se adivina

| Lo que llega | Qué se hace |
|---|---|
| `valor: "80.00"` (texto) | `desdePesos` → 8000 centavos, sin pasar por un float |
| Más de dos decimales, no numérico, negativo | Se descarta: es un dato roto |
| `valor: "0.00"` | **Se descarta.** El sin cargo lo decide bouquet en `config/envios` (ADR 026), no una tarifa del proveedor; un cero de Envíopack es más probablemente una tarifa sin cargar que un regalo |
| Sin `horas_entrega`, o `<= 0` | Se descarta: no se promete un plazo inventado |
| `horas_entrega: 96` | 4 días (`ceil(h/24)`), y se muestra *"4 a 6 días hábiles"* |
| `modalidad: "S"` | Se ignora (§2) |
| `servicio: "R"` o sin servicio | Se descarta (§2) |
| Banda de peso que no contiene lo declarado | Se descarta (§2) |

**Sólo la lista VACÍA** es *"Ese código postal no nos suena"*. Una respuesta que no es una
lista, o una lista de la que no se puede leer **ninguna** fila, es que Envíopack contesta con
otra forma: es *"No pudimos calcular el envío ahora"*, y al log va **cuántas filas y por qué
motivo se descartó cada una** (`"3 filas y ninguna sirve (peso: 3)"`). La primera versión las
leía como CP desconocido: todos los compradores habrían visto *"no nos suena"* con el log
vacío (hallazgo M1). Un HTTP que no es 2xx (429 del tope de 3.000 cada 5 minutos, 5xx,
timeout de 5 s) → también *caído*. Los dos estados existían desde ADR 010; ahora los dispara
algo real.

### 6. Las claves no salen del servidor, ni al log

`enviopack.ts` vive en `src/server/` (la frontera de credenciales, ADR 004) y se importa
sólo desde `envios.ts`. El token viaja **en la query** —es lo que pide Envíopack—, así que
**ningún mensaje de error lleva la URL**: al log va `"Envíopack /cotizar/precio/a-domicilio
respondió 500"`, nunca la dirección pedida. Hay un test que lo mide.

⚠️ **Latente:** hoy no hay `instrumentation.ts`. El día que alguien registre OpenTelemetry,
Next arma un span `fetch GET <url>` con la URL entera, y el token termina en Cloud Trace.
Antes de eso, `NEXT_OTEL_FETCH_DISABLED=1` o sacarle la query al span. Está escrito en
`enviopack.ts`, al lado de la línea que pone el token.

### 7. La provincia que viaja es la del comprador, no la adivinada

Hasta este cambio la provincia salía del **primer dígito del código postal** y era sólo un
prellenado. Con Envíopack es un parámetro que cambia el precio, y la adivinanza mandaba
**CABA como Buenos Aires** (1425 → `B`), Mendoza y San Luis como Córdoba, Santa Fe como Entre
Ríos. Y si el comprador la corregía, el precio se quedaba con la adivinada (hallazgo A1).

- **Del 1000 al 1499 es la Ciudad** (`C`), con el 1500 como control de que la banda no se
  comió el conurbano.
- **`cotizarEnvio` recibe la provincia del formulario**, y si es un ISO válido manda.
- **La pantalla la manda sólo si ya es la de ESE código postal** (`provinciaDelCp`): con un
  código recién escrito, la del anterior no vale y la adivina el servidor.
- **Y no cotiza dos veces cada código postal.** La primera va sin provincia, el servidor la
  adivina y la pantalla la precarga; si eso volviera a cotizar, cada CP serían dos requests.
  `useCotizacion` recuerda la pregunta que ya tiene respuesta —mismo CP, misma carga, **la
  provincia que vino en la respuesta**— y no la vuelve a hacer. Corregirla sí re-cotiza.

`PaginaDelCheckout.tsx` pasó las 200 líneas con esto y `widget-size-guard` frenó: la rama del
pedido vacío salió a `PedidoVacio.tsx`, sin cambios.

### 8. El texto de las opciones, en un solo lugar

`opciones-de-envio.ts` arma la opción a domicilio y la de sucursal para **los dos**
cotizadores. Dos copias de *"Hasta tu puerta"* se separan en la primera corrección de `voz`, y
la pantalla diría cosas distintas según quién cotizó. El texto **no cambió**: se mudó.

## Por qué NO las alternativas

| Alternativa | Por qué no |
|---|---|
| Esperar a tener las claves para escribirlo | El dueño lo pidió antes, y el simulado ya tiene la forma: lo que faltaba era traducción, y la traducción se prueba contra la doc |
| `/cotizar/costo` | Es lo que paga bouquet. Mostrarlo es vender el envío al costo sin que nadie lo haya decidido |
| Guardar un `access_token` como secreto | Vence a las cuatro horas |
| Caer al simulado si falla Envíopack | Un precio inventado en producción. El estado *caído* existe para esto |
| Ofrecer también el prioritario | Una segunda opción a domicilio que se diferencia en días y plata obliga a explicar qué es "prioritario". Si el dueño la quiere, es un cambio en `laMasBarata` |
| Vivir en `functions/` desde ya | Hoy la única que cotiza es la vidriera. Ver §*Lo que queda abierto* |
| El SDK no oficial (`Fblind/enviopack-node`) | Marcado *under development*; son dos `fetch` |

## Presupuesto de lecturas

Campo obligatorio.

| | Lecturas de Firestore |
|---|---|
| Una cotización | **0.** Va a Envíopack, no a la base |
| El token | **0.** En memoria de la instancia, no en Firestore (§4) |

**Lo que sí cuesta es el tope de Envíopack: 3.000 requests cada 5 minutos.** Una cotización es
un `GET` (más un `POST /auth` cada 3 h 45 por instancia, y la tienda corre con
`maxInstances: 1`). El debounce de 400 ms de `useCotizacion` (ADR 010 §3) es la defensa
contra el comprador —un código postal escrito es una cotización, no cuatro—, y §7 evita la
segunda por la provincia precargada. **Contra quien llama a la Server Action directo no hay
defensa todavía**: ver M2 en *Lo que queda abierto*.

## Cómo se prende

1. Con las dos claves de la cuenta de Envíopack:
   ```
   firebase apphosting:secrets:set ENVIOPACK_API_KEY --project bouquet-vinos
   firebase apphosting:secrets:set ENVIOPACK_SECRET_KEY --project bouquet-vinos
   firebase apphosting:secrets:grantaccess ENVIOPACK_API_KEY,ENVIOPACK_SECRET_KEY --backend bouquet-tienda --project bouquet-vinos
   ```
2. Descomentar el bloque de `apps/tienda/apphosting.yaml`. **Comentado a propósito**: un
   `apphosting.yaml` que referencia un secreto inexistente hace fallar el rollout.
3. Antes del deploy, en local: las dos claves en `apps/tienda/.env.local` y `npm run dev`
   (en `localhost`, no en `127.0.0.1`). Cotizar un CP de CABA y uno de Ushuaia, y llenar la
   tabla de abajo.
4. Desplegar la tienda.
5. **Verificar con un canario discriminante**: con el simulado el checkout ofrece **dos**
   opciones y precios redondos a la centena; con Envíopack, **una**. Control negativo: un CP
   inventado tiene que dar *"no nos suena"*. Y el log del backend sin una sola línea
   `cotizarEnvio:` en la prueba que salió bien. Cotizar **un CP de CABA**, que es el que
   antes viajaba como `B`.
6. Mirar `git diff apps/tienda/apphosting.yaml` después de `apphosting:secrets:set`: no está
   verificado si el CLI agrega entradas por su cuenta.

## Lo que hay que medir con las claves en la mano

| Qué | Por qué importa |
|---|---|
| La forma real de la respuesta de `/auth` (`access_token`, ¿`expires_in`?) | Si el campo se llama distinto, todo cae en *proveedor caído* |
| Qué devuelve `/cotizar/precio/a-domicilio` para un CP que no existe (¿`[]`, 400, 404?) | Hoy un 4xx se lee como *caído*, no como *CP desconocido* |
| Si `peso` es el total o por paquete cuando `paquetes` trae varios | Se manda el **total**. Si Envíopack lo lee por paquete, las bandas vuelven alrededor de 8 kg, todas caen por `peso` (§2) y **el log lo dice el primer día**: `ninguna sirve (peso: N)` |
| Si `horas_entrega` son horas corridas o hábiles | Cambia cuántos días se prometen |
| Precio contra costo para el mismo CP | Si el dueño no cargó tarifas, ¿el precio es el costo, o es cero? (cero se descarta, §5) |
| Que Envíopack acepte despachar vino | Zona gris de `enviopack.md` §12. **Antes del primer envío real**, no del primer precio |

## Lo que queda abierto

- **`crearOrden` tiene que re-cotizar del lado del servidor** — hallazgo 11 de
  [ADR 008](008-catalogo-stock-y-carrito.md). El precio del envío que manda el navegador no
  vale; y si `crearOrden` vive en `functions/`, este adaptador **se muda** a un lugar que las
  dos puedan importar. Está escrito sin nada de Next adentro para que la mudanza sea mover un
  archivo.
- **A sucursal**, con su pantalla para elegir la sucursal (§2).
- **La Server Action no tiene límite propio** (hallazgo M2). El debounce es del navegador:
  quien la llama directo no pasa por él. La cuota de 3.000 cada 5 minutos es **una sola**
  para la vidriera, `crearOrden` y el despacho, y con `maxInstances: 1` un Envíopack lento
  con 80 cotizaciones colgadas ocupa la única instancia. Como hay una sola, alcanza con un
  tope y una caché en memoria por `(cp, provincia, paquetes)`. **Disparador: antes de
  prender las claves con el dominio publicado.**
- **El precio simulado se ve como real** (hallazgo A4, anterior a este cambio). El checkout
  muestra *"La entrega $ 9.700"* sin decir que es estimado, y la pantalla ofrece cerrarlo por
  WhatsApp. Una oferta a consumidores obliga a quien la emite (Ley 24.240, art. 7): conviene
  consultarlo. Salida barata: que `ResultadoDeCotizacion` diga de dónde viene el precio
  (`fuente: 'simulado' | 'enviopack'`), la pantalla diga *"estimado"* con el simulado, y
  `preview.sh verificar` lo mida en cada deploy. **Disparador: antes de publicar con dominio.**
- **Crear el envío, la etiqueta y el tracking** (`POST /envios`, los webhooks por `GET`): es el
  despacho, no el checkout. Va con el panel.

## La revisión de `revisor-pagos` (Workflow D, 2026-10-01)

Antes del commit, sobre el diff. Veredicto: se puede desplegar dormido —el camino del simulado
no cambia nada visible—, pero **no prender las claves** sin A1, A3 y M1.

| | Hallazgo | Qué se hizo |
|---|---|---|
| A1 | La provincia adivinada viaja a Envíopack, y corregirla no re-cotiza | **Arreglado** (§7) |
| A2 | Sin claves cae al simulado en silencio, también con el cobro prendido | **Arreglado** (§3): atado a `EL_CHECKOUT_NO_COBRA`. La `fuente` medible queda abierta |
| A3 | "La más barata" se lleva una devolución, o la banda de otro peso | **Arreglado** (§2). El piso de precio (`"0.01"` pasa) queda sin hacer: un log por debajo de un umbral no frena nada |
| A4 | El simulado se muestra como real | **Abierto**, con disparador (arriba) |
| M1 | Una respuesta ilegible se lee como CP desconocido, sin log | **Arreglado** (§5) |
| M2 | La Server Action no tiene límite | **Abierto**, con disparador (arriba) |
| M3 | CI no tiene piso para los tests de la tienda | Se resta a mano: **+30** contra la corrida anterior |
| B1 | OpenTelemetry pondría el token en Cloud Trace | **Escrito** al lado del código (§6) |
| B2 | El hallazgo 11 no estaba en ADR 008 | **Agregado** |
| B3 | Reparto propio + claves = Punilla siempre *caído* | Falla con ruido, que es lo correcto. Sin cambios |
| B4 | Faltaban tests de timeout, de la autenticación que falla con dos esperando, de la provincia, de `R` y de la banda | **Agregados** |

Caminos de fuga de credenciales revisados, **sin hallazgo**: lo que vuelve al navegador, el
`console.error`, el JSON roto, `/auth`, el bundle del cliente, el `.deploy/` de la tienda
(`preparar_despliegue.mjs` excluye `.env*`), `apphosting.yaml` y `.env.example`.

## Verificación (2026-10-01)

- **CI restada**, no leída por el color: `alcance=tests` dio tienda **73** contra **43** de la
  corrida anterior (+30, los de este cambio), contratos 314 y functions 76 sin cambios. `guardas`
  en verde con `_verdad.md` regenerado en un worktree limpio de HEAD.
- **La copia desplegada es el commit**: los siete archivos tocados, mismo SHA-256 en
  `.deploy/tienda` que en `822a9fc`, y `src/` sin diferencias.
- **`preview.sh verificar`** en verde: rollout `SUCCEEDED` con el 100 % del tráfico, `noindex`,
  gates cerrados y puerta de edad, con sus controles negativos.
- **Canario discriminante, llamando la Server Action como la llama el navegador** (el id sale del
  payload RSC de `/pedido`): `1425` daba provincia **`B`** antes del deploy y **`C`** después;
  `1900` sigue en `B` (control positivo); el precio de seis botellas a `1425` sigue en 900000
  centavos (el simulado no cambió); `5500` con `"M"` devuelve `M` y con `"ZZ"` adivina `X`. El
  id de la acción vieja y uno inventado dan **404**.
- **Chrome por CDP sobre producción**, con carrito y puerta de edad sembrados: escribir `1425`
  dispara **una** cotización y precarga `C`; corregir a `B` dispara **una** más, con `"B"`; cuatro
  segundos quieto, **cero**. Captura mirada a 1280.

**Lo que no se verificó, porque no se puede sin claves:** nada del adaptador contra Envíopack. Eso
es *Lo que hay que medir con las claves en la mano*.

## Cuándo esta decisión deja de servir

- Se cambia de proveedor: el puerto queda, el adaptador se reemplaza.
- El dueño quiere ofrecer más de una opción a domicilio (§2).
- Envíopack empieza a devolver el correo en la respuesta de precio y se decide mostrarlo.
