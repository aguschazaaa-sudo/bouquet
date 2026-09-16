/**
 * La entrega: bultos, total y los datos que escribe el comprador.
 */

import { test } from 'node:test';
import assert from 'node:assert/strict';

import { BOTELLAS_POR_CAJA, type CargaDelPedido } from '../src/carrito.ts';
import { centavos } from '../src/dinero.ts';
import {
  CAJA_KG,
  bultosDelPedido,
  cajasADespachar,
  normalizarTelefonoAR,
  pesoDelBultoKg,
  pesoDelPedidoKg,
  totalConEnvio,
  validarDatosDeEntrega,
} from '../src/envio.ts';

/** Una carga de solo botellas sueltas, que es lo que median estos tests. */
const sueltas = (n: number): CargaDelPedido => ({ sueltas: n, propias: [] });

function entrega(cambios: Record<string, unknown> = {}) {
  return {
    nombre: 'Agustin Chazarreta',
    telefono: '3548 41-2233',
    email: '',
    calle: 'Av. San Martin',
    numero: '1234',
    piso: '',
    referencia: '',
    destino: { codigoPostal: '5176', localidad: 'Villa Giardino', provincia: 'X', propio: true },
    ...cambios,
  };
}

// ------------------------------------------------------------------ bultos

test('un pedido de seis botellas viaja en una caja', () => {
  assert.equal(cajasADespachar(sueltas(6)), 1);
  assert.equal(bultosDelPedido(sueltas(6)).length, 1);
  assert.equal(pesoDelPedidoKg(sueltas(6)), CAJA_KG);
});

test('doce botellas son DOS cajas y pesan el doble', () => {
  assert.equal(cajasADespachar(sueltas(12)), 2);
  assert.equal(pesoDelPedidoKg(sueltas(12)), CAJA_KG * 2);
  // El defecto que tenia la maqueta: cotizar siempre una caja sola.
  assert.notEqual(pesoDelPedidoKg(sueltas(12)), pesoDelPedidoKg(sueltas(6)));
});

test('un pedido incompleto redondea para arriba: 7 botellas van en dos cajas', () => {
  assert.equal(cajasADespachar(sueltas(7)), 2);
});

test('un carrito vacio no despacha nada', () => {
  assert.equal(cajasADespachar(sueltas(0)), 0);
  assert.deepEqual(bultosDelPedido(sueltas(0)), []);
  assert.deepEqual(bultosDelPedido({ sueltas: 0, propias: [] }), []);
});

test('la regla es parametrica: con cajas de 3, seis botellas son dos cajas', () => {
  // El control positivo es la linea de arriba con el tamano por defecto: si
  // este numero no cambiara al cambiar el parametro, la constante estaria
  // clavada adentro.
  assert.equal(cajasADespachar(sueltas(6), 3), 2);
  assert.equal(cajasADespachar(sueltas(6)), 1);
});

test('una caja de cero o fraccionaria es un error, no un cero silencioso', () => {
  assert.throws(() => cajasADespachar(sueltas(6), 0), RangeError);
  assert.throws(() => cajasADespachar(sueltas(6), 1.5), RangeError);
});

test('cada bulto lleva peso y las tres medidas', () => {
  const bultos = bultosDelPedido(sueltas(6));
  assert.equal(bultos.length, 1);
  const b = bultos[0]!;
  assert.equal(b.pesoKg, CAJA_KG);
  assert.ok(b.largoCm > 0 && b.anchoCm > 0 && b.altoCm > 0);
});

// ------------------------------------------- lo que viene en su propia caja

test('un pack viaja en SU bulto, no adentro de la caja de seis', () => {
  // Seis sueltas + un pack de 2 son OCHO botellas. Contarlas juntas daba
  // ceil(8/6) = 2 bultos por casualidad; la cuenta correcta tambien da 2, pero
  // NO pesan lo mismo: el segundo bulto lleva dos botellas, no seis.
  const carga: CargaDelPedido = { sueltas: 6, propias: [2] };
  assert.equal(cajasADespachar(carga), 2);
  assert.equal(pesoDelPedidoKg(carga), CAJA_KG + pesoDelBultoKg(2));
  assert.ok(pesoDelPedidoKg(carga) < CAJA_KG * 2, 'un pack no pesa una caja entera');
});

test('seis botellas en tres packs son TRES bultos, no una caja', () => {
  // El defecto que corrige ADR 009 §10: aplanar a "6 botellas" hacia cotizar
  // UN bulto y entregarle tres al correo.
  const carga: CargaDelPedido = { sueltas: 0, propias: [2, 2, 2] };
  assert.equal(cajasADespachar(carga), 3);
  assert.notEqual(cajasADespachar(carga), cajasADespachar(sueltas(6)));
});

test('un pedido de un solo pack despacha un bulto', () => {
  assert.equal(cajasADespachar({ sueltas: 0, propias: [2] }), 1);
  assert.equal(pesoDelPedidoKg({ sueltas: 0, propias: [2] }), pesoDelBultoKg(2));
});

test('el peso de un bulto sale de la botella medida, y con seis da el declarado', () => {
  // El control de la calibracion: 1,118 kg por botella + 0,6 de embalaje, con
  // techo. Si alguien mueve la formula, este numero -el unico que estaba
  // escrito antes- se mueve con ella.
  assert.equal(pesoDelBultoKg(BOTELLAS_POR_CAJA), CAJA_KG);
  assert.equal(pesoDelBultoKg(2), 3);
  assert.ok(pesoDelBultoKg(2) < pesoDelBultoKg(6));
});

test('el bulto de un pack es mas angosto que la caja de seis, y nunca menos que una botella', () => {
  const pack = bultosDelPedido({ sueltas: 0, propias: [2] })[0]!;
  const caja = bultosDelPedido(sueltas(6))[0]!;
  assert.ok(pack.anchoCm < caja.anchoCm);
  assert.ok(pack.anchoCm >= 9);
  assert.equal(pack.largoCm, caja.largoCm, 'el largo es el de la botella: no escala');
});

// ------------------------------------------------------------------- total

test('el envio se suma al subtotal', () => {
  assert.equal(totalConEnvio(centavos(10910000), centavos(890000)), 11800000);
});

test('sin cotizacion todavia, el total es el de los vinos', () => {
  assert.equal(totalConEnvio(centavos(10910000), null), 10910000);
});

test('un envio sin cargo no cambia el total, y no es lo mismo que no tenerlo', () => {
  assert.equal(totalConEnvio(centavos(10910000), centavos(0)), 10910000);
});

// ---------------------------------------------------------------- telefono

test('un numero como se disca en Argentina queda en E.164 movil', () => {
  assert.equal(normalizarTelefonoAR('3548 41-2233'), '+5493548412233');
});

test('el 15 se saca: no existe en E.164', () => {
  assert.equal(normalizarTelefonoAR('03548 15 41-2233'), '+5493548412233');
  assert.equal(normalizarTelefonoAR('011 15 6789-0000'), '+5491167890000');
});

test('un numero que ya viene completo no se rompe al normalizarlo dos veces', () => {
  const una = normalizarTelefonoAR('+54 9 3548 41-2233');
  assert.equal(una, '+5493548412233');
  assert.equal(normalizarTelefonoAR(una as string), una);
});

test('un numero corto o largo devuelve null, no un E.164 inventado', () => {
  assert.equal(normalizarTelefonoAR('412233'), null);
  assert.equal(normalizarTelefonoAR('354841223399'), null);
  assert.equal(normalizarTelefonoAR(''), null);
});

// -------------------------------------------------- datos de la entrega

test('los datos completos validan y devuelven el telefono normalizado', () => {
  const r = validarDatosDeEntrega(entrega());
  assert.ok(r.ok);
  assert.equal(r.valor.telefonoE164, '+5493548412233');
  assert.equal(r.valor.email, null);
  assert.equal(r.valor.piso, null);
  assert.equal(r.valor.destino.propio, true);
  assert.equal(r.valor.destino.provincia, 'X');
});

test('la provincia va en ISO, no por su nombre: el correo espera el codigo', () => {
  // Control positivo arriba: con 'X' valida. Con el nombre, no.
  const r = validarDatosDeEntrega(
    entrega({ destino: { codigoPostal: '5176', localidad: 'Villa Giardino', provincia: 'Cordoba' } }),
  );
  assert.equal(r.ok, false);
  assert.equal(r.ok === false && r.motivo, 'provincia');
});

test('el email es opcional, y si esta tiene que ser un email', () => {
  const sin = validarDatosDeEntrega(entrega({ email: '' }));
  assert.ok(sin.ok);
  const con = validarDatosDeEntrega(entrega({ email: 'vos@ejemplo.com' }));
  assert.ok(con.ok);
  assert.equal(con.valor.email, 'vos@ejemplo.com');
  const roto = validarDatosDeEntrega(entrega({ email: 'vos@' }));
  assert.equal(roto.ok, false);
});

test('falta el numero de la calle: no valida', () => {
  const r = validarDatosDeEntrega(entrega({ numero: '   ' }));
  assert.equal(r.ok, false);
  assert.equal(r.ok === false && r.motivo, 'numero');
});

test('un telefono que no se puede normalizar no valida', () => {
  const r = validarDatosDeEntrega(entrega({ telefono: '1234' }));
  assert.equal(r.ok, false);
  assert.equal(r.ok === false && r.motivo, 'telefono');
});

test('un codigo postal que no son cuatro digitos no valida', () => {
  for (const cp of ['X5176', '517', '51766', '']) {
    const r = validarDatosDeEntrega(entrega({ destino: { codigoPostal: cp, localidad: 'x', provincia: 'X' } }));
    assert.equal(r.ok, false, `acepto ${cp}`);
  }
});

test('sin destino no valida: el codigo postal es lo que decide como viaja', () => {
  const r = validarDatosDeEntrega(entrega({ destino: undefined }));
  assert.equal(r.ok, false);
});

test('lo que no es un objeto no valida', () => {
  assert.equal(validarDatosDeEntrega(null).ok, false);
  assert.equal(validarDatosDeEntrega('Agustin').ok, false);
});
