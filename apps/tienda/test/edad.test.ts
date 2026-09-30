import { test } from 'node:test';
import assert from 'node:assert/strict';

import { CLAVE_EDAD, SCRIPT_EDAD, marcaDeMayoria } from '../src/features/edad/edad.ts';

/* El script en línea corre en el navegador antes de React, así que no lo
 * cubre nada más: si se desincroniza de lo que guarda `PuertaDeEdad`, quien
 * ya entró vuelve a ver el telón en cada carga y ningún tipo se queja. Se
 * corre acá con un `document` y un `localStorage` de mentira. */
function correrScript(guardado: Record<string, string>, tira = false): string | undefined {
  const dataset: Record<string, string> = {};
  const localStorage = {
    getItem(clave: string) {
      if (tira) throw new Error('SecurityError: localStorage bloqueado');
      return clave in guardado ? guardado[clave] : null;
    },
  };
  const document = { documentElement: { dataset } };
  new Function('localStorage', 'document', SCRIPT_EDAD)(localStorage, document);
  return dataset.edad;
}

test('lo que guarda la puerta es lo que acepta el script en línea', () => {
  const marca = marcaDeMayoria(new Date('2026-09-30T12:00:00Z'));
  assert.equal(correrScript({ [CLAVE_EDAD]: marca }), 'ok');
});

test('la marca guarda un booleano y una fecha, y nada de nacimiento', () => {
  const marca = JSON.parse(marcaDeMayoria(new Date('2026-09-30T12:00:00Z')));
  assert.deepEqual(Object.keys(marca).sort(), ['fecha', 'mayor']);
  assert.equal(marca.mayor, true);
  assert.equal(marca.fecha, '2026-09-30T12:00:00.000Z');
});

test('sin marca, con otra clave, o con la marca en false, el telón queda puesto', () => {
  const marca = marcaDeMayoria(new Date());
  assert.equal(correrScript({}), undefined);
  // La misma marca bajo otra clave: prueba que el script lee CLAVE_EDAD.
  assert.equal(correrScript({ 'bouquet.carrito': marca }), undefined);
  assert.equal(correrScript({ [CLAVE_EDAD]: JSON.stringify({ mayor: false }) }), undefined);
  assert.equal(correrScript({ [CLAVE_EDAD]: JSON.stringify({ mayor: 'true' }) }), undefined);
});

test('basura guardada o localStorage bloqueado no rompen la página', () => {
  assert.equal(correrScript({ [CLAVE_EDAD]: 'ok' }), undefined);
  assert.equal(correrScript({ [CLAVE_EDAD]: '{' }), undefined);
  assert.equal(correrScript({ [CLAVE_EDAD]: 'null' }), undefined);
  assert.equal(correrScript({}, true), undefined);
});
