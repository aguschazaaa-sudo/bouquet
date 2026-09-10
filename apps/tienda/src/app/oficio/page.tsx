import type { Metadata } from 'next';

import { SeccionOficio } from '@/features/oficio/SeccionOficio';

/* /oficio — el oficio completo, en tres tramos.
 *
 * Reemplaza a `/custodia` y absorbe a `/contacto`. "Custodia" nombraba sólo el
 * tramo del medio; acá pasa a ser el nombre de ese tramo, que es donde la
 * palabra rinde. Y el contacto no es una sección aparte: es el final del arco
 * —quién es "nosotros"—, así que va como cierre de esta página, en `#mostrador`.
 *
 * ⚠️ Tiene que leerse SIN haber visto la home: llega gente por un enlace mandado
 * a mano por WhatsApp, sin pasar por la portada. Por eso la sección no importa
 * nada de `features/landing/` y repite con sus palabras lo que la home dice con
 * las suyas.
 *
 * Cero lecturas de Firestore por visitante. El contenido vive en `oficio.ts`,
 * así que esto es HTML estático que sólo cambia cuando cambia el diseño: no
 * entra al circuito de purga por tag del ADR 004 y no toca la cuota de 50.000
 * lecturas/día.
 */

export const metadata: Metadata = {
  title: 'El oficio — bouquet',
  description:
    'Entre la bodega y tu mesa hay tres tramos: elegir, guardar y abrir. Trabajamos los dos primeros.',
};

export default function Oficio() {
  return (
    <>
      <SeccionOficio />

      {/* El grano va último y por encima de todo, igual que en la home: disuelve
          las bandas que los dos degradés de fondo hacen en una pantalla de 8
          bits. Es de `shared/deco/` y va en la PÁGINA, no en la sección, porque
          es `position: fixed` y cubre el viewport entero. */}
      <div className="grano" aria-hidden="true" />
    </>
  );
}
