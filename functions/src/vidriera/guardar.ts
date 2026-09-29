/**
 * El nucleo de `guardarCajasSugeridas`: valida el pedido del panel, verifica
 * que cada caja sume una caja y reescribe `cajasSugeridas/publicas` entero.
 * HU-09.2, HU-09.3, ADR 009 §8.
 *
 * Recibe la base por parametro, sin `onCall` adentro, para poder probarlo
 * contra el emulador de Firestore SIN levantar el de Functions -cuyo
 * discovery no completa en esta maquina-.  Es el mismo molde de `mover.ts` y
 * `crear.ts`.
 *
 * ⚠️ La escritura del documento esta cerrada incluso para el admin
 * (`firestore.rules`, `cajasSugeridas/{documento}`): la unica regla que
 * importa de una caja -que SUME una caja- solo se sabe mirando
 * `presentacion.botellas` de cada producto, y comprobarlo en las reglas
 * serian seis `get()` FACTURADOS POR ESCRITURA.  Por eso el panel guarda por
 * esta callable, que corre con el Admin SDK.
 *
 * SIN TRANSACCION, a proposito:
 *   - `presentacion.botellas` es INMUTABLE por reglas (el `update` de
 *     `productos` no la deja tocar): lo que se lee en el paso 2 no puede
 *     cambiar entre la lectura y el `set` del paso 4.
 *   - Un producto no se borra desde un cliente (`allow delete: if false`):
 *     el id que existio al leer sigue existiendo al escribir.
 *   - El `set` reescribe el documento ENTERO: guardar dos veces da lo mismo
 *     (idempotente por construccion), y no hay un marcador que perder en la
 *     ventana entre dos escrituras -no hay dos escrituras.
 *
 * NO exige publicado ni stock: HU-09.3 dice que una caja con un vino
 * despublicado o agotado se sigue mostrando con el lugar marcado, y
 * re-guardar (por ejemplo al reordenar) no puede fallar por eso.  Solo se
 * exige la composicion: que cada id exista, que ninguno "viaje solo" (venga
 * en su propia caja) y que la suma cierre en `BOTELLAS_POR_CAJA`.
 */
import type { Firestore } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';

import { armarCajasSugeridas, verificarComposicion } from '@bouquet/contratos';

export interface ResultadoDeGuardar {
  /** Cuantas cajas quedaron en el documento. */
  readonly cajas: number;
}

const esEntero = (x: unknown): x is number => typeof x === 'number' && Number.isInteger(x);

export async function guardarCajasSugeridas(db: Firestore, entrada: unknown): Promise<ResultadoDeGuardar> {
  // 1. La forma del pedido: slugs derivados, tope de cajas, nombres
  //    repetidos, y que cada caja tenga exactamente BOTELLAS_POR_CAJA ids.
  //    Sin catalogo: es lo que se puede juzgar sin leer Firestore.
  const armado = armarCajasSugeridas(entrada);
  if (!armado.ok) throw new HttpsError('invalid-argument', armado.motivo);
  const cajas = armado.valor;

  // 2. Los ids DISTINTOS de todas las cajas, en UNA lectura.  Si no hay
  //    cajas (guardar la lista vacia), no hay nada que leer: `getAll` sin
  //    argumentos no es una lectura de cero documentos, es un error.
  const idsDistintos = [...new Set(cajas.flatMap((c) => c.productoIds))];
  const botellasPorProducto = new Map<string, number>();
  if (idsDistintos.length > 0) {
    const refs = idsDistintos.map((id) => db.collection('productos').doc(id));
    const snaps = await db.getAll(...refs);
    snaps.forEach((snap, i) => {
      const id = idsDistintos[i];
      if (id === undefined || !snap.exists) return;
      const b: unknown = snap.get('presentacion.botellas');
      // Un producto con `presentacion.botellas` roto no puede formar caja: se
      // deja afuera del mapa, y `verificarComposicion` lo trata igual que un
      // id que no existe -el motivo que ve el dueno es el mismo, y ninguno de
      // los dos es un caso que un catalogo sano deje pasar.
      if (esEntero(b) && b >= 1) botellasPorProducto.set(id, b);
    });
  }

  // 3. Cada caja tiene que SUMAR una caja, con botellas sueltas.  La primera
  //    que falla corta: el panel dice el nombre de esa caja y por que, y no
  //    se escribe nada de lo demas.
  for (const caja of cajas) {
    const v = verificarComposicion(caja, botellasPorProducto);
    if (!v.ok) throw new HttpsError('failed-precondition', v.motivo, { caja: caja.nombre });
  }

  // 4. Todas cierran: se reescribe el documento ENTERO.  Sin `muestra` -el
  //    seed lo pone; un guardado del dueno lo saca- y sin ningun otro campo:
  //    lo que devuelve `armarCajasSugeridas` ya es exactamente
  //    { slug, nombre, productoIds } por caja.
  await db.doc('cajasSugeridas/publicas').set({ cajas });

  return { cajas: cajas.length };
}
