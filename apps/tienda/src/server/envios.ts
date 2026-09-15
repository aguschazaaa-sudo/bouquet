'use server';

import {
  bultosDelPedido,
  centavos,
  esProvinciaIso,
  type Bulto,
  type DestinoDeEnvio,
  type OpcionDeEnvio,
  type ProveedorDeEnvio,
  type ProvinciaIso,
  type ResultadoDeCotizacion,
} from '@bouquet/contratos';

/**
 * El cotizador. HOY DEVUELVE NÚMEROS INVENTADOS, y está acá —en `server/`, la
 * frontera de credenciales— porque ahí es donde va a entrar el proveedor real:
 * Envíopack cotiza con una `api-key` + `secret-key` que no pueden viajar al
 * navegador.
 *
 * ⚠️ NINGÚN PRECIO DE ESTE ARCHIVO ES REAL. Están puestos para poder mirar la
 * pantalla, no para cobrar. Lo que sí es real es la FORMA: una lista de
 * opciones con precio, plazo y transportista, calculada sobre los bultos que
 * de verdad viajan. El día que el proveedor esté confirmado se reemplaza el
 * cuerpo de `CotizadorSimulado.cotizar` y la pantalla no se entera.
 *
 * Lo que Envíopack va a pedir, y por eso está todo junto acá
 * (docs/vault/architecture/proveedores/enviopack.md):
 *   GET /cotizar/precio/a-domicilio?access_token=…&provincia=X&codigo_postal=5000
 *       &peso=8.00&paquetes=18x24x34
 *   → { correo, valor: "44.85", horas_entrega: 72, … }
 *
 * `provincia` es el ISO sin prefijo y `paquetes` es alto×ancho×largo por bulto,
 * separados por coma: por eso `bultosDelPedido` devuelve una lista y no un peso.
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
 * más de una provincia. El proveedor real la resuelve con su webservice de
 * localidades; esto es el reemplazo barato hasta entonces.
 */
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
 * El precio no se duplica al duplicar las cajas: un correo cobra por escalón de
 * peso, y el segundo bulto del mismo envío sale menos que el primero. 0,6 es
 * inventado, pero la FORMA —sublineal, no proporcional— es la real.
 */
function porBultos(base: number, bultos: number) {
  return base * (1 + 0.6 * Math.max(0, bultos - 1));
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
          precio: aCentenas(porBultos(2500, bultos.length)),
          desdeDias: 2,
          hastaDias: 4,
          transportista: null,
        },
      ];
    }

    const lejos = factorDeDistancia(destino.codigoPostal);
    const base = porBultos(6900, bultos.length) * lejos;
    const dias = lejos > 1.5 ? 6 : lejos > 1.2 ? 4 : 3;

    return [
      {
        id: 'domicilio',
        modalidad: 'domicilio',
        nombre: 'Hasta tu puerta',
        detalle: `Llega en ${dias} a ${dias + 2} días hábiles.`,
        precio: aCentenas(base),
        desdeDias: dias,
        hastaDias: dias + 2,
        transportista: 'correo',
      },
      {
        id: 'sucursal',
        modalidad: 'sucursal',
        nombre: 'A una sucursal cerca',
        detalle: `Llega en ${dias + 1} a ${dias + 3} días hábiles. Lo retirás con documento.`,
        precio: aCentenas(base * 0.72),
        desdeDias: dias + 1,
        hastaDias: dias + 3,
        transportista: 'correo',
      },
    ];
  },
};

/**
 * Lo que llama la pantalla. Recibe el código postal y cuántas botellas hay en
 * el carrito —no cuántas cajas: las cajas las cuenta contratos—, y devuelve el
 * destino que pudo deducir más las opciones.
 *
 * El destino que vuelve es una SUGERENCIA: la localidad y la provincia quedan
 * editables en el formulario, porque una banda de CP cubre más de una
 * provincia y el que vive ahí sabe más que esta tabla.
 */
export async function cotizarEnvio(codigoPostal: string, botellas: number): Promise<ResultadoDeCotizacion> {
  const cp = String(codigoPostal ?? '').trim();
  if (!/^\d{4}$/.test(cp)) return { ok: false, motivo: 'codigo-postal' };
  if (!Number.isFinite(botellas) || botellas <= 0) return { ok: false, motivo: 'pedido-vacio' };

  /* ⚠️ El rango existe para que el estado "ese código postal no nos suena" SE
   * PUEDA DISPARAR. Sin él, cualquier número de cuatro cifras cotizaba —9999
   * incluido— y esa pantalla era UI que nadie podía abrir: se estrenaría el día
   * del proveedor real, que sí rechaza. Es una plausibilidad, no una validez:
   * los códigos argentinos van de 1000 (CABA) a ~9431 (Tierra del Fuego), y el
   * proveedor tiene la lista de verdad. */
  const numero = Number(cp);
  if (numero < 1000 || numero > 9431) return { ok: false, motivo: 'codigo-postal' };

  const propio = REPARTIMOS_NOSOTROS && cp in PUNILLA;
  const adivinada = BANDA[cp[0] as string];
  const deCordoba = propio || cp in PUNILLA;
  const provincia: ProvinciaIso = deCordoba ? 'X' : esProvinciaIso(adivinada) ? adivinada : 'B';

  const destino: DestinoDeEnvio = {
    codigoPostal: cp,
    localidad: PUNILLA[cp] ?? '',
    provincia,
    propio,
  };

  try {
    const opciones = await CotizadorSimulado.cotizar(destino, bultosDelPedido(botellas));
    return { ok: true, destino, opciones };
  } catch {
    /* El proveedor real se cae. Que el camino exista desde hoy es la mitad del
     * punto de tener un puerto. */
    return { ok: false, motivo: 'proveedor-caido' };
  }
}
