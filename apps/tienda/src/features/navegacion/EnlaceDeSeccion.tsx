'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';

import type { Seccion } from './secciones';

/* Un enlace de la barra, y la única pieza cliente de la navegación.
 *
 * Es cliente por una sola razón: `aria-current="page"`. En el App Router un
 * layout no conoce la ruta activa, y sin marcar cuál es la página en la que
 * estás, la barra es una lista de enlaces, no una navegación.
 *
 * El costo se midió antes de aceptarlo: el resto de la barra —y las cuatro
 * escenas de la home— siguen siendo servidor. Lo que baja al bundle es este
 * archivo y `usePathname`, no el `<header>`.
 *
 * ⚠️ El subrayado NO es `text-decoration`. Es un pseudo-elemento con la
 * geometría del filete de la marca, porque un subrayado de navegador sobre una
 * versalita con tracking abierto corta las serifas por la mitad.
 */

type Props = {
  seccion: Seccion;
};

export function EnlaceDeSeccion({ seccion }: Props) {
  const ruta = usePathname();

  /* `/vinos` sigue activa dentro de `/vinos/<slug>`: la ficha de un vino no es
   * otra sección, es más adentro de la misma. La igualdad exacta sola dejaría
   * la barra sin ninguna sección marcada justo en la página más profunda. */
  const activa = ruta === seccion.href || ruta.startsWith(`${seccion.href}/`);

  return (
    <Link
      className="barra__enlace versalita"
      href={seccion.href}
      aria-current={activa ? 'page' : undefined}
    >
      {seccion.nombre}
    </Link>
  );
}
