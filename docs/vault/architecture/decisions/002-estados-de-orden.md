# ADR 002 — La Orden tiene dos ejes de estado, no uno

- **Fecha:** 2026-09-01
- **Estado:** aceptada
- **Decide:** cómo se modela el ciclo de vida de una Orden, y cómo reaccionan los
  triggers

## Contexto

Es el artefacto del día 1. `SETUP` §0.1 lo marca como el punto no negociable:

> En PadelPunilla los estados de Reserva quedaron repartidos entre Dart y TS, y
> la condición correcta para "entró en confirmada" hubo que **descubrirla**
> auditando 5 rutas distintas, meses después de que el primer trigger estuviera
> mal.

## Decisión

Una Orden tiene **dos campos de estado independientes** y una **proyección
derivada** para mostrar.

### `estadoPago`

| Estado | Significa | Entra desde |
|---|---|---|
| `pendiente` | Se debe | creación |
| `en_proceso` | El proveedor la tomó y no resolvió | `pendiente` |
| `pagada` | Cobrada y conciliada | **creación**, `pendiente`, `en_proceso` |
| `rechazada` | El proveedor la rechazó | `pendiente`, `en_proceso` |
| `reembolsada` | Se devolvió la plata | `pagada` |

### `estadoEntrega`

| Estado | Significa | Entra desde |
|---|---|---|
| `sin_preparar` | Confirmada, sin tocar | creación |
| `preparando` | Se está armando | `sin_preparar` |
| `despachada` | Salió | `preparando` |
| `entregada` | Llegó y firmó un mayor de 18 | `despachada` |
| `fallida` | No se pudo entregar | `despachada` |
| `cancelada` | No se entrega | `sin_preparar`, `preparando` |

### La proyección

`proyectarEstadoPublico(estadoPago, estadoEntrega)` vive en
`packages/contratos` y es **la única fuente** del rótulo que ve el cliente y del
que ve el operador.

## Por qué dos ejes

Los dos hechos avanzan por separado y a veces en desorden:

- **Se cobró** puede pasar antes (Mercado Pago), después (efectivo contra
  entrega) o nunca (cancelada antes de despachar).
- **Se entregó** avanza por logística, no por plata.

Un único string obliga a inventar estados cruzados (`entregada_impaga`,
`pagada_no_despachada`) y a decidir cuál gana cuando llegan desordenados.
`LECCIONES` §5.2 marca exactamente ese caso: *"una notificación `pagado` que
llega después de `cancelado`"*. Con dos ejes esa notificación escribe **su** eje
y no pisa el otro — no hay conflicto que resolver porque no hay campo compartido.

## Por qué NO un solo string con estados cruzados

Es lo que sale naturalmente si se modela por la pantalla en vez de por la
entidad. Se descarta porque el número de estados es el producto de los dos ejes
(5 × 6 = 30), y de esos sólo un puñado tiene nombre en castellano. El resto
existen igual y quedan sin nombre, que es cuando aparecen los `default:` que
tragan casos.

## Por qué NO un campo `historial[]` como fuente de verdad

Un event log es más expresivo. Se descarta para el MVP porque obliga a derivar el
estado en cada lectura, y la derivación es exactamente el tipo de lógica que
termina duplicada entre TS y Dart. Los dos campos planos se leen igual desde los
dos lados. El historial se guarda como **auditoría**, no como fuente de verdad.

## Las tres reglas que salen de la evidencia

### 1. Una Orden puede NACER en el estado final

Es §5.1, la lección más transferible del documento original. Una Reserva de
PadelPunilla podía llegar a `confirmada` por **5 rutas**, y **dos la creaban ya
confirmada**. Un agregado construido sobre `onDocumentUpdated` habría ignorado
justo el caso más fuerte, y **el ranking habría parecido funcionar**.

```
❌  onDocumentUpdated  +  "pasó a pagada"
✅  onDocumentWritten  +  entroEnPagada(antes, después)
```

`entroEnPagada` = `después === 'pagada' && antes !== 'pagada'`, con
`antes === undefined` en un create. **Vive en `packages/contratos` como helper
compartido, porque es un hecho del ciclo de vida de la entidad, no de un flujo.**

Rutas por las que una Orden nace `pagada` hoy: carga manual desde el panel, y
cualquier cosa que agregue el dueño el año que viene.

> **Antes de ensanchar un trigger, buscá quién MÁS emite por ese hecho.** En
> PadelPunilla, al pasar un trigger a `onDocumentWritten`, la mitad importante
> del arreglo fue **excluir** el caso que ya mandaba su propio aviso — con
> fingerprint distinto, así que la deduplicación no lo habría frenado y el grupo
> habría recibido dos avisos con dos textos.

### 2. Idempotencia por marcador, en la misma transacción que el efecto

Los triggers son at-least-once (§5.2). El marcador va en
`ordenes/{ordenId}/marcadores/{efecto}`, escrito **en la misma transacción** que
el efecto.

Si el efecto y el marcador no son atómicos, la ventana entre los dos es
exactamente donde ocurre el doble descuento. Y un `increment` repetido **infla en
silencio**: el peor modo de falla, porque el dato queda mal sin error.

### 3. Lo crítico no comparte función con lo accesorio

§5.5: un fallo escribiendo contadores sociales no puede tumbar la disponibilidad.
Traducido:

- **El stock se descuenta en la transacción de `crearOrden`**, no en un trigger.
- El mail al cliente, el aviso al depósito y "los más vendidos" son triggers
  **separados**. Que uno tire no puede impedir que otro corra.

## Nombrar los triggers

El primero puede llamarse por el evento; los siguientes se nombran por **lo que
mantienen** (§5.4), no `onOrdenPagadaAlgo`. Y hay una razón mecánica: `index.ts`
hace `export *` de cada flujo, así que **dos flujos no pueden exportar el mismo
nombre** — lo descubre `tsc` con un `TS2308`, no una búsqueda.

## Consecuencias

- `packages/contratos` exporta los dos enums, la tabla de transiciones válidas,
  los helpers `entroEn*` y la proyección.
- `apps/admin` espeja los enums en Dart con un test contra
  `contratos/generated/contratos.json`, y **`scripts/ci/auditar_estados.mjs`
  verifica que ese JSON esté fresco**. Sin esa verificación el test pasa contra
  un contrato viejo y se vuelve teatro.
- La UI nunca arma un rótulo a partir de los dos campos: llama a la proyección.
  Dos implementaciones del mismo rótulo se desincronizan (§6.4).
- El estado transitorio entre "confirmé" y "el pago resolvió" **no se llama
  `pendiente`**. §5.6: la misma palabra con la que se lee una espera de días que
  depende de una persona hace que el cliente no distinga su orden detenida de una
  que resuelve en dos segundos. Va `Confirmando…` o equivalente, y **eso sobrevive
  a cualquier optimización de latencia**: el estado existe siempre, aunque dure
  300 ms.
