'use client';

import { llenarConLaCaja, type CajaSugeridaResuelta } from '@bouquet/contratos';

import { carritoActual, guardarCarrito } from './almacen';
import { avisar } from './aviso';
import { TEXTOS } from './textos';

/* Llenar el carrito con una caja que armó el vendedor.
 *
 * AGREGA, no reemplaza: si ya había algo, se suma. Borrar lo que el comprador
 * venía eligiendo para meter una sugerencia sería decidir por él, y el carrito
 * ya sabe decir que sobran dos.
 *
 * Los lugares caídos se saltean —no hay qué agregar— y el `tope` de cada vino
 * se respeta, así que la caja puede quedar incompleta. La pantalla lo dice: el
 * estado del pedido sale de `resolverCarrito`, no de este botón. */

type Props = {
  caja: CajaSugeridaResuelta;
};

export function ControlDeCaja({ caja }: Props) {
  const llenar = () => {
    guardarCarrito(llenarConLaCaja(carritoActual(), caja));
    avisar(TEXTOS.quedoEnTuPedido(caja.nombre));
  };

  const hayAlgo = caja.lugares.some((l) => l.estado === 'vigente');
  if (!hayAlgo) return null;

  return (
    <button type="button" className="boton" onClick={llenar}>
      <span>{TEXTOS.agregarLaCaja}</span>
    </button>
  );
}
