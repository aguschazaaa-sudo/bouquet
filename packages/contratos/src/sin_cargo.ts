/**
 * El envio sin cargo desde un monto (HU-11.1, ADR 026).
 *
 * El dueno fija desde cuanto no cobra el envio, para empujar pedidos mas
 * grandes. Vive en `config/envios`, que es SOLO DEL SERVIDOR, creacion incluida
 * (ARQUITECTURA §9.4): el panel lo guarda por la callable `fijarEnvioSinCargo`,
 * y la baranda contra el dedo gordo corre ahi, sobre el valor NUEVO -en la
 * primera escritura no hay anterior, y es justo cuando mas se equivoca uno-.
 *
 * Cuatro lados lo usan, y por eso esta aca y no en ninguno:
 *   - la callable, que valida y guarda (`parsearPedidoDeSinCargo`,
 *     `motivoParaConfirmar`);
 *   - la vidriera, que lee el documento y lo aplica al cotizar
 *     (`leerConfigDeEnvios`, `conEnvioSinCargo`, `faltaParaSinCargo`);
 *   - `crearOrden`, que TODAVIA NO EXISTE y va a tener que aplicar la MISMA
 *     regla sobre el subtotal que recalcula el servidor -nunca sobre el que
 *     manda el navegador-. Anotado en ADR 026 y en la lista de ADR 008;
 *   - el panel, que muestra el valor y el motivo de confirmar.
 *
 * ⚠️ UN DOCUMENTO ROTO SE LEE COMO APAGADO. Leerlo como "sin cargo desde 0"
 * regalaria el envio en cada pedido; leerlo como apagado cobra el envio, que
 * es lo que se hacia antes de que existiera esta historia.
 */

import { BOTELLAS_POR_CAJA } from './carrito.ts';
import { centavos, type Centavos } from './dinero.ts';
import { SIN_CARGO, type OpcionDeEnvio } from './envio.ts';
import type { Validacion } from './producto.ts';

/**
 * El piso duro: un peso. Cero no es un umbral -es "siempre sin cargo", y eso
 * se dice poniendo un monto bajo y confirmandolo-, y un negativo es un error.
 */
export const SIN_CARGO_MINIMO: Centavos = centavos(100);

/**
 * El techo duro: cien millones de pesos. Por arriba no es un umbral, son ceros
 * de mas -ningun pedido llegaria nunca-, y un numero asi de grande tampoco se
 * acerca al borde de los enteros seguros cuando se compara con un subtotal.
 * Holgado a proposito: con la inflacion, un techo justo envejece en meses.
 */
export const SIN_CARGO_MAXIMO: Centavos = centavos(100_000_000 * 100);

/**
 * Con menos vinos publicados que esto, la mediana no dice nada: es el mismo
 * numero que usa la baranda del precio del panel (HU-03.5,
 * `cambio_de_precio.dart`), y por la misma razon.
 */
export const MINIMO_PARA_LA_MEDIANA = 5;

export interface ConfigDeEnvios {
  /** `null`: apagado, el envio se cobra siempre. */
  readonly sinCargoDesde: Centavos | null;
}

function esObjeto(x: unknown): x is Record<string, unknown> {
  return typeof x === 'object' && x !== null && !Array.isArray(x);
}

/** Un monto de umbral valido: pesos enteros, dentro de los topes duros. */
function esUmbral(x: unknown): x is Centavos {
  return (
    typeof x === 'number' &&
    Number.isSafeInteger(x) &&
    x % 100 === 0 &&
    x >= SIN_CARGO_MINIMO &&
    x <= SIN_CARGO_MAXIMO
  );
}

/**
 * Lee el documento crudo `config/envios`. Sin documento, o roto, es APAGADO
 * (ver arriba): `roto` lo dice para que quien lo lee lo loguee, porque un
 * umbral que el dueno fijo y la tienda ignora en silencio es el modo de falla
 * que este campo existe para evitar.
 */
export function leerConfigDeEnvios(datos: unknown): ConfigDeEnvios & { readonly roto: boolean } {
  if (datos === undefined || datos === null) return { sinCargoDesde: null, roto: false };
  if (!esObjeto(datos)) return { sinCargoDesde: null, roto: true };
  const desde = datos.sinCargoDesde;
  if (desde === null) return { sinCargoDesde: null, roto: false };
  return esUmbral(desde) ? { sinCargoDesde: desde, roto: false } : { sinCargoDesde: null, roto: true };
}

/** Si con este subtotal el envio sale sin cargo. */
export function saleSinCargo(subtotal: Centavos, sinCargoDesde: Centavos | null): boolean {
  return sinCargoDesde !== null && subtotal >= sinCargoDesde;
}

/**
 * Las opciones de envio con el umbral aplicado: si el subtotal llega, TODAS
 * salen sin cargo -domicilio y sucursal-. Decision mia (ADR 026 §3): "no
 * cobro el envio" es lo que dijo el dueno, y dejar una opcion con precio
 * obligaria a explicar por que una si y la otra no.
 *
 * Devuelve la MISMA lista si no aplica: nada que recalcular en la pantalla.
 */
export function conEnvioSinCargo(
  opciones: readonly OpcionDeEnvio[],
  subtotal: Centavos,
  sinCargoDesde: Centavos | null,
): readonly OpcionDeEnvio[] {
  if (!saleSinCargo(subtotal, sinCargoDesde)) return opciones;
  return opciones.map((o) => ({ ...o, precio: SIN_CARGO }));
}

/**
 * Cuanto le falta a este subtotal para el envio sin cargo, o `null` si ya
 * llega o si no hay umbral. Es el empujon arriba del total: *"te faltan $X
 * para que el envio salga sin cargo"*.
 */
export function faltaParaSinCargo(subtotal: Centavos, sinCargoDesde: Centavos | null): Centavos | null {
  if (sinCargoDesde === null || subtotal >= sinCargoDesde) return null;
  return centavos(sinCargoDesde - subtotal);
}

// ------------------------------------------------------------- la callable

export interface PedidoDeSinCargo {
  readonly sinCargoDesde: Centavos | null;
  /** El dueno ya vio el motivo para confirmar y dijo que si. */
  readonly confirmado: boolean;
}

/** Lo que manda el panel a `fijarEnvioSinCargo`. */
export function parsearPedidoDeSinCargo(entrada: unknown): Validacion<PedidoDeSinCargo> {
  if (!esObjeto(entrada)) return { ok: false, motivo: 'no es un objeto' };
  const extras = Object.keys(entrada).filter((k) => k !== 'sinCargoDesde' && k !== 'confirmado');
  if (extras.length) return { ok: false, motivo: `campos de mas: ${extras.join(', ')}` };

  const confirmado = entrada.confirmado ?? false;
  if (typeof confirmado !== 'boolean') return { ok: false, motivo: 'confirmado va true o false' };

  const desde = entrada.sinCargoDesde;
  if (desde === null) return { ok: true, valor: { sinCargoDesde: null, confirmado } };
  if (!esUmbral(desde)) {
    return {
      ok: false,
      motivo: `el monto va en pesos enteros, de ${SIN_CARGO_MINIMO / 100} a ${SIN_CARGO_MAXIMO / 100}`,
    };
  }
  return { ok: true, valor: { sinCargoDesde: desde, confirmado } };
}

/** Un vino publicado, como lo necesita la baranda: su precio y cuantas botellas trae. */
export interface PrecioPublicado {
  readonly precio: number;
  readonly botellas: number;
}

export type MotivoParaConfirmar =
  /** El umbral queda por debajo de una caja a precio tipico: casi todo sale sin cargo. */
  | { readonly motivo: 'debajo-de-una-caja'; readonly cajaTipica: Centavos }
  /** El umbral baja a menos de la mitad del que habia. */
  | { readonly motivo: 'menos-de-la-mitad'; readonly anterior: Centavos };

/**
 * La caja tipica: seis botellas a la mediana del precio POR BOTELLA de lo
 * publicado. `null` con menos de `MINIMO_PARA_LA_MEDIANA` vinos: con un
 * catalogo de tres, la mediana es un vino.
 *
 * Por botella y no por unidad de venta: un estuche de dos a $40.000 son dos
 * botellas de $20.000, y mezclarlo con las sueltas corre la mediana para
 * arriba. Un precio o unas botellas que no son enteros sanos no entran.
 */
export function cajaTipica(publicados: readonly PrecioPublicado[]): Centavos | null {
  const porBotella = publicados
    .filter((p) => Number.isSafeInteger(p.precio) && p.precio > 0 && Number.isInteger(p.botellas) && p.botellas >= 1)
    .map((p) => p.precio / p.botellas)
    .sort((a, b) => a - b);
  const n = porBotella.length;
  if (n < MINIMO_PARA_LA_MEDIANA) return null;
  const medio = Math.floor(n / 2);
  const mediana = n % 2 === 1 ? porBotella[medio]! : (porBotella[medio - 1]! + porBotella[medio]!) / 2;
  return centavos(Math.round(mediana * BOTELLAS_POR_CAJA));
}

/**
 * LA BARANDA BLANDA, sobre el valor NUEVO (ARQUITECTURA §9.4): si hay motivo,
 * la callable no guarda hasta que el dueno confirme. Dos condiciones,
 * cualquiera alcanza:
 *
 *   1. El umbral queda por debajo de una caja a precio tipico. Todo pedido es
 *      al menos una caja (ADR 009), asi que eso es "casi todo sale sin cargo":
 *      el cero de menos. Funciona en la PRIMERA escritura, que no tiene
 *      anterior.
 *   2. Baja a menos de la mitad del anterior: el cambio grande sobre un
 *      umbral sano. El anterior es la senal opcional.
 *
 * Solo mira para ABAJO: subir el umbral, o apagarlo, no regala nada -como
 * mucho, menos pedidos llegan- y el criterio del panel confirma solo lo que
 * evita una perdida concreta. Apagar no pasa por aca.
 */
export function motivoParaConfirmar(
  nuevo: Centavos,
  contexto: { readonly anterior: Centavos | null; readonly cajaTipica: Centavos | null },
): MotivoParaConfirmar | null {
  const { anterior, cajaTipica: caja } = contexto;
  if (caja !== null && nuevo < caja) return { motivo: 'debajo-de-una-caja', cajaTipica: caja };
  if (anterior !== null && nuevo * 2 < anterior) return { motivo: 'menos-de-la-mitad', anterior };
  return null;
}
