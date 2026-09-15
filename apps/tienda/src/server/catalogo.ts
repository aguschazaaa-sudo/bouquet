import { unstable_cache } from 'next/cache';
import type { QuerySnapshot } from 'firebase-admin/firestore';
import {
  armarCatalogo,
  resolverCajasSugeridas,
  validarCajasSugeridas,
  type CajaSugeridaResuelta,
  type Catalogo,
  type DocumentoCrudo,
} from '@bouquet/contratos';

import { db } from './firebase-admin';

/**
 * La proyección pública del catálogo: la ÚNICA lectura de Firestore de la
 * vidriera. ADR 004, 005 y 008.
 *
 * La consumen /vinos, /vinos/[slug] y /carrito, así que las tres pantallas
 * dicen el mismo precio. Cuesta P + B + 1 lecturas por reconstrucción
 * (productos publicados, bodegas enteras y la métrica de popularidad) —P + B +
 * 2 con las cajas sugeridas, ver `leerVidrieraSinCache`—, y se
 * reconstruye como mucho una vez por minuto POR INSTANCIA: la caché de datos
 * de Next vive en la memoria de cada instancia de Cloud Run, no se comparte
 * entre instancias ni se purga desde afuera. La home la lee sin caché, una vez
 * por build (abajo).
 *
 * ⚠️ Nunca sin vencimiento. La purga de Cloudflare (tramo 4) no llega a esta
 * capa: una entrada sin `revalidate` dejaría un precio viejo para siempre en
 * esa instancia (hallazgo 6 de revisor-pagos). Un precio viejo en pantalla no
 * se puede cobrar —`crearOrden` compara el precio visto—, pero sí se puede
 * mostrar, y eso es lo que acota este número.
 *
 * Las tres rutas repiten el 60 como literal en `revalidate`, porque Next lo
 * exige literal. apps/tienda/test/revalidacion.test.ts compara los cuatro
 * números, así que no se pueden desincronizar sin que falle un test.
 */
const SEGUNDOS_DE_CATALOGO = 60;

const aCrudos = (snap: QuerySnapshot): DocumentoCrudo[] =>
  snap.docs.map((d) => ({ id: d.id, datos: d.data() }));

/**
 * La misma lectura, SIN caché: la de la home, que se hornea en el build —una
 * lectura por deploy, cero por visita— (ADR 008 §7).
 *
 * La home no puede usar `obtenerCatalogo`: un `unstable_cache` con
 * `revalidate` numérico le baja el `revalidate` a la página que lo llama (caso
 * `prerender-legacy` de next/dist/server/web/spec-extension/unstable-cache.js),
 * y la home pasaría sola a ISR de 60 s. Y al revés: una ruta dinámica que llame
 * a ésta lee P + B + 1 en CADA pedido.
 */
export async function leerCatalogoSinCache(): Promise<Catalogo> {
  const base = db();
  const [productos, bodegas, popularidad] = await Promise.all([
    // Índice automático de un campo: cero índices compuestos (ADR 004).
    base.collection('productos').where('publicado', '==', true).get(),
    base.collection('bodegas').get(),
    base.doc('metricas/popularidad').get(),
  ]);

  const { catalogo, descartes } = armarCatalogo(aCrudos(productos), aCrudos(bodegas), popularidad.data());
  // Un documento roto no tira el render que comparten las tres pantallas:
  // queda afuera de la proyección, y acá queda en el log.
  for (const d of descartes) console.error(`[catalogo] descartado ${d.id}: ${d.motivo}`);
  return catalogo;
}

/**
 * Lo que necesita `/vinos`: la proyección y las cajas que ofrece el vendedor.
 *
 * Las dos juntas a propósito. Ver `leerVidrieraSinCache`.
 */
export interface Vidriera {
  readonly catalogo: Catalogo;
  readonly cajas: readonly CajaSugeridaResuelta[];
}

/**
 * El catálogo MÁS las cajas sugeridas: P + B + 2.
 *
 * ⚠️ Tres cosas que este cuerpo tiene que hacer y que no se ven mirándolo:
 *
 * 1. **La lectura de cajas NO va adentro de `leerCatalogoSinCache`.** A ésa la
 *    llama la home, que no dibuja ningún carril: pagaría una lectura por un
 *    documento que no renderiza.
 * 2. **Tampoco va en un `unstable_cache` propio.** Un segundo `unstable_cache`
 *    con `revalidate` numérico le baja el `revalidate` a la página que lo
 *    llama; si lo tocara la home, la ruta más visitada pasaría sola a ISR de
 *    60 s y leería Firestore por visita, sin un error ni un aviso.
 * 3. **El join de las cajas con sus vinos va EN MEMORIA**, nunca con un `get()`
 *    por id: seis ids por caja y seis cajas serían 36 lecturas por
 *    reconstrucción —32 → 68, más que el doble— y 133 % de la cuota con el
 *    catálogo del MVP a 250 visitas.
 */
async function leerVidrieraSinCache(): Promise<Vidriera> {
  const [catalogo, crudo] = await Promise.all([
    leerCatalogoSinCache(),
    db().doc('cajasSugeridas/publicas').get(),
  ]);

  // Un documento ausente son cero cajas, no un error: el vendedor todavía no
  // cargó ninguna. (La lectura se cobra igual, exista o no.)
  const { cajas, descartes: deForma } = validarCajasSugeridas(crudo.data());
  const { cajas: resueltas, descartes: deComposicion } = resolverCajasSugeridas(cajas, catalogo.productos);

  for (const d of [...deForma, ...deComposicion]) {
    console.error(`[cajas] descartada ${d.id}: ${d.motivo}`);
  }

  // El seed marca el documento con `muestra: true`, y ese campo tiene que
  // llegar al gate de deploy: si no, es un campo que SE LEE COMO gate y no lo
  // es, justo sobre la superficie que el gate existe para proteger.
  const cajasDeMuestra = crudo.get('muestra') === true && resueltas.length > 0;

  return {
    catalogo: { ...catalogo, deMuestra: catalogo.deMuestra || cajasDeMuestra },
    cajas: resueltas,
  };
}

export const obtenerVidriera = unstable_cache(leerVidrieraSinCache, ['catalogo'], {
  revalidate: SEGUNDOS_DE_CATALOGO,
  tags: ['catalogo'],
});

/** Las rutas que no dibujan carril piden sólo la proyección. Misma entrada de caché. */
export const obtenerCatalogo = async (): Promise<Catalogo> => (await obtenerVidriera()).catalogo;
