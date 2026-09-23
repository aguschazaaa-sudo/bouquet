/**
 * La puerta de las callables del panel.
 *
 * Las reglas de Firestore y de Storage NO protegen una callable: corre con el
 * Admin SDK y las saltea por diseno.  Esto es lo unico que la protege, asi
 * que vive en UN lugar y lo usan todas -`procesarFoto` y `moverStock`-: dos
 * copias de una guarda de seguridad se desincronizan (LECCIONES 6.4), y la
 * que queda vieja es la que deja pasar a alguien.
 *
 * Devuelve el `uid`, porque una callable que escribe plata tiene que dejar
 * dicho QUIEN lo hizo.
 */
import { HttpsError, type CallableRequest } from 'firebase-functions/v2/https';

export function exigirAdmin(request: Pick<CallableRequest<unknown>, 'auth'>): string {
  if (!request.auth) {
    throw new HttpsError('unauthenticated', 'hace falta estar autenticado');
  }
  if (request.auth.token['rol'] !== 'admin') {
    throw new HttpsError('permission-denied', 'hace falta el rol admin');
  }
  return request.auth.uid;
}
