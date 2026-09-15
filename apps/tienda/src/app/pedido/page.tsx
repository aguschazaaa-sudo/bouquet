import type { Metadata, Viewport } from 'next';

import { PaginaDelCheckout } from '@/features/carrito/checkout/PaginaDelCheckout';
import { SELLO } from '@/features/oficio/oficio';
import { obtenerCatalogo } from '@/server/catalogo';
import { cotizarEnvio } from '@/server/envios';
import { COLORES } from '@/shared/tokens/colores';

/* /pedido — terminar la compra. Papel sin excepción (direccion.md §3).
 *
 * `app/` compone lo que las features no pueden pedirse entre sí (ADR 006 regla
 * 3): la proyección del catálogo, el WhatsApp —que es de `oficio/` y lleva su
 * propio gate— y la Server Action que cotiza el envío, que vive en `server/`
 * porque ahí es donde va a estar la credencial del proveedor y un `'use
 * client'` no puede importarla.
 *
 * Es la MISMA proyección de /vinos y /carrito: comparten la entrada de caché,
 * así que esta pantalla cuesta cero lecturas de más.
 *
 * ⚠️ NO COBRA. `EL_CHECKOUT_NO_COBRA` en `features/carrito/checkout/textos.ts`
 * está en `true` y sale al HTML como `data-checkout-simulado`. */

export const revalidate = 60;

export const metadata: Metadata = {
  title: 'Terminar la compra — bouquet',
  /* `noindex`: un checkout es de una persona, no del buscador. */
  robots: { index: false, follow: false },
};

export const viewport: Viewport = {
  themeColor: COLORES.papel,
  colorScheme: 'light',
};

export default async function Pedido() {
  const { productos } = await obtenerCatalogo();
  const whatsapp = SELLO.canales[0]?.href ?? '';

  return <PaginaDelCheckout productos={productos} cotizar={cotizarEnvio} whatsapp={whatsapp} />;
}
