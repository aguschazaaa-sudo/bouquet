import type { Metadata } from 'next';

import { PaginaEnObra } from '@/shared/ui/PaginaEnObra';

/* /contacto — el mostrador.
 *
 * ⚠️ NO se inventa acá un mail ni un WhatsApp. voz.md §4.2 dice que del otro
 * lado hay una persona; publicar un canal que no atiende nadie es exactamente
 * la mentira que ese párrafo evita. La página dice que falta, y ya está.
 */

export const metadata: Metadata = {
  title: 'Escribinos — bouquet',
  description: 'Cómo llegar a bouquet.',
};

export default function Contacto() {
  return (
    <PaginaEnObra
      rotulo="El mostrador"
      titulo="Escribinos"
      cuerpo="Todavía no hay dónde. Falta poner el mostrador, y del otro lado va una persona: por eso no lo reemplaza un formulario."
      salida={{ href: '/', texto: 'Volver a la portada' }}
    />
  );
}
