/**
 * El nucleo de `fijarEnvioSinCargo`: valida el monto, corre la baranda sobre el
 * valor NUEVO y reescribe `config/envios`. HU-11.1, ADR 026.
 *
 * Recibe la base por parametro, sin `onCall` adentro, para poder probarlo
 * contra el emulador de Firestore SIN levantar el de Functions -cuyo
 * discovery no completa en esta maquina-. Es el molde de `guardar.ts`.
 *
 * ⚠️ `config` esta cerrado para escribir incluso al admin (`firestore.rules`):
 * esta callable es la UNICA puerta, y por eso la baranda vive aca y no en el
 * panel -un panel con un bug, o una llamada armada a mano, pasa por el mismo
 * lugar- (ARQUITECTURA §9.4).
 *
 * Orden de las guardas, cada una antes de la siguiente:
 *   1. La forma: pesos enteros dentro de los topes duros, o `null` (apagar).
 *      Lo que no la cumple NO se guarda nunca, confirmado o no.
 *   2. Apagar no pide confirmacion: cobrar el envio no regala nada.
 *   3. La baranda blanda (`motivoParaConfirmar`): por debajo de una caja a
 *      precio tipico, o menos de la mitad del anterior. Con motivo y sin
 *      `confirmado`, NO se guarda y se devuelve el motivo para que el panel
 *      lo diga con palabras. Se evalua SIEMPRE, confirmado o no, y un
 *      guardado que la baranda marcaba devuelve `barandaConfirmada`: la
 *      callable lo loguea como advertencia. Sin eso, un umbral de $1 mandado
 *      con `confirmado: true` de entrada quedaba en el log igual que un cambio
 *      sano (hallazgo MEDIO de `revisor-pagos`, 2026-09-29).
 *
 * SIN TRANSACCION, a proposito: dos personas fijando el umbral a la vez es
 * "gana el ultimo", igual que las cajas (ADR 024). Lo que se lee -el anterior y
 * los precios- es una SENAL para preguntar, no una condicion de plata: si
 * cambia entre la lectura y el `set`, lo peor es una pregunta de mas o de
 * menos, y el valor guardado es igual de valido.
 */
import { FieldValue, type Firestore } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';

import {
  cajaTipica,
  leerConfigDeEnvios,
  motivoParaConfirmar,
  parsearPedidoDeSinCargo,
  type Centavos,
  type MotivoParaConfirmar,
} from '@bouquet/contratos';

export type ResultadoDeFijar =
  | {
      readonly guardado: true;
      readonly sinCargoDesde: Centavos | null;
      /** La baranda marcaba este monto y se guardo porque vino `confirmado`. */
      readonly barandaConfirmada?: MotivoParaConfirmar;
    }
  | ({ readonly guardado: false } & MotivoParaConfirmar);

export async function fijarEnvioSinCargo(db: Firestore, uid: string, entrada: unknown): Promise<ResultadoDeFijar> {
  // 1. La forma.
  const pedido = parsearPedidoDeSinCargo(entrada);
  if (!pedido.ok) throw new HttpsError('invalid-argument', pedido.motivo);
  const { sinCargoDesde, confirmado } = pedido.valor;

  const documento = db.doc('config/envios');

  // 2. Apagar: sin lecturas, sin preguntas.
  let motivo: MotivoParaConfirmar | null = null;
  if (sinCargoDesde !== null) {
    // 3. La baranda. El anterior es la senal opcional; la caja tipica sale de
    //    lo publicado. Las dos lecturas juntas: un documento y la coleccion
    //    publicada (P lecturas, una vez por guardado, que es de vez en cuando).
    const [anterior, publicados] = await Promise.all([
      documento.get(),
      db.collection('productos').where('publicado', '==', true).select('precio', 'presentacion').get(),
    ]);
    motivo = motivoParaConfirmar(sinCargoDesde, {
      anterior: leerConfigDeEnvios(anterior.data()).sinCargoDesde,
      cajaTipica: cajaTipica(
        publicados.docs.map((d) => ({
          precio: d.get('precio') as number,
          botellas: d.get('presentacion.botellas') as number,
        })),
      ),
    });
    if (motivo !== null && !confirmado) return { guardado: false, ...motivo };
  }

  // 4. Se reescribe el documento ENTERO: guardar dos veces da lo mismo.
  await documento.set({
    sinCargoDesde,
    actualizadoEn: FieldValue.serverTimestamp(),
    actualizadoPor: uid,
  });
  return motivo === null ? { guardado: true, sinCargoDesde } : { guardado: true, sinCargoDesde, barandaConfirmada: motivo };
}
