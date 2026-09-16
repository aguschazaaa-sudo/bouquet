'use client';

import { useEffect, useState } from 'react';
import type { CargaDelPedido, ResultadoDeCotizacion } from '@bouquet/contratos';

/* La cotización, pedida al servidor mientras el comprador escribe.
 *
 * ⚠️ LA FUNCIÓN LLEGA POR PARÁMETRO, NO POR IMPORT, y no es preferencia: el
 * hook `server-only-guard` prohíbe que un `'use client'` importe de
 * `src/server/`. La Server Action viaja desde `app/pedido/page.tsx` —un Server
 * Component— hasta acá, que es el mismo camino que ADR 008 §5 usa para los
 * elementos del catálogo. De paso queda inyectable: un cotizador falso prueba
 * el descarte de respuestas viejas sin levantar un servidor.
 *
 * TRES COSAS QUE NO SON ADORNO:
 *
 *  1. **Espera a que dejen de escribir.** Sin esto, "5176" son cuatro
 *     cotizaciones y tres se tiran. Contra un proveedor que cobra por request,
 *     eso es plata.
 *  2. **Descarta las respuestas viejas.** Se escribe 5176, se borra, se escribe
 *     1425: las dos vuelven, y sin el testigo puede ganar la primera. Una
 *     cotización de otro código postal no es un error visible — es un precio
 *     equivocado, que es peor.
 *  3. **Re-cotiza si cambia la carga.** Doce botellas sueltas son dos cajas y
 *     pesan el doble; un pack más es un bulto más. Si alguien vuelve al pedido,
 *     agrega algo y avanza, el precio de antes ya no es el suyo. */

const ESPERA_MS = 400;

export type Cotizador = (codigoPostal: string, carga: CargaDelPedido) => Promise<ResultadoDeCotizacion>;

export type EstadoDeCotizacion =
  | { readonly fase: 'quieta' }
  | { readonly fase: 'cotizando' }
  | { readonly fase: 'lista'; readonly resultado: ResultadoDeCotizacion };

export function useCotizacion(cotizar: Cotizador, codigoPostal: string, carga: CargaDelPedido): EstadoDeCotizacion {
  const [estado, setEstado] = useState<EstadoDeCotizacion>({ fase: 'quieta' });
  const cp = codigoPostal.trim();

  /* ⚠️ LA CARGA ES UN OBJETO NUEVO EN CADA RENDER, así que no puede ser una
   * dependencia: el efecto se dispararía siempre y cada render pediría otra
   * cotización. Se descompone en dos primitivas —el número de sueltas y los
   * packs unidos por coma— y el efecto arma la carga de vuelta desde ellas: lo
   * que dispara es el CONTENIDO, que es lo que cambia el precio. */
  const sueltas = carga.sueltas;
  const packs = carga.propias.join(',');

  useEffect(() => {
    if (!/^\d{4}$/.test(cp) || (sueltas <= 0 && packs === '')) {
      setEstado({ fase: 'quieta' });
      return;
    }

    let vigente = true;
    setEstado({ fase: 'cotizando' });

    const reloj = setTimeout(() => {
      cotizar(cp, { sueltas, propias: packs === '' ? [] : packs.split(',').map(Number) })
        .then((resultado) => {
          if (vigente) setEstado({ fase: 'lista', resultado });
        })
        .catch(() => {
          if (vigente) setEstado({ fase: 'lista', resultado: { ok: false, motivo: 'proveedor-caido' } });
        });
    }, ESPERA_MS);

    return () => {
      vigente = false;
      clearTimeout(reloj);
    };
  }, [cotizar, cp, sueltas, packs]);

  return estado;
}
