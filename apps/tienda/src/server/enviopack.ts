import {
  desdePesos,
  type Bulto,
  type Centavos,
  type DestinoDeEnvio,
  type OpcionDeEnvio,
  type ProveedorDeEnvio,
} from '@bouquet/contratos';

import { aDomicilio } from './opciones-de-envio.ts';

/**
 * El cotizador de Envíopack: el adaptador real del puerto `ProveedorDeEnvio`
 * (ADR 030). https://developers.enviopack.com.ar/cotiza-un-envio
 *
 * NO SE PRENDE SOLO. `envios.ts` lo usa cuando están las DOS claves en el
 * entorno —`ENVIOPACK_API_KEY` y `ENVIOPACK_SECRET_KEY`, secretos de App
 * Hosting—; sin ninguna sigue contestando el simulado.
 *
 * ⚠️ ESCRITO CONTRA LA DOCUMENTACIÓN, SIN CUENTA. Los tests prueban la
 * traducción contra los ejemplos de la doc, no que Envíopack conteste así. Lo
 * que no se sabe hasta tener las claves está en la tabla de ADR 030.
 *
 * Cotiza el PRECIO —lo que paga el comprador, según las tarifas que el dueño
 * fija en el panel de Envíopack, "Correos y Tarifas"— y no el COSTO, que es lo
 * que paga bouquet. Son dos endpoints distintos, y mostrarle al comprador el
 * costo es regalar el margen que el dueño haya puesto ahí.
 *
 * ⚠️ HOY SÓLO A DOMICILIO. A sucursal pide el id de localidad de Envíopack, que
 * no se busca por código postal, y el comprador tendría que ELEGIR la sucursal:
 * es otra pantalla, y su forma depende de una respuesta que todavía nadie vio.
 */

const BASE = 'https://api.enviopack.com';

/** El token dura cuatro horas. Se pide otro quince minutos antes: uno que
 * vence en el medio de una cotización es un "proveedor caído" que no lo es. */
const VIDA_DEL_TOKEN_MS = (4 * 60 - 15) * 60 * 1000;

/** Lo que se espera antes de decir que el proveedor no contesta. La pantalla
 * ya muestra "cotizando…"; más que esto, el comprador se va. */
const PACIENCIA_MS = 5000;

/** Ningún correo promete un día: el plazo se muestra como rango. */
const MARGEN_DE_DIAS = 2;

export type Credenciales = { readonly apiKey: string; readonly secretKey: string };

/** Lo único de `fetch` que se usa. Un tipo propio y no `typeof fetch`, que trae
 * las sobrecargas del DOM y de Node juntas. */
export type Pedir = (url: string | URL, init?: RequestInit) => Promise<Response>;

/** Inyectables para los tests. En producción, el `fetch` global y el reloj. */
export type Dependencias = {
  readonly fetch?: Pedir;
  readonly ahora?: () => number;
};

export function crearCotizadorEnviopack({ apiKey, secretKey }: Credenciales, deps: Dependencias = {}): ProveedorDeEnvio {
  /* El global se resuelve en cada llamada, no al crear: así un test que lo
   * reemplaza después de que el módulo ya armó el cotizador lo ve igual. */
  const pedir: Pedir = deps.fetch ?? ((url, init) => globalThis.fetch(url, init));
  const ahora = deps.ahora ?? Date.now;

  let token: { readonly valor: string; readonly vence: number } | null = null;
  /* Dos cotizaciones que llegan juntas con el token vencido esperan la MISMA
   * autenticación: sin esto, cada una pide la suya. */
  let autenticando: Promise<string> | null = null;

  async function autenticar(): Promise<string> {
    const pedido = ahora();
    const r = await pedir(`${BASE}/auth`, {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({ 'api-key': apiKey, 'secret-key': secretKey }).toString(),
      signal: AbortSignal.timeout(PACIENCIA_MS),
    });
    // ⚠️ Ningún mensaje de error lleva la URL ni el cuerpo: van al log del servidor.
    if (!r.ok) throw new Error(`Envíopack /auth respondió ${r.status}`);
    const cuerpo = (await r.json()) as { access_token?: unknown } | null;
    const valor = cuerpo?.access_token;
    if (typeof valor !== 'string' || valor === '') throw new Error('Envíopack /auth no devolvió access_token');
    token = { valor, vence: pedido + VIDA_DEL_TOKEN_MS };
    return valor;
  }

  function tokenVigente(): Promise<string> {
    if (token !== null && ahora() < token.vence) return Promise.resolve(token.valor);
    autenticando ??= autenticar().finally(() => {
      autenticando = null;
    });
    return autenticando;
  }

  async function precioADomicilio(consulta: URLSearchParams): Promise<Response> {
    const url = new URL('/cotizar/precio/a-domicilio', BASE);
    url.search = consulta.toString();
    /* El token viaja en la query, no en un header: es lo que pide Envíopack.
     * ⚠️ Por eso la URL es un secreto. Hoy no hay `instrumentation.ts`; el día
     * que alguien registre OpenTelemetry, Next arma un span `fetch GET <url>`
     * con la URL entera y el token termina en Cloud Trace. Antes de eso:
     * `NEXT_OTEL_FETCH_DISABLED=1`, o sacarle la query al span. */
    url.searchParams.set('access_token', await tokenVigente());
    return pedir(url, { signal: AbortSignal.timeout(PACIENCIA_MS) });
  }

  return {
    async cotizar(destino: DestinoDeEnvio, bultos: readonly Bulto[]): Promise<readonly OpcionDeEnvio[]> {
      // El reparto propio es la tabla de bouquet, no algo que cotice un correo.
      if (destino.propio) throw new Error('el reparto propio no lo cotiza Envíopack');
      if (bultos.length === 0) return [];

      const kg = pesoTotalKg(bultos);
      const consulta = consultaDePrecio(destino, bultos, kg);
      let r = await precioADomicilio(consulta);
      /* Un token rechazado antes de su hora —lo revocaron, o el reloj de
       * Envíopack no es el nuestro— se renueva UNA vez. Dos rechazos seguidos
       * ya no son el token. */
      if (r.status === 401 || r.status === 403) {
        token = null;
        r = await precioADomicilio(consulta);
      }
      if (!r.ok) throw new Error(`Envíopack /cotizar/precio/a-domicilio respondió ${r.status}`);

      /* ⚠️ La lista VACÍA es la única respuesta que se lee como "no conocemos ese
       * código postal". Algo que no es una lista, o una lista de la que no se
       * puede leer ninguna fila, es que Envíopack contesta con otra forma: TIRA,
       * y va al log con el motivo. Leído como CP desconocido, todos los
       * compradores verían "no nos suena" y el log quedaría vacío. */
      const filas: unknown = await r.json();
      if (!Array.isArray(filas)) throw new Error('Envíopack /cotizar/precio/a-domicilio no devolvió una lista');
      if (filas.length === 0) return [];
      const { opcion, descartes } = laMasBarata(filas, kg);
      if (opcion === null) {
        const porque = Object.entries(descartes)
          .map(([motivo, n]) => `${motivo}: ${n}`)
          .join(', ');
        throw new Error(`Envíopack devolvió ${filas.length} filas y ninguna sirve (${porque})`);
      }
      return [opcion];
    },
  };
}

function pesoTotalKg(bultos: readonly Bulto[]): number {
  return bultos.reduce((total, b) => total + b.pesoKg, 0);
}

/**
 * Lo que pide la doc. `provincia` es el ISO sin `AR-` —el mismo código que ya
 * viaja en `DestinoDeEnvio`, cero traducción—; `peso` es el TOTAL en kg con dos
 * decimales, y `paquetes` lleva un alto×ancho×largo por bulto, separados por
 * coma. Es la razón por la que `bultosDelPedido` devuelve una lista.
 */
function consultaDePrecio(destino: DestinoDeEnvio, bultos: readonly Bulto[], kg: number): URLSearchParams {
  return new URLSearchParams({
    provincia: destino.provincia,
    codigo_postal: destino.codigoPostal,
    peso: kg.toFixed(2),
    paquetes: bultos.map((b) => `${b.altoCm}x${b.anchoCm}x${b.largoCm}`).join(','),
  });
}

/** Estándar, prioritario y express. La doc lista también `R`, DEVOLUCIONES:
 * una tarifa de devolución más barata que la estándar no es un envío. */
const SERVICIOS_DE_ENTREGA: readonly unknown[] = ['N', 'P', 'X'];

type MotivoDeDescarte = 'forma' | 'modalidad' | 'servicio' | 'precio' | 'plazo' | 'peso';

type Lectura =
  | { readonly ok: true; readonly opcion: OpcionDeEnvio; readonly horas: number }
  | { readonly ok: false; readonly motivo: MotivoDeDescarte };

/**
 * Una sola opción a domicilio: la más barata de los servicios de entrega; a
 * igual precio, la que tarda menos. La pantalla ofrece una forma por modalidad;
 * elegir entre correos es trabajo del agregador, no del comprador (ADR 010).
 *
 * Una fila que no se puede leer SE DESCARTA, no se adivina, y se cuenta por
 * qué: si no queda ninguna, el motivo va al log (arriba).
 *
 * ⚠️ El precio en cero también se descarta. La entrega sin cargo la decide bouquet desde
 * `config/envios` (ADR 026), no la tarifa de un proveedor: un `"0.00"` de
 * Envíopack es más probablemente una tarifa sin cargar que un regalo.
 */
function laMasBarata(
  filas: readonly unknown[],
  kg: number,
): { opcion: OpcionDeEnvio | null; descartes: Partial<Record<MotivoDeDescarte, number>> } {
  let mejor: { opcion: OpcionDeEnvio; horas: number } | null = null;
  const descartes: Partial<Record<MotivoDeDescarte, number>> = {};
  for (const fila of filas) {
    const leida = leerFila(fila, kg);
    if (!leida.ok) {
      descartes[leida.motivo] = (descartes[leida.motivo] ?? 0) + 1;
      continue;
    }
    if (
      mejor === null ||
      leida.opcion.precio < mejor.opcion.precio ||
      (leida.opcion.precio === mejor.opcion.precio && leida.horas < mejor.horas)
    ) {
      mejor = leida;
    }
  }
  return { opcion: mejor?.opcion ?? null, descartes };
}

function leerFila(fila: unknown, kg: number): Lectura {
  if (typeof fila !== 'object' || fila === null) return { ok: false, motivo: 'forma' };
  const f = fila as Record<string, unknown>;
  if (f.modalidad !== 'D') return { ok: false, motivo: 'modalidad' };
  if (!SERVICIOS_DE_ENTREGA.includes(f.servicio)) return { ok: false, motivo: 'servicio' };

  /* ⚠️ La tarifa tiene que ser la del peso que se declaró. Una fila de la banda
   * de 1 a 2 kg para un pedido de 16 no es este envío. Y es además la pregunta
   * abierta de ADR 030: si Envíopack lee `peso` POR PAQUETE y no total, las
   * bandas vuelven alrededor de 8 kg, todas se descartan por `peso`, y el log
   * lo dice el primer día. Sin banda en la fila, no hay nada que comparar. */
  if (!pesoEnLaBanda(kg, f.peso_desde, f.peso_hasta)) return { ok: false, motivo: 'peso' };

  const precio = precioDe(f.valor);
  if (precio === null) return { ok: false, motivo: 'precio' };

  /* `horas_entrega` son HORAS, no días ni una fecha. 72 h son 3 días; 20 h, 1. */
  const horas = f.horas_entrega;
  if (typeof horas !== 'number' || !Number.isFinite(horas) || horas <= 0) return { ok: false, motivo: 'plazo' };
  const desdeDias = Math.ceil(horas / 24);

  /* La respuesta de PRECIO no trae el correo (la de costo sí). Si algún día lo
   * trae, viaja para el panel; si no, quien lo lleva es Envíopack. */
  const correo = f.correo as { nombre?: unknown } | null | undefined;
  const transportista = typeof correo?.nombre === 'string' && correo.nombre !== '' ? correo.nombre : 'Envíopack';

  return {
    ok: true,
    opcion: aDomicilio({ precio, desdeDias, hastaDias: desdeDias + MARGEN_DE_DIAS, transportista }),
    horas,
  };
}

/** Los bordes cuentan los dos: si 2 kg es el techo de una banda y el piso de la
 * siguiente, cualquiera de las dos es una tarifa de 2 kg. */
function pesoEnLaBanda(kg: number, desde: unknown, hasta: unknown): boolean {
  if (desde === undefined && hasta === undefined) return true;
  const piso = kilos(desde);
  const techo = kilos(hasta);
  return piso !== null && techo !== null && piso <= kg && kg <= techo;
}

function kilos(x: unknown): number | null {
  if (typeof x === 'number') return Number.isFinite(x) ? x : null;
  if (typeof x !== 'string' || !/^\d+(\.\d+)?$/.test(x.trim())) return null;
  return Number(x);
}

/** `valor` viene como TEXTO ("80.00"). `desdePesos` lo parsea como texto, sin
 * pasar por un float, y tira con más de dos decimales: eso es un dato roto, no
 * algo a redondear. */
function precioDe(valor: unknown): Centavos | null {
  if (typeof valor !== 'string' && typeof valor !== 'number') return null;
  try {
    const precio = desdePesos(valor);
    return precio > 0 ? precio : null;
  } catch {
    return null;
  }
}
