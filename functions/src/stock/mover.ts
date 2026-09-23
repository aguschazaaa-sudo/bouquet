/**
 * El nucleo de `moverStock`: una transaccion que cambia `stock` y deja el
 * marcador del movimiento.  EP-05, ADR 016.
 *
 * Recibe la base por parametro, sin `onCall` adentro, para poder probarlo
 * contra el emulador de Firestore SIN levantar el de Functions -cuyo
 * discovery no completa en esta maquina-.  La callable (`mover_stock.ts`) es
 * un envoltorio de diez lineas: guardas, parseo, y esto.
 *
 * LAS TRES COSAS QUE TIENEN QUE CUMPLIRSE EN LA MISMA TRANSACCION:
 *
 *  1. Leer el producto y el marcador.  Si el marcador ya esta, es un reintento
 *     y NO se vuelve a aplicar.
 *  2. Aplicar la cuenta sobre el stock que se ACABA de leer, no sobre el que
 *     el panel tenia en pantalla.
 *  3. Escribir el stock y el marcador.  Escrito el marcador DESPUES, la
 *     ventana entre las dos escrituras es exactamente donde un reintento suma
 *     dos veces.  CLAUDE.md, "Idempotencia".
 *
 * Y una que NO se hace: escribir algo que no sea `stock`.  Un campo de mas en
 * el producto rompe el `hasOnly` de las reglas y el panel deja de poder
 * editar ese vino, en silencio.
 *
 * `crearOrden` va a escribir este mismo campo en su propia transaccion.
 * Firestore serializa las dos sobre el mismo documento, asi que no hay
 * sobreventa por esta via.  Lo que NO resuelve: cuando existan pedidos
 * vendidos y sin despachar, "lo que conte en el deposito" deja de ser el
 * stock -los ya vendidos siguen en la estanteria-, y corregir ahi es una
 * decision de producto (ADR 016, "Lo que queda para crearOrden").
 */
import { FieldValue, type Firestore } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';

import { aplicarOperacion, type PedidoDeMovimiento } from '@bouquet/contratos';

export interface ResultadoDelMovimiento {
  readonly antes: number;
  readonly despues: number;
  /** true si este `idMovimiento` ya estaba aplicado y no se toco nada. */
  readonly repetido: boolean;
}

/**
 * La operacion como texto comparable.  Firestore devuelve los mapas con las
 * claves ordenadas, no en el orden en que se escribieron: comparar el
 * `JSON.stringify` de lo guardado contra el de lo que llega solo seria estable
 * por casualidad.  Ordenar las claves lo hace estable por construccion.
 */
export function firmaDeOperacion(operacion: object): string {
  return JSON.stringify(operacion, Object.keys(operacion).sort());
}

const esEntero = (x: unknown): x is number => typeof x === 'number' && Number.isInteger(x);

export async function moverStock(
  db: Firestore,
  pedido: PedidoDeMovimiento,
  uid: string,
): Promise<ResultadoDelMovimiento> {
  const producto = db.collection('productos').doc(pedido.productoId);
  const marcador = producto.collection('movimientos').doc(pedido.idMovimiento);

  // 10 y no los 5 de por defecto: `crearOrden` va a competir por este mismo
  // documento, y un aborto por contencion no es un error del operador.
  return db.runTransaction(
    async (tx): Promise<ResultadoDelMovimiento> => {
      // Las dos lecturas, antes de cualquier escritura: una transaccion de
      // Firestore no puede leer despues de escribir.
      const [snapProducto, snapMarcador] = await Promise.all([tx.get(producto), tx.get(marcador)]);

      if (!snapProducto.exists) {
        throw new HttpsError('not-found', `no existe el producto ${pedido.productoId}`);
      }
      // EL MARCADOR PRIMERO.  Un reintento de un movimiento que ya paso tiene
      // que devolver lo que paso, aunque el producto haya cambiado de estado
      // entre las dos llamadas (hallazgo 6 de `revisor-pagos`).
      if (snapMarcador.exists) {
        const guardada = snapMarcador.get('operacion') as object | undefined;
        if (guardada && firmaDeOperacion(guardada) === firmaDeOperacion(pedido.operacion)) {
          // Un reintento: el mismo movimiento otra vez.  Se devuelve lo que
          // paso la primera vez, aunque el stock ya sea otro.
          return {
            antes: snapMarcador.get('antes') as number,
            despues: snapMarcador.get('despues') as number,
            repetido: true,
          };
        }
        // El mismo id con OTRA operacion no es un reintento: es un error, y
        // aplicarla seria sumar algo que el operador no pidio.
        throw new HttpsError('already-exists', 'ese idMovimiento ya se uso para otra operacion');
      }

      if (snapProducto.get('tipo') !== 'simple') {
        // Un compuesto no tiene stock propio: lo deriva de sus componentes
        // (ADR 009 §10).  Escribirle uno lo dejaria a la venta con un numero
        // que ninguna regla del catalogo mira.
        throw new HttpsError('failed-precondition', 'un producto compuesto no tiene stock propio');
      }
      const stockActual: unknown = snapProducto.get('stock');
      if (!esEntero(stockActual) || stockActual < 0) {
        // Un simple con stock roto no se "arregla": alguien lo tiene que mirar.
        throw new HttpsError('failed-precondition', 'el stock del producto no es un entero valido');
      }

      const cuenta = aplicarOperacion(stockActual, pedido.operacion);
      if (!cuenta.ok) {
        // El numero de AHORA viaja en el error: el panel se lo muestra al
        // operador, que decide, en vez de reintentar a ciegas.
        throw new HttpsError(
          'failed-precondition',
          cuenta.codigo === 'cambio-el-stock'
            ? 'el stock cambio mientras lo contabas'
            : 'el stock pasaria el tope',
          { codigo: cuenta.codigo, actual: stockActual },
        );
      }

      tx.update(producto, { stock: cuenta.despues });
      tx.create(marcador, {
        operacion: pedido.operacion,
        antes: stockActual,
        despues: cuenta.despues,
        por: uid,
        en: FieldValue.serverTimestamp(),
      });
      return { antes: stockActual, despues: cuenta.despues, repetido: false };
    },
    { maxAttempts: 10 },
  );
}
