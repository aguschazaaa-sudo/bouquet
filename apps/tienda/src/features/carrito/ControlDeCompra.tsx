'use client';

import Link from 'next/link';
import { agregar, fijarCantidad, quitar } from '@bouquet/contratos';

import { carritoActual, guardarCarrito } from './almacen';
import { avisar } from './aviso';
import { TEXTOS } from './textos';
import { useCarrito } from './useCarrito';

/* Comprar a un toque: `Agregar` y, después del primer toque, el selector de
 * cantidad (design.md §9). El `+` se traba en el tope y no dice el número: el
 * tope por debajo de 12 ES el stock, y la pantalla nunca lo afirma (ADR 008).
 *
 * Lo monta `app/`, no el catálogo: en la tarjeta, en la ficha y en cada línea
 * del carrito. La cantidad sale de contratos (`agregar`, `fijarCantidad`), la
 * misma cuenta que va a repetir `crearOrden`. */

type Props = {
  productoId: string;
  nombre: string;
  tope: number;
  botellas: number;
  variante?: 'tarjeta' | 'ficha' | 'linea';
};

export function ControlDeCompra({ productoId, nombre, tope, botellas, variante = 'tarjeta' }: Props) {
  const carrito = useCarrito();
  if (tope <= 0) return null;

  const guardada = carrito.lineas.find((l) => l.productoId === productoId)?.cantidad ?? 0;
  // Si el tope bajó desde que se agregó, se muestra el tope; el carrito lo
  // ajusta y lo guarda cuando se abre.
  const n = Math.min(guardada, tope);
  const cosa = botellas > 1 ? 'caja' : 'botella';

  const fijar = (cantidad: number) => {
    guardarCarrito(
      cantidad < 1
        ? quitar(carritoActual(), productoId)
        : fijarCantidad(carritoActual(), { productoId, botellas, tope }, cantidad).carrito,
    );
  };
  const agregarUna = () => {
    guardarCarrito(agregar(carritoActual(), { productoId, botellas, tope }, 1).carrito);
    avisar(TEXTOS.quedoEnTuPedido(nombre));
  };

  if (n === 0) {
    const etiqueta =
      variante === 'tarjeta' ? TEXTOS.agregar : botellas > 1 ? TEXTOS.agregarLaCaja : TEXTOS.agregarAlCarrito;
    return (
      <div className={`control-compra control-compra--${variante}`}>
        <button type="button" className="boton control-compra__agregar" onClick={agregarUna}>
          <span>{etiqueta}</span>
        </button>
      </div>
    );
  }

  return (
    <div className={`control-compra control-compra--${variante}`}>
      <div className="control-compra__selector" role="group" aria-label={TEXTOS.cantidadDe(nombre)}>
        <button
          type="button"
          className="control-compra__menos"
          aria-label={n === 1 ? TEXTOS.sacar : TEXTOS.unaMenos(cosa)}
          onClick={() => fijar(n - 1)}
        />
        <output className="cifra" aria-live="polite">
          {n}
        </output>
        <button
          type="button"
          className="control-compra__mas"
          aria-label={TEXTOS.unaMas(cosa)}
          disabled={n >= tope}
          onClick={() => fijar(n + 1)}
        />
      </div>
      {variante === 'ficha' ? (
        <p className="control-compra__nota">
          {n >= tope ? TEXTOS.alTope : TEXTOS.enTuPedido} <Link href="/carrito">{TEXTOS.verElCarrito}</Link>
        </p>
      ) : null}
    </div>
  );
}
