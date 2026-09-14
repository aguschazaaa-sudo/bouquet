import type { ProductoPublicado } from '@bouquet/contratos';

import { SiluetaDeBotella } from './SiluetaDeBotella';
import { TEXTOS } from './textos';

/* La ventana de la botella: papel cálido con su lámpara, y la botella parada
 * adentro. design.md §9.
 *
 * `mix-blend-mode: multiply` absorbe el blanco del JPG de vinoteca en el papel,
 * y el PNG transparente de bodega cae limpio. La altura la iguala el recorte
 * que hizo el seed al borde de la botella (`sharp().trim()`), no el CSS:
 * `object-fit` no sabe dónde está la botella dentro del cuadro. Lo encontraron
 * las dos maquetas por separado.
 *
 * `<img>` y no `next/image`, a propósito: en App Hosting el optimizador corre en
 * Cloud Run y cobra CPU por transformación (ADR 005 §5), y la foto ya llega en
 * WebP, recortada y a su tamaño desde Storage.
 */

type Props = {
  producto: Pick<ProductoPublicado, 'nombre' | 'imagenes'>;
  /** En la tarjeta la foto va adentro de un enlace que ya dice el nombre. */
  decorativa?: boolean;
  tamano?: 'tarjeta' | 'ficha' | 'linea';
  /** La primera fila y la ficha cargan de entrada; el resto, cuando se acerca. */
  prioridad?: boolean;
};

export function VentanaDeBotella({ producto, decorativa = false, tamano = 'tarjeta', prioridad = false }: Props) {
  const foto = producto.imagenes[0];

  return (
    <div className={`ventana-botella ventana-botella--${tamano}`}>
      {foto ? (
        <img
          className="ventana-botella__foto"
          src={foto}
          alt={decorativa ? '' : `La botella de ${producto.nombre}`}
          loading={prioridad ? 'eager' : 'lazy'}
          fetchPriority={prioridad ? 'high' : 'auto'}
          decoding="async"
        />
      ) : (
        <div className="ventana-botella__sin-foto">
          <SiluetaDeBotella />
          <span className="versalita">{TEXTOS.sinFoto}</span>
        </div>
      )}
    </div>
  );
}
