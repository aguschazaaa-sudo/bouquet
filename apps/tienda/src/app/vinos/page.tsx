import type { Metadata } from 'next';

import { PaginaEnObra } from '@/shared/ui/PaginaEnObra';

/* /vinos — el catálogo.
 *
 * Es la ruta que la home apunta DOS veces: los CTA duros de EscenaSeleccion y
 * de EscenaMesa. Hasta este commit las dos tiraban 404, que es el defecto que
 * el vault llama "terminada y sin puerta".
 *
 * ⚠️ Vacía a propósito. El catálogo es el paso 5 de ARQUITECTURA §12 y
 * necesita `scripts/seed` antes: los seis vinos de la portada son INVENTADOS
 * mientras `LA_SELECCION_ES_DE_MUESTRA` siga en true, y una página de catálogo
 * con datos falsos es peor que una que dice que todavía no está.
 */

export const metadata: Metadata = {
  title: 'Los vinos — bouquet',
  description: 'La selección de bouquet.',
};

export default function Vinos() {
  return (
    <PaginaEnObra
      rotulo="La selección"
      titulo="Todavía no"
      cuerpo="Estamos eligiendo qué entra y qué no, que es la parte lenta. Cuando la selección esté cerrada, va a estar acá."
      salida={{ href: '/', texto: 'Volver a la portada' }}
    />
  );
}
