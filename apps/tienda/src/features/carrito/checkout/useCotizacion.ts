'use client';

import { useEffect, useState } from 'react';
import type { ResultadoDeCotizacion } from '@bouquet/contratos';

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
 *  3. **Re-cotiza si cambian las botellas.** Doce botellas son dos cajas y
 *     pesan el doble. Si alguien vuelve al pedido, agrega una caja y avanza, el
 *     precio de antes ya no es el suyo. */

const ESPERA_MS = 400;

export type Cotizador = (codigoPostal: string, botellas: number) => Promise<ResultadoDeCotizacion>;

export type EstadoDeCotizacion =
  | { readonly fase: 'quieta' }
  | { readonly fase: 'cotizando' }
  | { readonly fase: 'lista'; readonly resultado: ResultadoDeCotizacion };

export function useCotizacion(cotizar: Cotizador, codigoPostal: string, botellas: number): EstadoDeCotizacion {
  const [estado, setEstado] = useState<EstadoDeCotizacion>({ fase: 'quieta' });
  const cp = codigoPostal.trim();

  useEffect(() => {
    if (!/^\d{4}$/.test(cp) || botellas <= 0) {
      setEstado({ fase: 'quieta' });
      return;
    }

    let vigente = true;
    setEstado({ fase: 'cotizando' });

    const reloj = setTimeout(() => {
      cotizar(cp, botellas)
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
  }, [cotizar, cp, botellas]);

  return estado;
}
