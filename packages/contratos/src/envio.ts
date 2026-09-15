/**
 * La entrega: cuantos bultos viajan, a donde, cuanto sale y con que datos.
 *
 * ESTE ARCHIVO NO SABE QUIEN DESPACHA. Define el puerto `ProveedorDeEnvio` y
 * los tipos que cruzan la frontera; el adaptador -Enviopack, Andreani, o el
 * reparto propio- vive afuera. Es la misma forma que ADR 003 le dio a los
 * pagos, y por la misma razon: si el eje nace el dia que llega el proveedor,
 * estrena toda la maquinaria de golpe y la estrena con plata de por medio.
 *
 * ⚠️ LO QUE CAMBIO RESPECTO DEL MODELO ESCRITO. El glosario dice que una
 * direccion fuera de toda zona NO PUEDE COMPRAR y que se le avisa antes del
 * carrito. Con envio a todo el pais eso deja de ser cierto: nadie queda
 * afuera. `Zona` pasa a significar "hasta donde llegamos NOSOTROS" -el valle
 * de Punilla- y no "hasta donde llega el pedido". La modalidad no la elige el
 * comprador: la decide el codigo postal.
 */

import { BOTELLAS_POR_CAJA } from './carrito.ts';
import { CERO, sumar, type Centavos } from './dinero.ts';
import type { Validacion } from './producto.ts';

// ------------------------------------------------------------------ bultos

/**
 * Peso y medidas de UNA caja de seis, con las botellas adentro.
 *
 * EL PESO YA NO ES UN NUMERO DE CATALOGO. El dueno peso una botella el
 * 2026-09-15: **1,118 kg**. Seis dan 6,666 kg, mas la caja y el relleno queda
 * en ~7 kg, y sube o baja segun la botella -- una borgonesa pesada no pesa lo
 * mismo que una bordelesa liviana.
 *
 * Se deja en 8 A PROPOSITO, del lado seguro: un correo que repesa el bulto y
 * lo encuentra mas pesado de lo declarado cobra la diferencia al vendedor,
 * mientras que declarar de mas solo puede caer en el escalon de peso de
 * arriba. El dia que existan tarifas reales hay que mirar DONDE caen los
 * escalones: si 7 y 8 estan en el mismo, esto no cuesta nada; si no, cuesta
 * en cada pedido.
 *
 * ⚠️ Las MEDIDAS siguen siendo de catalogo de proveedores, no medidas.
 */
export const CAJA_KG = 8;
/* NO se exporta: `bultosDelPedido` ya devuelve las medidas por bulto, que es
 * como las pide un correo. Un export que nadie abre no esta entregado, esta
 * escrito. */
const CAJA_CM = { largo: 34, ancho: 24, alto: 18 } as const;

export interface Bulto {
  readonly pesoKg: number;
  readonly largoCm: number;
  readonly anchoCm: number;
  readonly altoCm: number;
}

/**
 * Cuantas cajas FISICAS viajan.
 *
 * El carrito se cobra de a multiplos de seis botellas (ADR 009), asi que 12
 * botellas son dos cajas y dos cajas pesan el doble. Cotizar siempre una sola
 * caja fue el defecto que tenia la maqueta: el precio del envio de un pedido
 * grande salia igual que el de uno chico.
 *
 * Redondea para arriba a proposito: 7 botellas -que no se pueden cobrar, pero
 * se pueden cotizar mientras el comprador completa- viajan en dos cajas.
 */
export function cajasADespachar(botellas: number, porCaja: number = BOTELLAS_POR_CAJA): number {
  if (!Number.isInteger(porCaja) || porCaja < 1) {
    throw new RangeError(`la caja va entera y >= 1; llego ${porCaja}`);
  }
  if (!Number.isFinite(botellas) || botellas <= 0) return 0;
  return Math.ceil(botellas / porCaja);
}

/** Un bulto por caja. Es lo que espera un correo: una lista, no un peso solo. */
export function bultosDelPedido(botellas: number, porCaja: number = BOTELLAS_POR_CAJA): readonly Bulto[] {
  const cajas = cajasADespachar(botellas, porCaja);
  return Array.from({ length: cajas }, () => ({
    pesoKg: CAJA_KG,
    largoCm: CAJA_CM.largo,
    anchoCm: CAJA_CM.ancho,
    altoCm: CAJA_CM.alto,
  }));
}

export function pesoDelPedidoKg(botellas: number, porCaja: number = BOTELLAS_POR_CAJA): number {
  return cajasADespachar(botellas, porCaja) * CAJA_KG;
}

// -------------------------------------------------------------- modalidades

/**
 * Como llega el pedido. NO es una eleccion del comprador: sale del codigo
 * postal. `propio` es el reparto nuestro en Punilla; los otros dos son el
 * correo, que cobra distinto segun donde lo deje.
 */
export const MODALIDADES_DE_ENTREGA = ['propio', 'domicilio', 'sucursal'] as const;
export type ModalidadDeEntrega = (typeof MODALIDADES_DE_ENTREGA)[number];

export interface DestinoDeEnvio {
  /** Cuatro digitos. El alfanumerico (CPA) no se pide: el correo cotiza con este. */
  readonly codigoPostal: string;
  readonly localidad: string;
  /** ISO 3166-2:AR sin prefijo. Es lo que el correo espera, no el nombre. */
  readonly provincia: ProvinciaIso;
  /** true si lo repartimos nosotros. Lo decide la tabla de cobertura. */
  readonly propio: boolean;
}

/**
 * Las 24 jurisdicciones con su codigo ISO 3166-2:AR sin el prefijo `AR-`.
 *
 * El codigo NO es decorativo: es lo que un correo argentino espera en el campo
 * `provincia` al cotizar y al despachar. Guardar "Cordoba" como texto obliga a
 * traducirlo en el momento equivocado -cuando ya no hay a quien preguntarle
 * como se escribia-, asi que el codigo viaja desde el formulario.
 */
/* ⚠️ Los nombres van CON TILDE aunque los comentarios de este paquete no la
 * usen: esto no es una nota para quien programa, es lo que lee un comprador en
 * el selector. "Cordoba" salió en la primera captura y se vio mal de lejos. */
export const PROVINCIAS = [
  { iso: 'B', nombre: 'Buenos Aires' },
  { iso: 'C', nombre: 'Ciudad de Buenos Aires' },
  { iso: 'K', nombre: 'Catamarca' },
  { iso: 'H', nombre: 'Chaco' },
  { iso: 'U', nombre: 'Chubut' },
  { iso: 'X', nombre: 'Córdoba' },
  { iso: 'W', nombre: 'Corrientes' },
  { iso: 'E', nombre: 'Entre Ríos' },
  { iso: 'P', nombre: 'Formosa' },
  { iso: 'Y', nombre: 'Jujuy' },
  { iso: 'L', nombre: 'La Pampa' },
  { iso: 'F', nombre: 'La Rioja' },
  { iso: 'M', nombre: 'Mendoza' },
  { iso: 'N', nombre: 'Misiones' },
  { iso: 'Q', nombre: 'Neuquén' },
  { iso: 'R', nombre: 'Río Negro' },
  { iso: 'A', nombre: 'Salta' },
  { iso: 'J', nombre: 'San Juan' },
  { iso: 'D', nombre: 'San Luis' },
  { iso: 'Z', nombre: 'Santa Cruz' },
  { iso: 'S', nombre: 'Santa Fe' },
  { iso: 'G', nombre: 'Santiago del Estero' },
  { iso: 'V', nombre: 'Tierra del Fuego' },
  { iso: 'T', nombre: 'Tucumán' },
] as const;

export type ProvinciaIso = (typeof PROVINCIAS)[number]['iso'];

export function esProvinciaIso(x: unknown): x is ProvinciaIso {
  return typeof x === 'string' && PROVINCIAS.some((p) => p.iso === x);
}

export function nombreDeProvincia(iso: string): string | null {
  return PROVINCIAS.find((p) => p.iso === iso)?.nombre ?? null;
}

export interface OpcionDeEnvio {
  readonly id: string;
  readonly modalidad: ModalidadDeEntrega;
  /** Lo que lee el comprador: "Hasta tu puerta". Nunca el nombre del correo. */
  readonly nombre: string;
  readonly detalle: string;
  readonly precio: Centavos;
  /** Dias habiles. Un rango, porque ningun correo promete un dia. */
  readonly desdeDias: number;
  readonly hastaDias: number;
  /** Quien lo lleva. Para el panel y el despacho, NO para la vidriera. */
  readonly transportista: string | null;
}

/**
 * El puerto. Una sola implementacion hoy -`CotizadorSimulado`- y el adaptador
 * real cuando el proveedor este confirmado.
 *
 * `cotizar` devuelve una lista porque un correo puede ofrecer varias
 * modalidades y porque un agregador devuelve varios correos. Que la vidriera
 * muestre una, dos o las cinco es decision de la pantalla, no del puerto.
 */
export interface ProveedorDeEnvio {
  cotizar(destino: DestinoDeEnvio, bultos: readonly Bulto[]): Promise<readonly OpcionDeEnvio[]>;
}

// ------------------------------------------------------------------- total

/**
 * El envio se SUMA al precio de los vinos. No esta adentro, no se prorratea
 * por linea: es un renglon propio, y por eso `crearOrden` lo va a guardar
 * aparte del subtotal.
 */
export function totalConEnvio(subtotal: Centavos, envio: Centavos | null): Centavos {
  return envio === null ? subtotal : sumar(subtotal, envio);
}

/** Sin cargo es un precio, no la ausencia de uno. Existe para que se lea. */
export const SIN_CARGO: Centavos = CERO;

// ------------------------------------------------------------- telefono

/**
 * El telefono a E.164, que es como lo pide el glosario y como lo lee `wa.me`.
 *
 * NO ES COSMETICO. `wa.me` interpreta los digitos como E.164 COMPLETO: un
 * numero escrito como se disca en Argentina -`3548412233`- es, para WhatsApp,
 * el pais 3. Y no falla ruidosamente: abre un chat con otra persona.
 *
 * El `15` se saca porque no existe en E.164; la longitud nacional argentina es
 * siempre 10 digitos (area + abonado), asi que un numero de 12 con `15` adentro
 * se corrige buscando donde cortarlo.
 *
 * ⚠️ Asume MOVIL: antepone el `9`. Un fijo normalizado asi queda mal, y es
 * deliberado -el campo existe para escribir por WhatsApp, y a un fijo no se le
 * escribe-. El dia que haga falta distinguirlos, este es el lugar.
 */
export function normalizarTelefonoAR(entrada: string): string | null {
  if (typeof entrada !== 'string') return null;
  let d = entrada.replace(/\D/g, '');
  if (d.startsWith('54')) d = d.slice(2);
  if (d.startsWith('9')) d = d.slice(1);
  while (d.startsWith('0')) d = d.slice(1);
  if (d.length > 10) {
    for (const corte of [2, 3, 4]) {
      if (d.length - 2 === 10 && d.slice(corte, corte + 2) === '15') {
        d = d.slice(0, corte) + d.slice(corte + 2);
        break;
      }
    }
  }
  if (d.length !== 10) return null;
  return `+549${d}`;
}

// ----------------------------------------------------- datos de la entrega

/**
 * Lo que el comprador escribe. Viaja DENTRO de la Orden: no hay coleccion
 * `clientes` y el checkout es sin registro (ARQUITECTURA 5.1).
 *
 * `email` es opcional a proposito. El comprobante NO se manda por mail: vive
 * en una URL estable y el link viaja por WhatsApp, que ya es el canal. El mail
 * queda como segundo camino para escribirle a alguien, no como infraestructura
 * de envio.
 */
export interface DatosDeEntrega {
  readonly nombre: string;
  readonly telefonoE164: string;
  readonly email: string | null;
  readonly calle: string;
  readonly numero: string;
  readonly piso: string | null;
  readonly referencia: string | null;
  readonly destino: DestinoDeEnvio;
}

const LARGO_MAXIMO = 120;

function texto(x: unknown): string {
  return typeof x === 'string' ? x.trim() : '';
}

/**
 * Valida lo que escribio el comprador. Un solo validador para los dos lados:
 * lo usa la vidriera para habilitar el boton y lo va a usar `crearOrden` al
 * recibir el pedido. Dos validadores del mismo dato se desincronizan.
 *
 * Devuelve el PRIMER motivo, no una lista: la pantalla marca el campo que
 * falta, y una lista de siete motivos no la lee nadie.
 */
export function validarDatosDeEntrega(datos: unknown): Validacion<DatosDeEntrega> {
  if (typeof datos !== 'object' || datos === null) return { ok: false, motivo: 'no es un objeto' };
  const d = datos as Record<string, unknown>;

  const nombre = texto(d.nombre);
  if (nombre.length < 2) return { ok: false, motivo: 'nombre' };
  if (nombre.length > LARGO_MAXIMO) return { ok: false, motivo: 'nombre largo' };

  const telefonoE164 = normalizarTelefonoAR(texto(d.telefono));
  if (telefonoE164 === null) return { ok: false, motivo: 'telefono' };

  const crudo = texto(d.email);
  if (crudo !== '' && !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(crudo)) return { ok: false, motivo: 'email' };
  const email = crudo === '' ? null : crudo;

  const calle = texto(d.calle);
  if (calle.length < 2) return { ok: false, motivo: 'calle' };
  const numero = texto(d.numero);
  if (numero === '') return { ok: false, motivo: 'numero' };

  const destino = d.destino as Record<string, unknown> | undefined;
  if (typeof destino !== 'object' || destino === null) return { ok: false, motivo: 'destino' };
  const codigoPostal = texto(destino.codigoPostal);
  if (!/^\d{4}$/.test(codigoPostal)) return { ok: false, motivo: 'codigo postal' };
  const localidad = texto(destino.localidad);
  if (localidad === '') return { ok: false, motivo: 'localidad' };
  const provincia = texto(destino.provincia);
  if (!esProvinciaIso(provincia)) return { ok: false, motivo: 'provincia' };

  return {
    ok: true,
    valor: {
      nombre,
      telefonoE164,
      email,
      calle,
      numero,
      piso: texto(d.piso) || null,
      referencia: texto(d.referencia) || null,
      destino: { codigoPostal, localidad, provincia, propio: destino.propio === true },
    },
  };
}

// ------------------------------------------------------- lo que vuelve

export type MotivoSinCotizacion = 'codigo-postal' | 'pedido-vacio' | 'proveedor-caido';

/**
 * Lo que devuelve una cotizacion. Es el tipo que cruza del servidor al
 * navegador, asi que vive aca y no en la tienda: el dia que la cotizacion la
 * pida el panel para rearmar un envio, ya esta escrito.
 *
 * ⚠️ `proveedor-caido` existe desde el dia 1 aunque hoy no pueda pasar. Un
 * cotizador real se cae, y una pantalla que no tiene ese estado lo estrena en
 * produccion.
 */
export type ResultadoDeCotizacion =
  | { readonly ok: true; readonly destino: DestinoDeEnvio; readonly opciones: readonly OpcionDeEnvio[] }
  | { readonly ok: false; readonly motivo: MotivoSinCotizacion };
