/**
 * Las credenciales de Mercado Pago, en Secret Manager.  ADR 022 §6.
 *
 * ⚠️ HOY NO EXISTEN (2026-09-28): el dueno todavia no paso las de prueba.  El
 * CLI valida los secretos de las functions que despliega, asi que un
 * `firebase deploy --only functions` a secas deberia fallar mientras falten
 * (NO medido).  Hasta que existan, el deploy de functions va NOMBRANDO las que
 * no los usan (`--only functions:cancelarOrden,...`).  Se cargan con
 * `firebase functions:secrets:set MERCADOPAGO_ACCESS_TOKEN` y
 * `... MERCADOPAGO_SECRETO_DE_FIRMA`.
 *
 * Nunca salen del servidor: la vidriera no las ve, el panel tampoco.
 */
import { defineSecret } from 'firebase-functions/params';

import type { ProveedorDePago } from '@bouquet/contratos';

import { clienteDelSdk, proveedorMercadoPago } from './mercadopago.ts';

const TOKEN = defineSecret('MERCADOPAGO_ACCESS_TOKEN');
const FIRMA = defineSecret('MERCADOPAGO_SECRETO_DE_FIRMA');

/** Lo que declara cada function que habla con Mercado Pago. */
export const SECRETOS_DE_MERCADO_PAGO = [TOKEN, FIRMA];

/** El proveedor de verdad.  Se arma DENTRO del handler: `.value()` no existe al cargar el modulo. */
export function proveedorDeProduccion(): ProveedorDePago {
  return proveedorMercadoPago(clienteDelSdk(TOKEN.value()), FIRMA.value());
}
