import { test } from 'node:test';
import assert from 'node:assert/strict';

import { cotizarEnvio } from '../src/server/envios.ts';

/* El cotizador simulado. Los PRECIOS son inventados y estos tests no los
 * fijan: fijan la FORMA, que es lo que no puede cambiar el día que atrás haya
 * un proveedor de verdad.
 *
 * El caso que motivó el archivo es el de las dos cajas: la maqueta cotizaba
 * siempre un pedido de seis, así que un pedido de doce viajaba gratis la mitad. */

test('HOY Punilla tambien sale por correo: el reparto propio esta apagado', async () => {
  // `REPARTIMOS_NOSOTROS = false` (decision del dueno, 2026-09-15). Lo que
  // queda de la tabla de Punilla es el prellenado de la localidad.
  const r = await cotizarEnvio('5176', 6);
  assert.ok(r.ok);
  assert.equal(r.destino.propio, false);
  assert.equal(r.destino.localidad, 'Villa Giardino');
  assert.equal(r.destino.provincia, 'X');
  assert.equal(r.opciones.length, 2);
  assert.ok(r.opciones.every((o) => o.modalidad !== 'propio'));
});

test('un codigo postal de afuera va por correo, con dos formas de recibirlo', async () => {
  const r = await cotizarEnvio('1425', 6);
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
  const seis = await cotizarEnvio('1425', 6);
  const doce = await cotizarEnvio('1425', 12);
  assert.ok(seis.ok && doce.ok);
  const unaCaja = seis.opciones[0]?.precio ?? 0;
  const dosCajas = doce.opciones[0]?.precio ?? 0;
  assert.ok(dosCajas > unaCaja, `dos cajas (${dosCajas}) no salen mas que una (${unaCaja})`);
  // Y NO el doble: un correo cobra por escalon de peso, no por bulto.
  assert.ok(dosCajas < unaCaja * 2);
});

test('lejos sale mas caro que cerca, y tarda mas', async () => {
  const cerca = await cotizarEnvio('5000', 6); // Cordoba
  const lejos = await cotizarEnvio('9410', 6); // Ushuaia
  assert.ok(cerca.ok && lejos.ok);
  assert.ok((lejos.opciones[0]?.precio ?? 0) > (cerca.opciones[0]?.precio ?? 0));
  assert.ok((lejos.opciones[0]?.desdeDias ?? 0) > (cerca.opciones[0]?.desdeDias ?? 0));
});

test('nadie queda fuera de zona: un codigo postal cualquiera cotiza igual', async () => {
  // El glosario decia que una direccion fuera de toda zona NO PUEDE COMPRAR.
  // Con envio a todo el pais eso dejo de ser cierto, y este test lo fija.
  for (const cp of ['9410', '3300', '8324', '4400']) {
    const r = await cotizarEnvio(cp, 6);
    assert.ok(r.ok, `${cp} no cotizo`);
    assert.ok(r.opciones.length > 0);
  }
});

test('un codigo postal que no son cuatro digitos no cotiza', async () => {
  for (const cp of ['517', '51766', 'X5176', '']) {
    const r = await cotizarEnvio(cp, 6);
    assert.equal(r.ok, false, `acepto ${cp}`);
    assert.equal(r.ok === false && r.motivo, 'codigo-postal');
  }
});

test('un numero de cuatro cifras que NO es un codigo postal argentino no cotiza', async () => {
  // Existe para que el estado "ese codigo postal no nos suena" se pueda mirar.
  // Control positivo al lado: 9410 (Ushuaia) es el borde y SI cotiza.
  const inventado = await cotizarEnvio('9999', 6);
  assert.equal(inventado.ok, false);
  assert.equal(inventado.ok === false && inventado.motivo, 'codigo-postal');
  const borde = await cotizarEnvio('9410', 6);
  assert.ok(borde.ok);
  const abajo = await cotizarEnvio('0999', 6);
  assert.equal(abajo.ok, false);
});

test('un carrito vacio no cotiza: no hay nada que despachar', async () => {
  const r = await cotizarEnvio('5176', 0);
  assert.equal(r.ok, false);
  assert.equal(r.ok === false && r.motivo, 'pedido-vacio');
});

test('el precio es un entero de centavos, nunca un float', async () => {
  const r = await cotizarEnvio('1425', 12);
  assert.ok(r.ok);
  for (const o of r.opciones) {
    assert.ok(Number.isInteger(o.precio), `${o.id} vino ${o.precio}`);
  }
});
