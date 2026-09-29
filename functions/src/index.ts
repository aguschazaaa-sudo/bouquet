/**
 * Punto de entrada de las Cloud Functions de bouquet.
 *
 * `procesarFoto` es la PRIMERA function del proyecto
 * (openspec/changes/panel-fotos-de-un-vino), `moverStock` la segunda, la
 * primera que escribe plata (EP-05, ADR 016), y `crearOrdenDelPanel` la
 * tercera, la primera que CREA una Orden (HU-10.1, ADR 018). Las del paso 4 de
 * ARQUITECTURA §12 que faltan -- `crearOrden` de la vidriera (transaccion),
 * `entroEnPagada` (trigger con marcador de idempotencia) y `consultarOrden`
 * (callable) -- se escriben en su propio change.
 *
 * Cuando se escriban, las dos reglas que no se negocian:
 *
 *  · `onDocumentWritten` + los helpers `entroEn*` de @bouquet/contratos.
 *    NUNCA `onDocumentUpdated`: los triggers son at-least-once y el mismo
 *    evento llega dos veces.
 *
 *  · El marcador de idempotencia va en la MISMA TRANSACCION que el efecto.
 *    Escrito despues, la ventana entre los dos es exactamente donde el
 *    segundo evento cobra dos veces.
 */

export { procesarFoto } from './foto/procesar_foto.ts';
export { moverStock } from './stock/mover_stock.ts';
export { crearOrdenDelPanel } from './pedidos/crear_orden_del_panel.ts';
// La cuarta, y la unica que DEVUELVE stock (HU-07.6, ADR 019).
export { cancelarOrden } from './pedidos/cancelar_orden.ts';
// El cobro de la vidriera, del lado que recibe (HU-08.1, HU-08.3, ADR 022): el
// webhook y la re-consulta, sobre el mismo nucleo.  ⚠️ Los secretos de Mercado
// Pago tienen HOY valores FALSOS: ver `pagos/secretos.ts`.
export { avisoDeMercadoPago } from './pagos/aviso_de_mercado_pago.ts';
export { revisarPago } from './pagos/revisar_pago.ts';
// La vidriera curada, tramo cajas sugeridas (HU-09.2, HU-09.3): el panel arma
// y reordena las cajas, y esta callable es la unica puerta de escritura --
// `cajasSugeridas/publicas` esta cerrado incluso para el admin en las reglas.
export { guardarCajasSugeridas } from './vidriera/guardar_cajas_sugeridas.ts';
// El primer job programado (HU-11.3, ADR 025): recalcula `metricas/popularidad`
// entero cada madrugada, con las ventas reales de los ultimos 90 dias.  Hasta
// hoy ese documento lo escribia solo el seed, simulado.
export { calcularPopularidad } from './metricas/calcular_popularidad.ts';
// La primera que escribe `config` (HU-11.1, ADR 026): desde que monto el envio
// sale sin cargo.  `config` esta cerrado incluso para el admin en las reglas, y
// la baranda contra el dedo gordo corre aca, sobre el valor NUEVO (§9.4).
export { fijarEnvioSinCargo } from './config/fijar_envio_sin_cargo.ts';
