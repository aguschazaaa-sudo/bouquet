'use client';

import { botellasGuardadas, contarCaja } from '@bouquet/contratos';

import { TEXTOS } from './textos';
import { useCarrito } from './useCarrito';

/* El avance de la caja en la barra: se lee de localStorage y vive en TODAS las
 * rutas, así que no lee Firestore (ADR 006, presupuesto: 0 lecturas). Llega a
 * la barra como slot desde `app/layout.tsx`: navegacion/ no sabe que existe un
 * carrito.
 *
 * Cuenta BOTELLAS, no unidades, y por eso la línea guarda `botellas`: con un
 * pack de 2 en el pedido, contar unidades diría 3 donde hay 6 y alguien
 * seguiría comprando una caja que ya está cerrada.
 *
 * ⚠️ Lo guardado no distingue lo agotado: para eso hace falta la proyección, y
 * traerla acá costaría una lectura en cada ruta. `/carrito` es la fuente de
 * verdad y ahí el número se recalcula. */

export function ContadorDelCarrito() {
  const botellas = botellasGuardadas(useCarrito());
  if (botellas === 0) return null;

  const { faltan, cajasCompletas } = contarCaja(botellas);
  const meta = botellas + faltan;

  return (
    <span className={`contador-carrito${faltan === 0 ? ' contador-carrito--completa' : ''}`}>
      <span className="cifra">{faltan === 0 ? botellas : TEXTOS.avance(botellas, meta)}</span>
      <span className="sr">
        {' '}
        {TEXTOS.avanceLargo(botellas, meta)}.{' '}
        {faltan === 0
          ? cajasCompletas === 1
            ? TEXTOS.cajaCompleta
            : TEXTOS.cajasCompletas(cajasCompletas)
          : TEXTOS.faltan(faltan)}
      </span>
    </span>
  );
}
