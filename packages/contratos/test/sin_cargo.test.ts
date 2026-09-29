/**
 * El envio sin cargo desde un monto (HU-11.1, ADR 026). Toca plata: cada regla
 * con el lado que aplica y el que no.
 */

import { test } from 'node:test';
import assert from 'node:assert/strict';

import { centavos } from '../src/dinero.ts';
import { SIN_CARGO, type OpcionDeEnvio } from '../src/envio.ts';
import {
  cajaTipica,
  conEnvioSinCargo,
  faltaParaSinCargo,
  leerConfigDeEnvios,
  MINIMO_PARA_LA_MEDIANA,
  motivoParaConfirmar,
  parsearPedidoDeSinCargo,
  saleSinCargo,
  SIN_CARGO_MAXIMO,
  SIN_CARGO_MINIMO,
} from '../src/sin_cargo.ts';

const pesos = (n: number) => centavos(n * 100);

const opcion = (id: string, precio: number): OpcionDeEnvio => ({
  id,
  modalidad: id === 'sucursal' ? 'sucursal' : 'domicilio',
  nombre: id,
  detalle: '',
  precio: pesos(precio),
  desdeDias: 3,
  hastaDias: 5,
  transportista: 'correo',
});

const OPCIONES = [opcion('domicilio', 9000), opcion('sucursal', 6500)];

// ------------------------------------------------------------ leer el documento

test('leerConfigDeEnvios: sin documento es apagado, y no es un documento roto', () => {
  assert.deepEqual(leerConfigDeEnvios(undefined), { sinCargoDesde: null, roto: false });
  assert.deepEqual(leerConfigDeEnvios(null), { sinCargoDesde: null, roto: false });
  assert.deepEqual(leerConfigDeEnvios({ sinCargoDesde: null }), { sinCargoDesde: null, roto: false });
});

test('leerConfigDeEnvios: un umbral sano se lee', () => {
  assert.deepEqual(leerConfigDeEnvios({ sinCargoDesde: 15_000_000, actualizadoPor: 'x' }), {
    sinCargoDesde: 15_000_000,
    roto: false,
  });
});

test('leerConfigDeEnvios: ROTO se lee como APAGADO, nunca como sin cargo desde 0', () => {
  for (const malo of [0, -100, 150.5, 15_000_050, '150000', SIN_CARGO_MAXIMO + 100, Number.MAX_SAFE_INTEGER + 1, true, {}]) {
    assert.deepEqual(leerConfigDeEnvios({ sinCargoDesde: malo }), { sinCargoDesde: null, roto: true }, String(malo));
  }
  assert.deepEqual(leerConfigDeEnvios({}), { sinCargoDesde: null, roto: true });
  assert.deepEqual(leerConfigDeEnvios('config'), { sinCargoDesde: null, roto: true });
  assert.deepEqual(leerConfigDeEnvios([15_000_000]), { sinCargoDesde: null, roto: true });
});

// --------------------------------------------------------------- aplicarlo

test('saleSinCargo: desde el umbral inclusive, y nunca sin umbral', () => {
  assert.equal(saleSinCargo(pesos(150_000), pesos(150_000)), true);
  assert.equal(saleSinCargo(pesos(150_001), pesos(150_000)), true);
  assert.equal(saleSinCargo(centavos(14_999_999), pesos(150_000)), false);
  assert.equal(saleSinCargo(pesos(10_000_000), null), false);
});

test('conEnvioSinCargo: al llegar, TODAS las opciones salen sin cargo', () => {
  const r = conEnvioSinCargo(OPCIONES, pesos(200_000), pesos(150_000));
  assert.deepEqual(
    r.map((o) => o.precio),
    [SIN_CARGO, SIN_CARGO],
  );
  // Lo demas de la opcion queda igual: plazo, nombre, transportista.
  assert.equal(r[0]!.hastaDias, 5);
  assert.equal(r[1]!.id, 'sucursal');
});

test('conEnvioSinCargo: sin llegar, o sin umbral, la MISMA lista con sus precios', () => {
  assert.equal(conEnvioSinCargo(OPCIONES, pesos(100_000), pesos(150_000)), OPCIONES);
  assert.equal(conEnvioSinCargo(OPCIONES, pesos(900_000), null), OPCIONES);
  assert.deepEqual(
    OPCIONES.map((o) => o.precio),
    [pesos(9000), pesos(6500)],
  );
});

test('faltaParaSinCargo: la diferencia exacta, o null si ya llega o no hay umbral', () => {
  assert.equal(faltaParaSinCargo(pesos(120_000), pesos(150_000)), pesos(30_000));
  assert.equal(faltaParaSinCargo(centavos(14_999_999), pesos(150_000)), centavos(1));
  assert.equal(faltaParaSinCargo(pesos(150_000), pesos(150_000)), null);
  assert.equal(faltaParaSinCargo(pesos(10), null), null);
});

// --------------------------------------------------------------- la callable

test('parsearPedidoDeSinCargo: un monto sano, con y sin confirmar', () => {
  assert.deepEqual(parsearPedidoDeSinCargo({ sinCargoDesde: 15_000_000 }), {
    ok: true,
    valor: { sinCargoDesde: 15_000_000, confirmado: false },
  });
  assert.deepEqual(parsearPedidoDeSinCargo({ sinCargoDesde: 15_000_000, confirmado: true }), {
    ok: true,
    valor: { sinCargoDesde: 15_000_000, confirmado: true },
  });
});

test('parsearPedidoDeSinCargo: apagar es null', () => {
  assert.deepEqual(parsearPedidoDeSinCargo({ sinCargoDesde: null }), {
    ok: true,
    valor: { sinCargoDesde: null, confirmado: false },
  });
});

test('parsearPedidoDeSinCargo: los topes duros, con sus bordes', () => {
  assert.equal(parsearPedidoDeSinCargo({ sinCargoDesde: SIN_CARGO_MINIMO }).ok, true);
  assert.equal(parsearPedidoDeSinCargo({ sinCargoDesde: SIN_CARGO_MAXIMO }).ok, true);
  for (const malo of [0, 99, -100, SIN_CARGO_MAXIMO + 100, 150_050, 1500.5, '150000', undefined, true]) {
    assert.equal(parsearPedidoDeSinCargo({ sinCargoDesde: malo }).ok, false, String(malo));
  }
});

test('parsearPedidoDeSinCargo: nada de campos de mas, ni un confirmado que no es booleano', () => {
  assert.equal(parsearPedidoDeSinCargo({ sinCargoDesde: 15_000_000, actualizadoPor: 'otro' }).ok, false);
  assert.equal(parsearPedidoDeSinCargo({ sinCargoDesde: 15_000_000, confirmado: 'si' }).ok, false);
  assert.equal(parsearPedidoDeSinCargo(null).ok, false);
  assert.equal(parsearPedidoDeSinCargo([15_000_000]).ok, false);
});

// ------------------------------------------------------------- la baranda

const sueltas = (...precios: number[]) => precios.map((p) => ({ precio: pesos(p), botellas: 1 }));

test('cajaTipica: seis botellas a la mediana del precio POR BOTELLA', () => {
  // Impar: la del medio. 10, 20, 30, 40, 50 -> 30 x 6.
  assert.equal(cajaTipica(sueltas(50_000, 10_000, 30_000, 20_000, 40_000)), pesos(180_000));
  // Par: el promedio de las dos del medio. 10, 20, 30, 40, 50, 60 -> 35 x 6.
  assert.equal(cajaTipica(sueltas(10_000, 20_000, 30_000, 40_000, 50_000, 60_000)), pesos(210_000));
  // Un estuche de dos a 60.000 son dos botellas de 30.000: no corre la mediana.
  assert.equal(
    cajaTipica([...sueltas(10_000, 20_000, 40_000, 50_000), { precio: pesos(60_000), botellas: 2 }]),
    pesos(180_000),
  );
});

test('cajaTipica: con menos de MINIMO_PARA_LA_MEDIANA no dice nada, y lo roto no cuenta', () => {
  assert.equal(MINIMO_PARA_LA_MEDIANA, 5);
  assert.equal(cajaTipica(sueltas(10_000, 20_000, 30_000, 40_000)), null);
  assert.equal(
    cajaTipica([...sueltas(10_000, 20_000, 30_000, 40_000), { precio: 0, botellas: 1 }, { precio: 5, botellas: 0 }]),
    null,
  );
});

test('motivoParaConfirmar: por debajo de una caja tipica, AUN EN LA PRIMERA escritura', () => {
  const caja = pesos(180_000);
  assert.deepEqual(motivoParaConfirmar(pesos(15_000), { anterior: null, cajaTipica: caja }), {
    motivo: 'debajo-de-una-caja',
    cajaTipica: caja,
  });
  // El borde: una caja tipica exacta ya no pide confirmar.
  assert.equal(motivoParaConfirmar(caja, { anterior: null, cajaTipica: caja }), null);
});

test('motivoParaConfirmar: bajar a menos de la mitad del anterior', () => {
  assert.deepEqual(motivoParaConfirmar(pesos(99_000), { anterior: pesos(200_000), cajaTipica: null }), {
    motivo: 'menos-de-la-mitad',
    anterior: pesos(200_000),
  });
  // Justo la mitad no: "menos de".
  assert.equal(motivoParaConfirmar(pesos(100_000), { anterior: pesos(200_000), cajaTipica: null }), null);
});

test('motivoParaConfirmar: subir, o un catalogo que no discrimina, no pide nada', () => {
  assert.equal(motivoParaConfirmar(pesos(900_000), { anterior: pesos(200_000), cajaTipica: pesos(180_000) }), null);
  assert.equal(motivoParaConfirmar(pesos(15_000), { anterior: null, cajaTipica: null }), null);
});

test('motivoParaConfirmar: la caja gana sobre la mitad, porque dice mas', () => {
  const r = motivoParaConfirmar(pesos(10_000), { anterior: pesos(200_000), cajaTipica: pesos(180_000) });
  assert.equal(r?.motivo, 'debajo-de-una-caja');
});
