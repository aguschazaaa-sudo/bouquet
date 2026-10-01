import { test } from 'node:test';
import assert from 'node:assert/strict';

import { bultosDelPedido, type DestinoDeEnvio } from '@bouquet/contratos';

import { crearCotizadorEnviopack, type Pedir } from '../src/server/enviopack.ts';

/* El adaptador de Envíopack contra un Envíopack FALSO que contesta lo que dice
 * la documentación (https://developers.enviopack.com.ar/cotiza-un-envio).
 *
 * ⚠️ Esto prueba la TRADUCCIÓN, no el servicio: que lo que mandamos es lo que
 * la doc pide y que lo que la doc dice que vuelve se lee bien. Que Envíopack
 * conteste así de verdad se mide el día de las claves (ADR 030). */

const CLAVES = { apiKey: 'clave-de-prueba', secretKey: 'secreto-de-prueba' };

const CABA: DestinoDeEnvio = { codigoPostal: '1414', localidad: '', provincia: 'C', propio: false };

/** Doce botellas sueltas: dos cajas de seis, dos bultos de 8 kg. */
const DOS_CAJAS = bultosDelPedido({ sueltas: 12, propias: [] });

/** Una fila a domicilio que se lee bien para DOS_CAJAS. Cada caso rompe UN
 * campo: si rompiera dos, el test no sabría por cuál se descartó. */
const fila = (cambios: Record<string, unknown> = {}) => ({
  modalidad: 'D',
  servicio: 'N',
  peso_desde: '15.00',
  peso_hasta: '20.00',
  valor: '80.00',
  horas_entrega: 72,
  ...cambios,
});

/** El ejemplo de la doc para /cotizar/precio/a-domicilio, con UNA diferencia:
 * la banda. La doc cotiza 1,5 kg (banda de 1 a 2); acá van 16, y una banda que
 * no contiene el peso declarado se descarta. */
const EJEMPLO_DE_LA_DOC = [
  { modalidad: 'D', servicio: 'N', peso_desde: '15.00', peso_hasta: '20.00', valor: '80.00', horas_entrega: 96 },
  { modalidad: 'D', servicio: 'P', peso_desde: '15.00', peso_hasta: '20.00', valor: '120.00', horas_entrega: 24 },
];

const json = (cuerpo: unknown, status = 200) =>
  new Response(JSON.stringify(cuerpo), { status, headers: { 'content-type': 'application/json' } });

type Llamada = { readonly url: URL; readonly init: RequestInit | undefined };

/**
 * Un Envíopack en memoria. Cada /auth entrega un token NUEVO (`tok-1`, `tok-2`…)
 * para poder ver cuál viajó en cada cotización.
 */
function envioPackFalso(respuestas: { precio?: (llamada: Llamada) => Response; auth?: () => Response } = {}) {
  const llamadas: Llamada[] = [];
  let tokens = 0;
  const pedir: Pedir = async (url, init) => {
    const llamada = { url: new URL(String(url)), init };
    llamadas.push(llamada);
    if (llamada.url.pathname === '/auth') {
      return respuestas.auth ? respuestas.auth() : json({ access_token: `tok-${++tokens}` });
    }
    if (llamada.url.pathname === '/cotizar/precio/a-domicilio') {
      return respuestas.precio ? respuestas.precio(llamada) : json(EJEMPLO_DE_LA_DOC);
    }
    return new Response('ruta inventada', { status: 404 });
  };
  return {
    pedir,
    llamadas,
    auths: () => llamadas.filter((l) => l.url.pathname === '/auth'),
    cotizaciones: () => llamadas.filter((l) => l.url.pathname === '/cotizar/precio/a-domicilio'),
  };
}

test('con el ejemplo de la doc: UNA opcion a domicilio, la mas barata, en centavos enteros', async () => {
  const ep = envioPackFalso();
  const opciones = await crearCotizadorEnviopack(CLAVES, { fetch: ep.pedir }).cotizar(CABA, DOS_CAJAS);
  assert.equal(opciones.length, 1);
  const [o] = opciones;
  assert.equal(o?.id, 'domicilio');
  assert.equal(o?.modalidad, 'domicilio');
  // "80.00" -> 8000 centavos. El prioritario de "120.00" sale mas caro y no va.
  assert.equal(o?.precio, 8000);
  assert.ok(Number.isInteger(o?.precio));
  // 96 horas son 4 dias; el rango suma dos.
  assert.equal(o?.desdeDias, 4);
  assert.equal(o?.hastaDias, 6);
  assert.equal(o?.detalle, 'Llega en 4 a 6 días hábiles.');
  // La respuesta de PRECIO no trae el correo.
  assert.equal(o?.transportista, 'Envíopack');
});

test('la consulta lleva lo que pide la doc: provincia ISO, CP, peso TOTAL y un paquete por bulto', async () => {
  const ep = envioPackFalso();
  await crearCotizadorEnviopack(CLAVES, { fetch: ep.pedir }).cotizar(CABA, DOS_CAJAS);
  const [c] = ep.cotizaciones();
  assert.ok(c);
  assert.equal(c.url.origin, 'https://api.enviopack.com');
  const q = c.url.searchParams;
  assert.equal(q.get('provincia'), 'C');
  assert.equal(q.get('codigo_postal'), '1414');
  assert.equal(q.get('peso'), '16.00');
  // alto x ancho x largo, NO largo x ancho x alto: la caja es 34 x 24 x 18.
  assert.equal(q.get('paquetes'), '18x24x34,18x24x34');
  assert.equal(q.get('access_token'), 'tok-1');
});

test('/auth va por POST form-urlencoded con las dos claves', async () => {
  const ep = envioPackFalso();
  await crearCotizadorEnviopack(CLAVES, { fetch: ep.pedir }).cotizar(CABA, DOS_CAJAS);
  const [a] = ep.auths();
  assert.ok(a);
  assert.equal(a.init?.method, 'POST');
  assert.equal(new Headers(a.init?.headers).get('content-type'), 'application/x-www-form-urlencoded');
  const cuerpo = new URLSearchParams(String(a.init?.body));
  assert.equal(cuerpo.get('api-key'), 'clave-de-prueba');
  assert.equal(cuerpo.get('secret-key'), 'secreto-de-prueba');
});

test('el token se reusa: dos cotizaciones, UNA autenticacion', async () => {
  const ep = envioPackFalso();
  const cotizador = crearCotizadorEnviopack(CLAVES, { fetch: ep.pedir });
  await cotizador.cotizar(CABA, DOS_CAJAS);
  await cotizador.cotizar(CABA, DOS_CAJAS);
  assert.equal(ep.auths().length, 1);
  assert.deepEqual(
    ep.cotizaciones().map((c) => c.url.searchParams.get('access_token')),
    ['tok-1', 'tok-1'],
  );
});

test('dos cotizaciones A LA VEZ esperan la misma autenticacion', async () => {
  const ep = envioPackFalso();
  const cotizador = crearCotizadorEnviopack(CLAVES, { fetch: ep.pedir });
  await Promise.all([cotizador.cotizar(CABA, DOS_CAJAS), cotizador.cotizar(CABA, DOS_CAJAS)]);
  assert.equal(ep.auths().length, 1);
});

test('el token se renueva ANTES de las cuatro horas, no despues', async () => {
  const ep = envioPackFalso();
  let reloj = 0;
  const cotizador = crearCotizadorEnviopack(CLAVES, { fetch: ep.pedir, ahora: () => reloj });
  await cotizador.cotizar(CABA, DOS_CAJAS);
  reloj = 3 * 60 * 60 * 1000; // tres horas: sigue el mismo
  await cotizador.cotizar(CABA, DOS_CAJAS);
  assert.equal(ep.auths().length, 1);
  reloj = (4 * 60 - 10) * 60 * 1000; // diez minutos antes de vencer: otro
  await cotizador.cotizar(CABA, DOS_CAJAS);
  assert.equal(ep.auths().length, 2);
  assert.equal(ep.cotizaciones().at(-1)?.url.searchParams.get('access_token'), 'tok-2');
});

test('un 401 renueva el token y reintenta UNA vez', async () => {
  const ep = envioPackFalso({
    precio: (l) => (l.url.searchParams.get('access_token') === 'tok-1' ? json({ error: 'token' }, 401) : json(EJEMPLO_DE_LA_DOC)),
  });
  const opciones = await crearCotizadorEnviopack(CLAVES, { fetch: ep.pedir }).cotizar(CABA, DOS_CAJAS);
  assert.equal(opciones[0]?.precio, 8000);
  assert.equal(ep.auths().length, 2);
  assert.equal(ep.cotizaciones().length, 2);
});

test('dos rechazos seguidos ya no son el token: tira, y no reintenta para siempre', async () => {
  const ep = envioPackFalso({ precio: () => json({ error: 'token' }, 401) });
  await assert.rejects(crearCotizadorEnviopack(CLAVES, { fetch: ep.pedir }).cotizar(CABA, DOS_CAJAS));
  assert.equal(ep.cotizaciones().length, 2);
});

test('un 429 o un 500 TIRA: es proveedor caido, no una lista vacia', async () => {
  for (const status of [429, 500, 502]) {
    const ep = envioPackFalso({ precio: () => json({ error: 'x' }, status) });
    await assert.rejects(
      crearCotizadorEnviopack(CLAVES, { fetch: ep.pedir }).cotizar(CABA, DOS_CAJAS),
      new RegExp(String(status)),
    );
  }
});

test('un /auth que falla o no trae access_token tira', async () => {
  for (const auth of [() => json({ error: 'claves' }, 401), () => json({}), () => json({ access_token: '' })]) {
    const ep = envioPackFalso({ auth });
    await assert.rejects(crearCotizadorEnviopack(CLAVES, { fetch: ep.pedir }).cotizar(CABA, DOS_CAJAS));
    assert.equal(ep.cotizaciones().length, 0);
  }
});

test('el error no lleva las claves ni el token: va al log del servidor', async () => {
  const ep = envioPackFalso({ precio: () => json({ error: 'x' }, 500) });
  try {
    await crearCotizadorEnviopack(CLAVES, { fetch: ep.pedir }).cotizar(CABA, DOS_CAJAS);
    assert.fail('tenia que tirar');
  } catch (e) {
    const mensaje = e instanceof Error ? e.message : String(e);
    assert.match(mensaje, /500/); // control positivo: el mensaje dice algo
    for (const secreto of ['clave-de-prueba', 'secreto-de-prueba', 'tok-1', 'access_token']) {
      assert.ok(!mensaje.includes(secreto), `el mensaje lleva ${secreto}: ${mensaje}`);
    }
  }
});

test('cada fila ilegible se descarta POR SU MOTIVO, y si no queda ninguna TIRA con los motivos', async () => {
  const malas = [
    fila({ valor: 'abc' }),
    fila({ valor: '12.345' }), // tres decimales: dato roto
    fila({ valor: '-50.00' }),
    fila({ valor: '0.00' }), // el sin cargo lo decide bouquet (ADR 026)
    fila({ horas_entrega: undefined }),
    fila({ horas_entrega: 0 }),
    fila({ horas_entrega: '72' }), // texto: no se adivina que son horas
    fila({ modalidad: 'S' }), // a sucursal: no se ofrece todavia
    fila({ servicio: 'R' }), // devoluciones
    fila({ servicio: undefined }),
    fila({ peso_desde: '1.00', peso_hasta: '2.00' }), // la banda de otro envio
    fila({ peso_desde: 'x' }),
    null,
  ];
  const ep = envioPackFalso({ precio: () => json(malas) });
  await assert.rejects(crearCotizadorEnviopack(CLAVES, { fetch: ep.pedir }).cotizar(CABA, DOS_CAJAS), (e: Error) => {
    assert.match(e.message, /13 filas y ninguna sirve/);
    for (const motivo of ['precio: 4', 'plazo: 3', 'modalidad: 1', 'servicio: 2', 'peso: 2', 'forma: 1']) {
      assert.ok(e.message.includes(motivo), `falta "${motivo}" en: ${e.message}`);
    }
    return true;
  });

  // Control positivo: la misma lista con UNA buena devuelve esa, y no otra.
  const conUna = envioPackFalso({ precio: () => json([...malas, fila({ valor: '99.50', horas_entrega: 20 })]) });
  const [o, ...resto] = await crearCotizadorEnviopack(CLAVES, { fetch: conUna.pedir }).cotizar(CABA, DOS_CAJAS);
  assert.equal(resto.length, 0);
  assert.equal(o?.precio, 9950);
  // 20 horas son un dia, no cero.
  assert.equal(o?.desdeDias, 1);
});

test('la lista VACIA es la unica respuesta que vuelve vacia: es un codigo postal que no conocen', async () => {
  const ep = envioPackFalso({ precio: () => json([]) });
  assert.deepEqual(await crearCotizadorEnviopack(CLAVES, { fetch: ep.pedir }).cotizar(CABA, DOS_CAJAS), []);
});

test('una respuesta que NO es una lista tira: es otra forma, no un codigo postal', async () => {
  for (const cuerpo of [{ mensaje: 'sin cobertura' }, { data: [fila()] }, 'texto']) {
    const ep = envioPackFalso({ precio: () => json(cuerpo) });
    await assert.rejects(crearCotizadorEnviopack(CLAVES, { fetch: ep.pedir }).cotizar(CABA, DOS_CAJAS), /no devolvi/);
  }
});

test('una tarifa de DEVOLUCION mas barata no gana', async () => {
  const ep = envioPackFalso({ precio: () => json([fila({ servicio: 'R', valor: '30.00' }), fila({ valor: '50.00' })]) });
  const [o] = await crearCotizadorEnviopack(CLAVES, { fetch: ep.pedir }).cotizar(CABA, DOS_CAJAS);
  assert.equal(o?.precio, 5000);
});

test('la banda de peso tiene que contener lo declarado, con los dos bordes adentro', async () => {
  const ep = envioPackFalso({
    precio: () =>
      json([
        fila({ peso_desde: '1.00', peso_hasta: '2.00', valor: '10.00' }), // mas barata, otra banda
        fila({ peso_desde: '16.00', peso_hasta: '20.00', valor: '70.00' }), // 16 es el piso: vale
      ]),
  });
  const [o] = await crearCotizadorEnviopack(CLAVES, { fetch: ep.pedir }).cotizar(CABA, DOS_CAJAS);
  assert.equal(o?.precio, 7000);
});

test('si Enviopack lee el peso POR PAQUETE, todas caen por peso y el motivo lo dice', async () => {
  // Es la pregunta abierta de ADR 030: con 16 kg declarados, bandas de 8.
  const ep = envioPackFalso({ precio: () => json([fila({ peso_desde: '5.00', peso_hasta: '10.00' })]) });
  await assert.rejects(crearCotizadorEnviopack(CLAVES, { fetch: ep.pedir }).cotizar(CABA, DOS_CAJAS), /peso: 1/);
});

test('una fila sin banda de peso no tiene nada que comparar: vale', async () => {
  const ep = envioPackFalso({ precio: () => json([fila({ peso_desde: undefined, peso_hasta: undefined })]) });
  const [o] = await crearCotizadorEnviopack(CLAVES, { fetch: ep.pedir }).cotizar(CABA, DOS_CAJAS);
  assert.equal(o?.precio, 8000);
});

test('a igual precio gana la que tarda MENOS, no la primera de la lista', async () => {
  const ep = envioPackFalso({ precio: () => json([fila({ horas_entrega: 120 }), fila({ horas_entrega: 48 })]) });
  const [o] = await crearCotizadorEnviopack(CLAVES, { fetch: ep.pedir }).cotizar(CABA, DOS_CAJAS);
  assert.equal(o?.desdeDias, 2);
});

test('cada pedido a Enviopack lleva su limite de tiempo', async () => {
  // Sin `signal`, un Enviopack colgado deja al comprador en "cotizando..." para
  // siempre. No se espera el timeout real (5 s): se mide que viaja.
  const ep = envioPackFalso();
  await crearCotizadorEnviopack(CLAVES, { fetch: ep.pedir }).cotizar(CABA, DOS_CAJAS);
  assert.equal(ep.llamadas.length, 2);
  for (const l of ep.llamadas) assert.ok(l.init?.signal instanceof AbortSignal, `${l.url.pathname} sin signal`);
});

test('una autenticacion que falla con dos esperandola no queda pegada: la siguiente reintenta', async () => {
  let intentos = 0;
  const ep = envioPackFalso({
    auth: () => (++intentos === 1 ? json({ error: 'x' }, 500) : json({ access_token: 'tok-bueno' })),
  });
  const cotizador = crearCotizadorEnviopack(CLAVES, { fetch: ep.pedir });
  const juntas = await Promise.allSettled([cotizador.cotizar(CABA, DOS_CAJAS), cotizador.cotizar(CABA, DOS_CAJAS)]);
  assert.deepEqual(
    juntas.map((r) => r.status),
    ['rejected', 'rejected'],
  );
  assert.equal(ep.auths().length, 1);
  const [o] = await cotizador.cotizar(CABA, DOS_CAJAS);
  assert.equal(o?.precio, 8000);
  assert.equal(ep.auths().length, 2);
});

test('el reparto propio no se le pregunta a un correo', async () => {
  const ep = envioPackFalso();
  await assert.rejects(
    crearCotizadorEnviopack(CLAVES, { fetch: ep.pedir }).cotizar({ ...CABA, propio: true }, DOS_CAJAS),
  );
  assert.equal(ep.llamadas.length, 0);
});

test('sin bultos no se llama a nadie', async () => {
  const ep = envioPackFalso();
  assert.deepEqual(await crearCotizadorEnviopack(CLAVES, { fetch: ep.pedir }).cotizar(CABA, []), []);
  assert.equal(ep.llamadas.length, 0);
});
