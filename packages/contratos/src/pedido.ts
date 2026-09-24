/**
 * El pedido que carga el panel (HU-10.1) y la Orden que nace de el.  ADR 018.
 *
 * `parsearPedidoDelPanel` es el UNICO lugar que valida ese pedido: lo usa la
 * callable `crearOrdenDelPanel` al recibirlo, y la forma que define es la que
 * el panel arma en Dart.  Igual que `parsearCarrito` y `parsearPedidoDeMovimiento`,
 * RECHAZA lo que no cumple y no lo corrige: una cantidad negativa no es una
 * cantidad a arreglar, es un dato que alguien toco.
 *
 * ⚠️ El pedido NO lleva `origen` ni `estadoPago`, y si los trae se rechaza.  El
 * origen decide una regla de plata -la caja de seis no aplica a WhatsApp-, asi
 * que lo fija el servidor segun QUE callable se llamo.  Si lo declarara quien
 * llama, un comprador de la vidriera se saltearia la regla diciendo
 * `'whatsapp'` (hallazgo 12 del mapa del panel).
 */

import { esProductoId, type LineaDePedido } from './carrito.ts';
import { centavos, type Centavos } from './dinero.ts';
import { validarDatosDeEntrega, type DatosDeEntrega, type DestinoDeEnvio } from './envio.ts';
import type { EstadoEntrega, EstadoPago, Origen } from './orden.ts';
import type { Validacion } from './producto.ts';
import { TOPE_DE_STOCK } from './stock.ts';

/**
 * Cuantas lineas distintas puede tener un pedido.  Decision mia (ADR 018): el
 * hallazgo 5 de `revisor-pagos` pedia un tope, porque diez mil ids inventados
 * validan y cada uno es una lectura.  Treinta vinos distintos en un pedido de
 * WhatsApp es mas que cualquiera que se haya hecho; el dia que uno lo toque, se
 * sube.
 */
export const TOPE_DE_LINEAS = 30;

/** Igual que `idCompra` y `idMovimiento`: `crypto.randomUUID()` da 36. */
const ID_DE_PEDIDO = /^[A-Za-z0-9_-]{16,64}$/;

/**
 * Lo que recibe `crearOrdenDelPanel`.
 *
 * `entrega` ya viene NORMALIZADO: `validarDatosDeEntrega` es el mismo
 * validador que usa la vidriera, y saca el telefono a E.164 (`telefonoE164`).
 * Dos validadores del mismo dato se desincronizan (LECCIONES 6.4).
 */
export interface PedidoDelPanel {
  /**
   * La clave de idempotencia, y ademas el id de la Orden: crear el documento ES
   * escribir el marcador, en la misma transaccion que el descuento de stock.
   * Nace cuando el operador abre el formulario y NO se regenera nunca, ni tras
   * un error (ADR 018 §4).
   */
  readonly idPedido: string;
  readonly lineas: readonly LineaDePedido[];
  readonly entrega: DatosDeEntrega;
}

function esObjeto(x: unknown): x is Record<string, unknown> {
  return typeof x === 'object' && x !== null && !Array.isArray(x);
}

function soloClaves(x: Record<string, unknown>, permitidas: readonly string[]): boolean {
  return Object.keys(x).every((k) => permitidas.includes(k));
}

/** Un entero SANO: `-0`, `1.5`, `'3'` y `NaN` no lo son.  Ver `stock.ts`. */
const esEnteroSano = (x: unknown): x is number =>
  typeof x === 'number' && Number.isInteger(x) && !Object.is(x, -0);

function parsearLinea(x: unknown, indice: number): Validacion<LineaDePedido> {
  const donde = `la linea ${indice + 1}`;
  if (!esObjeto(x) || !soloClaves(x, ['productoId', 'cantidad', 'precioUnitarioVisto'])) {
    return { ok: false, motivo: `${donde} no tiene la forma {productoId, cantidad, precioUnitarioVisto}` };
  }
  if (!esProductoId(x.productoId)) return { ok: false, motivo: `${donde}: productoId invalido` };
  if (!esEnteroSano(x.cantidad) || x.cantidad < 1 || x.cantidad > TOPE_DE_STOCK) {
    return { ok: false, motivo: `${donde}: la cantidad es un entero de 1 a ${TOPE_DE_STOCK}` };
  }
  // Un precio de 0 no es un precio: pasa la comparacion contra un producto
  // publicado con `precio: 0` y deja una venta a cero (hallazgo 2, ADR 008).
  if (!esEnteroSano(x.precioUnitarioVisto) || x.precioUnitarioVisto < 1) {
    return { ok: false, motivo: `${donde}: el precio visto es un entero de centavos, mayor que cero` };
  }
  return {
    ok: true,
    valor: {
      productoId: x.productoId,
      cantidad: x.cantidad,
      precioUnitarioVisto: centavos(x.precioUnitarioVisto),
    },
  };
}

/**
 * RECHAZA lo que no cumple; no lo corrige.  Devuelve el PRIMER motivo.
 *
 * El objeto que devuelve se arma con las claves en ORDEN FIJO: la callable
 * compara las lineas de un reintento contra las guardadas, y eso solo es
 * estable si el orden lo es.
 */
export function parsearPedidoDelPanel(entrada: unknown): Validacion<PedidoDelPanel> {
  if (!esObjeto(entrada) || !soloClaves(entrada, ['idPedido', 'lineas', 'entrega'])) {
    return { ok: false, motivo: 'el pedido no tiene la forma {idPedido, lineas, entrega}' };
  }
  if (typeof entrada.idPedido !== 'string' || !ID_DE_PEDIDO.test(entrada.idPedido)) {
    return { ok: false, motivo: 'idPedido invalido' };
  }

  if (!Array.isArray(entrada.lineas) || entrada.lineas.length < 1) {
    return { ok: false, motivo: 'el pedido no tiene lineas' };
  }
  if (entrada.lineas.length > TOPE_DE_LINEAS) {
    return { ok: false, motivo: `el pedido tiene mas de ${TOPE_DE_LINEAS} lineas` };
  }
  const lineas: LineaDePedido[] = [];
  const vistos = new Set<string>();
  for (const [i, cruda] of entrada.lineas.entries()) {
    const linea = parsearLinea(cruda, i);
    if (!linea.ok) return linea;
    // Sumar la demanda por producto es lo que evita validar dos veces contra el
    // mismo stock (ADR 008, "lo que queda para crearOrden"): se rechaza la
    // repeticion y no se suma en silencio.
    if (vistos.has(linea.valor.productoId)) {
      return { ok: false, motivo: `el producto ${linea.valor.productoId} esta repetido` };
    }
    vistos.add(linea.valor.productoId);
    lineas.push(linea.valor);
  }

  const entrega = validarDatosDeEntrega(entrada.entrega);
  if (!entrega.ok) return { ok: false, motivo: `datos de entrega: ${entrega.motivo}` };

  return {
    ok: true,
    valor: {
      idPedido: entrada.idPedido,
      lineas,
      // `propio` lo decide la tabla de cobertura del servidor (ADR 010), no
      // quien carga el pedido.  Con el reparto propio apagado siempre es false.
      entrega: { ...entrega.valor, destino: { ...entrega.valor.destino, propio: false } },
    },
  };
}

// ----------------------------------------------------------------- la Orden

/**
 * Una linea de la Orden: un SNAPSHOT, no una referencia.  El precio del
 * producto cambia; el que se anoto, no.  `botellas` viaja tambien: una
 * cancelacion futura repone con ESTE numero y no con el del producto de hoy
 * (hallazgo 1 de ADR 008).
 */
export interface ItemDeOrden {
  readonly productoId: string;
  readonly nombre: string;
  readonly precioUnitario: Centavos;
  /** Unidades de venta, no botellas. */
  readonly cantidad: number;
  /** Botellas por unidad de venta, al momento de crear. */
  readonly botellas: number;
}

/** Quien recibe.  El indice `numero + contacto.email` ya esta declarado para `consultarOrden`. */
export interface ContactoDeOrden {
  readonly nombre: string;
  readonly telefonoE164: string;
  readonly email: string | null;
}

export interface EntregaDeOrden {
  readonly calle: string;
  readonly numero: string;
  readonly piso: string | null;
  readonly referencia: string | null;
  readonly destino: DestinoDeEnvio;
}

/**
 * La Orden tal como la escribe la transaccion, sin los dos `serverTimestamp`
 * (`creadaEn` y `actualizadaEn`), que pone la base al confirmar.
 *
 * `envio: null` va SIEMPRE escrito, nunca ausente: un campo que puede faltar es
 * la trampa de `publicado` (ARQUITECTURA §5.2).  En un pedido de WhatsApp el
 * precio y el correo se arreglan por el chat, asi que no se cotiza.
 */
export interface OrdenNueva {
  readonly numero: number;
  readonly origen: Origen;
  readonly estadoPago: EstadoPago;
  readonly estadoEntrega: EstadoEntrega;
  readonly items: readonly ItemDeOrden[];
  readonly subtotal: Centavos;
  readonly envio: null;
  /** Igual al subtotal mientras `envio` sea `null`.  NO es lo que se cobro. */
  readonly total: Centavos;
  readonly contacto: ContactoDeOrden;
  readonly entrega: EntregaDeOrden;
  /** El uid de quien la cargo. */
  readonly creadaPor: string;
}

/** Parte los datos que escribio el operador en lo que va a `contacto` y lo que va a `entrega`. */
export function contactoYEntrega(datos: DatosDeEntrega): {
  readonly contacto: ContactoDeOrden;
  readonly entrega: EntregaDeOrden;
} {
  return {
    contacto: { nombre: datos.nombre, telefonoE164: datos.telefonoE164, email: datos.email },
    entrega: {
      calle: datos.calle,
      numero: datos.numero,
      piso: datos.piso,
      referencia: datos.referencia,
      destino: datos.destino,
    },
  };
}
