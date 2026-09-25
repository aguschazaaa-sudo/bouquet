/**
 * Mover una Orden por el eje de entrega despues de que nacio: prepararla,
 * despacharla, registrar una entrega que fallo y cancelarla.  EP-07, ADR 019.
 *
 * Dos caminos, y la diferencia es de plata:
 *
 *  · Todo lo que NO toca el stock lo escribe el panel directo, y las reglas lo
 *    validan contra el documento de ahora (`resource.data`), sin una lectura
 *    extra: preparar, despachar, entregar y la entrega fallida.
 *  · Cancelar DEVUELVE el stock, y eso lo hace solo el servidor
 *    (`cancelarOrden`), en la misma transaccion que el cambio de estado.  Por eso
 *    `cancelada` esta en `SOLO_LO_ESCRIBE_EL_SERVIDOR`: si las reglas la dejaran
 *    escribir desde un cliente, un panel con un error cancelaria sin reponer, y
 *    el vino quedaria vendido para siempre.
 *
 * Este archivo es lo que los tres lados tienen que entender igual: la callable,
 * el panel (que lo espeja contra el JSON generado) y la suite de reglas (que lee
 * el MISMO JSON para saber que esperar).  Las reglas no pueden importar nada, asi
 * que tienen su propia copia de estas listas; la suite es lo que impide que esa
 * copia se desincronice.
 */

import { TRANSICIONES_ENTREGA, type EstadoEntrega, type EstadoPago, type Origen } from './orden.ts';
import type { Validacion } from './producto.ts';

// ----------------------------------------------------------------- despachar

/**
 * Por donde salio.  Se elige con un toque (poca burocracia, overview del panel).
 *
 * `en_mano` es *"lo llevamos nosotros"*: con el reparto propio apagado para la
 * vidriera (`REPARTIMOS_NOSOTROS = false`), un pedido de WhatsApp de la zona lo
 * puede llevar la familia.  `otro` existe para que ningun envio real quede sin
 * opcion y nadie elija uno falso; el nombre va en el seguimiento.
 * **Decision mia** (ADR 019 §4): el dueno la puede cambiar.
 */
export const CORREOS = ['andreani', 'correo_argentino', 'oca', 'en_mano', 'otro'] as const;

/**
 * El numero de seguimiento es OPCIONAL: una entrega en mano no tiene, y una
 * etiqueta se puede imprimir despues.  Cuando esta, de 1 a este largo: los
 * codigos de los correos argentinos rondan los 20 caracteres.
 */
export const LARGO_DEL_SEGUIMIENTO = 60;

/**
 * Un pedido de la VIDRIERA impago no se despacha: si Mercado Pago no aprobo, no
 * hay venta.  Uno de WHATSAPP se despacha sin mirar el pago, porque su cobro va
 * por fuera y el panel no lo sigue (EP-07, respuestas 5 y 9 del dueno).
 *
 * Las reglas lo repiten sobre `resource.data` con cero lecturas.
 */
export function sePuedeDespachar(origen: Origen, estadoPago: EstadoPago): boolean {
  return origen === 'whatsapp' || estadoPago === 'pagada';
}

// ------------------------------------------------------ la entrega que fallo

/**
 * Por que no se pudo entregar.  **`sin_mayor` es un caso operativo real, no un
 * adorno**: `entregada` significa que firmo un mayor de 18 (ARQUITECTURA §9.5),
 * asi que un paquete que llega a una casa con un menor solo no se entrega.
 */
export const MOTIVOS_DE_FALLA = ['sin_mayor', 'nadie', 'direccion', 'rechazo', 'otro'] as const;

// ------------------------------------------------------------------ cancelar

/** Lo que las reglas NUNCA dejan escribir desde un cliente en `estadoEntrega`. */
export const SOLO_LO_ESCRIBE_EL_SERVIDOR: readonly EstadoEntrega[] = ['cancelada'];

/**
 * Las transiciones que el panel escribe directo: las de la tabla, menos las que
 * son del servidor.  Reescribir el mismo estado NO es una transicion aca: el
 * panel lo hace al anotar, y eso no cambia nada del despacho.
 */
export function laEscribeElPanel(antes: EstadoEntrega, despues: EstadoEntrega): boolean {
  return (
    antes !== despues &&
    !SOLO_LO_ESCRIBE_EL_SERVIDOR.includes(despues) &&
    TRANSICIONES_ENTREGA[antes].includes(despues)
  );
}

export const MOTIVOS_DE_CANCELACION = ['mal_cargado', 'cliente', 'falta_vino', 'otro'] as const;
type MotivoDeCancelacion = (typeof MOTIVOS_DE_CANCELACION)[number];

/**
 * Por que una linea de una Orden cancelada NO volvio al stock.  Cancelar nunca
 * se traba por una linea: un pedido mal cargado que no se puede sacar cuesta
 * vino (ADR 018 §10).  Lo que no se puede devolver se dice, con su motivo, y lo
 * resuelve una persona.
 *
 *  · `no_existe`: el vino se borro.  No hay donde devolverlo.
 *  · `otra_presentacion`: el vino de hoy no viene en las botellas del snapshot
 *    -se borro y se volvio a crear con el mismo slug-.  Devolver 1 caja de 6
 *    como 1 botella suelta es el hallazgo 1 de ADR 008: 12 a la venta sobre 10
 *    fisicas.
 *  · `compuesto` / `producto_roto`: no tiene un stock propio sano donde sumar.
 */
export const MOTIVOS_SIN_REPONER = ['no_existe', 'otra_presentacion', 'compuesto', 'producto_roto'] as const;
export type MotivoSinReponer = (typeof MOTIVOS_SIN_REPONER)[number];

export interface LineaSinReponer {
  readonly productoId: string;
  readonly nombre: string;
  readonly cantidad: number;
  readonly motivo: MotivoSinReponer;
}

/** Lo que recibe `cancelarOrden`. */
export interface PedidoDeCancelacion {
  readonly ordenId: string;
  readonly motivo: MotivoDeCancelacion;
}

/** El mismo rango que `idPedido`: el `ordenId` ES el `idPedido` (ADR 018 §4). */
const ID_DE_ORDEN = /^[A-Za-z0-9_-]{16,64}$/;
const RESERVADO = /^__.*__$/;

function esObjeto(x: unknown): x is Record<string, unknown> {
  return typeof x === 'object' && x !== null && !Array.isArray(x);
}

/** RECHAZA lo que no cumple; no lo corrige.  Mismo trato que los otros parsers. */
export function parsearPedidoDeCancelacion(entrada: unknown): Validacion<PedidoDeCancelacion> {
  if (!esObjeto(entrada) || !Object.keys(entrada).every((k) => k === 'ordenId' || k === 'motivo')) {
    return { ok: false, motivo: 'el pedido no tiene la forma {ordenId, motivo}' };
  }
  if (typeof entrada.ordenId !== 'string' || !ID_DE_ORDEN.test(entrada.ordenId) || RESERVADO.test(entrada.ordenId)) {
    return { ok: false, motivo: 'ordenId invalido' };
  }
  if (typeof entrada.motivo !== 'string' || !(MOTIVOS_DE_CANCELACION as readonly string[]).includes(entrada.motivo)) {
    return { ok: false, motivo: `el motivo es uno de: ${MOTIVOS_DE_CANCELACION.join(', ')}` };
  }
  return { ok: true, valor: { ordenId: entrada.ordenId, motivo: entrada.motivo as MotivoDeCancelacion } };
}
