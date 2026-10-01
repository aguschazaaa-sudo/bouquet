'use server';

import {
  bultosDelPedido,
  CAJA_KG,
  centavos,
  esProvinciaIso,
  type Bulto,
  type CargaDelPedido,
  type DestinoDeEnvio,
  type OpcionDeEnvio,
  type ProveedorDeEnvio,
  type ProvinciaIso,
  type ResultadoDeCotizacion,
} from '@bouquet/contratos';

import { EL_CHECKOUT_NO_COBRA } from '../features/carrito/checkout/textos.ts';
import { crearCotizadorEnviopack } from './enviopack.ts';
import { aDomicilio, aSucursal } from './opciones-de-envio.ts';

/* Los topes del saneo de la carga. No son reglas de negocio —el carrito ya
 * tiene las suyas—: son el techo de lo que este endpoint público acepta
 * construir. Un pedido real no se acerca ni de lejos. */
const TOPE_DE_BULTOS = 60;
const TOPE_DE_BOTELLAS_SUELTAS = 600;
const TOPE_DE_BOTELLAS_POR_BULTO = 24;

/**
 * La cotización. Está acá —en `server/`, la frontera de credenciales— porque
 * Envíopack cotiza con una `api-key` + `secret-key` que no pueden viajar al
 * navegador.
 *
 * DOS COTIZADORES, y contesta uno según el entorno (`elCotizador`, abajo):
 * Envíopack (`enviopack.ts`, ADR 030) si están sus dos claves, y el SIMULADO
 * de este archivo si no está ninguna. La pantalla no se entera de cuál.
 *
 * ⚠️ NINGÚN PRECIO DEL SIMULADO ES REAL. Están puestos para poder mirar la
 * pantalla, no para cobrar. Lo que sí es real es la FORMA: una lista de
 * opciones con precio, plazo y transportista, calculada sobre los bultos que
 * de verdad viajan.
 */

/** Una demora que el cotizador real va a tener. Ver la nota de abajo. */
const DEMORA_MS = 220;

/**
 * ⚠️ EL REPARTO PROPIO ESTÁ APAGADO (2026-09-15, decisión del dueño: *"de
 * momento no lo vamos a hacer nosotros"*). Con esto en `false`, **todo sale por
 * correo**, también Punilla, y la modalidad `propio` de contratos queda sin uso
 * — como `tipo: 'compuesto'`, y por la misma razón: el camino existe entero y
 * se prende con esta línea.
 *
 * Y apagarlo desactiva el riesgo de la tabla de abajo, que era el peor de los
 * tres números inventados: un código postal mal puesto mandaba al reparto
 * propio un pedido que había que despachar, y eso **no falla ruidosamente** —
 * sale más barato y no llega. Con el reparto apagado, lo peor que hace un CP
 * equivocado es prellenar mal una localidad que el comprador corrige.
 */
const REPARTIMOS_NOSOTROS = false;

/**
 * El valle de Punilla. Hoy sólo sirve para prellenar la localidad; el día que
 * `REPARTIMOS_NOSOTROS` vuelva a `true` es además la cobertura.
 *
 * ⚠️ ESTOS CÓDIGOS POSTALES NO ESTÁN VERIFICADOS uno por uno. Antes de
 * prenderlo hay que confrontarlos con el buscador del Correo Argentino, con un
 * control negativo: un CP que NO es de Punilla no puede dar reparto propio.
 */
const PUNILLA: Readonly<Record<string, string>> = {
  '5152': 'Villa Carlos Paz',
  '5153': 'San Antonio de Arredondo',
  '5155': 'Tanti',
  '5158': 'Bialet Massé',
  '5164': 'Santa María de Punilla',
  '5166': 'Cosquín',
  '5172': 'La Falda',
  '5174': 'Huerta Grande',
  '5176': 'Villa Giardino',
  '5184': 'Capilla del Monte',
};

/**
 * La provincia que se adivina del primer dígito del código postal, para no
 * hacerle elegir entre 24 a alguien que ya escribió el CP.
 *
 * Es una APROXIMACIÓN y el comprador la puede corregir: varias bandas cubren
 * más de una provincia. Y desde ADR 030 NO es decorativa: es lo que recibe
 * Envíopack en `provincia`. Por eso la corrección del comprador vuelve a
 * cotizar (`provinciaElegida`, abajo), y por eso CABA tiene su rango propio:
 * del 1000 al 1499 es la Ciudad, no la provincia de Buenos Aires.
 */
const CABA = { desde: 1000, hasta: 1499 } as const;
const BANDA: Readonly<Record<string, ProvinciaIso>> = {
  '1': 'B',
  '2': 'S',
  '3': 'E',
  '4': 'T',
  '5': 'X',
  '6': 'L',
  '7': 'B',
  '8': 'Q',
  '9': 'U',
};

function adivinarProvincia(cp: string): ProvinciaIso {
  if (cp in PUNILLA) return 'X';
  const numero = Number(cp);
  if (numero >= CABA.desde && numero <= CABA.hasta) return 'C';
  const adivinada = BANDA[cp[0] as string];
  return esProvinciaIso(adivinada) ? adivinada : 'B';
}

/** Cuánto encarece la distancia. Inventado, y ordenado de cerca a lejos. */
function factorDeDistancia(codigoPostal: string): number {
  const banda = codigoPostal[0] ?? '5';
  if (banda === '5') return 1;
  if (banda === '1' || banda === '2' || banda === '3' || banda === '4') return 1.3;
  if (banda === '6' || banda === '7') return 1.35;
  return 1.75;
}

/** Redondeo a centenas de peso, que es como se ven los precios de un correo. */
function aCentenas(pesos: number) {
  return centavos(Math.round(pesos / 100) * 100 * 100);
}

/**
 * El precio sale del PESO DECLARADO, no de la cantidad de bultos.
 *
 * ⚠️ Contaba bultos hasta el 2026-09-15, y funcionaba de casualidad: todos los
 * bultos pesaban lo mismo —una caja de seis— así que contar cajas y sumar kilos
 * daban lo mismo. Desde ADR 009 §10 un vino que trae su propia caja viaja en un
 * bulto de 3 kg, y contando bultos ese pack salía **igual** que una caja de
 * seis llena. El propio comentario de esta función decía que un correo cobra
 * por escalón de peso.
 *
 * Anclado a `CAJA_KG` = `base`, y sublineal: el kilo 16 sale menos que el 8. Ni
 * la base ni el exponente son reales —no hay tarifas todavía—; lo real es la
 * forma: sube con el peso y sube menos que proporcional.
 */
function porPeso(base: number, bultos: readonly Bulto[]) {
  const kg = bultos.reduce((total, b) => total + b.pesoKg, 0);
  return base * Math.pow(Math.max(kg, 1) / CAJA_KG, 0.7);
}

const CotizadorSimulado: ProveedorDeEnvio = {
  async cotizar(destino: DestinoDeEnvio, bultos: readonly Bulto[]): Promise<readonly OpcionDeEnvio[]> {
    /* La demora existe a propósito. Un cotizador instantáneo deja el estado
     * "cotizando…" sin ejecutar nunca, y ese estado se estrenaría el día que
     * entre el proveedor de verdad — que tarda entre medio segundo y dos. */
    await new Promise((listo) => setTimeout(listo, DEMORA_MS));

    if (destino.propio) {
      return [
        {
          id: 'propio',
          modalidad: 'propio',
          nombre: 'Te lo llevamos nosotros',
          detalle: 'Salimos martes y viernes. Coordinamos la hora por WhatsApp.',
          precio: aCentenas(porPeso(2500, bultos)),
          desdeDias: 2,
          hastaDias: 4,
          transportista: null,
        },
      ];
    }

    const lejos = factorDeDistancia(destino.codigoPostal);
    const base = porPeso(6900, bultos) * lejos;
    const dias = lejos > 1.5 ? 6 : lejos > 1.2 ? 4 : 3;

    return [
      aDomicilio({ precio: aCentenas(base), desdeDias: dias, hastaDias: dias + 2, transportista: 'correo' }),
      aSucursal({ precio: aCentenas(base * 0.72), desdeDias: dias + 1, hastaDias: dias + 3, transportista: 'correo' }),
    ];
  },
};

/* Uno por instancia del servidor: guarda el token de Envíopack, que dura
 * cuatro horas, y no tiene sentido pedir uno por cotización. */
let enviopack: ProveedorDeEnvio | null = null;

/**
 * Quién contesta. Envíopack si están las DOS claves; el simulado si no está
 * NINGUNA, que es hoy.
 *
 * ⚠️ CON UNA SOLA NO ES "SIMULADO": es una configuración rota, y caer al
 * simulado ahí es mostrar en producción un precio inventado porque faltó un
 * secreto. Tira, y el comprador ve "no pudimos calcular el envío" con el
 * WhatsApp al lado: se nota en la pantalla y en el log, que es lo que tiene que
 * pasar con un secreto a medio cargar.
 *
 * ⚠️ Y SIN NINGUNA, EL SIMULADO SÓLO VALE MIENTRAS EL CHECKOUT NO COBRA. Un
 * deploy hecho desde un árbol con el bloque de `apphosting.yaml` comentado
 * —un worktree viejo, un revert— vuelve al simulado sin una línea de log. Con
 * el cobro prendido eso es cobrar un envío inventado en cada venta. El gate es
 * una constante del CÓDIGO, así que un árbol viejo trae las dos cosas juntas:
 * el simulado y el checkout que no cobra.
 */
function elCotizador(): ProveedorDeEnvio {
  const apiKey = process.env.ENVIOPACK_API_KEY?.trim() ?? '';
  const secretKey = process.env.ENVIOPACK_SECRET_KEY?.trim() ?? '';
  if (apiKey === '' && secretKey === '') {
    if (!EL_CHECKOUT_NO_COBRA) throw new Error('el checkout cobra y no hay claves de Envíopack: el simulado no cotiza');
    return CotizadorSimulado;
  }
  if (apiKey === '' || secretKey === '') {
    throw new Error('Envíopack a medio configurar: falta ENVIOPACK_API_KEY o ENVIOPACK_SECRET_KEY');
  }
  enviopack ??= crearCotizadorEnviopack({ apiKey, secretKey });
  return enviopack;
}

/**
 * Lo que llama la pantalla. Recibe el código postal y la CARGA del pedido —qué
 * botellas van sueltas y qué unidades traen su propia caja; los bultos los
 * cuenta contratos—, y devuelve el destino que pudo deducir más las opciones.
 *
 * ⚠️ La carga llega del NAVEGADOR: es una Server Action, o sea una entrada
 * pública. Se sanea acá antes de que toque `bultosDelPedido`, porque una lista
 * de packs inventada se convierte en una lista de bultos del mismo largo.
 *
 * El destino que vuelve es una SUGERENCIA: la localidad y la provincia quedan
 * editables en el formulario, porque una banda de CP cubre más de una
 * provincia y el que vive ahí sabe más que esta tabla.
 *
 * `provinciaElegida` es la que el comprador dejó en el formulario PARA ESTE
 * código postal. Si es un ISO válido, manda; si no viene, se adivina. Con
 * Envíopack la provincia cambia el precio, y cotizar con la adivinada después
 * de que la corrigieron es mostrar la tarifa de otra provincia (ADR 030).
 */
export async function cotizarEnvio(
  codigoPostal: string,
  carga: CargaDelPedido,
  provinciaElegida?: string,
): Promise<ResultadoDeCotizacion> {
  const cp = String(codigoPostal ?? '').trim();
  if (!/^\d{4}$/.test(cp)) return { ok: false, motivo: 'codigo-postal' };

  const sueltas = Number(carga?.sueltas);
  const propias = (Array.isArray(carga?.propias) ? carga.propias : [])
    /* El corte va ANTES del filtro: una lista de un millón de entradas no se
     * recorre entera para después quedarse con sesenta. El sobrante del corte
     * deja lugar para entradas inválidas sin perder packs legítimos. */
    .slice(0, TOPE_DE_BULTOS * 4)
    .filter((n) => Number.isInteger(n) && n >= 2 && n <= TOPE_DE_BOTELLAS_POR_BULTO)
    .slice(0, TOPE_DE_BULTOS);
  const pedido: CargaDelPedido = {
    sueltas: Number.isInteger(sueltas) && sueltas > 0 ? Math.min(sueltas, TOPE_DE_BOTELLAS_SUELTAS) : 0,
    propias,
  };
  if (pedido.sueltas === 0 && propias.length === 0) return { ok: false, motivo: 'pedido-vacio' };

  /* ⚠️ El rango existe para que el estado "ese código postal no nos suena" SE
   * PUEDA DISPARAR. Sin él, cualquier número de cuatro cifras cotizaba —9999
   * incluido— y esa pantalla era UI que nadie podía abrir: se estrenaría el día
   * del proveedor real, que sí rechaza. Es una plausibilidad, no una validez:
   * los códigos argentinos van de 1000 (CABA) a ~9431 (Tierra del Fuego), y el
   * proveedor tiene la lista de verdad. */
  const numero = Number(cp);
  if (numero < 1000 || numero > 9431) return { ok: false, motivo: 'codigo-postal' };

  const propio = REPARTIMOS_NOSOTROS && cp in PUNILLA;
  const provincia = esProvinciaIso(provinciaElegida) ? provinciaElegida : adivinarProvincia(cp);

  const destino: DestinoDeEnvio = {
    codigoPostal: cp,
    localidad: PUNILLA[cp] ?? '',
    provincia,
    propio,
  };

  try {
    const opciones = await elCotizador().cotizar(destino, bultosDelPedido(pedido));
    /* Sin ninguna opción no hay nada que elegir: la pantalla dibujaría una
     * lista vacía. Para un código postal plausible, que el proveedor no ofrezca
     * nada es que no lo conoce, y la salida es la misma: escribirnos. */
    if (opciones.length === 0) return { ok: false, motivo: 'codigo-postal' };
    return { ok: true, destino, opciones };
  } catch (e) {
    /* El proveedor real se cae. Que el camino exista desde hoy es la mitad del
     * punto de tener un puerto. Al log va el MENSAJE, que nunca lleva la URL:
     * el token de Envíopack viaja en ella. */
    console.error('cotizarEnvio:', e instanceof Error ? e.message : String(e));
    return { ok: false, motivo: 'proveedor-caido' };
  }
}
