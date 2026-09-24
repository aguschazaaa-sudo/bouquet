## Why

Hay ventas que **ya existen** y no pasan por la vidriera: se piden por WhatsApp y
se cobran por fuera. Hoy nada las registra, así que el stock del panel miente en
cuanto se entrega una, y el dueño no tiene dónde ver qué hay que despachar.

Es el primer tramo del **hito 2**, y va primero porque **no espera a Mercado
Pago**: lleva el panel a producción con pedidos reales mientras la vidriera
sigue sin cobrar (sexto gate). Es también la primera vez que se **crea una
Orden**, así que la forma del documento se fija acá y la vidriera va a escribir
la misma cuando exista su `crearOrden`.

Historias: **HU-10.1** ([EP-10](../../../docs/vault/features/panel/EP-10-ventas-por-fuera.md)),
**HU-06.1** y **HU-06.2** ([EP-06](../../../docs/vault/features/panel/EP-06-ver-pedidos.md)).
Las dos de EP-06 entran porque sin ellas cargar un pedido no se puede verificar en
pantalla: se vería sólo leyendo Firestore.

**La decisión entera, con sus alternativas descartadas y el presupuesto de
lecturas, está en [ADR 018](../../../docs/vault/architecture/decisions/018-pedidos-de-whatsapp.md).**
Esta propuesta la cita y no la repite.

## What Changes

- **`contratos`**: el eje de pago gana un valor, **`por_fuera`** (terminal, sin
  transiciones), y la proyección pasa de 30 a **36 pares** con un estado público
  nuevo, **`por_preparar`**. Un `origen` (`whatsapp` | `vidriera`) y la regla
  *origen ⇔ estado de pago inicial* viven acá. El JSON generado y sus fixtures se
  regeneran. **BREAKING** para quien enumere `EstadoPago`: el espejo de Dart y su
  test se actualizan en el mismo cambio.
- **`functions`**: una callable nueva, **`crearOrdenDelPanel`**, con `exigirAdmin`.
  Una transacción que descuenta stock, numera contra `contadores/ordenes` y crea la
  Orden, donde **el documento es su propio marcador de idempotencia**. La regla de
  las seis botellas **no se exige** (respuesta 7 del dueño), y por eso el origen lo
  fija el servidor, no el pedido.
- **`firestore.rules`**: `ordenes` pide `limit <= 50` en un `list`, igual que
  `movimientos`. La creación sigue cerrada a los clientes. Suite nueva de reglas
  para `ordenes`, que hoy no tiene ninguna.
- **Panel (`apps/admin`)**: una feature `pedidos/` con tres pantallas —cargar un
  pedido, la bandeja por estado de entrega y el detalle— sobre un espejo de la
  Orden en Dart.
- Se borra `textoOcultarMovimientos`, una constante huérfana que dejó HU-05.4.

**No cambia:** la vidriera, `procesarFoto`, `moverStock`, ni el cobro. Tampoco se
puede **cancelar** ni **despachar** un pedido desde el panel todavía: son EP-07.

## Capabilities

### New Capabilities

- `estado-de-pago-por-fuera`: el valor `por_fuera` del eje de pago, el estado
  público `por_preparar`, el origen de una Orden y la regla que los liga.
- `crear-orden-del-panel`: la callable `crearOrdenDelPanel` y lo que garantiza:
  stock que no baja de cero, número único, reintento sin duplicar, precio visto.
- `cargar-pedido-de-whatsapp`: el formulario del panel (HU-10.1).
- `bandeja-de-pedidos`: la lista por estado de entrega, con los más nuevos arriba
  (HU-06.1).
- `detalle-del-pedido`: un pedido entero, con el rótulo que sale de la proyección
  (HU-06.2).

### Modified Capabilities

<!-- Ninguna: openspec/specs/ está vacío (ningún change se archivó nunca). -->

## Impact

- `packages/contratos/src/{orden,proyeccion}.ts`, `generated/contratos.json` y sus
  tests; `scripts/ci/auditar_estados.mjs` (los 36 pares).
- `functions/src/pedidos/` y `functions/test/pedidos/`; `functions/src/index.ts`.
- `firestore.rules`, `scripts/reglas/ordenes.test.mjs`.
- `apps/admin/lib/core/contratos/estado_{pago,publico}.dart`, la feature
  `apps/admin/lib/features/pedidos/`, el enrutador y la navegación.
- **Deploy en el orden fijo:** reglas → functions → panel, con `revisor-pagos`
  sobre el backend **antes** del commit. El backend se verifica en producción
  antes de que el formulario lo llame.
- **Lecturas:** ~850/día, 1,7 % de la cuota (ADR 018, *Presupuesto*).
