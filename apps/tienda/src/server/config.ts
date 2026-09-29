import { unstable_cache } from 'next/cache';
import { leerConfigDeEnvios, type Centavos } from '@bouquet/contratos';

import { db } from './firebase-admin';

/**
 * Desde qué monto la entrega sale sin cargo (HU-11.1, ADR 026), o `null` si el
 * dueño no fijó ninguno. Lo escribe SÓLO la callable `fijarEnvioSinCargo`, que
 * corre la baranda contra el dedo gordo; acá sólo se lee.
 *
 * UNA lectura por reconstrucción, en su PROPIA entrada de caché y no en la del
 * catálogo: la lee sólo `/pedido`, y metida en `obtenerVidriera` la pagarían
 * `/vinos`, la ficha y `/carrito` por un documento que no dibujan. `/pedido`
 * ya revalida cada 60 s, así que un `unstable_cache` de 60 no le cambia nada
 * (el riesgo de ADR 008 §7 es la home, y la home no la importa:
 * apps/tienda/test/revalidacion.test.ts lo vigila).
 *
 * ⚠️ Un documento roto se lee como APAGADO y queda en el log: cobrar la entrega
 * es lo que se hacía antes de esta historia; regalarla por un dato roto, no.
 *
 * ⚠️ Esto es lo que MUESTRA la pantalla. Lo que se cobre lo decide
 * `crearOrden` —que todavía no existe— aplicando la misma regla sobre el
 * subtotal que recalcule el servidor, nunca sobre el del navegador (ADR 026).
 */
const SEGUNDOS_DE_CONFIG = 60;

async function leerEnvioSinCargoSinCache(): Promise<Centavos | null> {
  const crudo = await db().doc('config/envios').get();
  const { sinCargoDesde, roto } = leerConfigDeEnvios(crudo.data());
  if (roto) console.error('[config] config/envios no se pudo leer: la entrega se cobra');
  return sinCargoDesde;
}

export const obtenerEnvioSinCargo = unstable_cache(leerEnvioSinCargoSinCache, ['config-envios'], {
  revalidate: SEGUNDOS_DE_CONFIG,
  tags: ['config'],
});
