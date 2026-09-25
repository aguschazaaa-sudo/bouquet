/**
 * La transaccion de `cancelarOrden`: devuelve el stock y marca la Orden
 * `cancelada`, todo o nada.  HU-07.6, ADR 019 §5.
 *
 * Recibe la base por parametro, sin `onCall` adentro, para probarla contra el
 * emulador de Firestore sin el de Functions.  Es el molde de `crear.ts`.
 *
 * LA ORDEN ES SU PROPIO MARCADOR.  `cancelada` es terminal (ADR 002): de ahi no
 * sale nada.  Y la UNICA escritura que la pone `cancelada` es esta transaccion,
 * que en el mismo commit devuelve el stock -- las reglas no dejan que un cliente
 * la escriba (`SOLO_LO_ESCRIBE_EL_SERVIDOR`).  Asi que "ya esta cancelada" quiere
 * decir "el stock ya volvio, exactamente una vez", y un reintento devuelve lo que
 * paso sin tocar nada.  No hay una ventana entre el efecto y el marcador.
 *
 * Y una que NO se hace: escribir un campo de mas en el producto.  Solo `stock`,
 * igual que `moverStock` y `crearOrdenDelPanel`: un campo que las reglas no
 * conocen rompe su `hasOnly` y el panel deja de poder editar ese vino.
 */
import { FieldValue, type Firestore } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';

import {
  ESTADOS_ENTREGA,
  transicionEntregaValida,
  type EstadoEntrega,
  type LineaSinReponer,
  type PedidoDeCancelacion,
} from '@bouquet/contratos';

import { armarReposicion, leerItems } from './reponer.ts';

export interface ResultadoDeCancelar {
  readonly numero: number;
  /** true si la Orden ya estaba cancelada y no se toco nada. */
  readonly repetido: boolean;
  /** Lo que NO volvio al stock, con su motivo.  Vacio en el caso normal. */
  readonly sinReponer: readonly LineaSinReponer[];
}

const esEstadoEntrega = (x: unknown): x is EstadoEntrega =>
  typeof x === 'string' && (ESTADOS_ENTREGA as readonly string[]).includes(x);

export async function cancelarOrden(
  db: Firestore,
  pedido: PedidoDeCancelacion,
  uid: string,
): Promise<ResultadoDeCancelar> {
  const orden = db.collection('ordenes').doc(pedido.ordenId);

  // 10 y no los 5 de por defecto: compite con `moverStock` y con otras ventas
  // por los mismos productos.  Un aborto por contencion no es un error del
  // operador (hallazgo 10 de ADR 018).
  return db.runTransaction(
    async (tx): Promise<ResultadoDeCancelar> => {
      const snap = await tx.get(orden);
      if (!snap.exists) throw new HttpsError('not-found', 'no existe la orden', { codigo: 'no-existe' });

      const numero: unknown = snap.get('numero');
      const estado: unknown = snap.get('estadoEntrega');
      if (typeof numero !== 'number' || !Number.isInteger(numero) || !esEstadoEntrega(estado)) {
        throw new HttpsError('failed-precondition', 'la orden tiene un dato roto', { codigo: 'orden-rota' });
      }

      // 1. Ya cancelada: es un reintento.  Devuelve lo que paso la primera vez.
      if (estado === 'cancelada') {
        const guardado: unknown = snap.get('cancelacion.sinReponer');
        return { numero, repetido: true, sinReponer: Array.isArray(guardado) ? (guardado as LineaSinReponer[]) : [] };
      }

      // 2. La tabla de ADR 002 decide, no una lista escrita aca: un pedido que ya
      //    salio no se cancela, porque el envio ya costo.  El estado de AHORA viaja
      //    en el error y el panel lo dice.
      if (!transicionEntregaValida(estado, 'cancelada')) {
        throw new HttpsError('failed-precondition', 'el pedido ya salio: no se cancela', {
          codigo: 'ya-salio',
          estado,
        });
      }

      const items = leerItems(snap.get('items'));
      if (items === null) {
        throw new HttpsError('failed-precondition', 'la orden no tiene lineas legibles', { codigo: 'orden-rota' });
      }

      // 3. Los vinos, en un solo viaje y ANTES de escribir: una transaccion de
      //    Firestore no puede leer despues de escribir.
      const ids = [...new Set(items.map((i) => i.productoId))];
      const refs = ids.map((id) => db.collection('productos').doc(id));
      const snaps = await tx.getAll(...refs);
      const leidos = new Map<string, unknown>();
      snaps.forEach((s, i) => {
        const id = ids[i];
        if (id !== undefined) leidos.set(id, s.exists ? s.data() : undefined);
      });

      const { stock, sinReponer } = armarReposicion(items, leidos);

      // 4. Todo o nada.
      for (const cambio of stock) {
        const producto = db.collection('productos').doc(cambio.productoId);
        tx.update(producto, { stock: cambio.despues });
        // El mismo registro que las ventas y `moverStock` (ADR 016 §6): sin esto
        // la hoja de HU-05.4 muestra un salto que nadie explica.  El id lleva el
        // `ordenId`, que es el `idPedido`: no choca con `venta-<idPedido>` ni con
        // los hexadecimales de `moverStock`.  `create`, no `set`: un choque tiene
        // que fallar, no pisar.
        tx.create(producto.collection('movimientos').doc(`cancelacion-${pedido.ordenId}`), {
          operacion: {
            tipo: 'cancelacion',
            cantidad: cambio.despues - cambio.antes,
            idPedido: pedido.ordenId,
            numero,
          },
          antes: cambio.antes,
          despues: cambio.despues,
          por: uid,
          en: FieldValue.serverTimestamp(),
        });
      }
      tx.update(orden, {
        estadoEntrega: 'cancelada',
        cancelacion: { motivo: pedido.motivo, por: uid, en: FieldValue.serverTimestamp(), sinReponer },
        actualizadaEn: FieldValue.serverTimestamp(),
      });
      return { numero, repetido: false, sinReponer };
    },
    { maxAttempts: 10 },
  );
}
