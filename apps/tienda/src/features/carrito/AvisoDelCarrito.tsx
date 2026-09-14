'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';
import { useSyncExternalStore } from 'react';

import { avisoActual, suscribirAviso } from './aviso';
import { TEXTOS } from './textos';

/* Lo que pasó, dicho en una línea: "Trumpeter Malbec quedó en tu pedido." No
 * es un toast: direccion.md §6 dice "una línea de texto que aparece y se
 * queda", así que no se va sola. La reemplaza el próximo aviso.
 *
 * Sólo en /vinos, que es donde se agrega sin otra señal. En la ficha el
 * control ya lo dice al lado, y en /carrito sobra. */

export function AvisoDelCarrito() {
  const aviso = useSyncExternalStore(suscribirAviso, avisoActual, () => null);
  const ruta = usePathname();
  if (ruta !== '/vinos') return null;

  return (
    <div className={`aviso-carrito${aviso ? ' aviso-carrito--visible' : ''}`} role="status">
      {aviso ? (
        <>
          <span>{aviso.texto}</span>
          <Link className="enlace-blando" href="/carrito">
            {TEXTOS.verElCarrito}
          </Link>
        </>
      ) : null}
    </div>
  );
}
