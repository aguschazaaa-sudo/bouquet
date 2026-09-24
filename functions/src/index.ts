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
