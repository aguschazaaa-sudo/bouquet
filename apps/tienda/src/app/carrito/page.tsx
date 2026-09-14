import type { Metadata, Viewport } from 'next';

import { PaginaDelCarrito } from '@/features/carrito/PaginaDelCarrito';
import { VentanaDeBotella } from '@/features/catalogo/VentanaDeBotella';
import { obtenerCatalogo } from '@/server/catalogo';
import { COLORES } from '@/shared/tokens/colores';

/* /carrito — el pedido. Papel sin excepción (direccion.md §3).
 *
 * El carrito vive en localStorage (ARQUITECTURA §4.4): el servidor no sabe qué
 * hay adentro. Lo que sí manda es la proyección de hoy, para que el navegador
 * una cada línea con su precio y su balde, y la ventana de cada botella, que es
 * del catálogo y llega como elemento (design.md §9). Es la misma proyección de
 * /vinos: cero lecturas de más.
 *
 * El estado vacío sigue siendo el de voz.md §9.4, literal: "No hay nada acá
 * todavía." y `Ver los vinos`. Ahora lo pinta el navegador. */

export const revalidate = 60;

export const metadata: Metadata = {
  title: 'Tu pedido — bouquet',
  /* `noindex`: un carrito es de una persona, no del buscador. */
  robots: { index: false, follow: true },
};

/* La barra del navegador acompaña al papel. */
export const viewport: Viewport = {
  themeColor: COLORES.papel,
  colorScheme: 'light',
};

export default async function Carrito() {
  const { productos } = await obtenerCatalogo();
  const ventanas = Object.fromEntries(
    productos.map((p) => [p.id, <VentanaDeBotella key={p.id} producto={p} tamano="linea" decorativa />]),
  );

  return <PaginaDelCarrito productos={productos} ventanas={ventanas} />;
}
