/**
 * La transaccion de `crearOrdenDelPanel`: descuenta el stock, reserva el
 * numero y crea la Orden, todo o nada.  HU-10.1, ADR 018 §4.
 *
 * Recibe la base por parametro, sin `onCall` adentro, para poder probarlo
 * contra el emulador de Firestore SIN levantar el de Functions -cuyo discovery
 * no completa en esta maquina (ADR 015, 3.7)-.  Es el molde de `moverStock`.
 *
 * LAS COSAS QUE TIENEN QUE CUMPLIRSE EN LA MISMA TRANSACCION:
 *
 *  1. Leer la Orden.  Si ya existe con las MISMAS lineas es un reintento y se
 *     devuelve lo que paso; con otras, es un error.  El documento ES su propio
 *     marcador: `ordenId = idPedido`, asi que no hay una ventana entre "escribi
 *     la Orden" y "escribi el marcador" donde un reintento cobre dos veces.
 *  2. Leer los productos y el contador.  Toda validacion corre sobre lo que se
 *     ACABA de leer, no sobre lo que el panel tenia en pantalla.
 *  3. Escribir el stock de cada producto, el contador y la Orden.
 *
 * Y una que NO se hace: escribir un campo de mas en el producto.  Un campo que
 * las reglas no conocen rompe el `hasOnly` y el panel deja de poder editar ese
 * vino, en silencio.  Solo `stock`.
 *
 * `moverStock` escribe el mismo campo en su propia transaccion.  Firestore
 * serializa las dos sobre el mismo documento, asi que no hay sobreventa por
 * esta via.
 */
import { FieldValue, type Firestore } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';

import { contactoYEntrega, type PedidoDelPanel } from '@bouquet/contratos';

import { armarOrden, firmaDelPedido, type RechazoDeOrden } from './armar.ts';

export interface ResultadoDeCrear {
  /** El id del documento: es el `idPedido`.  Nunca se le muestra al comprador. */
  readonly ordenId: string;
  /** Lo que dice el comprador, y lo que ve el operador. */
  readonly numero: number;
  /** true si este `idPedido` ya era una Orden y no se toco nada. */
  readonly repetido: boolean;
}

const esEnteroNoNegativo = (x: unknown): x is number =>
  typeof x === 'number' && Number.isInteger(x) && x >= 0;

/** El rechazo del nucleo, como el error que ve el panel. */
function errorDe(r: RechazoDeOrden): HttpsError {
  const detalles = { codigo: r.codigo, productoId: r.productoId, actual: r.actual, motivo: r.motivo };
  // `undefined` no viaja por el cable: se saca para que el JSON sea el que se ve.
  const limpios = Object.fromEntries(Object.entries(detalles).filter(([, v]) => v !== undefined));
  if (r.codigo === 'no-existe') return new HttpsError('not-found', `no existe el producto ${r.productoId}`, limpios);
  const mensajes: Record<Exclude<RechazoDeOrden['codigo'], 'no-existe'>, string> = {
    'producto-roto': `el producto ${r.productoId} tiene un dato roto`,
    'de-muestra': `el producto ${r.productoId} es de muestra: no se puede vender`,
    compuesto: `el producto ${r.productoId} es compuesto y no tiene stock propio`,
    'sin-precio': `el producto ${r.productoId} no tiene precio`,
    'cambio-el-precio': `el precio de ${r.productoId} cambio`,
    'sin-stock': `no hay stock suficiente de ${r.productoId}`,
  };
  return new HttpsError('failed-precondition', mensajes[r.codigo], limpios);
}

export async function crearOrdenDelPanel(
  db: Firestore,
  pedido: PedidoDelPanel,
  uid: string,
): Promise<ResultadoDeCrear> {
  const orden = db.collection('ordenes').doc(pedido.idPedido);
  const contador = db.collection('contadores').doc('ordenes');
  const productos = pedido.lineas.map((l) => db.collection('productos').doc(l.productoId));

  // 10 y no los 5 de por defecto: compite con `moverStock` por los mismos
  // productos y con otra carga por el mismo contador, y un aborto por
  // contencion no es un error del operador.
  return db.runTransaction(
    async (tx): Promise<ResultadoDeCrear> => {
      // 1. La Orden primero: un reintento devuelve lo que paso, aunque el stock
      //    o el precio sean otros ahora (mismo criterio que el marcador de
      //    `moverStock`, hallazgo 6 de `revisor-pagos`).
      const existente = await tx.get(orden);
      if (existente.exists) {
        const guardadas = (existente.get('items') as { productoId: string; cantidad: number }[] | undefined) ?? [];
        const numeroGuardado = existente.get('numero') as number;
        const { contacto, entrega } = contactoYEntrega(pedido.entrega);
        const mismo =
          firmaDelPedido({ lineas: guardadas, contacto: existente.get('contacto'), entrega: existente.get('entrega') }) ===
          firmaDelPedido({ lineas: pedido.lineas, contacto, entrega });
        if (mismo) return { ordenId: orden.id, numero: numeroGuardado, repetido: true };
        // El mismo id con OTRO pedido no es un reintento: con otras lineas seria
        // descontar algo que el operador no cargo, y con otra direccion o otro
        // cliente seria devolver "exito" sin haber guardado lo que escribio.  El
        // numero de la Orden que ya existe viaja en el error: el panel manda a
        // abrirla, en vez de dejar cargar otra (hallazgo 3 de `revisor-pagos`).
        throw new HttpsError('already-exists', 'ese idPedido ya se uso para otro pedido', {
          codigo: 'otro-pedido',
          numero: numeroGuardado,
        });
      }

      // 2. Los productos y el contador, en un solo viaje.  Antes de cualquier
      //    escritura: una transaccion de Firestore no puede leer despues de
      //    escribir.
      const [snapContador, ...snapProductos] = await tx.getAll(contador, ...productos);
      const leidos = new Map<string, unknown>();
      snapProductos.forEach((s, i) => {
        const id = pedido.lineas[i]?.productoId;
        if (id !== undefined) leidos.set(id, s?.exists ? s.data() : undefined);
      });

      const ultimo: unknown = snapContador?.exists ? snapContador.get('ultimo') : 0;
      if (!esEnteroNoNegativo(ultimo)) {
        // Un contador roto no se "arregla": dos ordenes con el mismo numero es
        // exactamente lo que este documento existe para impedir.
        throw new HttpsError('failed-precondition', 'el contador de ordenes no es un entero valido');
      }
      const numero = ultimo + 1;

      const armado = armarOrden(pedido, leidos, { numero, uid, origen: 'whatsapp' });
      if (!armado.ok) throw errorDe(armado.rechazo);

      // 3. Todo o nada.
      for (const cambio of armado.stock) {
        const producto = db.collection('productos').doc(cambio.productoId);
        tx.update(producto, { stock: cambio.despues });
        // La venta deja SU movimiento, en el mismo registro que `moverStock`
        // (ADR 016 §6): sin esto la hoja de HU-05.4 muestra 0 -> 32 y despues
        // 30 -> 29, y faltan dos unidades sin explicacion (hallazgo 2).  El id
        // lleva el `idPedido`, asi que un reintento no puede duplicarlo; y no
        // choca con los de `moverStock`, que son hexadecimales sin guion.
        // `create`, no `set`: un choque tiene que fallar, no pisar un marcador.
        tx.create(producto.collection('movimientos').doc(`venta-${pedido.idPedido}`), {
          operacion: { tipo: 'venta', cantidad: cambio.antes - cambio.despues, idPedido: pedido.idPedido, numero },
          antes: cambio.antes,
          despues: cambio.despues,
          por: uid,
          en: FieldValue.serverTimestamp(),
        });
      }
      tx.set(contador, { ultimo: numero });
      tx.create(orden, {
        ...armado.orden,
        creadaEn: FieldValue.serverTimestamp(),
        actualizadaEn: FieldValue.serverTimestamp(),
      });
      return { ordenId: orden.id, numero, repetido: false };
    },
    { maxAttempts: 10 },
  );
}
