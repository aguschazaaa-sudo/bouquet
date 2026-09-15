'use client';

import Link from 'next/link';
import { useEffect, useMemo, useState, type ReactNode } from 'react';
import { quitar, resolverCarrito, sePuedeCobrar, type ProductoPublicado } from '@bouquet/contratos';

import { carritoActual, guardarCarrito } from './almacen';
import { EstadoDeLaCaja } from './EstadoDeLaCaja';
import { LineaDelCarrito } from './LineaDelCarrito';
import { TEXTOS } from './textos';
import { TotalDelCarrito } from './TotalDelCarrito';
import { useCarrito, useHidratado } from './useCarrito';

/* /carrito: el pedido contra la proyección de hoy. Papel, sin excepción
 * (direccion.md §3).
 *
 * Desde 2026-09-15 SÍ tiene botón de terminar la compra, y lleva a /pedido.
 * `crearOrden` sigue sin existir: lo que hay del otro lado es el checkout
 * armado con el cobro apagado (`EL_CHECKOUT_NO_COBRA`).
 *
 * Si el tope de un vino bajó desde que se agregó, la cantidad se ajusta y se
 * GUARDA: el total nunca se calcula con la cantidad vieja. El aviso de ajuste
 * se recuerda acá, porque después de guardar la línea ya no está "ajustada".
 *
 * En el servidor no hay carrito, así que hasta hidratar se reserva el lugar
 * en vez de mostrar un carrito vacío que no es el de nadie (direccion.md §6:
 * espacio reservado, no skeleton). */

type Props = {
  productos: readonly ProductoPublicado[];
  ventanas: Readonly<Record<string, ReactNode>>;
};

export function PaginaDelCarrito({ productos, ventanas }: Props) {
  const hidratado = useHidratado();
  const carrito = useCarrito();
  const resuelto = useMemo(() => resolverCarrito(carrito, productos), [carrito, productos]);
  const [ajustadas, setAjustadas] = useState<ReadonlySet<string>>(() => new Set());

  useEffect(() => {
    if (!resuelto.ajustado) return;
    const ids = resuelto.lineas.filter((l) => l.ajustada).map((l) => l.productoId);
    setAjustadas((previas) => new Set([...previas, ...ids]));
    guardarCarrito(resuelto.carrito);
  }, [resuelto]);

  let cuerpo: ReactNode = <div className="pagina-carrito__reservado" />;
  if (hidratado && resuelto.lineas.length === 0) {
    cuerpo = (
      <div className="pagina-carrito__vacio">
        <p className="display">{TEXTOS.vacio}</p>
        <Link className="enlace-blando" href="/vinos">
          {TEXTOS.verLosVinos}
        </Link>
      </div>
    );
  } else if (hidratado) {
    cuerpo = (
      <>
        <ul className="pagina-carrito__lineas">
          {resuelto.lineas.map((l) => (
            <LineaDelCarrito
              key={l.productoId}
              linea={l}
              ajustada={ajustadas.has(l.productoId)}
              ventana={ventanas[l.productoId]}
              alQuitar={() => guardarCarrito(quitar(carritoActual(), l.productoId))}
            />
          ))}
        </ul>
        <EstadoDeLaCaja resuelto={resuelto} />
        <TotalDelCarrito resuelto={resuelto} />
        {/* El botón aparece SÓLO con la caja cerrada, y la frase de arriba ya
         * dice qué falta: un botón apagado obliga a explicar dos veces lo
         * mismo, y uno encendido que rebota en /pedido es peor. La misma
         * precondición la repite el checkout sobre su propia proyección, y la
         * va a repetir `crearOrden`: un número de botellas que manda el
         * navegador no se cree. */}
        {sePuedeCobrar(resuelto) ? (
          <p className="pagina-carrito__terminar">
            <Link className="boton" href="/pedido">
              <span>{TEXTOS.terminar}</span>
            </Link>
          </p>
        ) : null}
        <p className="pagina-carrito__seguir">
          <Link className="enlace-blando" href="/vinos">
            {TEXTOS.seguir}
          </Link>
        </p>
      </>
    );
  }

  return (
    <main className="pagina-carrito papel">
      <div className="pagina-carrito__contenedor">
        <h1 className="display">{TEXTOS.titulo}</h1>
        {cuerpo}
      </div>
    </main>
  );
}
