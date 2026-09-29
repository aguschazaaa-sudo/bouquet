# ADR 026 — La entrega sin cargo desde un monto: `config/envios`, por una callable con baranda

- **Fecha:** 2026-09-29
- **Estado:** aceptada; **desplegada y verificada el 2026-09-29** —functions, panel (`e95e653`) y la preview de la tienda—. **Apagada**: `config/envios` no existe hasta que el dueño fije un monto. Ver *Verificación*, al final
- **Decide:** dónde vive el umbral de la entrega sin cargo, quién lo escribe, qué
  lo frena, y cómo lo aplica la vidriera sin decidir lo que se cobra
- **Historias:** HU-11.1 ([EP-11](../../features/panel/EP-11-parametros-y-tablero.md)).
  **Segundo tramo de EP-11**, con él la épica entera. **Toca plata: Workflow D**
- **Toca:** [ARQUITECTURA §9.4](../../../../ARQUITECTURA.md#94-la-baranda-de-config-tiene-que-proteger-la-primera-escritura)
  (la baranda de `config` protege la primera escritura), [ADR 010](010-el-checkout.md)
  (el checkout ya soportaba `precio: 0` y lo dice con palabras),
  [ADR 008](008-catalogo-stock-y-carrito.md) (la lista de lo que `crearOrden` tiene
  que cumplir: suma el hallazgo 10), [ADR 023](023-la-portada-la-elige-el-duenio.md)
  (los plazos de `cuando_se_ve.dart`)
- **Hace cumplir:** `packages/contratos/test/sin_cargo.test.ts`,
  `functions/test/config/fijar.emulador.mjs` (**entra a CI**), el bloque *config* de
  `scripts/reglas/productos.test.mjs`, el caso nuevo de
  `apps/tienda/test/revalidacion.test.ts` y
  `apps/admin/test/features/vidriera/envio_sin_cargo_test.dart`
- **Sin openspec, a pedido del dueño** (2026-09-29): este ADR y la épica son la
  especificación

## Contexto

El dueño lo dejó abierto: *"no sé desde qué monto me conviene"*. EP-11 lo escribió
con disparador —las tarifas reales del proveedor— y con dos cosas ya decididas:
**`config` es sólo del servidor, creación incluida**, y **la baranda contra el dedo
gordo mira el valor nuevo**, porque en la primera escritura no hay anterior. El
panel guarda por una callable.

**Se construye antes del disparador, a pedido del dueño, y nace APAGADO.** El
mecanismo no necesita las tarifas; el monto sí, y lo pone el dueño cuando las
tenga. Hasta entonces no cambia nada: sin documento, la entrega se cobra siempre.

## Decisión

### 1. `config/envios`, escrito sólo por `fijarEnvioSinCargo`

`{ sinCargoDesde: centavos | null, actualizadoEn, actualizadoPor }`, reescrito
entero. Las reglas ya lo cerraban (`allow write: if false`, lectura sólo del admin);
ahora hay tests que lo prueban, creación incluida. **La callable es la única
puerta**, así que la baranda no tiene un camino que la saltee.

### 2. La baranda, en dos tiempos y sobre el valor nuevo

1. **Dura** (`parsearPedidoDeSinCargo`): pesos enteros, de **$1 a $100.000.000**,
   o `null` para apagar. Fuera de eso no se guarda **nunca**, confirmado o no. El
   techo es holgado a propósito: con la inflación, uno justo envejece en meses.
2. **Blanda** (`motivoParaConfirmar`): si el monto queda **por debajo de una caja a
   precio típico** —seis botellas a la mediana del precio **por botella** de lo
   publicado, con al menos 5 publicados—, o **baja a menos de la mitad** del
   anterior, la callable **no guarda** y devuelve el motivo con el monto que lo
   explica. El panel lo pregunta con palabras, y sólo con *"Guardar igual"* vuelve a
   llamar con `confirmado: true`.

La primera condición es la que protege la **primera escritura**: todo pedido es al
menos una caja (ADR 009), así que un umbral por debajo es *"casi todo sale sin
cargo"* —el cero de menos—, y no necesita anterior. La segunda usa el anterior como
señal opcional, como pide §9.4.

**Sólo mira para abajo.** Subir el umbral o apagarlo no regala nada; el criterio
del panel confirma sólo lo que evita una pérdida concreta.

**Sin transacción**: lo que se lee —el anterior y los precios— es una señal para
preguntar, no una condición de plata. Dos personas a la vez: gana la última, como
las cajas (ADR 024).

### 3. Sin cargo es TODA la entrega

Si los vinos llegan al umbral, **todas** las opciones —domicilio y sucursal— salen
a precio 0. Decisión mía: *"no cobro el envío"* es lo que dijo el dueño, y dejar una
con precio obliga a explicar por qué una sí y la otra no.

### 4. La vidriera lo MUESTRA; lo que se cobra lo decide `crearOrden`

`/pedido` lee `config/envios` en **su propia** caché de 60 s (`server/config.ts`),
y no en la del catálogo: metido ahí lo pagarían `/vinos`, la ficha y `/carrito`.
El checkout aplica `conEnvioSinCargo` sobre lo cotizado, con el subtotal de los
vinos, y el resumen dice **"Con $ X más, la entrega sale sin cargo."** —curado con
`voz`: mostrador, presente, sin imperativo—.

**Un documento roto se lee como apagado** y queda en el log: cobrar la entrega es
lo que se hacía antes de esta historia; regalarla por un dato roto, no.

⚠️ **El checkout no cobra** (`EL_CHECKOUT_NO_COBRA`), y **`crearOrden` no existe**.
Cuando exista, **tiene que** aplicar `conEnvioSinCargo` con el subtotal que
recalcule **él** y el umbral leído **en la misma transacción**, nunca con lo que
mande el navegador. Queda como **hallazgo 10** en la lista de ADR 008.

### 5. El panel: un bloque más en *Vidriera*

*"La entrega sin cargo"*, debajo de las cajas: el monto de hoy —o *"hoy la entrega
se cobra siempre"*—, *Fijar / Cambiar el monto* y *Cobrar siempre la entrega*. Un
documento roto se dice en rojo. Después de guardar, cuándo se ve: `/pedido` se
rearma como el catálogo, así que es el mismo *"hasta unos 13 minutos"* de
`cuando_se_ve.dart`.

## Por qué NO las alternativas

| Alternativa | Por qué no |
|---|---|
| Que el panel escriba `config` directo | §9.4: una regla sobre el valor anterior no protege la creación, y una sobre el nuevo necesitaría leer el catálogo en las reglas |
| La baranda sólo en el panel, como el precio (HU-03.5) | Un panel con un bug, o una llamada armada a mano, la saltearía; `config` se diseñó cerrado justamente para esto |
| Rechazar en vez de preguntar | "Siempre sin cargo" es una decisión comercial legítima: la baranda frena el dedo gordo, no la decisión |
| Un piso fijo en pesos para la baranda | Con la inflación envejece en meses; la caja típica sale del catálogo de hoy |
| Leer el umbral en la entrada de caché del catálogo | Tres rutas pagarían por un documento que no dibujan |
| Aplicar el umbral en el cotizador del servidor | Necesita el subtotal, que en el cotizador vendría del navegador: no decide nada que el navegador no pueda falsear. Decide `crearOrden` |
| Esperar a las tarifas reales | El mecanismo no las necesita, y nace apagado |

## Presupuesto de lecturas

| Quién | Cuánto | Cuándo |
|---|---|---|
| La callable | **1 + P** (el anterior y los publicados, ~200) | Por guardado: unas pocas veces al año |
| El panel, al abrir *Vidriera* | **+1** (`config/envios`) y ~1 por cambio | Sobre la selección, las cajas y el catálogo |
| `/pedido` | **+1 por reconstrucción**, como mucho una por minuto por instancia y sólo si alguien la visita | Hoy nadie: el checkout no cobra |
| `crearOrden` (cuando exista) | **+1** por pedido, adentro de la transacción | — |

Todo junto, por debajo del **0,1 %** de la cuota.

## Lo que este ADR deja abierto, con su disparador

| Qué | Disparador |
|---|---|
| **El monto**: nace apagado | Las tarifas reales del proveedor; lo fija el dueño desde *Vidriera* |
| **Hallazgo 10 de ADR 008**: `crearOrden` aplica la regla con su subtotal y el umbral leído en la transacción | La sesión de `crearOrden` |
| **El empujón sólo está en el checkout**, no en `/carrito` —que es donde se suman vinos— | Si el dueño lo quiere antes de la compra: es la misma función y una lectura más en `/carrito` |
| **Todas las opciones salen sin cargo**, decisión mía | Que el dueño prefiera sólo una (por ejemplo, sucursal) |

## Verificación (2026-09-29)

| Qué | Cómo |
|---|---|
| Las suites | CI `36606564183` (`completo`) sobre la rama descartable `ci/ep11-t2`, restada contra `main` (`36605555613`): contratos 292 → **309 (+17)**, emulador 221 → **234 (+13 = 11 de la callable + 2 de reglas de `config`)**, Dart 522 → **534 (+12)**, tienda 38 → **39 (+1)**; functions 76 sin cambios; el bundle carga **9 functions**. `flutter analyze` **No issues found!** |
| `revisor-pagos` (Workflow D) | **Cero ALTOS.** Un **MEDIO**, corregido: el guardado que la baranda marcaba y venía `confirmado` no dejaba rastro distinto de un cambio sano —el comentario lo prometía y el código descartaba el motivo—. Ahora el resultado lleva `barandaConfirmada` y la callable lo loguea como **advertencia**; dos casos nuevos en el emulador (con marca y sin nada que confirmar). Dos BAJOS: el orden de deploy (functions antes que panel y tienda, se respeta) y este ADR, que no existía cuando revisó |
| Quién lo abre | `PantallaDeLaVidriera` → `SeccionDelEnvioSinCargo` → `DialogoDelEnvioSinCargo` / `ConfirmacionDelEnvio`; `/pedido` → `obtenerEnvioSinCargo` → `PaginaDelCheckout` (`conEnvioSinCargo`) → `ElResumen` (`faltaParaSinCargo`); `functions/src/index.ts` → `fijarEnvioSinCargo`. Cada símbolo con su llamada (grep directo; control inventado 0) |
| La callable en producción | `fijarEnvioSinCargo` `ACTIVE`; preflight con `Origin` del panel **204** con `access-control-allow-origin`; `POST` anónimo **401** con el JSON de `exigirAdmin` (corre el código, no lo frena IAM); una inventada **404**. `config/envios` sigue **sin existir** después del anónimo |
| La tienda | Preview `build-2026-09-29-002` `SUCCEEDED` al 100 %, gates cerrados; `/pedido` recibe `sinCargoDesde: null` del servidor (una clave inventada: 0) |
| Panel | El mismo publicado de ADR 025: *"La entrega sin cargo"* va en el build `e95e653` (canario `fijarEnvioSinCargo` y *"Cobrar siempre la entrega"* 0 → 1) |
| Lo que NO se verificó | **Nadie fijó un monto** —el control de la baranda contra producción espera al dueño— ni se vio el empujón en `/pedido` con un umbral puesto |
