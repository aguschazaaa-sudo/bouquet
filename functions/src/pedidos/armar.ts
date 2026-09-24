/**
 * El nucleo PURO de `crearOrdenDelPanel`: dado el pedido y lo que la
 * transaccion acaba de leer, arma la Orden y el stock nuevo de cada producto,
 * o dice por que no se puede.  HU-10.1, ADR 018 §5.
 *
 * No toca Firestore ni recibe una base: casi toda la logica que importa -stock,
 * precio visto, muestra, compuesto, snapshot, total- se prueba con `node --test`
 * en segundos y sin emulador.  El emulador queda para lo que solo el puede
 * probar: concurrencia, atomicidad y el marcador (`crear.ts`).
 *
 * ⚠️ El ORIGEN no viene del pedido: lo pasa quien llama, y hoy el unico origen
 * que puede pasar es `'whatsapp'` -el tipo no admite otro-.  Si `armarOrden`
 * lo leyera del pedido, la puerta que ADR 018 §1 cierra quedaria abierta en el
 * primer refactor: un comprador de la vidriera se saltearia la regla de la caja
 * diciendo `'whatsapp'`.  La rama de la vidriera se escribe con su callable.
 */
import {
  contactoYEntrega,
  PRECIO_MAXIMO,
  estadoDePagoInicial,
  porCantidad,
  sumar,
  validarProducto,
  type Centavos,
  type ItemDeOrden,
  type LineaDePedido,
  type OrdenNueva,
  type PedidoDelPanel,
} from '@bouquet/contratos';

/** Por que una linea no se puede vender.  Cada uno lleva `productoId`. */
export const CODIGOS_DE_RECHAZO_DE_ORDEN = [
  'no-existe',
  'producto-roto',
  'de-muestra',
  'compuesto',
  'sin-precio',
  'cambio-el-precio',
  'sin-stock',
] as const;

export type CodigoDeRechazoDeOrden = (typeof CODIGOS_DE_RECHAZO_DE_ORDEN)[number];

export interface RechazoDeOrden {
  readonly codigo: CodigoDeRechazoDeOrden;
  readonly productoId: string;
  /**
   * El valor de AHORA que hace falta para decidir: el precio en `cambio-el-
   * precio`, el stock en `sin-stock`.  El panel se lo muestra al operador, que
   * decide, en vez de reintentar a ciegas.
   */
  readonly actual?: number;
  /** Solo en `producto-roto`: que le falta al documento. */
  readonly motivo?: string;
}

export interface CambioDeStock {
  readonly productoId: string;
  readonly antes: number;
  readonly despues: number;
}

export type ResultadoDeArmar =
  | { readonly ok: true; readonly orden: OrdenNueva; readonly stock: readonly CambioDeStock[] }
  | { readonly ok: false; readonly rechazo: RechazoDeOrden };

export interface ContextoDeArmar {
  /** El `numero` que la transaccion acaba de reservar. */
  readonly numero: number;
  /** El uid de quien carga el pedido. */
  readonly uid: string;
  readonly origen: 'whatsapp';
}

const rechazo = (r: RechazoDeOrden): ResultadoDeArmar => ({ ok: false, rechazo: r });

/**
 * @param leidos  `productoId` -> los datos crudos del documento, o `undefined`
 *                si no existe.  Lo que devolvio `tx.getAll`, sin tocar.
 */
export function armarOrden(
  pedido: PedidoDelPanel,
  leidos: ReadonlyMap<string, unknown>,
  contexto: ContextoDeArmar,
): ResultadoDeArmar {
  const items: ItemDeOrden[] = [];
  const stock: CambioDeStock[] = [];
  const subtotales: Centavos[] = [];

  for (const linea of pedido.lineas) {
    const productoId = linea.productoId;
    const crudo = leidos.get(productoId);
    if (crudo === undefined || crudo === null) return rechazo({ codigo: 'no-existe', productoId });

    // De muestra ANTES de validar: un vino de muestra es un documento valido, y
    // por eso pasaria; pero su stock es inventado y venderlo descuenta un
    // numero que no existe (los 20 del seed, `muestra: true`).
    if ((crudo as { muestra?: unknown }).muestra === true) {
      return rechazo({ codigo: 'de-muestra', productoId });
    }

    const producto = validarProducto(productoId, crudo);
    if (!producto.ok) return rechazo({ codigo: 'producto-roto', productoId, motivo: producto.motivo });

    // Un compuesto no tiene stock propio: lo deriva de sus componentes (ADR 009
    // §10) y nada lo expande todavia.
    if (producto.valor.tipo !== 'simple') return rechazo({ codigo: 'compuesto', productoId });

    // Un vino sin precio no se vende, y NO se dice "cambio el precio": el parser
    // no deja mandar un precio visto de 0, asi que el panel ofreceria reintentar
    // a $0 y volveria a rebotar (hallazgo 9 de `revisor-pagos`).
    if (producto.valor.precio < 1) return rechazo({ codigo: 'sin-precio', productoId });
    // Y uno absurdo desbordaria la suma: `sumar` lanzaria un RangeError que la
    // callable contestaria `internal` (hallazgo 6).  Es el mismo tope del parser.
    if (producto.valor.precio > PRECIO_MAXIMO) {
      return rechazo({ codigo: 'producto-roto', productoId, motivo: 'el precio es absurdo' });
    }

    // El precio visto tiene que ser el de AHORA: la lista del panel puede tener
    // atraso, y un precio viejo no se guarda.
    if (producto.valor.precio !== linea.precioUnitarioVisto) {
      return rechazo({ codigo: 'cambio-el-precio', productoId, actual: producto.valor.precio });
    }

    const stockActual = producto.valor.stock;
    if (stockActual < 0) {
      // Un stock negativo no se "arregla": alguien lo tiene que mirar.
      return rechazo({ codigo: 'producto-roto', productoId, motivo: 'el stock es negativo' });
    }
    if (stockActual < linea.cantidad) {
      return rechazo({ codigo: 'sin-stock', productoId, actual: stockActual });
    }

    items.push({
      productoId,
      nombre: producto.valor.nombre,
      precioUnitario: producto.valor.precio,
      cantidad: linea.cantidad,
      botellas: producto.valor.presentacion.botellas,
    });
    subtotales.push(porCantidad(producto.valor.precio, linea.cantidad));
    stock.push({ productoId, antes: stockActual, despues: stockActual - linea.cantidad });
  }

  const subtotal = sumar(...subtotales);
  const { contacto, entrega } = contactoYEntrega(pedido.entrega);

  return {
    ok: true,
    stock,
    orden: {
      numero: contexto.numero,
      origen: contexto.origen,
      estadoPago: estadoDePagoInicial(contexto.origen),
      estadoEntrega: 'sin_preparar',
      items,
      subtotal,
      envio: null,
      // Sin envio cotizado, el total ES el subtotal.  Y no es lo que se cobro:
      // el cobro va por fuera (ADR 018 §6).
      total: subtotal,
      contacto,
      entrega,
      creadaPor: contexto.uid,
    },
  };
}

/**
 * Las lineas como texto comparable: `productoId:cantidad`, ordenadas.  El precio
 * visto no entra: pudo cambiar entre los dos intentos, y el primero ya se guardo
 * con el de entonces.
 */
export function firmaDeLineas(lineas: readonly Pick<LineaDePedido, 'productoId' | 'cantidad'>[]): string {
  return lineas
    .map((l) => `${l.productoId}:${l.cantidad}`)
    .sort()
    .join('|');
}


/** JSON con las claves ordenadas, recursivo: Firestore devuelve los mapas en otro orden. */
function estable(x: unknown): string {
  if (Array.isArray(x)) return `[${x.map(estable).join(',')}]`;
  if (x !== null && typeof x === 'object') {
    const o = x as Record<string, unknown>;
    return `{${Object.keys(o)
      .sort()
      .map((k) => `${JSON.stringify(k)}:${estable(o[k])}`)
      .join(',')}}`;
  }
  return JSON.stringify(x) ?? 'null';
}

/**
 * El pedido ENTERO como texto comparable: lineas, contacto y entrega.  Con esto
 * se decide si un reintento con el mismo `idPedido` es el MISMO pedido -devuelve
 * lo que paso- o uno distinto -`already-exists`-.
 *
 * ⚠️ Comparaba solo las LINEAS, y era un error (hallazgo 3 de `revisor-pagos`): un
 * reintento con la direccion corregida devolvia `repetido: true`, el panel
 * mostraba exito y la Orden seguia con la direccion vieja, en silencio.  Un
 * reintento de verdad manda LO MISMO; si difiere algo, no es un reintento y el
 * operador tiene que enterarse.
 */
export function firmaDelPedido(p: {
  readonly lineas: readonly Pick<LineaDePedido, 'productoId' | 'cantidad'>[];
  readonly contacto: unknown;
  readonly entrega: unknown;
}): string {
  return `${firmaDeLineas(p.lineas)}#${estable(p.contacto)}#${estable(p.entrega)}`;
}
