import { test } from 'node:test';
import assert from 'node:assert/strict';

import type { CargaDelPedido } from '@bouquet/contratos';

import { cotizarEnvio } from '../src/server/envios.ts';

/** Botellas sueltas, que es lo que median estos casos. */
const sueltas = (n: number): CargaDelPedido => ({ sueltas: n, propias: [] });

/* El cotizador simulado. Los PRECIOS son inventados y estos tests no los
 * fijan: fijan la FORMA, que es lo que no puede cambiar el día que atrás haya
 * un proveedor de verdad.
 *
 * El caso que motivó el archivo es el de las dos cajas: la maqueta cotizaba
 * siempre un pedido de seis, así que un pedido de doce viajaba gratis la mitad. */

test('HOY Punilla tambien sale por correo: el reparto propio esta apagado', async () => {
  // `REPARTIMOS_NOSOTROS = false` (decision del dueno, 2026-09-15). Lo que
  // queda de la tabla de Punilla es el prellenado de la localidad.
  const r = await cotizarEnvio('5176', sueltas(6));
  assert.ok(r.ok);
  assert.equal(r.destino.propio, false);
  assert.equal(r.destino.localidad, 'Villa Giardino');
  assert.equal(r.destino.provincia, 'X');
  assert.equal(r.opciones.length, 2);
  assert.ok(r.opciones.every((o) => o.modalidad !== 'propio'));
});

test('un codigo postal de afuera va por correo, con dos formas de recibirlo', async () => {
  const r = await cotizarEnvio('1425', sueltas(6));
  assert.ok(r.ok);
  assert.equal(r.destino.propio, false);
  assert.deepEqual(
    r.opciones.map((o) => o.modalidad),
    ['domicilio', 'sucursal'],
  );
  // A sucursal siempre sale menos: es la razon por la que la opcion existe.
  assert.ok((r.opciones[1]?.precio ?? 0) < (r.opciones[0]?.precio ?? 0));
});

test('DOCE botellas cuestan mas que seis: son dos cajas', async () => {
  const seis = await cotizarEnvio('1425', sueltas(6));
  const doce = await cotizarEnvio('1425', sueltas(12));
  assert.ok(seis.ok && doce.ok);
  const unaCaja = seis.opciones[0]?.precio ?? 0;
  const dosCajas = doce.opciones[0]?.precio ?? 0;
  assert.ok(dosCajas > unaCaja, `dos cajas (${dosCajas}) no salen mas que una (${unaCaja})`);
  // Y NO el doble: un correo cobra por escalon de peso, no por bulto.
  assert.ok(dosCajas < unaCaja * 2);
});

test('lejos sale mas caro que cerca, y tarda mas', async () => {
  const cerca = await cotizarEnvio('5000', sueltas(6)); // Cordoba
  const lejos = await cotizarEnvio('9410', sueltas(6)); // Ushuaia
  assert.ok(cerca.ok && lejos.ok);
  assert.ok((lejos.opciones[0]?.precio ?? 0) > (cerca.opciones[0]?.precio ?? 0));
  assert.ok((lejos.opciones[0]?.desdeDias ?? 0) > (cerca.opciones[0]?.desdeDias ?? 0));
});

test('nadie queda fuera de zona: un codigo postal cualquiera cotiza igual', async () => {
  // El glosario decia que una direccion fuera de toda zona NO PUEDE COMPRAR.
  // Con envio a todo el pais eso dejo de ser cierto, y este test lo fija.
  for (const cp of ['9410', '3300', '8324', '4400']) {
    const r = await cotizarEnvio(cp, sueltas(6));
    assert.ok(r.ok, `${cp} no cotizo`);
    assert.ok(r.opciones.length > 0);
  }
});

test('un codigo postal que no son cuatro digitos no cotiza', async () => {
  for (const cp of ['517', '51766', 'X5176', '']) {
    const r = await cotizarEnvio(cp, sueltas(6));
    assert.equal(r.ok, false, `acepto ${cp}`);
    assert.equal(r.ok === false && r.motivo, 'codigo-postal');
  }
});

test('un numero de cuatro cifras que NO es un codigo postal argentino no cotiza', async () => {
  // Existe para que el estado "ese codigo postal no nos suena" se pueda mirar.
  // Control positivo al lado: 9410 (Ushuaia) es el borde y SI cotiza.
  const inventado = await cotizarEnvio('9999', sueltas(6));
  assert.equal(inventado.ok, false);
  assert.equal(inventado.ok === false && inventado.motivo, 'codigo-postal');
  const borde = await cotizarEnvio('9410', sueltas(6));
  assert.ok(borde.ok);
  const abajo = await cotizarEnvio('0999', sueltas(6));
  assert.equal(abajo.ok, false);
});

test('un carrito vacio no cotiza: no hay nada que despachar', async () => {
  const r = await cotizarEnvio('5176', sueltas(0));
  assert.equal(r.ok, false);
  assert.equal(r.ok === false && r.motivo, 'pedido-vacio');
});

test('un pedido de SOLO packs cotiza: cada uno es un bulto', async () => {
  // Cero botellas sueltas ya no es un pedido vacio. Con la firma vieja
  // -un solo numero de botellas- este pedido no existia: o se aplanaba a 2 y
  // se cotizaba una caja de seis, o daba `pedido-vacio`.
  const r = await cotizarEnvio('1425', { sueltas: 0, propias: [2] });
  assert.ok(r.ok);
  assert.ok(r.opciones.length > 0);
});

test('un pack NO sale lo mismo que una caja de seis', async () => {
  const pack = await cotizarEnvio('1425', { sueltas: 0, propias: [2] });
  const caja = await cotizarEnvio('1425', sueltas(6));
  assert.ok(pack.ok && caja.ok);
  assert.ok(
    (pack.opciones[0]?.precio ?? 0) < (caja.opciones[0]?.precio ?? 0),
    'dos botellas empacadas pesan menos que seis',
  );
});

test('tres packs cuestan mas que uno: son tres bultos', async () => {
  const uno = await cotizarEnvio('1425', { sueltas: 0, propias: [2] });
  const tres = await cotizarEnvio('1425', { sueltas: 0, propias: [2, 2, 2] });
  assert.ok(uno.ok && tres.ok);
  assert.ok((tres.opciones[0]?.precio ?? 0) > (uno.opciones[0]?.precio ?? 0));
});

test('una carga inventada por el navegador se sanea antes de armar bultos', async () => {
  // Es una Server Action: la entrada es publica. Lo que no es un entero
  // razonable se cae, y si no queda nada es un pedido vacio.
  const basura = await cotizarEnvio('1425', {
    sueltas: -5,
    propias: [0, 1, 1.5, -2, 'x', null] as unknown as number[],
  });
  assert.equal(basura.ok, false);
  assert.equal(basura.ok === false && basura.motivo, 'pedido-vacio');

  // Control positivo: la misma carga con UN pack valido adentro si cotiza.
  const conUno = await cotizarEnvio('1425', {
    sueltas: 0,
    propias: [0, 2, 'x'] as unknown as number[],
  });
  assert.ok(conUno.ok);
});

test('el precio es un entero de centavos, nunca un float', async () => {
  const r = await cotizarEnvio('1425', sueltas(12));
  assert.ok(r.ok);
  for (const o of r.opciones) {
    assert.ok(Number.isInteger(o.precio), `${o.id} vino ${o.precio}`);
  }
});

/* ------------------------------------------------- quien contesta (ADR 030)
 *
 * El entorno decide: con las DOS claves de Enviopack contesta Enviopack; sin
 * ninguna, el simulado. Cada caso deja el entorno y el `fetch` como estaban,
 * porque los de arriba miden el simulado y corren en el mismo proceso. */

async function conEntorno(claves: Record<string, string>, cuerpo: () => Promise<void>) {
  const antes = { ...process.env };
  const fetchDeAntes = globalThis.fetch;
  Object.assign(process.env, claves);
  try {
    await cuerpo();
  } finally {
    for (const k of Object.keys(claves)) {
      if (antes[k] === undefined) delete process.env[k];
      else process.env[k] = antes[k];
    }
    globalThis.fetch = fetchDeAntes;
  }
}

/** Un Enviopack falso en el `fetch` global: lo que vea el adaptador es esto.
 * Devuelve las URLs pedidas, para mirar QUE viajo. */
function envioPackGlobal(filas: unknown) {
  const pedidos: URL[] = [];
  globalThis.fetch = (async (url: string | URL) => {
    const u = new URL(String(url));
    pedidos.push(u);
    if (u.pathname === '/auth') return Response.json({ access_token: 'tok' });
    return Response.json(filas);
  }) as unknown as typeof fetch;
  return pedidos;
}

const CLAVES = { ENVIOPACK_API_KEY: 'k', ENVIOPACK_SECRET_KEY: 's' };
const UNA_FILA = [{ modalidad: 'D', servicio: 'N', valor: '4321.00', horas_entrega: 72 }];

/** La provincia que recibio Enviopack en la ultima cotizacion. */
const provinciaEnviada = (pedidos: readonly URL[]) =>
  pedidos.filter((u) => u.pathname === '/cotizar/precio/a-domicilio').at(-1)?.searchParams.get('provincia');

test('con UNA sola clave NO cotiza con numeros inventados: es proveedor caido', async () => {
  for (const claves of [{ ENVIOPACK_API_KEY: 'k' }, { ENVIOPACK_SECRET_KEY: 's' }]) {
    await conEntorno(claves, async () => {
      const pedidos = envioPackGlobal([]);
      const r = await cotizarEnvio('1425', sueltas(6));
      assert.equal(r.ok, false, `con ${Object.keys(claves)} cotizo igual`);
      assert.equal(r.ok === false && r.motivo, 'proveedor-caido');
      assert.equal(pedidos.length, 0);
    });
  }
});

test('con las DOS claves contesta Enviopack, no el simulado', async () => {
  await conEntorno(CLAVES, async () => {
    const pedidos = envioPackGlobal(UNA_FILA);
    const r = await cotizarEnvio('1425', sueltas(6));
    assert.ok(r.ok);
    // Una sola opcion, a domicilio, con el precio de Enviopack. El simulado
    // devuelve dos y redondea a centenas: 432100 no sale de el.
    assert.deepEqual(
      r.opciones.map((o) => [o.modalidad, o.precio]),
      [['domicilio', 432100]],
    );
    assert.ok(pedidos.some((u) => u.pathname === '/cotizar/precio/a-domicilio'));
  });
});

test('si Enviopack no ofrece nada, es un codigo postal que no conocemos', async () => {
  await conEntorno(CLAVES, async () => {
    envioPackGlobal([]);
    const r = await cotizarEnvio('1425', sueltas(6));
    assert.equal(r.ok, false);
    assert.equal(r.ok === false && r.motivo, 'codigo-postal');
  });
});

test('sin ninguna clave vuelve el simulado, y no sale a la red', async () => {
  // Control de que `conEntorno` deja todo como estaba: es lo que miden los de
  // arriba, y si las claves quedaran puestas cotizarian contra el falso.
  const fetchDeAntes = globalThis.fetch;
  const pedidos = envioPackGlobal([]);
  try {
    const r = await cotizarEnvio('1425', sueltas(6));
    assert.ok(r.ok);
    assert.equal(r.opciones.length, 2);
    assert.equal(pedidos.length, 0);
  } finally {
    globalThis.fetch = fetchDeAntes;
  }
});

test('si Enviopack contesta algo que no se puede leer, es proveedor caido y NO codigo postal', async () => {
  // Leido como CP desconocido, todos verian "no nos suena" y el log, vacio.
  await conEntorno(CLAVES, async () => {
    envioPackGlobal({ data: UNA_FILA });
    const r = await cotizarEnvio('1425', sueltas(6));
    assert.equal(r.ok === false && r.motivo, 'proveedor-caido');
  });
});

test('del 1000 al 1499 es la CIUDAD, no la provincia de Buenos Aires', async () => {
  for (const [cp, iso] of [
    ['1000', 'C'],
    ['1425', 'C'],
    ['1499', 'C'],
    ['1500', 'B'], // control: el primero de afuera
    ['1900', 'B'],
  ]) {
    const r = await cotizarEnvio(cp as string, sueltas(6));
    assert.ok(r.ok, `${cp} no cotizo`);
    assert.equal(r.destino.provincia, iso, `${cp} dio ${r.destino.provincia}`);
  }
});

test('Enviopack recibe la provincia ADIVINADA solo si nadie la eligio', async () => {
  await conEntorno(CLAVES, async () => {
    const pedidos = envioPackGlobal(UNA_FILA);

    await cotizarEnvio('5500', sueltas(6)); // Mendoza, que la banda adivina Cordoba
    assert.equal(provinciaEnviada(pedidos), 'X');

    // El comprador la corrige: viaja la suya, y vuelve en el destino.
    const corregida = await cotizarEnvio('5500', sueltas(6), 'M');
    assert.equal(provinciaEnviada(pedidos), 'M');
    assert.ok(corregida.ok);
    assert.equal(corregida.destino.provincia, 'M');

    // Lo que no es un ISO no se cree: se adivina.
    for (const basura of ['ZZ', '', 'm', ' M']) {
      await cotizarEnvio('5500', sueltas(6), basura);
      assert.equal(provinciaEnviada(pedidos), 'X', `con "${basura}" viajo otra cosa`);
    }
  });
});
