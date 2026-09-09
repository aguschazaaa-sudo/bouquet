import type { Metadata } from 'next';

import { PaginaEnObra } from '@/shared/ui/PaginaEnObra';

/* /custodia — el porqué físico de cómo se guarda.
 *
 * Es lo único que bouquet hace con sus manos, y hoy vive entero adentro de la
 * tercera escena de la home. Esta sección existe para que ese argumento tenga
 * una URL propia: es lo que alguien manda por WhatsApp cuando le preguntan
 * "¿y por qué a ellos y no al supermercado?".
 */

export const metadata: Metadata = {
  title: 'La custodia — bouquet',
  description:
    'Acostada, a temperatura pareja y sin luz. Cómo bouquet guarda el vino entre la bodega y tu mesa.',
};

export default function Custodia() {
  return (
    <PaginaEnObra
      rotulo="Cómo se guarda"
      titulo="Acostada, a temperatura pareja, sin luz"
      cuerpo="Las tres cosas están dichas en la portada. El porqué de cada una —que es la parte que importa— va acá, y todavía la estamos escribiendo."
      salida={{ href: '/', texto: 'Volver a la portada' }}
    />
  );
}
