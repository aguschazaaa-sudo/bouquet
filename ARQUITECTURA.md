# Arquitectura de bouquet

> **Qué es esto.** El diseño del sistema, decidido contra la evidencia de
> [LECCIONES.md](LECCIONES.md) y [DIAGNOSTICO.md](DIAGNOSTICO.md). Cada decisión
> cita la lección que la respalda: si no puedo señalar el caso concreto, no está
> acá.
>
> **Qué NO es.** No es un plan de implementación. El orden de construcción está
> en §12; los pasos de setup del repo están en
> [SETUP-PRIMERA-CORRIDA.md](SETUP-PRIMERA-CORRIDA.md).
>
> **Contexto:** tienda de vinos en Argentina. Catálogo curado de menos de 200
> productos, carga manual. Sólo envío a domicilio. Vidriera pública indexable,
> panel de administración privado.

---

## 0. Las cuatro decisiones tomadas — no re-proponer

Están acá arriba porque el `SETUP` §0.3 dice que lo que no se escribe se
re-discute cada dos semanas.

| Decisión | Elegida | ADR | Qué queda cerrado |
|---|---|---|---|
| Stack | Vidriera **Next.js**, panel **Flutter**, backend **Firebase** | [001](docs/vault/architecture/decisions/001-stack.md) | No se re-evalúa Flutter web para la vidriera |
| Estados de Orden | **Dos ejes** (pago y entrega) + proyección para mostrar | [002](docs/vault/architecture/decisions/002-estados-de-orden.md) | No hay un único `estado` string lineal |
| Pagos | **Diferida** — puerto y adaptador, contrato escrito hoy | [003](docs/vault/architecture/decisions/003-pagos.md) | El eje de pago existe desde el día 1 igual |
| Frescura del catálogo | **ISR con revalidación por trigger** | [004](docs/vault/architecture/decisions/004-frescura-y-lecturas.md) | La vidriera no lee Firestore por visitante |

Y una quinta que sale de las anteriores:

| Filtrado del catálogo | **En memoria**, sobre la proyección publicada | [004](docs/vault/architecture/decisions/004-frescura-y-lecturas.md) | Cero índices compuestos para el catálogo |

---

## 1. La forma del sistema

```
                        ┌──────────────────────────┐
   visitante ──────────▶│  apps/tienda  (Next.js)  │
   (anónimo)            │  SSR + ISR               │
                        └───────────┬──────────────┘
                                    │ Admin SDK, sólo del lado servidor
                                    │ (src/server/**)
                                    ▼
                        ┌──────────────────────────┐
                        │        Firestore         │◀───┐
                        └───────────┬──────────────┘    │
                                    │ triggers          │ Admin SDK
                                    ▼                   │
                        ┌──────────────────────────┐    │
                        │   functions/  (TS)       │────┘
                        │   callables + triggers   │
                        └───────────┬──────────────┘
                                    │ revalidación on-demand
                                    ▼
                             (webhook → tienda)

   operador ────────────▶ apps/admin (Flutter, web + Android)
   (claim rol=admin)      SDK cliente, reglas de Firestore aplicadas
```

**Las tres reglas de tráfico, y ninguna es negociable:**

1. **El navegador del cliente nunca escribe `ordenes/`.** La orden la crea una
   callable, dentro de una transacción que re-lee precio y stock desde
   Firestore. Confiar en el precio que manda el cliente es el agujero obvio; lo
   menos obvio es que sin transacción no hay forma de descontar stock sin
   sobrevender.
2. **La vidriera no habla con Firestore desde el navegador.** Todo acceso a
   datos vive en `apps/tienda/src/server/**` y corre en el servidor. Esto es lo
   que hace que las lecturas escalen con las *ediciones del catálogo* y no con
   las *visitas* (§6).
3. **El panel sí usa el SDK cliente**, con las reglas de Firestore aplicándose
   de verdad. Es el único consumidor autenticado, y es donde las reglas se
   ejercitan.

---

## 2. La forma del repo

```
apps/
  admin/            # Flutter — panel (web + Android)
  tienda/           # Next.js — vidriera pública
functions/          # Cloud Functions (TypeScript)
packages/
  contratos/        # TS: estados de Orden, transiciones, proyecciones, tipos
docs/
  vault/            # documentación viva (ver SETUP §3)
scripts/
  hooks/            # hooks de Claude
  ci/               # verificadores
  seed/             # siembra de catálogo de demo
.github/workflows/
```

**Monorepo con npm workspaces**, sin turbo ni pnpm. Tres paquetes TS
(`tienda`, `functions`, `contratos`) y un proyecto Flutter afuera del workspace.
Agregar un orquestador de monorepo antes de tener tres paquetes es costo sin
pregunta que conteste.

### 2.1 `packages/contratos` es el punto no negociable

Una sola definición de los estados de una Orden y de sus transiciones válidas
(`SETUP` §0.1). La consumen los tres lados, y cada uno de forma distinta:

| Consumidor | Cómo la consume |
|---|---|
| `functions/` | import directo de TypeScript |
| `apps/tienda/` | import directo de TypeScript |
| `apps/admin/` | espeja el `enum` en Dart, **con un test que compara contra `contratos/generated/contratos.json`** |

**Y la parte que se olvida siempre:** ese JSON generado tiene que verificarse
**fresco en CI** — regenerar y comparar, exit 1 si difiere. Un JSON viejo hace
que el test de Dart pase contra un contrato que ya no existe, y el test se
vuelve teatro. Es exactamente el modo de falla de "documentar la intención en
vez del comportamiento" (`DIAGNOSTICO` §2), pero en código.

`scripts/ci/auditar_estados.mjs` hace las dos cosas: regenera el JSON y compara,
y verifica que el `enum` de Dart lo cubra entero.

---

## 3. El dominio

Dominio en español, infraestructura en inglés.

| Término | Qué es | Nota |
|---|---|---|
| **Producto** | Lo que se vende. Tiene precio, stock, fotos y slug. | Ver abajo por qué no se llama `Vino` |
| **FichaVino** | Sub-objeto opcional del Producto: bodega, varietal, añada, región, graduación, volumen | |
| **Bodega** | Productor. Tiene página propia indexable. | |
| **Varietal** | Malbec, Cabernet Franc, corte… Un producto puede tener varios. | |
| **Orden** | Una compra confirmada. **Nace confirmada** (§4). | |
| **Cliente** | Los datos de contacto y envío de una Orden. **No es una cuenta.** | Checkout sin registro |
| **Envío** | Dirección, zona, costo y ventana de entrega de una Orden | |
| **Zona** | Área de cobertura con su costo de envío | |

**Por qué `Producto` y no `Vino`.** Una vinoteca vende también espumantes,
destilados, copas y cajas de regalo. Si la entidad se llama `Vino`, el día que
entre la primera copa Riedel hay dos caminos y los dos son malos: una tabla
paralela, o un `Vino` que no es un vino. La ficha enológica es un sub-objeto
opcional; el producto es el agregado.

> **Cambiar la unidad de precio, el IVA o el formato de botella después de
> sembrar deja órdenes viejas que ya no se pueden interpretar** (§8.2). Por eso
> el glosario se escribe hoy y los `items[]` de una Orden guardan un **snapshot**
> del precio, no una referencia al producto (§5.2).

---

## 4. La máquina de estados de Orden

Es el artefacto del día 1. Todo lo demás se puede reescribir barato; esto no.

### 4.1 Por qué dos ejes y no un `estado` lineal

Una Orden tiene dos hechos que avanzan **por separado y a veces en desorden**:

- **Se cobró** — puede pasar antes (Mercado Pago), o después (efectivo contra
  entrega), o nunca (cancelada antes de despachar).
- **Se entregó** — avanza por logística, no por plata.

Un único string obliga a inventar estados cruzados (`entregada_impaga`,
`pagada_no_despachada`) y a decidir cuál gana cuando llegan desordenados. Es
justo el problema que `LECCIONES` §5.2 marca como extrapolado pero seguro: *"una
notificación `pagado` que llega después de `cancelado`"*. Con dos ejes, esa
notificación escribe **su** eje y no pisa el otro.

### 4.2 Los dos ejes

**`estadoPago`**

| Estado | Significa | Entra desde |
|---|---|---|
| `pendiente` | Se debe. Transferencia o contra entrega sin cobrar. | creación |
| `en_proceso` | El proveedor la tomó y no resolvió. | `pendiente` |
| `pagada` | Cobrada y conciliada. | creación, `pendiente`, `en_proceso` |
| `rechazada` | El proveedor la rechazó. | `pendiente`, `en_proceso` |
| `reembolsada` | Se devolvió la plata. | `pagada` |

**`estadoEntrega`**

| Estado | Significa | Entra desde |
|---|---|---|
| `sin_preparar` | Confirmada, todavía no la tocó nadie. | creación |
| `preparando` | Se está armando el pedido. | `sin_preparar` |
| `despachada` | Salió. | `preparando` |
| `entregada` | Llegó y alguien mayor de 18 firmó. | `despachada` |
| `fallida` | No se pudo entregar. | `despachada` |
| `cancelada` | No se entrega. | `sin_preparar`, `preparando` |

**La proyección para mostrar** (`proyectarEstadoPublico`) vive en `contratos` y
es la única fuente del rótulo que ve el cliente y del que ve el operador. Nunca
se arma un rótulo en la UI a partir de los dos campos: eso son dos
implementaciones que se desincronizan (§6.4).

### 4.3 Las tres reglas que salen de la evidencia

**1. Una Orden puede NACER en el estado final.** Es la lección §5.1, la más
transferible del documento entero. Rutas por las que una Orden nace `pagada`:
carga manual desde el panel, link de pago pre-aprobado, y cualquier cosa que
agregue el dueño el año que viene.

```
❌ onDocumentUpdated + "pasó a pagada"     → NO se dispara para las que nacen pagadas
✅ onDocumentWritten + entroEnPagada(antes, después)
```

`entroEnPagada` es `después === 'pagada' && antes !== 'pagada'`, con
`antes === undefined` en un create. Vive en `contratos` como helper compartido,
**porque es un hecho del ciclo de vida de la entidad, no de un flujo**. Cada
efecto de "se pagó" —descontar nada más, mandar el mail, avisar al depósito— usa
ese mismo helper.

**2. Los triggers son at-least-once: marcador de idempotencia en la MISMA
transacción que el efecto** (§5.2). El marcador va en
`ordenes/{ordenId}/marcadores/{efecto}`. Si el efecto y el marcador no son
atómicos, la ventana entre los dos es exactamente donde ocurre el doble
descuento, y un `increment` repetido **infla en silencio** — el peor modo de
falla, porque el dato queda mal sin error.

**3. El que mantiene algo crítico no comparte función con el accesorio**
(§5.5). El stock se descuenta en la transacción de creación de la Orden, no en
un trigger. Los efectos accesorios (mail, aviso, "los más vendidos") son
triggers separados, y que uno tire no puede tumbar a otro.

### 4.4 El carrito no es un documento

El carrito vive en `localStorage` del navegador. **No hay colección `carritos`.**

Dos razones, una barata y una cara. La barata: cero escrituras y cero lecturas
por carrito abandonado. La cara: un carrito persistido en Firestore es un
documento que hay que revalidar contra precio y stock igual al confirmar, así
que no compra ninguna garantía — sólo agrega una copia más del precio que se
puede desincronizar.

Consecuencia: **la Orden nace confirmada**, y `crearOrden` es el único punto
donde se valida stock y precio. Un solo lugar que puede decir que no.

---

## 5. Modelo de datos en Firestore

### 5.1 Colecciones

```
productos/{productoId}
bodegas/{bodegaId}
ordenes/{ordenId}
  marcadores/{efecto}          # subcolección: idempotencia
zonas/{zonaId}                 # cobertura de envío + costo
config/{documento}             # parámetros operativos
contadores/{nombre}            # numeración secuencial de órdenes
```

No hay colección `clientes` en el MVP: el checkout es sin registro y los datos
de contacto viven en la Orden. Crear la entidad `Cliente` es una decisión con
disparador (§11), no una que se toma por prolijidad.

### 5.2 Los campos que tienen trampa, y cuál es

| Campo | Regla | Lección |
|---|---|---|
| `precio` | **Entero en centavos de ARS.** Nunca float, nunca string. | §8.2 |
| `items[]` de una Orden | **Snapshot** de `{productoId, nombre, precioUnitario, cantidad}`. Nunca una referencia. | §8.2 |
| `publicado` | Se escribe **siempre** en la creación, por una única factory. | §4.3 |
| `imagenes[]` | **Una sola ruta canónica.** Un producto tiene un array de URLs y nada más. | §4.4 |
| `numero` de Orden | Secuencial, asignado en la transacción de creación contra `contadores/ordenes`. | — |
| `busqueda.tokens[]` | Generado por trigger. El cliente nunca lo escribe. | §6.4 |

**Sobre `publicado`, la trampa que ya costó una vez:** `where('publicado','==',
true)` **no devuelve los documentos donde el campo no existe** (§4.3). Somos
greenfield, así que la defensa correcta no es un backfill: es que ningún
documento pueda nacer sin el campo. Un verificador de CI que cuente productos sin
`publicado` y salga con exit 1 cierra el agujero para siempre por cuatro líneas.

**Sobre `imagenes[]`, la trampa que vivió desde el commit inicial en
PadelPunilla:** había **dos** campos `photoUrl` —uno anidado y uno en la raíz—
y aun con la subida arreglada la foto nueva no se veía en ningún otro lado, para
siempre (§4.4). Un dato, una ruta.

### 5.3 Escrituras concurrentes en arrays

`arrayUnion` / `arrayRemove`, **nunca reescribir el array entero** (§4.4). Dos
personas editando el mismo producto a la vez hacen que el segundo en guardar
borre lo que subió el primero. Aplica a `imagenes[]` y a `varietales[]`.

### 5.4 Fotos de producto: la regla de la extensión

Las fotos las carga gente no técnica **desde el navegador**, con el panel en
Flutter web. Ahí aplica textual el bug que vivió desde el commit inicial en
PadelPunilla (§4.4):

> En web, `XFile.path` **no es una ruta de archivo, es un blob URL**. Sacar la
> extensión con `path.split('.').last` devuelve `app/<uuid>` — **con una barra
> adentro**. La barra convierte el archivo en subcarpeta, la regla de Storage
> declara un solo segmento `{x}`, deja de matchear, cae en el deny-all y Storage
> devuelve `unauthorized`.

**Reglas, las cuatro:**

1. **Lista cerrada de extensiones derivada del `mimeType`**, nunca del path.
2. La ruta es `productos/{productoId}/{uuid}.{ext}` — **un solo segmento** de
   nombre de archivo.
3. El `contentType` que se manda es el real, no `image/jpeg` fijo. `imageQuality`
   del picker **sólo aplica a jpeg/webp**; un PNG se guardaría etiquetado JPEG.
4. **`try/catch`, no `try/finally` sin `catch`.** El bug de PadelPunilla vivió
   meses sin un solo reporte porque la excepción se perdía como error async no
   manejado: spinner, vuelta al botón, nada. **Un fallo invisible no genera
   reportes, genera la sensación de que "no anda".**

### 5.5 Índices

**El catálogo no necesita ninguno.** Con menos de 200 productos, la vidriera
carga la proyección publicada entera y filtra en memoria (§6). Eso elimina de
raíz la familia entera de trampas de §4.2 —el orden igualdad → rango → orderBy,
la ausencia de prefix matching, el `collectionGroup` que necesita
`fieldOverrides`— para el caso que más las tocaría.

> **Cuándo deja de servir, escrito hoy para no discutirlo después:** se migra a
> queries con índices cuando pase lo primero de — el catálogo supere ~1.000
> productos, o la proyección publicada supere ~2 MB. Ahí valen las 4 reglas de
> forma de §4.2 y hace falta `scripts/ci/auditar_indices.mjs`, que **corre** cada
> forma de query y sale con exit 1 si falta un índice. Verificar que un índice
> existe y está `READY` no verifica nada.

Sí hacen falta índices para **órdenes** en el panel: `estadoEntrega == X
orderBy creadaEn desc`. Es una igualdad más un `orderBy`, la forma fácil. Se
declara y se verifica corriendo la query, no mirando `gcloud`.

Y la regla de higiene inversa: **un índice declarado y no consultado es costo de
escritura**. Antes de agregar uno, grepear si el campo aparece en algún
`.where()`.

---

## 6. Frescura de la vidriera y presupuesto de lecturas

Esta sección es la que justifica la decisión más importante del sistema, y va con
el número adelante.

### 6.1 El número que decide

La vidriera puede leer Firestore de dos maneras:

| | Lecturas/día a 100 visitas | A 250 visitas | A 1.000 visitas |
|---|---:|---:|---:|
| **Por visitante** (SPA que consulta Firestore) | 20.000 | **50.000** | 200.000 |
| **ISR con revalidación por trigger** | ~1.500 | ~1.600 | ~2.000 |

La cuota gratuita son **50.000 lecturas/día**. Una vidriera que lee por
visitante la revienta **a las 250 visitas diarias** — que para una tienda es un
día flojo. Con ISR, las lecturas escalan con las **ediciones del catálogo**, no
con las visitas, y el catálogo lo edita una persona.

### 6.2 Cómo funciona la frescura

`LECCIONES` §1.1 es tajante: *"el precio y el stock cambian el mismo día.
Prerenderizar en build significa que la página del producto miente hasta el
próximo deploy"*. La respuesta no es revalidar seguido —eso multiplica las
lecturas— sino **revalidar cuando cambió algo**:

```
admin escribe productos/{id}
        │
        ▼
trigger revalidarVidriera  (onDocumentWritten)
        │
        │  compara la PROYECCIÓN PÚBLICA de antes contra la de después
        │  ¿son iguales?  → no hace nada
        │  ¿son distintas? → POST al webhook de revalidación de la tienda
        ▼
Next.js regenera /vino/<slug> y el listado
```

**Comparar la proyección y no el documento** es el detalle que hace que esto sea
barato. Descontar una botella de 12 a 11 no cambia lo que la página dice
(`disponible`), así que no dispara nada. Cambiar el precio, agotar el stock o
despublicar el producto sí.

**El stock se muestra en baldes, no como número exacto**: `disponible` ·
`últimas unidades` · `agotado`. Dos razones. La de costo: el balde cambia pocas
veces, el número cambia en cada venta. La de honestidad: *"Últimas 3 botellas"*
afirma un número exacto y *"poco stock"* no — si el pool de redacciones las
mezcla, mentís en la mitad de los casos (§7.4).

Fallback: `revalidate` largo (6 h) por si un webhook se pierde. Con ISR el
fallback sólo consume lecturas cuando alguien pide la página después de que venza
la ventana.

### 6.3 El presupuesto completo

Escenario MVP: 100 visitas/día, 200 productos, ~20 ediciones de catálogo/día,
5 órdenes/día, 1 operador con ~10 sesiones de panel.

| Origen | Lecturas/día | Nota |
|---|---:|---|
| Vidriera — revalidaciones por edición | ~400 | 20 ediciones × (listado + ficha) |
| Vidriera — fallback de 6 h | ~800 | sólo las páginas efectivamente pedidas |
| Checkout — revalidación de precio y stock | ~20 | 5 órdenes × ~4 ítems, dentro de la transacción |
| Triggers de Orden | ~15 | |
| Panel — catálogo | ~200 | con caché de sesión; **sin ella, 2.000** |
| Panel — órdenes paginadas | ~250 | 25 por página × 10 sesiones |
| **Total** | **~1.700** | **3,4 % de la cuota** |

**El renglón que más se mueve es el panel, no la vidriera.** Lo caro suele ser
`autoDispose`, no el volumen (§4.1.4): descartar los providers hace releer lo
mismo en cada navegación. La caché del catálogo en el panel **no lleva
`autoDispose`** y converge a ~0 lecturas cuando el operador va y vuelve entre
pantallas.

> **Regla de proceso, tomada de `DIAGNOSTICO` "qué agregaría" §4:** todo ADR de
> feature nueva declara cuántas lecturas agrega por apertura de pantalla y contra
> qué queda eso de los 50k/día. Es un campo obligatorio de la plantilla, no una
> nota al pie.

---

## 7. Búsqueda: una sola implementación

`LECCIONES` §6.4 documenta **tres implementaciones copiadas** de la misma
búsqueda por trigramas, idénticas hasta en una clase privada. Mejorar una no
mejoraba la app. En una tienda el riesgo es peor: el buscador de la vidriera, el
del panel y el del carrito son la misma búsqueda.

**La salida acá no es compartir código entre TS y Dart — es que el segundo caso
no exista.** Con menos de 200 productos:

- **La vidriera** embebe un índice estático derivado de la misma proyección
  publicada (`{slug, nombre, bodega, varietales, region, anada, precio}`).
  Son ~40 KB comprimidos. Búsqueda en el cliente, **cero lecturas de Firestore**,
  respuesta instantánea, y funciona con el sitio estático.
- **El panel** ya tiene los 200 productos en memoria por la caché de sesión. Un
  filtro `contains` normalizado alcanza. **No necesita búsqueda difusa**, así que
  no hay una segunda implementación que mantener sincronizada.

Si algún día el panel necesita la misma búsqueda que la vidriera, la salida
**no** es copiarla a Dart: es que el panel consuma el mismo índice generado. La
regla queda escrita para que no se redescubra.

La normalización (acentos, mayúsculas, "cabernet sauvignon" vs "cab sauv") vive
en `packages/contratos` con sus fixtures. Un solo lugar.

---

## 8. Fronteras, y qué hook mide cada una

> **Lo que no está en un hook, no está** (§9.3). Un prompt describe la intención;
> un hook mide el resultado. En PadelPunilla un widget convivió con
> `cloud_firestore` **desde el commit inicial** pese a que el agente de
> presentación lo prohibía en su texto.

| Frontera | Qué prohíbe | Hook | Tipo |
|---|---|---|---|
| Capas del panel | `domain/` importa Firebase o Flutter | `layer-boundary.sh` | HARD |
| | `presentation/` importa `data/` | `layer-boundary.sh` | HARD |
| | `presentation/` importa el **SDK de Firebase directo** | `layer-boundary.sh` | HARD |
| Credenciales | `firebase-admin` importado fuera de `apps/tienda/src/server/**` | `server-only-guard.sh` | HARD |
| Tamaño | archivo de presentación > 200 líneas | `widget-size-guard.sh` | HARD |
| Composición | más de un widget público por archivo | `one-widget-per-file.sh` | HARD |
| Tema | `Color(0x…)`, `Colors.*`, hex literal fuera de tokens | `no-hardcoded-colors.sh` | HARD |
| Puerta | clase pública sin call site fuera de su archivo | `call-site-guard.sh` | SOFT |
| Vault | escribir código sin haber leído el vault | `vault-precheck.sh` | HARD |

**Dos hooks son nuevos respecto de PadelPunilla y los dos atacan modos de falla
medidos:**

- **`server-only-guard.sh`** — si `firebase-admin` o la service account entran en
  un componente cliente de Next.js, las credenciales viajan al bundle. Es el
  equivalente exacto del agujero de §9.3, trasladado al stack nuevo, y hay que
  cerrarlo antes de que exista el primer archivo.
- **`call-site-guard.sh`** — la feature escrita que nadie puede abrir pasó
  **cuatro veces** en seis meses (§6). Es SOFT a propósito: en composición
  bottom-up un widget hoja legítimamente no tiene consumidores durante los diez
  minutos que tarda en escribirse el que lo compone. El aviso aparece justo
  cuando cerrás la tarea sin haberlo cableado.

**Y una verificación propia de Next.js que no existe en el documento original:**
toda ruta `app/**/page.tsx` tiene que aparecer en el sitemap o estar enlazada
desde otra página. Una página sin enlaces entrantes es la versión web de la
página huérfana del panel de PadelPunilla — *"59/59 completa"*, sin ruta ni
navegación (§6.1). Va en `scripts/ci/`, no en un hook: necesita ver el repo
entero.

---

## 9. Seguridad y reglas

### 9.1 Quién puede leer qué

| Colección | Cliente anónimo | Operador (`rol: admin`) | Servidor (Admin SDK) |
|---|---|---|---|
| `productos` | **denegado** | lectura y escritura | todo |
| `bodegas` | **denegado** | lectura y escritura | todo |
| `ordenes` | **denegado** | lectura y escritura | todo |
| `zonas` | **denegado** | lectura | todo |
| `config` | denegado | lectura | todo |

**Todo denegado por defecto para el navegador anónimo, y no es una postura
paranoica: es que no lo necesita.** La vidriera renderiza del lado servidor, así
que el visitante nunca tiene un SDK de Firestore en la mano. Si mañana hace falta
una lectura desde el cliente, se abre esa lectura a propósito y se escribe por
qué.

El cliente consulta su propia orden por una callable `consultarOrden(numero,
email)`, no por una lectura directa. Una lectura directa por id permite
enumerar órdenes ajenas probando ids.

### 9.2 El rol va en un custom claim, no en un documento

`request.auth.token.rol == 'admin'`, no `get(/databases/…/usuarios/$(uid)).data.rol`.

Un `get()` dentro de las reglas **cuesta una lectura facturada por cada
evaluación**. Con el panel abierto y una lista de 200 productos, eso son 200
lecturas extra por pantalla, invisibles en cualquier auditoría de código porque
no aparecen en ninguna query.

### 9.3 Storage

```
productos/{productoId}/{archivo}
  read:  público    (las fotos se sirven en la vidriera)
  write: sólo rol == 'admin', contentType image/*, tamaño máximo declarado
```

Un segmento de nombre de archivo, no `{archivo=**}`. Ver §5.4 — la regla y el
código de subida tienen que estar de acuerdo sobre cuántos segmentos hay, y el
modo de falla cuando no lo están es un `unauthorized` que parece un problema de
permisos y es un problema de string.

### 9.4 La baranda de `config` tiene que proteger la PRIMERA escritura

Si `config/precios` o `config/envios` tiene un trigger con baranda anti
fat-finger, esa baranda **no puede depender sólo del valor anterior** (§5.7). En
una creación no hay "antes", y la primera escritura es exactamente cuando más se
equivoca uno. La condición se escribe sobre el valor nuevo, con el anterior como
señal opcional.

### 9.5 Alcohol y edad

Venta de bebidas alcohólicas: hay una verificación de mayoría de edad que
cumplir. Tres piezas y una restricción técnica que no es obvia:

- Puerta de edad al entrar al sitio, con la elección recordada.
- Copy explícito de que se exige documento en la entrega.
- El repartidor tiene que poder marcar `fallida` con motivo "sin mayor de edad".

**La restricción técnica:** la puerta de edad es un **overlay del lado cliente
sobre contenido que ya está en el HTML**, nunca un bloqueo del render. Si el
contenido no está en el HTML, Google no lo ve y la vidriera vuelve a ser
invisible — que es el problema que la decisión de Next.js vino a resolver. Es el
mismo patrón que el splash de §1.2: el contenido va visible en flujo normal y el
overlay lo tapa; los dos se coordinan en el cliente.

> **Pendiente de confirmar con el dueño (no es una decisión técnica):** qué
> exige la habilitación para vender vino online en su jurisdicción y qué
> inscripción en el INV corresponde. Está en §11 con su disparador.

---

## 10. Deploy y entornos

Las cuatro reglas de `SETUP` §5.1 se llevan tal cual: **orden reglas → functions
→ front impuesto con `needs:`**, promover en vez de republicar, `concurrency`
**sin** `cancel-in-progress` en deploy, y el workflow imprime qué falta.

Con una particularidad favorable del stack elegido:

| Pieza | Dónde vive | Modelo de release |
|---|---|---|
| `apps/tienda` | Vercel | **Deployments inmutables + promote.** Es §3.3 implementado por la plataforma: se promueve un build ya verificado, no se recompila. |
| `apps/admin` | Firebase Hosting | Build → canal de preview → verificar → `hosting:clone` a live |
| `functions` | Cloud Functions | Verificar **por nombre** en el log, no por color (§3.5) |
| Reglas e índices | Firebase | Primero, siempre |

**Vercel también resuelve el problema más caro del proyecto original.** El build
de Next.js corre en su infraestructura: no consume minutos de GitHub Actions
(§3.6, la cuota de 2.000 min/mes) y no corre en una máquina de 7,9 GB de RAM
(§9.4). El ciclo de feedback de la vidriera es local y de segundos — `next dev`
sí corre acá. El del panel no lo es, y eso ordena el plan de construcción (§12).

**La trampa heredada que sigue viva y hay que decidir hoy:** el deploy de front
reconstruye desde el HEAD pusheado, así que publica **toda la UI mergeada**, no
sólo el cambio que motivó el release (§3.2). En PadelPunilla eso puso en
producción un botón que llamaba a una Cloud Function inexistente. En una tienda
es directamente plata: un botón "Pagar" que llegue antes que su webhook es una
venta que se cobra y no se registra. **La mitigación real es desplegar desde un
tag**, no desde la rama.

**Y la palabra "aprobación" no se escribe en ningún lado** hasta que
`gh api repos/<owner>/<repo>/environments` devuelva `protection_rules` no vacío
(§3.4). Lo peligroso no es la falta de la red: es creer que hay una red que no
está.

---

## 11. Lo que queda abierto, con su disparador

Un pendiente sin disparador es un pendiente que nadie va a cerrar. Cada uno lleva
la condición que lo activa y la fecha en que se escribió.

| Abierto | Disparador | Escrito |
|---|---|---|
| **Proveedor de pagos** (MP Checkout Pro / Bricks / Ualá) | Cuando el dueño quiera cobrar online. El contrato ya está escrito en [ADR 003](docs/vault/architecture/decisions/003-pagos.md) y no cambia con el proveedor. | 2026-09-01 |
| **Reserva de stock antes de pagar** | Cuando aparezca la primera sobreventa real. Hoy el stock se descuenta al confirmar la orden; una reserva con expiración por cron cuesta más de lo que el problema vale a este volumen. | 2026-09-01 |
| **Entidad `Cliente` y cuentas** | Cuando el dueño pida "los que más compraron" o repetir un pedido. Antes no: prometer un ranking sobre datos que no medís es mentirle al usuario (§8.3). | 2026-09-01 |
| **Retiro en local** | Si el dueño lo pide. El eje `estadoEntrega` ya lo admite: son dos estados más, no un rediseño. | 2026-09-01 |
| **Buscador dedicado y queries con índices** | Catálogo > ~1.000 productos o proyección > ~2 MB (§5.5). | 2026-09-01 |
| **Requisitos legales de venta de alcohol online** | Antes de la primera venta real. No es técnico; lo contesta el dueño. | 2026-09-01 |
| **Deploy desde tag en vez de rama** | Antes del primer deploy que incluya cobro. | 2026-09-01 |

---

## 12. Orden de construcción

El orden no es por importancia: es por **dependencia y por velocidad de
feedback**. El ciclo local de la vidriera es de segundos; el del panel pasa por
CI y dura minutos (§9.4). Todo lo que se pueda hacer del lado rápido, primero.

| # | Qué | Por qué acá |
|---|---|---|
| 0 | Setup del repo: hooks, CI, `CLAUDE.md`, vault | Un CI montado sobre 200 archivos encuentra bugs viejos y es tolerable; sobre 1.100 te comés una semana (`SETUP` §4) |
| 1 | `packages/contratos`: estados, transiciones, `entroEn*`, proyección + `auditar_estados.mjs` | Es el punto no negociable. Todo lo demás lo importa |
| 2 | `firestore.rules` + índices de órdenes + verificadores | Antes de que haya datos |
| 3 | `scripts/seed`: 20 vinos reales | Desbloquea la vidriera **sin necesitar el panel** |
| 4 | `functions`: `crearOrden` (transacción) + `entroEnPagada` + marcador | El camino crítico completo, sin UI |
| 5 | `apps/tienda`: ficha de producto → listado → home → checkout | Bottom-up: del componente hoja a la página, nunca al revés |
| 6 | `apps/admin`: alta y edición de producto → lista de órdenes → cambio de estado | El operador ya tiene qué administrar |
| 7 | Pagos | Cuando el dueño decida. Enchufa en un camino que ya tiene evidencia |

### El detalle del paso 7 que vale por toda la sección

Desde el día 1 el operador marca `estadoPago = pagada` a mano en el panel
(transferencia, efectivo). Eso significa que **el trigger `entroEnPagada` corre
en producción desde el primer pedido**, meses antes de que exista un webhook.

Cuando el pago online llegue, no estrena la maquinaria: se enchufa en un camino
que ya se ejecutó cientos de veces. Es la respuesta directa a §9.6 — *un
componente que nunca ejecutó no tiene evidencia de funcionar, aunque sus tests
estén verdes*. Diferir el proveedor de pagos no difiere el riesgo del pago
**sólo si el eje existe y se usa desde el principio.**

---

## Apéndice: las decisiones de este documento, contra la lección que las respalda

| Decisión | Lección |
|---|---|
| Vidriera en Next.js | §1.1 — Flutter web es invisible y no hay flag que tocar |
| ISR con revalidación por trigger | §1.1 + §4.1.7 — el precio cambia hoy; la cuota es 50k/día |
| Filtrado en memoria, cero índices de catálogo | §4.2 — un índice `READY` puede no servir |
| Dos ejes de estado | §5.1 + §5.2 — nace en estado final; llega desordenado |
| `onDocumentWritten` + `entroEn*` en un helper | §5.1 |
| Marcador de idempotencia en la misma transacción | §5.2 |
| Stock en la transacción, efectos en triggers aparte | §5.5 |
| Carrito en `localStorage` | §4.1 — no pidas lo que no mostrás |
| Precio en centavos, `items[]` como snapshot | §8.2 |
| Extensión desde `mimeType`, un solo segmento | §4.4 |
| Una sola búsqueda | §6.4 |
| `server-only-guard` y `call-site-guard` | §9.3 y §6 |
| Rol en custom claim | §4.1 — el `get()` de las reglas se factura |
| Overlay de edad, contenido en el HTML | §1.2 |
| El operador marca `pagada` a mano desde el día 1 | §9.6 |
