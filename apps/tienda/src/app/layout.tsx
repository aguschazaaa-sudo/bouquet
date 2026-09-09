import type { Metadata, Viewport } from 'next';
import type { ReactNode } from 'react';
import { Fraunces, Newsreader } from 'next/font/google';
import { BarraPrincipal } from '@/features/navegacion/BarraPrincipal';
import { COLORES } from '@/shared/tokens/colores';
import './globals.css';

/* Las dos familias. direccion.md §4.
 *
 * Display: Fraunces. Old-style con esqueleto sólido y ejes SOFT y WONK que le
 * dan carácter real, no "elegancia genérica". El logotipo ya votó: sus serifas
 * son corchetadas y con peso, así que un didone —Playfair, Prata, Bodoni— se
 * ve como otra marca al lado del wordmark, y encima se desintegra sobre fondo
 * oscuro, donde el texto claro adelgaza ópticamente.
 * ⚠️ Bodoni Moda sigue abierta como alternativa; la decide el dueño.
 *
 * Texto: Newsreader. Dibujada para leer en pantalla, altura de x grande,
 * itálica con personalidad propia.
 *
 * NO entra una tercera familia. El presupuesto de §4.5 reserva una grotesca de
 * cifras tabulares para donde haya un número que no se pueda leer mal, y en
 * esta página no hay ninguno: no hay precio, ni stock, ni número de Orden.
 *
 * next/font las descarga en BUILD y las sirve desde el propio dominio, con el
 * fallback de métricas ajustadas. En runtime no queda ni un pedido a
 * fonts.googleapis.com, que es lo que exigen direccion.md §4.5 y parallax.md
 * §6.3 — un swap de fuente en el titular del héroe es lo más barato que puede
 * parecer un sitio caro.
 */

const fraunces = Fraunces({
  subsets: ['latin'],
  axes: ['SOFT', 'WONK', 'opsz'],
  display: 'swap',
  variable: '--fuente-fraunces',
});

const newsreader = Newsreader({
  subsets: ['latin'],
  style: ['normal', 'italic'],
  axes: ['opsz'],
  display: 'swap',
  variable: '--fuente-newsreader',
});

export const metadata: Metadata = {
  title: 'bouquet — el vino intacto',
  description:
    'Un vino puede estar bien hecho y llegar mal. Nos ocupamos del tramo entre la bodega y tu mesa: acostado, a temperatura pareja, sin luz.',
};

/* El color de la barra del navegador acompaña al modo cava. No hay toggle de
 * tema: el modo lo fija la página, no el usuario (direccion.md §3.2). */
export const viewport: Viewport = {
  themeColor: COLORES.tinta,
  colorScheme: 'dark',
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="es-AR" className={`${fraunces.variable} ${newsreader.variable}`}>
      <body>
        {/* La barra va en el layout y no en cada página: es la misma pieza en
            todas las rutas, y duplicarla sería la forma más rápida de que una
            sección quede sin navegación. Se pinta ANTES del contenido para que
            el orden del DOM coincida con el orden de lectura — un usuario de
            teclado llega a la navegación primero, que es donde la espera. */}
        <BarraPrincipal />
        {children}
      </body>
    </html>
  );
}
