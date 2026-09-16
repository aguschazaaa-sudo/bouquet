'use client';

import { botellasGuardadas, botellasSueltasGuardadas, contarCaja } from '@bouquet/contratos';

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
 * ⚠️ MIENTRAS FALTEN, el número es el de las botellas SUELTAS, no el del
 * pedido entero: son las únicas que se pueden completar (ADR 009 §10). Con 4
 * sueltas y un pack de 2 dice `4 de 6` habiendo seis botellas adentro, y es a
 * propósito —el 6 que importa es el de la caja que falta cerrar—. Cuando no
 * falta ninguna se muestra el total, que ahí sí es todo lo que viaja.
 *
 * ⚠️ Lo guardado no distingue lo agotado: para eso hace falta la proyección, y
 * traerla acá costaría una lectura en cada ruta. `/carrito` es la fuente de
 * verdad y ahí el número se recalcula. */

export function ContadorDelCarrito() {
  const carrito = useCarrito();
  const botellas = botellasGuardadas(carrito);
  if (botellas === 0) return null;

  const sueltas = botellasSueltasGuardadas(carrito);
  const { faltan, cajasCompletas } = contarCaja(sueltas);
  const meta = sueltas + faltan;
  /* Hay algo que viaja solo si lo guardado no es todo suelto. Es lo único que
   * el contador puede saber sin leer Firestore, y alcanza para elegir palabra. */
  const hayPropias = sueltas !== botellas;

  /* Sin caja empezada —un pedido de sólo cajas cerradas— no hay nada que
   * completar, así que no se anuncia una caja: se dice que ya puede viajar. */
  const cerrado =
    sueltas === 0
      ? TEXTOS.listoParaViajar
      : cajasCompletas === 1
        ? TEXTOS.cajaCompleta
        : TEXTOS.cajasCompletas(cajasCompletas);

  return (
    <span className={`contador-carrito${faltan === 0 ? ' contador-carrito--completa' : ''}`}>
      <span className="cifra">{faltan === 0 ? botellas : TEXTOS.avance(sueltas, meta)}</span>
      <span className="sr">
        {' '}
        {faltan === 0 ? (
          <>
            {TEXTOS.botellasEnTuPedido(botellas)}. {cerrado}
          </>
        ) : (
          <>
            {TEXTOS.avanceLargo(sueltas, meta)}. {TEXTOS.faltan(faltan, hayPropias)}
          </>
        )}
      </span>
    </span>
  );
}
