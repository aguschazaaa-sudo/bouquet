/**
 * Las credenciales de Mercado Pago, en Secret Manager.  ADR 022 §6.
 *
 * ⚠️ DESDE EL 2026-09-28 EXISTEN CON VALORES FALSOS (etiqueta `valor=falso`),
 * para poder desplegar antes de que el dueno pase los de su cuenta: aleatorios,
 * con prefijo `FALSO-`.  Con el token falso toda consulta a Mercado Pago falla
 * (401) y NO se escribe nada: el aviso contesta 500 y `revisarPago` dice
 * "Mercado Pago no contesto".  Para poner los reales:
 * `firebase functions:secrets:set MERCADOPAGO_ACCESS_TOKEN` (y
 * `MERCADOPAGO_SECRETO_DE_FIRMA`), y VOLVER A DESPLEGAR `avisoDeMercadoPago` y
 * `revisarPago`: una function desplegada no toma sola la version nueva.
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
