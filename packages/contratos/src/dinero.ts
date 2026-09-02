/**
 * Plata. Entera, en centavos de ARS, siempre.
 *
 * LECCIONES 8.2: cambiar la unidad de precio despues de sembrar el catalogo
 * deja ordenes viejas que ya no se pueden interpretar. El tipo es marcado
 * (branded) a proposito: un `number` suelto de pesos NO compila donde se
 * espera Centavos, asi que el error se atrapa en `tsc --noEmit` -que corre en
 * segundos- y no en una orden mal cobrada.
 */

declare const marca: unique symbol;

export type Centavos = number & { readonly [marca]: 'centavos' };

export function centavos(entero: number): Centavos {
  if (!Number.isInteger(entero)) {
    throw new RangeError(`la plata va en centavos ENTEROS; llego ${entero}`);
  }
  if (!Number.isSafeInteger(entero)) {
    throw new RangeError(`${entero} esta fuera del rango seguro de enteros`);
  }
  return entero as Centavos;
}

export const CERO: Centavos = 0 as Centavos;

const PESOS = /^(-)?(\d+)(?:[.,](\d{1,2}))?$/;

/**
 * Convierte "19.99", "19,99", "1990" o 19.99 a centavos, EXACTO.
 *
 * Se parsea como texto y no con `Math.round(pesos * 100)` porque el redondeo
 * flotante se equivoca justo donde duele: `1.005 * 100` da 100.49999999999999
 * y redondea a 100, o sea un centavo menos, en silencio, para siempre.
 *
 * Mas de dos decimales es un ERROR, no algo a redondear: un precio de 19.999
 * es un dato mal cargado y hay que verlo, no absorberlo.
 */
export function desdePesos(valor: string | number): Centavos {
  const texto = typeof valor === 'number' ? String(valor) : valor.trim();
  const m = PESOS.exec(texto);
  if (!m) {
    throw new RangeError(
      `"${texto}" no es un importe en pesos con hasta 2 decimales (ej: "19.99")`,
    );
  }
  const [, signo, enteros, decimales = ''] = m;
  const total = Number(enteros) * 100 + Number(decimales.padEnd(2, '0'));
  return centavos(signo ? -total : total);
}

export function sumar(...montos: Centavos[]): Centavos {
  return centavos(montos.reduce<number>((a, b) => a + b, 0));
}

/** Precio unitario por cantidad. La cantidad es entera: no se venden 2,5 botellas. */
export function porCantidad(unitario: Centavos, cantidad: number): Centavos {
  if (!Number.isInteger(cantidad) || cantidad < 0) {
    throw new RangeError(`la cantidad va entera y no negativa; llego ${cantidad}`);
  }
  return centavos(unitario * cantidad);
}

const FORMATO = new Intl.NumberFormat('es-AR', {
  style: 'currency',
  currency: 'ARS',
  minimumFractionDigits: 2,
});

export function formatearARS(monto: Centavos): string {
  return FORMATO.format(monto / 100);
}
