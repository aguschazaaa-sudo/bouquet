/**
 * Mover el stock: reponer y corregir.  EP-05, ADR 016.
 *
 * `stock` lo escribe SOLO el servidor (ADR 008): las reglas lo congelan en
 * cualquier `update` del panel, porque una regla ve el documento resultante y
 * no la operacion, y no distingue un `increment(10)` de un valor absoluto
 * calculado sobre un dato viejo.  Por eso el panel llama a la callable
 * `moverStock`, y ESTE archivo es lo que la callable y el panel entienden
 * igual: la forma del pedido, sus limites y la cuenta.
 *
 * Es PURO a proposito -sin Firestore ni SDK-: la transaccion vive en
 * `functions/`, y lo que tiene que ser identico de los dos lados es esto.
 * El panel lo espeja en Dart contra fixtures calculadas por este archivo.
 *
 * Dos operaciones, y la diferencia es de plata:
 *
 *  · `reponer` SUMA.  Entra mercaderia; no importa cuanto habia.  Es
 *    conmutativa, asi que dos reposiciones a la vez dan la suma exacta.
 *  · `corregir` FIJA un valor absoluto despues de contar el deposito.  Un
 *    absoluto PISA las ventas del medio: si entre que el operador conto y
 *    guardo se vendieron dos, fijar el numero las borra.  Por eso lleva
 *    `visto` -el stock que el operador tenia en pantalla- y se rechaza si ya
 *    no es ese.  Es el `precioUnitarioVisto` de `crearOrden`, para el stock.
 */

import { esProductoId } from './carrito.ts';
import type { Validacion } from './producto.ts';

/**
 * Por que se corrige un stock.  Se elige con un toque de una lista corta, no
 * se escribe (poca burocracia, overview del panel).  `otro` existe para que
 * ningun motivo real quede sin opcion y el operador no elija uno falso.
 */
export const MOTIVOS_DE_AJUSTE = ['conteo', 'rotura', 'otro'] as const;
type MotivoDeAjuste = (typeof MOTIVOS_DE_AJUSTE)[number];

/**
 * El stock, despues de cualquier movimiento, no pasa de esto.  Es una
 * baranda anti dedo-gordo: el tipeo de un cero de mas en una reposicion es el
 * error probable, y el catalogo real es de decenas de unidades por vino, no de
 * miles.  Sube con un cambio de esta constante -no de las reglas: `stock` no
 * pasa por ellas-, y el dia que un vino real la pase se decide de nuevo.
 */
export const TOPE_DE_STOCK = 5000;

/** Igual que `idCompra`: `crypto.randomUUID()` da 36 y el rango no acepta basura. */
const ID_DE_MOVIMIENTO = /^[A-Za-z0-9_-]{16,64}$/;

type OperacionDeStock =
  | { readonly tipo: 'reponer'; readonly cantidad: number }
  | {
      readonly tipo: 'corregir';
      /** El stock que el operador tenia en pantalla al contar. */
      readonly visto: number;
      readonly valor: number;
      readonly motivo: MotivoDeAjuste;
    };

export interface PedidoDeMovimiento {
  readonly productoId: string;
  /**
   * La clave de idempotencia: el mismo `idMovimiento` dos veces es UN
   * movimiento.  Nace cuando el operador abre la hoja, no cuando aprieta el
   * boton, asi que un reintento (un timeout, un doble toque) reusa el mismo.
   */
  readonly idMovimiento: string;
  readonly operacion: OperacionDeStock;
}

function esObjeto(x: unknown): x is Record<string, unknown> {
  return typeof x === 'object' && x !== null && !Array.isArray(x);
}

function soloClaves(x: Record<string, unknown>, permitidas: readonly string[]): boolean {
  return Object.keys(x).every((k) => permitidas.includes(k));
}

/**
 * Un entero SANO: `1.5`, `'3'`, `NaN` y `-0` no lo son.  El `-0` es el
 * traicionero: `Number.isInteger(-0)` es true y `-0 >= 0` tambien, pero
 * Firestore lo guarda como `doubleValue: 0`, y `d.stock is int` de las reglas
 * falla -- el panel ya no podria editar ese vino.  Un `JSON.stringify` nunca
 * emite `-0`; llega solo con un cuerpo escrito a mano (hallazgo 4 de
 * `revisor-pagos`).
 */
const esEnteroSano = (x: unknown): x is number =>
  typeof x === 'number' && Number.isInteger(x) && !Object.is(x, -0);

/** Un entero de `0` a `TOPE_DE_STOCK`. */
const esUnidades = (x: unknown): x is number => esEnteroSano(x) && x >= 0 && x <= TOPE_DE_STOCK;

function parsearOperacion(x: unknown): Validacion<OperacionDeStock> {
  if (!esObjeto(x)) return { ok: false, motivo: 'la operacion no es un objeto' };

  if (x.tipo === 'reponer') {
    if (!soloClaves(x, ['tipo', 'cantidad'])) {
      return { ok: false, motivo: 'reponer lleva {tipo, cantidad} y nada mas' };
    }
    if (!esUnidades(x.cantidad) || x.cantidad < 1) {
      return { ok: false, motivo: `la cantidad a reponer es un entero de 1 a ${TOPE_DE_STOCK}` };
    }
    return { ok: true, valor: { tipo: 'reponer', cantidad: x.cantidad } };
  }

  if (x.tipo === 'corregir') {
    if (!soloClaves(x, ['tipo', 'visto', 'valor', 'motivo'])) {
      return { ok: false, motivo: 'corregir lleva {tipo, visto, valor, motivo} y nada mas' };
    }
    // `visto` no tiene tope propio: si un dato anterior a la baranda lo paso,
    // el operador tiene que poder corregirlo hacia abajo.
    if (!esEnteroSano(x.visto) || x.visto < 0) {
      return { ok: false, motivo: 'visto es un entero de 0 en adelante' };
    }
    if (!esUnidades(x.valor)) {
      return { ok: false, motivo: `el valor es un entero de 0 a ${TOPE_DE_STOCK}` };
    }
    if (typeof x.motivo !== 'string' || !(MOTIVOS_DE_AJUSTE as readonly string[]).includes(x.motivo)) {
      return { ok: false, motivo: `el motivo es uno de: ${MOTIVOS_DE_AJUSTE.join(', ')}` };
    }
    // Corregir a lo mismo que ya habia no es una correccion: es un
    // movimiento sin efecto, y dejaria un registro que no explica nada.
    if (x.valor === x.visto) {
      return { ok: false, motivo: 'el valor es el mismo que el stock visto: no hay nada que corregir' };
    }
    return {
      ok: true,
      valor: { tipo: 'corregir', visto: x.visto, valor: x.valor, motivo: x.motivo as MotivoDeAjuste },
    };
  }

  return { ok: false, motivo: 'la operacion es reponer o corregir' };
}

/**
 * RECHAZA lo que no cumple; no lo corrige -- igual que `parsearCarrito`.  Un
 * stock con una cantidad negativa no es una cantidad a arreglar: es un dato
 * que alguien toco, y adivinar que quiso decir es exactamente lo que no se
 * hace con plata.
 *
 * El objeto que devuelve se arma con las claves en ORDEN FIJO, y eso importa:
 * la callable compara la operacion de un reintento contra la guardada por su
 * `JSON.stringify`, que solo es estable si el orden lo es.
 */
export function parsearPedidoDeMovimiento(entrada: unknown): Validacion<PedidoDeMovimiento> {
  if (!esObjeto(entrada) || !soloClaves(entrada, ['productoId', 'idMovimiento', 'operacion'])) {
    return { ok: false, motivo: 'el pedido no tiene la forma {productoId, idMovimiento, operacion}' };
  }
  if (!esProductoId(entrada.productoId)) return { ok: false, motivo: 'productoId invalido' };
  if (typeof entrada.idMovimiento !== 'string' || !ID_DE_MOVIMIENTO.test(entrada.idMovimiento)) {
    return { ok: false, motivo: 'idMovimiento invalido' };
  }
  const operacion = parsearOperacion(entrada.operacion);
  if (!operacion.ok) return operacion;
  return {
    ok: true,
    valor: {
      productoId: entrada.productoId,
      idMovimiento: entrada.idMovimiento,
      operacion: operacion.valor,
    },
  };
}

/** Por que una operacion no se puede aplicar sobre el stock de ahora. */
export const CODIGOS_DE_RECHAZO = ['cambio-el-stock', 'pasa-el-tope'] as const;
type CodigoDeRechazo = (typeof CODIGOS_DE_RECHAZO)[number];

type ResultadoDeAplicar =
  | { readonly ok: true; readonly despues: number }
  | { readonly ok: false; readonly codigo: CodigoDeRechazo };

/**
 * La cuenta, sobre el stock ACTUAL.  La callable la corre adentro de la
 * transaccion con el stock que acaba de leer; el panel la corre con el que
 * tiene en pantalla para mostrar "queda en N" y para no mandar lo que ya se
 * sabe que va a rebotar.
 *
 *  · `cambio-el-stock`: en `corregir`, el stock ya no es el que el operador
 *    vio.  No se corrige a ciegas: se le muestra el numero de ahora y decide.
 *  · `pasa-el-tope`: en `reponer`, la suma pasa de `TOPE_DE_STOCK`.
 */
export function aplicarOperacion(stockActual: number, operacion: OperacionDeStock): ResultadoDeAplicar {
  if (operacion.tipo === 'reponer') {
    const despues = stockActual + operacion.cantidad;
    return despues > TOPE_DE_STOCK ? { ok: false, codigo: 'pasa-el-tope' } : { ok: true, despues };
  }
  return stockActual === operacion.visto
    ? { ok: true, despues: operacion.valor }
    : { ok: false, codigo: 'cambio-el-stock' };
}

/**
 * Los pedidos de ejemplo del contrato, con su cuenta.  `generar.mjs` los
 * CALCULA con `parsearPedidoDeMovimiento` y `aplicarOperacion` de hoy y el
 * panel los verifica contra su espejo: ninguna salida esta escrita a mano.
 */
export const CASOS_DE_MOVIMIENTO: readonly {
  readonly porque: string;
  readonly stock: number;
  readonly operacion: unknown;
}[] = [
  { porque: 'reponer 6 sobre 4', stock: 4, operacion: { tipo: 'reponer', cantidad: 6 } },
  { porque: 'reponer sobre cero', stock: 0, operacion: { tipo: 'reponer', cantidad: 1 } },
  { porque: 'reponer justo hasta el tope', stock: 4990, operacion: { tipo: 'reponer', cantidad: 10 } },
  { porque: 'reponer pasa el tope por una', stock: 4990, operacion: { tipo: 'reponer', cantidad: 11 } },
  { porque: 'reponer cero no repone nada', stock: 4, operacion: { tipo: 'reponer', cantidad: 0 } },
  { porque: 'reponer una cantidad negativa', stock: 4, operacion: { tipo: 'reponer', cantidad: -3 } },
  { porque: 'reponer una fraccion', stock: 4, operacion: { tipo: 'reponer', cantidad: 1.5 } },
  { porque: 'reponer un texto', stock: 4, operacion: { tipo: 'reponer', cantidad: '6' } },
  {
    porque: 'corregir hacia abajo, lo visto coincide',
    stock: 10,
    operacion: { tipo: 'corregir', visto: 10, valor: 7, motivo: 'rotura' },
  },
  {
    porque: 'corregir hacia arriba, lo visto coincide',
    stock: 3,
    operacion: { tipo: 'corregir', visto: 3, valor: 12, motivo: 'conteo' },
  },
  {
    porque: 'corregir a cero',
    stock: 5,
    operacion: { tipo: 'corregir', visto: 5, valor: 0, motivo: 'otro' },
  },
  {
    porque: 'corregir cuando se vendieron dos en el medio',
    stock: 8,
    operacion: { tipo: 'corregir', visto: 10, valor: 7, motivo: 'conteo' },
  },
  {
    porque: 'corregir al mismo valor',
    stock: 10,
    operacion: { tipo: 'corregir', visto: 10, valor: 10, motivo: 'conteo' },
  },
  {
    porque: 'corregir pasado el tope',
    stock: 10,
    operacion: { tipo: 'corregir', visto: 10, valor: 5001, motivo: 'conteo' },
  },
  {
    porque: 'corregir con un motivo que no existe',
    stock: 10,
    operacion: { tipo: 'corregir', visto: 10, valor: 7, motivo: 'porque-si' },
  },
  { porque: 'una operacion que no existe', stock: 10, operacion: { tipo: 'vaciar' } },
];
