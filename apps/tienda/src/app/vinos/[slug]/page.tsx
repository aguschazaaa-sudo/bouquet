import type { Metadata } from 'next';
import { notFound } from 'next/navigation';

import { ControlDeCompra } from '@/features/carrito/ControlDeCompra';
import { FichaDeVino } from '@/features/catalogo/FichaDeVino';
import { describirUvas } from '@/features/catalogo/textos';
import { obtenerCatalogo } from '@/server/catalogo';

/* /vinos/[slug] — la ficha. Sale de la MISMA proyección que /vinos, sin una
 * lectura más (specs/vidriera-ficha).
 *
 * No se pregenera ninguna en el build: cada ficha se arma en el primer pedido
 * y queda 60 s (ISR). Un slug que no está en la proyección —inventado, o de un
 * vino despublicado— es 404, nunca una ficha vacía. */

export const revalidate = 60;
export const dynamicParams = true;

export function generateStaticParams() {
  return [];
}

type Props = {
  params: Promise<{ slug: string }>;
};

async function buscar(slug: string) {
  const { productos } = await obtenerCatalogo();
  return productos.find((p) => p.slug === slug) ?? null;
}

export async function generateMetadata({ params }: Props): Promise<Metadata> {
  const producto = await buscar((await params).slug);
  if (!producto) return {};
  return {
    title: `${producto.nombre} — bouquet`,
    description: `${describirUvas(producto)} de ${producto.bodega}. ${producto.region}.`,
  };
}

export default async function Ficha({ params }: Props) {
  const producto = await buscar((await params).slug);
  if (!producto) notFound();

  return (
    <main>
      <FichaDeVino
        producto={producto}
        control={
          <ControlDeCompra
            productoId={producto.id}
            nombre={producto.nombre}
            tope={producto.tope}
            botellas={producto.botellas}
            variante="ficha"
          />
        }
      />
    </main>
  );
}
