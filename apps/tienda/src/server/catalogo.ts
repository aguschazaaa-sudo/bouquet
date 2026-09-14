import { unstable_cache } from 'next/cache';
import type { QuerySnapshot } from 'firebase-admin/firestore';
import { armarCatalogo, type Catalogo, type DocumentoCrudo } from '@bouquet/contratos';

import { db } from './firebase-admin';

/**
 * La proyección pública del catálogo: la ÚNICA lectura de Firestore de la
 * vidriera. ADR 004, 005 y 008.
 *
 * La consumen /vinos, /vinos/[slug] y /carrito, así que las tres pantallas
 * dicen el mismo precio. Cuesta P + B + 1 lecturas por reconstrucción
 * (productos publicados, bodegas enteras y la métrica de popularidad), y se
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

export const obtenerCatalogo = unstable_cache(leerCatalogoSinCache, ['catalogo'], {
  revalidate: SEGUNDOS_DE_CATALOGO,
  tags: ['catalogo'],
});
