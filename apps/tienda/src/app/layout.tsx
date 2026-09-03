import type { Metadata } from 'next';
import type { ReactNode } from 'react';

export const metadata: Metadata = {
  title: 'bouquet',
  description: 'Tienda de vinos',
};

// Andamio. La direccion visual la define /disenio y todavia no corrio: no
// existen docs/vault/design/direccion.md ni tokens.md. No agregar fuentes,
// paleta ni layout hasta entonces -- el primer componente que se escriba fija
// la escala tipografica y el espaciado del proyecto entero, casi siempre sin
// que nadie lo haya decidido.
export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="es-AR">
      <body>{children}</body>
    </html>
  );
}
