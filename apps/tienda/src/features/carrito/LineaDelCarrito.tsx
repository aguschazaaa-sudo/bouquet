import Link from 'next/link';
import type { ReactNode } from 'react';
import { textoDelBalde, type LineaResuelta } from '@bouquet/contratos';

import { Precio } from '@/shared/ui/Precio';

import { ControlDeCompra } from './ControlDeCompra';
import { TEXTOS } from './textos';

/* Una línea del pedido. Una línea agotada o de un vino que ya no está queda
 * marcada, NO suma al total y se puede quitar (specs/vidriera-carrito). La
 * foto llega armada desde `app/`, porque la ventana de la botella es del
 * catálogo. */

type Props = {
  linea: LineaResuelta;
  ajustada: boolean;
  ventana?: ReactNode;
  alQuitar: () => void;
};

export function LineaDelCarrito({ linea, ajustada, ventana, alQuitar }: Props) {
  const p = linea.producto;
  const estado = p ? textoDelBalde(p.balde) : null;

  return (
    <li className={`linea-carrito linea-carrito--${linea.estado}`}>
      <div className="linea-carrito__ventana">{ventana}</div>
      <div className="linea-carrito__info">
        <h2 className="linea-carrito__nombre display">
          {p ? <Link href={`/vinos/${p.slug}`}>{p.nombre}</Link> : TEXTOS.yaNoEsta}
        </h2>
        {p ? (
          <p className="linea-carrito__datos versalita">
            {p.bodega} · {p.botellas > 1 ? TEXTOS.laCaja(p.botellas) : TEXTOS.laBotella}
          </p>
        ) : null}
        {estado ? <p className="linea-carrito__estado versalita">{estado}</p> : null}
        {/* Sólo en la línea del vino que trae su caja, y sólo acá: es donde el
            comprador ve que sus botellas no aparecen en el `4 de 6` de arriba.
            Decirlo una vez por línea es local; decirlo en la cabecera sería
            repetirlo para vinos a los que no les toca. */}
        {p && p.botellas > 1 ? <p className="linea-carrito__viaja">{TEXTOS.viajaSola}</p> : null}
        <button type="button" className="linea-carrito__quitar versalita" onClick={alQuitar}>
          {TEXTOS.quitar}
        </button>
      </div>
      <div className="linea-carrito__accion">
        {linea.estado === 'vigente' && p ? (
          <>
            <ControlDeCompra productoId={p.id} nombre={p.nombre} tope={p.tope} botellas={p.botellas} variante="linea" />
            <Precio centavos={linea.subtotal} className="linea-carrito__subtotal" />
          </>
        ) : (
          <span className="linea-carrito__no-suma">{TEXTOS.noSuma}</span>
        )}
      </div>
      {ajustada ? <p className="linea-carrito__aviso">{TEXTOS.ajustada}</p> : null}
    </li>
  );
}
