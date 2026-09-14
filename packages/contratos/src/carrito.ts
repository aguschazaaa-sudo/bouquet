/**
 * El carrito: lo que guarda el navegador, y el pedido que va a recibir
 * `crearOrden`.  ADR 008.
 *
 * El carrito NO lleva precios ni nombres. El precio sale siempre de la
 * proyeccion del momento, asi que un carrito viejo no puede "recordar" un
 * precio que ya no existe. El precio que el comprador VIO viaja aparte, en
 * `PedidoDeCompra`, para que `crearOrden` rechace -en vez de cobrar otro monto-
 * si cambio en el medio.
 *
 * `parsearCarrito` es el UNICO lugar que valida un carrito: lo usa el navegador
 * al leer `localStorage` y lo va a usar `crearOrden` al recibir el pedido. Dos
 * validadores del mismo dato se desincronizan (LECCIONES 6.4).
 */

import { CERO, porCantidad, sumar, type Centavos } from './dinero.ts';
import { TOPE_POR_PEDIDO, type ProductoPublicado, type Validacion } from './producto.ts';

export const VERSION_DEL_CARRITO = 1;

export interface LineaDeCarrito {
  readonly productoId: string;
  readonly cantidad: number;
}

export interface Carrito {
  readonly version: typeof VERSION_DEL_CARRITO;
  /** Clave de idempotencia de `crearOrden`. Nace en el navegador y se renueva despues de cada orden. */
  readonly idCompra: string;
  readonly lineas: readonly LineaDeCarrito[];
}

/**
 * Sin `/` ni `.`: el id termina en una ruta de Firestore, y `productos/${id}`
 * con una barra adentro apunta a OTRO documento.
 */
const PRODUCTO_ID = /^[A-Za-z0-9_-]{1,128}$/;

/** Firestore reserva los ids `__…__`: ninguno es un producto. */
const RESERVADO = /^__.*__$/;

const esProductoId = (x: unknown): x is string => typeof x === 'string' && PRODUCTO_ID.test(x) && !RESERVADO.test(x);

/** `crypto.randomUUID()` da 36; el rango deja lugar sin aceptar basura. */
const ID_COMPRA = /^[A-Za-z0-9_-]{16,64}$/;

function esObjeto(x: unknown): x is Record<string, unknown> {
  return typeof x === 'object' && x !== null && !Array.isArray(x);
}

function soloClaves(x: Record<string, unknown>, permitidas: readonly string[]): boolean {
  return Object.keys(x).every((k) => permitidas.includes(k));
}

/**
 * RECHAZA lo que no cumple; no lo corrige. Un carrito con una cantidad negativa
 * no es un carrito con una cantidad a arreglar: es un dato que alguien toco, y
 * adivinar que quiso decir es exactamente lo que no se hace con plata.
 */
export function parsearCarrito(entrada: unknown): Validacion<Carrito> {
  let valor = entrada;
  if (typeof entrada === 'string') {
    try {
      valor = JSON.parse(entrada);
    } catch {
      return { ok: false, motivo: 'el carrito no es JSON' };
    }
  }
  if (!esObjeto(valor) || !soloClaves(valor, ['version', 'idCompra', 'lineas'])) {
    return { ok: false, motivo: 'el carrito no tiene la forma {version, idCompra, lineas}' };
  }
  if (valor.version !== VERSION_DEL_CARRITO) {
    return { ok: false, motivo: `version desconocida: ${String(valor.version)}` };
  }
  if (!(typeof valor.idCompra === 'string' && ID_COMPRA.test(valor.idCompra))) {
    return { ok: false, motivo: 'idCompra invalido' };
  }
  if (!Array.isArray(valor.lineas)) return { ok: false, motivo: 'lineas no es una lista' };

  const vistos = new Set<string>();
  const lineas: LineaDeCarrito[] = [];
  for (const l of valor.lineas) {
    if (!esObjeto(l) || !soloClaves(l, ['productoId', 'cantidad'])) {
      return { ok: false, motivo: 'una linea no tiene la forma {productoId, cantidad}' };
    }
    if (!esProductoId(l.productoId)) {
      return { ok: false, motivo: `productoId invalido: ${String(l.productoId)}` };
    }
    if (vistos.has(l.productoId)) return { ok: false, motivo: `productoId repetido: ${l.productoId}` };
    vistos.add(l.productoId);
    const c = l.cantidad;
    if (!(typeof c === 'number' && Number.isInteger(c) && c >= 1 && c <= TOPE_POR_PEDIDO)) {
      return { ok: false, motivo: `cantidad invalida en ${l.productoId}: ${String(c)}` };
    }
    lineas.push({ productoId: l.productoId, cantidad: c });
  }
  return { ok: true, valor: { version: VERSION_DEL_CARRITO, idCompra: valor.idCompra, lineas } };
}

export function carritoVacio(idCompra: string): Carrito {
  if (!ID_COMPRA.test(idCompra)) throw new RangeError(`idCompra invalido: ${idCompra}`);
  return { version: VERSION_DEL_CARRITO, idCompra, lineas: [] };
}

// ------------------------------------------------------------- operaciones

export interface Cambio {
  readonly carrito: Carrito;
  /** true si lo pedido pasaba el tope: la cantidad quedo en el tope y la pantalla lo dice. */
  readonly alTope: boolean;
}

/** Deja la linea en `cantidad`, sin pasar el tope. Con tope 0 (agotado) no agrega nada. */
export function fijarCantidad(carrito: Carrito, productoId: string, cantidad: number, topeDelProducto: number): Cambio {
  if (!esProductoId(productoId)) throw new RangeError(`productoId invalido: ${productoId}`);
  if (!Number.isInteger(cantidad) || cantidad < 1) {
    throw new RangeError(`la cantidad va entera y >= 1; llego ${cantidad}`);
  }
  if (topeDelProducto <= 0) return { carrito, alTope: true };

  const nueva = Math.min(cantidad, topeDelProducto);
  const existe = carrito.lineas.some((l) => l.productoId === productoId);
  const lineas = existe
    ? carrito.lineas.map((l) => (l.productoId === productoId ? { productoId, cantidad: nueva } : l))
    : [...carrito.lineas, { productoId, cantidad: nueva }];
  return { carrito: { ...carrito, lineas }, alTope: cantidad > topeDelProducto };
}

/** Suma `cantidad` a lo que ya habia de ese vino, sin pasar su tope. */
export function agregar(carrito: Carrito, productoId: string, cantidad: number, topeDelProducto: number): Cambio {
  if (!Number.isInteger(cantidad) || cantidad < 1) {
    throw new RangeError(`se agrega de a enteros >= 1; llego ${cantidad}`);
  }
  const actual = carrito.lineas.find((l) => l.productoId === productoId)?.cantidad ?? 0;
  return fijarCantidad(carrito, productoId, actual + cantidad, topeDelProducto);
}

export function quitar(carrito: Carrito, productoId: string): Carrito {
  return { ...carrito, lineas: carrito.lineas.filter((l) => l.productoId !== productoId) };
}

/** Lo que muestra el contador de la barra. Sale de `localStorage`: cero lecturas. */
export function unidadesEnCarrito(carrito: Carrito): number {
  return carrito.lineas.reduce((n, l) => n + l.cantidad, 0);
}

// ------------------------------------------------ carrito contra proyeccion

export const ESTADOS_DE_LINEA = ['vigente', 'agotada', 'no-disponible'] as const;
export type EstadoDeLinea = (typeof ESTADOS_DE_LINEA)[number];

export interface LineaResuelta {
  readonly productoId: string;
  readonly cantidad: number;
  /** null si el producto ya no esta en la proyeccion: despublicado o borrado. */
  readonly producto: ProductoPublicado | null;
  readonly estado: EstadoDeLinea;
  /** true si la cantidad se bajo al tope de hoy. */
  readonly ajustada: boolean;
  /** CERO si la linea no esta vigente: lo que no se puede vender no suma. */
  readonly subtotal: Centavos;
}

export interface CarritoResuelto {
  readonly lineas: readonly LineaResuelta[];
  readonly total: Centavos;
  /** El carrito con las cantidades ajustadas. Se GUARDA antes de mostrar el total. */
  readonly carrito: Carrito;
  /** true si `carrito` cambio y hay que guardarlo. */
  readonly ajustado: boolean;
}

/**
 * Une el carrito con la proyeccion de hoy. El total es la suma de `precio x
 * cantidad` de las lineas vigentes, con la plata de `dinero.ts`, y es el mismo
 * calculo que va a repetir `crearOrden`: el total que ve el comprador no puede
 * salir de otra cuenta.
 *
 * Una linea agotada CONSERVA su cantidad en vez de bajar a 0: el parser rechaza
 * cantidades < 1, asi que bajarla dejaria guardado un carrito invalido, que en
 * la proxima visita se descartaria entero.
 */
export function resolverCarrito(carrito: Carrito, productos: readonly ProductoPublicado[]): CarritoResuelto {
  const porId = new Map(productos.map((p) => [p.id, p]));

  const lineas = carrito.lineas.map((l): LineaResuelta => {
    const producto = porId.get(l.productoId) ?? null;
    if (producto === null) {
      return { productoId: l.productoId, cantidad: l.cantidad, producto, estado: 'no-disponible', ajustada: false, subtotal: CERO };
    }
    if (producto.balde === 'agotado' || producto.tope <= 0) {
      return { productoId: l.productoId, cantidad: l.cantidad, producto, estado: 'agotada', ajustada: false, subtotal: CERO };
    }
    const cantidad = Math.min(l.cantidad, producto.tope);
    return {
      productoId: l.productoId,
      cantidad,
      producto,
      estado: 'vigente',
      ajustada: cantidad !== l.cantidad,
      subtotal: porCantidad(producto.precio, cantidad),
    };
  });

  const ajustado = lineas.some((l) => l.ajustada);
  return {
    lineas,
    total: sumar(...lineas.map((l) => l.subtotal)),
    carrito: ajustado
      ? { ...carrito, lineas: lineas.map(({ productoId, cantidad }) => ({ productoId, cantidad })) }
      : carrito,
    ajustado,
  };
}

// ------------------------------------------------------- pedido de compra

export interface LineaDePedido {
  readonly productoId: string;
  readonly cantidad: number;
  /**
   * El precio unitario que el comprador tenia en pantalla. `crearOrden` relee
   * el precio y RECHAZA si no coincide: la pantalla puede tener hasta unos dos
   * minutos de atraso, y un precio viejo no se cobra.
   */
  readonly precioUnitarioVisto: Centavos;
}

/**
 * Lo que va a recibir `crearOrden` (la proxima sesion). Se define aca, antes
 * que su consumidor, para que el carrito nazca con la forma que despues se
 * valida.
 */
export interface PedidoDeCompra {
  /** Clave de idempotencia: el mismo idCompra dos veces es UNA orden. */
  readonly idCompra: string;
  readonly lineas: readonly LineaDePedido[];
}
