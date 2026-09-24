## ADDED Requirements

### Requirement: El eje de pago SHALL tener un valor `por_fuera` terminal

`ESTADOS_PAGO` MUST incluir `por_fuera`, un estado del que nada sale y al que nada entra después del nacimiento: su lista de transiciones es vacía y ningún otro estado lo lista como destino.

Describe un cobro que el sistema **no sigue**: el de un pedido de WhatsApp
([ADR 018 §3](../../../../docs/vault/architecture/decisions/018-pedidos-de-whatsapp.md)).

#### Scenario: Nada sale de `por_fuera`
- **WHEN** se pregunta por cada estado de pago como destino desde `por_fuera`
- **THEN** `transicionPagoValida('por_fuera', destino)` es `false` salvo que el destino sea `por_fuera`

#### Scenario: Nada llega a `por_fuera` después de nacer
- **WHEN** se recorre `TRANSICIONES_PAGO`
- **THEN** ningún estado lista `por_fuera` como destino

#### Scenario: Una Orden puede nacer `por_fuera`
- **WHEN** se valida un nacimiento con `transicionPagoValida(undefined, 'por_fuera')`
- **THEN** es `true`

### Requirement: `por_fuera` SHALL NOT disparar `entroEnPagada`

`entroEnPagada` MUST ser `false` para toda Orden cuyo `estadoPago` es `por_fuera`, en el nacimiento y después: el aviso de pedido pagado no puede salir por un cobro que no pasó por el sistema.

#### Scenario: Nace `por_fuera`
- **WHEN** `antes` es `undefined` y `despues` es `por_fuera`
- **THEN** `entroEnPagada(antes, despues)` es `false`

### Requirement: La proyección SHALL ser total sobre los 36 pares

`proyectarEstadoPublico` MUST devolver un estado público para cada uno de los 6 × 6 = 36 pares de `(estadoPago, estadoEntrega)`, sin rama por defecto que trague casos.

Para `por_fuera` el resultado es: `sin_preparar → por_preparar`,
`preparando → en_preparacion`, `despachada → en_camino`, `entregada → entregada`,
`fallida → no_entregada`, `cancelada → cancelada`.

#### Scenario: Los 36 pares
- **WHEN** un test recorre todos los pares
- **THEN** cada uno devuelve un valor de `ESTADOS_PUBLICOS` y ninguno lanza

#### Scenario: Un pedido de WhatsApp entregado no es "entregada impaga"
- **WHEN** el par es `(por_fuera, entregada)`
- **THEN** el estado público es `entregada`, nunca `entregada_impaga`

#### Scenario: Un pedido de WhatsApp cancelado no pide devolver plata
- **WHEN** el par es `(por_fuera, cancelada)`
- **THEN** el estado público es `cancelada`, nunca `cancelada_con_pago`

### Requirement: `por_preparar` SHALL requerir acción y no afirmar un cobro

El estado público `por_preparar` MUST estar en `REQUIEREN_ACCION`, y su rótulo de operador MUST ser «Cobro por fuera - falta preparar»; ni su rótulo de operador ni el de cliente pueden decir «Pago acreditado» ni «falta cobrar».

#### Scenario: Está en la bandeja de lo que requiere acción
- **WHEN** se consulta `REQUIEREN_ACCION`
- **THEN** incluye `por_preparar`

#### Scenario: Los rótulos no mienten
- **WHEN** se leen los dos rótulos de `por_preparar`
- **THEN** ninguno contiene «acreditado» ni «cobrar»

### Requirement: El origen SHALL determinar el estado de pago inicial

`contratos` MUST exponer `estadoDePagoInicial(origen)`: `whatsapp` devuelve `por_fuera` y `vidriera` devuelve `pendiente`. Es la única fuente de esa correspondencia; la callable no la reescribe.

#### Scenario: WhatsApp
- **WHEN** `origen` es `whatsapp`
- **THEN** `estadoDePagoInicial` es `por_fuera`

#### Scenario: Vidriera
- **WHEN** `origen` es `vidriera`
- **THEN** `estadoDePagoInicial` es `pendiente`, y nunca `por_fuera`

### Requirement: El contrato generado y el espejo de Dart SHALL coincidir

`generated/contratos.json` MUST estar fresco respecto del TypeScript, y el panel MUST tener el mismo `EstadoPago`, la misma proyección de 36 pares y el mismo `estadosPublicosQueRequierenAccion`, verificado por un test de Dart contra ese JSON.

#### Scenario: JSON viejo
- **WHEN** se cambia `orden.ts` sin regenerar el JSON
- **THEN** `scripts/ci/auditar_estados.mjs` falla

#### Scenario: Espejo de Dart desactualizado
- **WHEN** el enum de Dart no tiene `por_fuera`
- **THEN** el test de `estados_orden_test.dart` falla nombrando el estado que falta
