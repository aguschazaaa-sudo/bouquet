/**
 * El nucleo PURO de `cancelarOrden`: dado lo que la Orden guardo y lo que la
 * transaccion acaba de leer de cada vino, dice cuanto vuelve al stock y que NO
 * puede volver.  HU-07.6, ADR 019 §5.
 *
 * Sin Firestore adentro, igual que `armar.ts`: todo lo que decide que se repone
 * se prueba con `node --test` y sin emulador.  El emulador queda para la
 * atomicidad y la concurrencia (`cancelar.ts`).
 *
 * ⚠️ SE REPONE CON EL SNAPSHOT, NUNCA CON EL VINO DE HOY (hallazgo 1 de ADR 008).
 * `items[].cantidad` son unidades de venta, y la unidad de venta la fija
 * `items[].botellas` AL MOMENTO DE VENDER.  Si el vino se borro y se volvio a
 * crear con el mismo slug en otra presentacion, devolver "1" suma una botella
 * suelta donde salio una caja de seis: 12 a la venta sobre 10 fisicas.  Esa
 * linea no se repone y se dice.
 *
 * Y cancelar NUNCA se traba por una linea: un pedido mal cargado que no se puede
 * sacar de la bandeja cuesta vino (ADR 018 §10).  Lo que no se puede devolver
 * viaja en `sinReponer`, con su motivo, y lo resuelve una persona.
 */
import type { LineaSinReponer } from '@bouquet/contratos';

import type { CambioDeStock } from './armar.ts';

/** Lo que la cancelacion necesita de cada linea de la Orden. */
export interface ItemAReponer {
  readonly productoId: string;
  readonly nombre: string;
  readonly cantidad: number;
  readonly botellas: number;
}

const esEnteroPositivo = (x: unknown): x is number => typeof x === 'number' && Number.isInteger(x) && x >= 1;

/**
 * Las lineas de la Orden, o `null` si `items` no se puede leer.  Una Orden asi no
 * la escribio `crearOrdenDelPanel` (el Admin SDK no pasa por las reglas, asi que
 * PUEDE existir) y no se adivina que se vendio: se rechaza la cancelacion.
 */
export function leerItems(crudo: unknown): ItemAReponer[] | null {
  if (!Array.isArray(crudo) || crudo.length < 1) return null;
  const items: ItemAReponer[] = [];
  for (const x of crudo) {
    if (typeof x !== 'object' || x === null) return null;
    const { productoId, nombre, cantidad, botellas } = x as Record<string, unknown>;
    if (typeof productoId !== 'string' || productoId.length < 1) return null;
    if (!esEnteroPositivo(cantidad) || !esEnteroPositivo(botellas)) return null;
    items.push({ productoId, nombre: typeof nombre === 'string' ? nombre : productoId, cantidad, botellas });
  }
  return items;
}

export interface Reposicion {
  /** Uno por vino, aunque la Orden lo tenga en dos lineas: un solo `update` y un solo movimiento. */
  readonly stock: readonly CambioDeStock[];
  readonly sinReponer: readonly LineaSinReponer[];
}

/**
 * @param leidos  `productoId` -> los datos crudos del documento, o `undefined` si
 *                no existe.  Lo que devolvio `tx.getAll`, sin tocar.
 *
 * Mira lo MISMO que `moverStock` antes de escribir `stock` -que sea `simple` y
 * que el stock sea un entero sano- y ademas la presentacion.  NO corre
 * `validarProducto` entero: un vino al que le falta un campo que nada tiene que
 * ver con el stock (una descripcion, un varietal nuevo) no puede impedir que
 * vuelvan sus botellas.
 *
 * **No aplica `TOPE_DE_STOCK`.**  El tope es una baranda contra el dedo gordo al
 * TIPEAR una reposicion; aca no se tipea nada, vuelve lo que salio.  Pasarlo solo
 * es posible si alguien repuso cerca del tope entre la venta y la cancelacion, y
 * un `corregir` lo baja (su `visto` no tiene tope).  Recortar perderia botellas
 * en silencio.
 */
export function armarReposicion(
  items: readonly ItemAReponer[],
  leidos: ReadonlyMap<string, unknown>,
): Reposicion {
  const sinReponer: LineaSinReponer[] = [];
  const porVino = new Map<string, { antes: number; despues: number }>();

  for (const item of items) {
    const no = (motivo: LineaSinReponer['motivo']): void => {
      sinReponer.push({ productoId: item.productoId, nombre: item.nombre, cantidad: item.cantidad, motivo });
    };

    const crudo = leidos.get(item.productoId);
    if (crudo === undefined || crudo === null || typeof crudo !== 'object') {
      no('no_existe');
      continue;
    }
    const p = crudo as { tipo?: unknown; stock?: unknown; presentacion?: { botellas?: unknown } };
    if (p.tipo !== 'simple') {
      no(p.tipo === 'compuesto' ? 'compuesto' : 'producto_roto');
      continue;
    }
    if (typeof p.stock !== 'number' || !Number.isInteger(p.stock) || p.stock < 0) {
      no('producto_roto');
      continue;
    }
    if (p.presentacion?.botellas !== item.botellas) {
      no('otra_presentacion');
      continue;
    }

    // Una segunda linea del mismo vino suma sobre lo que ya devolvio la primera,
    // no sobre el stock leido: si no, la segunda pisaria a la primera.
    const previo = porVino.get(item.productoId);
    const antes = previo?.antes ?? p.stock;
    const base = previo?.despues ?? p.stock;
    porVino.set(item.productoId, { antes, despues: base + item.cantidad });
  }

  return {
    stock: [...porVino].map(([productoId, { antes, despues }]) => ({ productoId, antes, despues })),
    sinReponer,
  };
}
