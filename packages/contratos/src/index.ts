/**
 * @bouquet/contratos - lo que los tres lados tienen que entender igual.
 *
 * Lo importan directo: functions/ y apps/tienda/ (TypeScript).
 * Lo espeja: apps/admin/ (Dart), con un test contra generated/contratos.json
 * y `scripts/ci/auditar_estados.mjs` verificando que ese JSON este fresco.
 *
 * Sin esa verificacion de frescura el JSON envejece, el test de Dart pasa
 * contra un contrato que ya no existe, y el test se vuelve teatro.
 */

export * from './orden.ts';
export * from './proyeccion.ts';
export * from './dinero.ts';
