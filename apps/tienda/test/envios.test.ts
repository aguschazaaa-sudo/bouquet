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
