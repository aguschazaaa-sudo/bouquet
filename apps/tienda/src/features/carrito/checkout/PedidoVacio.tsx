import Link from 'next/link';

import { TEXTOS } from './textos';

/* Cero botellas es un pedido VACÍO, no una caja a medio llenar: hasta el
 * 2026-09-15 esta rama decía "el vino viaja de a seis" sobre un carrito sin
 * nada adentro, que es contestar una pregunta que nadie hizo. */
export function PedidoVacio() {
  return (
    <main className="pagina-checkout papel">
      <div className="pagina-checkout__contenedor pagina-checkout__vacio">
        <p className="display">{TEXTOS.pedidoVacio}</p>
        <Link className="enlace-blando" href="/carrito">
          {TEXTOS.volver}
        </Link>
      </div>
    </main>
  );
}
