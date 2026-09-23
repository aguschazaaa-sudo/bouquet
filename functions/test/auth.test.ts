import { test } from 'node:test';
import assert from 'node:assert/strict';

import { exigirAdmin } from '../src/auth.ts';

// Lo que le llega a una callable: `auth` con el uid y el token decodificado.
const conToken = (token: Record<string, unknown>, uid = 'operador') =>
  ({ auth: { uid, token } }) as unknown as Parameters<typeof exigirAdmin>[0];

const codigoDe = (fn: () => unknown): string | undefined => {
  try {
    fn();
  } catch (e) {
    return (e as { code?: string }).code;
  }
  return undefined;
};

test('control positivo: con el claim rol:admin pasa y devuelve el uid', () => {
  assert.equal(exigirAdmin(conToken({ rol: 'admin' }, 'la-duena')), 'la-duena');
});

test('sin sesion: unauthenticated', () => {
  assert.equal(codigoDe(() => exigirAdmin({ auth: undefined })), 'unauthenticated');
});

test('con sesion pero sin el claim: permission-denied', () => {
  assert.equal(codigoDe(() => exigirAdmin(conToken({}))), 'permission-denied');
});

test('con otro rol, o el rol mal escrito: permission-denied', () => {
  for (const rol of ['comprador', 'Admin', 'ADMIN', ' admin', '', null, true, 1]) {
    assert.equal(codigoDe(() => exigirAdmin(conToken({ rol }))), 'permission-denied', String(rol));
  }
});

test('que el mail diga admin no da el permiso: solo el claim', () => {
  assert.equal(codigoDe(() => exigirAdmin(conToken({ email: 'admin@bouquet.test', admin: true }))), 'permission-denied');
});
