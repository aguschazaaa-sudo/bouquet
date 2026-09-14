import type { Metadata, Viewport } from 'next';
import type { ReactNode } from 'react';
import { Archivo, Fraunces, Newsreader } from 'next/font/google';
import { AvisoDelCarrito } from '@/features/carrito/AvisoDelCarrito';
import { ContadorDelCarrito } from '@/features/carrito/ContadorDelCarrito';
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
 * Cifras: Archivo (Omnibus-Type, Buenos Aires). El presupuesto de §4.5
 * reservaba una grotesca de cifras tabulares para donde hubiera un número que
 * no se pudiera leer mal, y la landing no tenía ninguno. El catálogo sí:
 * precio, cantidad y total (tokens.md §5, ADR 008). Va sólo en números.
 *
 * ⚠️ La maqueta mostrador traía Libre Franklin, y el archivo que sirve Google
 * NO tiene cifras tabulares: medido a 40 px, "1111" y "8888" dan 74,41 y
 * 106,89 px con tabular-nums, igual que sin. Archivo da 90,89 y 90,89. Una
 * columna de precios con cifras proporcionales baila.
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

const archivo = Archivo({
  subsets: ['latin'],
  display: 'swap',
  variable: '--fuente-archivo',
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
    <html lang="es-AR" className={`${fraunces.variable} ${newsreader.variable} ${archivo.variable}`}>
      <body>
        {/* La barra va en el layout y no en cada página: es la misma pieza en
            todas las rutas, y duplicarla sería la forma más rápida de que una
            sección quede sin navegación. Se pinta ANTES del contenido para que
            el orden del DOM coincida con el orden de lectura — un usuario de
            teclado llega a la navegación primero, que es donde la espera. */}
        {/* El contador llega a la barra como slot: navegacion/ no sabe que
            existe un carrito, y el layout es el único que compone las dos
            features (ADR 006, design.md §3). */}
        <BarraPrincipal contador={<ContadorDelCarrito />} />
        {children}
        <AvisoDelCarrito />
      </body>
    </html>
  );
}
