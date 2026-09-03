/**
 * Punto de entrada de las Cloud Functions de bouquet.
 *
 * Andamio: todavia no exporta ninguna function.  Las tres del paso 4 de
 * ARQUITECTURA §12 -- `crearOrden` (transaccion), `entroEnPagada` (trigger con
 * marcador de idempotencia) y `consultarOrden` (callable) -- se escriben en su
 * propio change.
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

export {};
