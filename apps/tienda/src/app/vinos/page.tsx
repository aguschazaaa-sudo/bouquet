import type { Metadata } from 'next';

import { ControlDeCaja } from '@/features/carrito/ControlDeCaja';
import { ControlDeCompra } from '@/features/carrito/ControlDeCompra';
import { CarrilDeCajas } from '@/features/catalogo/CarrilDeCajas';
import { ListadoDeVinos } from '@/features/catalogo/ListadoDeVinos';
import { ReglaDeLaCaja } from '@/features/catalogo/ReglaDeLaCaja';
import { TEXTOS } from '@/features/catalogo/textos';
import { obtenerVidriera } from '@/server/catalogo';

/* /vinos — el catálogo. ADR 008, design.md §9.
 *
 * ISR de 60 s: Next arma solo `s-maxage=60, stale-while-revalidate=300` con el
 * `expireTime` de next.config.ts, y el `Cache-Tag` sale de ahí también. El
 * literal tiene que estar ACÁ: Next lee la configuración de la ruta sin
 * ejecutar el módulo, así que no puede importar `SEGUNDOS_DE_CATALOGO`.
 *
 * `app/` compone: arma el control de compra de cada vino (de `carrito/`) y se
 * lo pasa al listado (de `catalogo/`) como elemento. Ninguna de las dos
 * features sabe de la otra (ADR 006).
 *
 * `data-catalogo-de-muestra` es un gate de deploy: sale en el HTML si hay
 * datos de muestra, así `auditor-produccion` lo ve con curl. Va con spread
 * condicional y no con `? '' : undefined`, que sale del DOM pero se queda en
 * el payload RSC (lo midió la sección El oficio). */

export const revalidate = 60;

export const metadata: Metadata = {
  title: 'Los vinos — bouquet',
  description: 'Tintos, blancos y rosados argentinos, por cepa o corte, con el precio a la vista.',
};

export default async function Vinos() {
  const { catalogo, cajas } = await obtenerVidriera();
  const { productos, hayPopularidad, deMuestra } = catalogo;
  const controles = Object.fromEntries(
    productos.map((p) => [
      p.id,
      <ControlDeCompra key={p.id} productoId={p.id} nombre={p.nombre} tope={p.tope} botellas={p.botellas} />,
    ]),
  );
  const controlesDeCaja = Object.fromEntries(cajas.map((c) => [c.slug, <ControlDeCaja key={c.slug} caja={c} />]));

  return (
    <main className="pagina-vinos contenedor-vinos" {...(deMuestra ? { 'data-catalogo-de-muestra': '' } : {})}>
      <header className="cabecera-vinos">
        <h1 className="display">{TEXTOS.titulo}</h1>
        <p>{TEXTOS.bajada}</p>
        <ReglaDeLaCaja />
      </header>
      <CarrilDeCajas cajas={cajas} controles={controlesDeCaja} />
      <ListadoDeVinos productos={productos} hayPopularidad={hayPopularidad} controles={controles} />
    </main>
  );
}
